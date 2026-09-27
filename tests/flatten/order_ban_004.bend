# THE ORDER BAN, named: a nested match on an earlier binder after a match
# on a later one is the order ban, and the error says so -- which binder
# came first, which was matched first, and the order that works.
import Base

type Ty is Data:
  TStr{}
  TU32{}

def f(t: Ty, mv: Maybe<&2, U32>) -> String:
  match mv:
    case None{}:
      "none"
    case Some{v}:
      match t:
        case TStr{}:
          "str"
        case TU32{}:
          "u32"

def main() -> IO(Unit):
  IO.print(f(TStr{}, Some{1}))

#|SOME PROOFS FAIL
#|Error:
#|- message  : a match in binder order (t is bound before mv, which was matched first: match t before mv, or give the value its own def)
#|Location:
#|14 |     case Some{v}:
#|15>|       match t:
#|   |             ^
#|16 |         case TStr{}:
#|exit 1
