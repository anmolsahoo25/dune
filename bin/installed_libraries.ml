open Stdune
open Import

let doc = "Print out libraries installed on the system."

let info = Term.info "installed-libraries" ~doc

let term =
  let+ common = Common.term
  and+ na =
    Arg.(
      value & flag
      & info [ "na"; "not-available" ]
          ~doc:"List libraries that are not available and explain why")
  in
  Common.set_common common ~targets:[];
  let capture_outputs = Common.capture_outputs common in
  let _env : Env.t = Import.Main.setup_env ~capture_outputs in
  Scheduler.go ~common (fun () ->
      let open Fiber.O in
      let () = Workspace.init () in
      let* ctxs = Context.DB.all () in
      let ctx = List.hd ctxs in
      let findlib = ctx.findlib in
      if na then (
        let broken =
          List.map (Findlib.all_broken_packages findlib) ~f:(fun (name, _) ->
              (Lib_name.of_package_name name, "invalid dune file"))
        in
        let hidden =
          List.filter_map (Findlib.all_packages findlib) ~f:(function
            | Hidden_library lib ->
              Some
                ( Dune_package.Lib.info lib |> Dune.Lib_info.name
                , "unsatisfied 'exist_if'" )
            | _ -> None)
        in
        let all =
          List.sort (broken @ hidden) ~compare:(fun (a, _) (b, _) ->
              Lib_name.compare a b)
        in
        let longest =
          String.longest_map all ~f:(fun (n, _) -> Lib_name.to_string n)
        in
        let ppf = Format.std_formatter in
        List.iter all ~f:(fun (n, r) ->
            Format.fprintf ppf "%-*s -> %s@\n" longest (Lib_name.to_string n) r);
        Format.pp_print_flush ppf ();
        Fiber.return ()
      ) else
        let pkgs =
          List.filter (Findlib.all_packages findlib) ~f:(function
            | Dune_package.Entry.Hidden_library _ -> false
            | _ -> true)
        in
        let max_len =
          String.longest_map pkgs ~f:(fun e ->
              Lib_name.to_string (Dune_package.Entry.name e))
        in
        List.iter pkgs ~f:(fun e ->
            let ver =
              match Dune_package.Entry.version e with
              | Some v -> v
              | _ -> "n/a"
            in
            Printf.printf "%-*s (version: %s)\n" max_len
              (Lib_name.to_string (Dune_package.Entry.name e))
              ver);
        Fiber.return ())

let command = (term, info)
