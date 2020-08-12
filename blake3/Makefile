all:
	ocamlc.opt -c -o blake3.cmi blake3.mli
	ocamlc.opt -c -o blake3.cmo blake3.ml
	ocamlc.opt -a -o blake3.cma -cclib -lblake3_stubs blake3.cmo
	ocamlc.opt -c blake3_stubs.c -o blake3_stubs.o
	gcc -O3 -fPIC -c -DBLAKE3_NO_AVX512 blake3_dispatch.c -o blake3_dispatch.o
	gcc -O3 -fPIC -c -DBLAKE3_NO_AVX512 blake3_portable.c -o blake3_portable.o
	gcc -O3 -fPIC -c -DBLAKE3_NO_AVX512 -msse4.1 blake3_sse41.c -o blake3_sse41.o
	gcc -O3 -fPIC -c -DBLAKE3_NO_AVX512 -mavx2 blake3_avx2.c -o blake3_avx2.o
	ocamlopt.opt -c -o blake3.cmx blake3.ml
	ocamlopt.opt -a -o blake3.cmxa -cclib -lblake3_stubs blake3.cmx
	gcc -O3 -fPIC -c blake3.c -o blake3.o
	ocamlmklib.opt -o blake3_stubs blake3.o blake3_dispatch.o blake3_portable.o blake3_sse41.o blake3_avx2.o blake3_stubs.o
  

install:
	cp blake3.cmi ${OPAM_SWITCH_PREFIX}/lib/ocaml/
	cp blake3.cmo ${OPAM_SWITCH_PREFIX}/lib/ocaml/
	cp blake3.cma ${OPAM_SWITCH_PREFIX}/lib/ocaml/
	cp blake3.cmx ${OPAM_SWITCH_PREFIX}/lib/ocaml/
	cp blake3.cmxa ${OPAM_SWITCH_PREFIX}/lib/ocaml/
	cp blake3.a ${OPAM_SWITCH_PREFIX}/lib/ocaml/
	cp libblake3_stubs.a ${OPAM_SWITCH_PREFIX}/lib/ocaml

clean:
	rm -f *.a
	rm -f *.o
	rm -f *.so
	rm -f *.cmi
	rm -f *.cma
	rm -f *.cmo
	rm -f *.cmx
	rm -f *.cmxa
