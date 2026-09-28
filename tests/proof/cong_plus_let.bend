# --verdict: a + let of Equal.cong over a function goes to the kernel with
# bend2's type. The kernel infers a let read at quantity 2 and checks the
# type it inferred against *2 before any β-reduction, so the un-reduced
# `((λx => ..) (mk n))` on one side of the equation sent it to infer the
# λ, and it refused "an annotated term" for a file bend2 accepts (#1133).
# Two shapes: a pair domain with a def as the function, and Nat with a
# λ written at the source.
import Base

def snd_of(p: U32 & Bool) -> Bool:
  (a, b) = p
  b

def mk(n: U32) -> U32 & Bool:
  (n, True{})

def lemma(+n: U32, x: U32 & Bool, +h: {x == mk(n) : U32 & Bool}) -> {snd_of(x) == snd_of(mk(n)) : Bool}:
  +h2 = Equal.cong(U32 & Bool, Bool, snd_of, x, mk(n), h)
  h2

def succ_of(a: Nat, e: {a == 0n : Nat}) -> {1n+a == 1n : Nat}:
  +tr = Equal.cong(Nat, Nat, x => 1n+x, a, 0n, e)
  tr

def main() -> IO(Unit):
  IO.print(Bool.show(snd_of(mk(1))))

#|True
