open Import

type effective =
  { loc : Loc.t
  ; alias : Alias.Name.Set.t
  ; deps : unit Build.t list
  ; enabled_if : Blang.t list
  }

let empty_effective =
  { loc = Loc.none
  ; alias = Alias.Name.Set.singleton Alias.Name.runtest
  ; enabled_if = [ Blang.true_ ]
  ; deps = []
  }

let missing_run_t (error : Cram.test) =
  Build.fail
    { fail =
        (fun () ->
          let dir =
            match error with
            | File _ ->
              (* This error is impossible for file tests *)
              assert false
            | Dir { dir; file = _ } -> dir
          in
          User_error.raise
            [ Pp.textf "Cram test directory %s does not contain a run.t file."
                (Path.Source.to_string dir)
            ])
    }
  |> Build.with_no_targets

let test_rule ~sctx ~expander ~dir (spec : effective)
    (test : (Cram.test, File_tree.Dir.error) result) =
  let module Alias_rules = Simple_rules.Alias_rules in
  let enabled = Expander.eval_blang expander (Blang.And spec.enabled_if) in
  let loc = Some spec.loc in
  let aliases =
    Alias.Name.Set.to_list spec.alias |> List.map ~f:(Alias.make ~dir)
  in
  let test_name =
    match test with
    | Ok t -> Cram.name t
    | Error (Missing_run_t t) -> Cram.name t
  in
  let stamp_no_rule () = (Path.Build.to_dyn dir, "no-cram-rules", test_name) in
  match test with
  | Error (Missing_run_t test) ->
    (* We error out on invalid tests even if they are disabled. *)
    List.iter aliases ~f:(fun alias ->
        Alias_rules.add sctx ~alias ~stamp:(stamp_no_rule ()) ~loc ~locks:[]
          (missing_run_t test))
  | Ok test -> (
    match enabled with
    | false ->
      List.iter aliases ~f:(fun alias ->
          Alias_rules.add_empty sctx ~alias ~loc ~stamp:(stamp_no_rule ()))
    | true ->
      let prefix_with, _ = Path.Build.extract_build_context_dir_exn dir in
      let script = Path.Build.append_source prefix_with (Cram.script test) in
      let action =
        Action.progn
          [ Action.Cram (Path.build script)
          ; Diff
              { Diff.optional = true
              ; mode = Text
              ; file1 = Path.build script
              ; file2 = Path.Build.extend_basename script ~suffix:".corrected"
              }
          ]
      in
      let stamp =
        (Path.Build.to_dyn dir, Action.for_shell action, Cram.name test)
      in
      let cram =
        let open Build.O in
        let+ () = Build.path (Path.build script)
        and+ () = Build.all_unit spec.deps
        and+ (_ : Path.Set.t) =
          match test with
          | File _ -> Build.return Path.Set.empty
          | Dir { dir; file = _ } ->
            let dir = Path.build (Path.Build.append_source prefix_with dir) in
            Build.source_tree ~dir
        and+ () =
          Build.dep (Dep.sandbox_config Sandbox_config.needs_sandboxing)
        in
        action
      in
      let cram = Build.with_no_targets cram in
      List.iter aliases ~f:(fun alias ->
          Alias_rules.add sctx ~alias ~stamp ~loc cram ~locks:[]) )

let rules ~sctx ~expander ~dir tests =
  let stanzas =
    let stanzas dir ~f =
      match Super_context.stanzas_in sctx ~dir with
      | None -> []
      | Some (d : Stanza.t list Dir_with_dune.t) ->
        List.filter_map d.data ~f:(function
          | Dune_file.Cram c -> Option.some_if (f c) (dir, c)
          | _ -> None)
    in
    let rec collect_whole_subtree acc dir =
      let acc =
        stanzas dir ~f:(fun (s : Cram.Stanza.t) -> s.applies_to = Whole_subtree)
        :: acc
      in
      match Path.Build.parent dir with
      | None -> List.concat acc
      | Some dir -> collect_whole_subtree acc dir
    in
    let acc = stanzas dir ~f:(fun _ -> true) in
    match Path.Build.parent dir with
    | None -> acc
    | Some dir -> collect_whole_subtree [ acc ] dir
  in
  List.iter tests ~f:(fun test ->
      let name =
        match test with
        | Ok test -> Cram.name test
        | Error (File_tree.Dir.Missing_run_t test) -> Cram.name test
      in
      let effective =
        let init =
          let alias =
            Alias.Name.of_string name
            |> Alias.Name.Set.add empty_effective.alias
          in
          { empty_effective with alias }
        in
        List.fold_left stanzas ~init
          ~f:(fun acc (dir, (spec : Cram.Stanza.t)) ->
            match
              match spec.applies_to with
              | Whole_subtree -> true
              | Files_matching_in_this_dir pred ->
                Predicate_lang.Glob.exec pred
                  ~standard:Predicate_lang.Glob.true_ name
            with
            | false -> acc
            | true ->
              let deps =
                match spec.deps with
                | None -> acc.deps
                | Some deps ->
                  let deps : unit Build.t =
                    let expander = Super_context.expander sctx ~dir in
                    let open Build.O in
                    let+ (_ : Path.t Bindings.t) =
                      Dep_conf_eval.named ~expander deps
                    in
                    ()
                  in
                  deps :: acc.deps
              in
              let enabled_if = spec.enabled_if :: acc.enabled_if in
              let alias =
                match spec.alias with
                | None -> acc.alias
                | Some a -> Alias.Name.Set.add acc.alias a
              in
              { acc with enabled_if; deps; alias })
      in
      test_rule ~sctx ~expander ~dir effective test)
