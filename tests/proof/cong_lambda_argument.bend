# --verdict: a +-bound let of Equal.cong over a function name goes to the
# kernel with its type, since the eta-long lambda the function becomes
# is not inferable, and a + let is inferred; without the annotation the
# kernel refused "λx => (snd_of x)" as an unannotated term (#1133).
import Base

def snd_of(p: U32 & Bool) -> Bool:
  (a, b) = p
  b

def mk(n: U32) -> U32 & Bool:
  (n, True{})

def lemma(+n: U32, x: U32 & Bool, +h: {x == mk(n) : U32 & Bool}) -> {snd_of(x) == snd_of(mk(n)) : Bool}:
  +h2 = Equal.cong(U32 & Bool, Bool, snd_of, x, mk(n), h)
  h2

def main() -> IO(Unit):
  IO.print(Bool.show(snd_of(mk(1))))

#|True
