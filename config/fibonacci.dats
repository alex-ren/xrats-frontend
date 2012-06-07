(*
** Copyright (C) 2012 Hongwei Xi, Boston University
** An Example of the ATS2 Typechecker at work with Fibonacci Numbers
*)
staload "doc/EXAMPLE/ARITH/basics.sats"
staload "doc/EXAMPLE/ARITH/fibonacci.sats"

implement
fib_istot {n} () = let
//
prfun
istot {n:nat} .<n>.
  (): [r:nat] FIB (n, r) =
  sif n == 0 then FIBbas1 ()
  else sif n == 1 then FIBbas2 ()
  else FIBind (
    istot {n-2} (), istot {n-1} ()
  ) // end of [sif]
// end of [istot]
//
in
  istot {n} ()
end // end of [fib_istot]

(* ****** ****** *)

implement
fib_isfun (pf1, pf2) = let
//
prfun isfun
  {n:nat}{r1,r2:int} .<n>. (
  pf1: FIB (n, r1), pf2: FIB (n, r2)
) : [r1==r2] void =
  case+ (pf1, pf2) of
  | (FIBbas1 (), FIBbas1 ()) => ()
  | (FIBbas2 (), FIBbas2 ()) => ()
  | (FIBind (pf11, pf12),
     FIBind (pf21, pf22)) => let
      prval () = isfun (pf11, pf21)
      prval () = isfun (pf12, pf22)
    in
      (*nothing*)
    end // end of [FIBind, FIBind]
// end of [isfun]
//
in
  isfun (pf1, pf2)
end // end of [fib_isfun]

implement
fib_isfun2 (pf1, pf2) = let
  prval () = fib_isfun (pf1, pf2) in inteq_make ()
end // end of [fib_isfun2]

(* ****** ****** *)
//
// HX-2012-03:
// fib(m+n+1)=fib(m)*fib(n)+fib(m+1)*fib(n+1)
//
implement
fibeq1
  (pf1, pf2, pf3, pf4) = let
//
prfun
lemma {m,n:nat}
  {r1,r2,r3,r4:int} .<m>. (
  pf1: FIB (m, r1) // r1 = fib(m)
, pf2: FIB (n, r2) // r2 = fib(n)
, pf3: FIB (m+1, r3) // r3 = fib(m+1)
, pf4: FIB (n+1, r4) // r4 = fib(n+1)
) : FIB (m+n+1, r1*r2+r3*r4) = let
//
// HX: it is by standard mathematical induction
//
in
//
sif m > 0 then let
  prval FIBind (pf30, pf31) = pf3
  prval INTEQ () = fib_isfun2 (pf1, pf31)
in
  lemma {m-1,n+1}
    (pf30, pf4, pf31, FIBind (pf2, pf4))
  // end of [lemma]
end else let
  prval FIBbas1 () = pf1; prval FIBbas2 () = pf3 in pf4
end // end of [sif]
//
end // end of [lemma]
//
in
//
lemma (pf1, pf2, pf3, pf4)
//
end // end of [fibeq1]

(* ****** ****** *)
//
// HX-2012-03:
// fib(n)*fib(n+2) + (-1)^n = (fib(n+1))^2
//
implement
fibeq2 (
  pf0, pf1, pf2, pf3
) = let
//
prfun
fibeq2
  {n:nat}{i:int}
  {f0,f1,f2:int} .<n>. (
  pf0: FIB (n, f0)
, pf1: FIB (n+1, f1)
, pf2: FIB (n+2, f2)
, pf3: SGN (n, i)
) : [
  f0*f2 + i == f1*f1
] void =
  sif n > 0 then let
    prval FIBind (pf11, pf12) = pf1
    prval INTEQ () = fib_isfun2 (pf0, pf12)
    prval pf_n_n = fibeq1 (pf0, pf0, pf1, pf1)
    prval pf_1n_n1 = fibeq1 (pf11, pf1, pf0, pf2)
    prval () = fib_isfun (pf_n_n, pf_1n_n1)
    prval SGNind (pf31) = pf3
    prval () = fibeq2 {n-1} (pf11, pf12, pf1, pf31) // IH
  in
    // nothing
  end else let
    prval FIBbas1 () = pf0
    prval FIBbas2 () = pf1
    prval FIBind (FIBbas1 (), FIBbas2 ()) = pf2
    prval SGNbas () = pf3
  in
    // nothing
  end // end of [sif]
// end of [fibeq2]
//
in
  fibeq2 (pf0, pf1, pf2, pf3)
end // end of [fibeq2]