# io (io_tcp_listen_shared): TCP.listen_shared lets N listeners share
# one port -- the mechanism a process-per-core server needs, since the
# runtime's IO loop is one per process -- while TCP.listen still owns
# its port. Two TCP.listen_shared calls on the same port both answer
# Done{}; a plain TCP.listen on that port then answers Fail(Address
# already in use), so an accidental second instance, and a probe for a
# free port (tcp_listen_any in the other TCP tests), still find it
# taken. The port comes from the same upward probe, made with
# TCP.listen_shared: a port a plain listener holds is refused and the
# probe moves on; one a concurrent copy of this test holds is shared,
# which this test tolerates -- it makes no connection, and the plain
# listen below is refused either way.
import Base

law third:
  for a: Listener
  for b: Listener
  for r: Result<&1, &1, (U32 & String), Listener>
  IO(U32)

def third(a, b, r):
  match r:
    case Done{c}:
      do IO<U32>:
        p : Unit <- IO.print("plain listen shared the port")
        x : Unit <- Listener.close(c)
        y : Unit <- Listener.close(b)
        z : Unit <- Listener.close(a)
        return 1
    case Fail{error}:
      (code, message) = error
      do IO<U32>:
        p : Unit <- IO.print(message)
        y : Unit <- Listener.close(b)
        z : Unit <- Listener.close(a)
        return 0

law second:
  for a: Listener
  for port: U32
  for r: Result<&1, &1, (U32 & String), Listener>
  IO(U32)

def second(a, port, r):
  match r:
    case Done{b}:
      do IO<U32>:
        p : Unit <- IO.print("shared again")
        s : Result<&1, &1, (U32 & String), Listener> <- TCP.listen(port)
        third(a, b, s)
    case Fail{error}:
      (code, message) = error
      do IO<U32>:
        p : Unit <- IO.print(message)
        x : Unit <- Listener.close(a)
        return 1

law first:
  for m: Listener & U32
  IO(U32)

def first(m):
  (a, +port) = m
  do IO<U32>:
    p : Unit <- IO.print("shared")
    s : Result<&1, &1, (U32 & String), Listener> <- TCP.listen_shared(port)
    second(a, port, s)

law shared_retry:
  for port : U32
  for r : Result<&1, &1, (U32 & String), Listener>
  for rest : IO(Listener & U32)
  IO(Listener & U32)

def shared_retry(port, r, rest):
  match r:
    case Done{l}:
      IO.pure(Listener & U32, (l, port))
    case Fail{e}:
      rest

law listen_shared_any:
  for tries : Nat
  for +port : U32
  IO(Listener & U32)

def listen_shared_any(tries, port):
  match tries:
    case 0n:
      IO.die(Listener & U32, 1, "no free tcp port")
    case 1n+t:
      rest = listen_shared_any(t, (port + 1 : U32))
      do IO<Listener & U32>:
        r : Result<&1, &1, (U32 & String), Listener> <- TCP.listen_shared(port)
        shared_retry(port, r, rest)

law main:
  IO(U32)

def main():
  do IO<U32>:
    m : Listener & U32 <- listen_shared_any(32n, 19947)
    first(m)

#|shared
#|shared again
#|Address already in use
