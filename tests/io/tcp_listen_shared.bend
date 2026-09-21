# io (io_tcp_listen_shared): SO_REUSEPORT lets N listeners share one
# port -- the mechanism a process-per-core server needs, since the
# runtime's IO loop is one per process and only spawned `!` work
# touches every thread. Two TCP.listen calls on the SAME port, in the
# SAME process, both answer Done{}; the second answered Fail(Address
# already in use) before the option was set. Each open prints its own
# step before the other opens, then both close.
import Base

law second:
  for a: Listener
  for r: Result<&1, &1, (U32 & String), Listener>
  IO(U32)

def second(a, r):
  match r:
    case Done{b}:
      do IO<U32>:
        p : Unit <- IO.print("second")
        x : Unit <- Listener.close(b)
        y : Unit <- Listener.close(a)
        return 0
    case Fail{error}:
      (code, message) = error
      do IO<U32>:
        p : Unit <- IO.print(message)
        x : Unit <- Listener.close(a)
        return 1

law first:
  for r: Result<&1, &1, (U32 & String), Listener>
  IO(U32)

def first(r):
  match r:
    case Done{a}:
      do IO<U32>:
        p : Unit <- IO.print("first")
        s : Result<&1, &1, (U32 & String), Listener> <- TCP.listen(8730)
        second(a, s)
    case Fail{error}:
      (code, message) = error
      do IO<U32>:
        p : Unit <- IO.print(message)
        return 1

law main:
  IO(U32)

def main():
  do IO<U32>:
    r : Result<&1, &1, (U32 & String), Listener> <- TCP.listen(8730)
    first(r)

#|first
#|second
