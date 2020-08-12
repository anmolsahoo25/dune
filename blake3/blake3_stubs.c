/**************************************************************************/
/*                                                                        */
/*                                 OCaml                                  */
/*                                                                        */
/*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           */
/*                                                                        */
/*   Copyright 1996 Institut National de Recherche en Informatique et     */
/*     en Automatique.                                                    */
/*                                                                        */
/*   All rights reserved.  This file is distributed under the terms of    */
/*   the GNU Lesser General Public License version 2.1, with the          */
/*   special exception on linking described in the file LICENSE.          */
/*                                                                        */
/**************************************************************************/
#define CAML_INTERNALS
#include "blake3.h"
#include <string.h>
#include "caml/alloc.h"
#include "caml/fail.h"
#include "caml/md5.h"
#include "caml/memory.h"
#include "caml/mlvalues.h"
#include "caml/io.h"
#include "caml/reverse.h"

value blake3_string(value str, value ofs, value len)
{
  // init hasher
  blake3_hasher hasher;
  blake3_hasher_init(&hasher);

  // add input string
  blake3_hasher_update(&hasher, &Byte_u(str, Long_val(ofs)), Long_val(len));

  // create output
  value res;
  res = caml_alloc_string(16);
  blake3_hasher_finalize(&hasher, &Byte_u(res, 0), 16);
  return res;
}

value blake3_channel(struct channel *chan, intnat toread)
{
  //constants
  CAMLparam0();
  blake3_hasher hasher;
  value res;
  intnat read;
  char buffer[4096];

  Lock(chan);
  blake3_hasher_init(&hasher);
  if (toread < 0){
    while (1){
      read = caml_getblock(chan, buffer, sizeof(buffer));
      if (read == 0) break;
      blake3_hasher_update(&hasher, (unsigned char *) buffer, read);
    }
  }else{
    while (toread > 0) {
      read = caml_getblock(chan, buffer,
                           toread > sizeof(buffer) ? sizeof(buffer) : toread);
      if (read == 0) caml_raise_end_of_file();
      blake3_hasher_update(&hasher, (unsigned char *) buffer, read);
      toread -= read;
    }
  }
  res = caml_alloc_string(16);
  blake3_hasher_finalize(&hasher, &Byte_u(res, 0), 16);
  Unlock(chan);
  CAMLreturn (res);
}

value blake3_chan(value vchan, value len)
{
   CAMLparam2 (vchan, len);
   CAMLreturn (blake3_channel(Channel(vchan), Long_val(len)));
}
