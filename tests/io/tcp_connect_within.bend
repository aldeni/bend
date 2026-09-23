# io (io_tcp_connect_within): TCP.connect_within is TCP.connect with a
# deadline ms from the call. To a local listener it connects and the
# socket carries a send. To a closed port it fails as TCP.connect does:
# the deadline rewrites no error. To TEST-NET-1 (192.0.2.1), whose
# packets the network drops, the 200 ms deadline fails the connect
# (ETIMEDOUT, its socket closed) long before a 1500 ms timer, where
# TCP.connect would wait out the kernel's own timeout (minutes): the
# timer would print first and the program would not end in time. A
# network that refuses the address at once fails it before the timer
# too, so both print the same lines; the line names the outcome, not
# the error. Every op threads its handle back OUTSIDE the Result.
import Base

def outcome(r: Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  match r:
    case Done{s}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("connected")
    case Fail{(code, text)}:
      IO.print(text)

def hole(r: Result<&1, &1, (U32 & String), Socket>) -> IO(Unit):
  match r:
    case Done{s}:
      do IO<Unit>:
        Unit <- Socket.close(s)
        IO.print("hole: connected")
    case Fail{e}:
      IO.print("hole: failed")

def timer() -> IO(Unit):
  do IO<Unit>:
    Unit <- IO.sleep(1500)
    IO.print("timer")

def send_go(m: Socket & Result<&1, &1, (U32 & String), Unit>) -> IO(Socket):
  (s, r) = m
  do IO<Socket>:
    Unit <- IO.pass(Unit, r)
    return s

# the listener closed, its port refuses; then the black hole, beside the
# timer
def step_read(port: U32, l: Listener, c: Socket, m: Socket & Result<&1, &1, (U32 & String), String>) -> IO(U32):
  (a, r) = m
  do IO<U32>:
    data : String <- IO.pass(String, r)
    Unit <- IO.print(data)
    Unit <- Socket.close(a)
    Unit <- Socket.close(c)
    Unit <- Listener.close(l)
    x : Result<&1, &1, (U32 & String), Socket> <- TCP.connect_within("127.0.0.1", port, 5000)
    Unit <- outcome(x)
    Unit <- IO.spawn(Unit, timer())
    y : Result<&1, &1, (U32 & String), Socket> <- TCP.connect_within("192.0.2.1", 80, 200)
    Unit <- hole(y)
    return 0

def step_accept(port: U32, c: Socket, p: Listener & Result<&1, &1, (U32 & String), Socket>) -> IO(U32):
  (l, ar) = p
  do IO<U32>:
    a  : Socket <- IO.pass(Socket, ar)
    sm : Socket & Result<&1, &1, (U32 & String), Unit> <- TCP.send(c, "bend-within")
    c2 : Socket <- send_go(sm)
    rm : Socket & Result<&1, &1, (U32 & String), String> <- TCP.recv(a, 64)
    step_read(port, l, c2, rm)

def main.go(b: Listener & U32) -> IO(U32):
  (l, +port) = b
  do IO<U32>:
    c : Socket <- IO.try(Socket, TCP.connect_within("127.0.0.1", port, 5000))
    p : Listener & Result<&1, &1, (U32 & String), Socket> <- TCP.accept(l)
    step_accept(port, c, p)

def tcp_retry(port: U32, r: Result<&1, &1, (U32 & String), Listener>, rest: IO(Listener & U32)) -> IO(Listener & U32):
  match r:
    case Done{l}:
      IO.pure(Listener & U32, (l, port))
    case Fail{e}:
      rest

def tcp_listen_any(tries: Nat, +port: U32) -> IO(Listener & U32):
  match tries:
    case 0n:
      IO.die(Listener & U32, 1, "no free tcp port")
    case 1n+t:
      rest = tcp_listen_any(t, (port + 1 : U32))
      do IO<Listener & U32>:
        r : Result<&1, &1, (U32 & String), Listener> <- TCP.listen(port)
        tcp_retry(port, r, rest)

def main() -> IO(U32):
  do IO<U32>:
    b : Listener & U32 <- tcp_listen_any(32n, 19687)
    main.go(b)

#|bend-within
#|Connection refused
#|hole: failed
#|timer
