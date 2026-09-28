# io (io_chan_try): Chan.try_send and Chan.try_recv answer at once. On a
# channel with room for one, the first try_send goes and the second does
# not (full, the value dropped); try_recv takes the one value, then
# answers Wait{}, and Closed{} once the channel is closed. On a channel
# with no room, a sender parked on send hands its value to try_recv, a
# receiver parked on recv takes the value of try_send, and a try_send
# with nobody waiting does not go. main yields (a sleep of 0) so each
# spawned computation reaches its park before main polls.
import Base

law show:
  for b: Bool
  String

def show(b):
  match b:
    case False{}:
      "False"
    case True{}:
      "True"

law show_poll:
  for p: Chan.Poll<&1, U32>
  String

def show_poll(p):
  match p:
    case Wait{}:
      "wait"
    case Closed{}:
      "closed"
    case Got{value}:
      "got " ++ U32.show(value)

law show_got:
  for m: Maybe<&1, U32>
  String

def show_got(m):
  match m:
    case None{}:
      "none"
    case Some{value}:
      U32.show(value)

law sender:
  for +c: Chan(U32)
  IO(Unit)

def sender(c):
  do IO<Unit>:
    Bool <- Chan.send(U32, c, 9)
    IO.print("sender: 9 went")

law receiver:
  for +c: Chan(U32)
  IO(Unit)

def receiver(c):
  do IO<Unit>:
    m : Maybe<&1, U32> <- Chan.recv(U32, c)
    IO.print("receiver: " ++ show_got(m))

law rendezvous:
  for c: Chan(U32)
  IO(U32)

def rendezvous(c):
  +ch = c
  do IO<U32>:
    Unit <- IO.spawn(Unit, sender(ch))
    Unit <- IO.sleep(0)
    p : Chan.Poll<&1, U32> <- Chan.try_recv(U32, ch)
    Unit <- IO.print("try_recv from a parked sender: " ++ show_poll(p))
    Unit <- IO.spawn(Unit, receiver(ch))
    Unit <- IO.sleep(0)
    a : Bool <- Chan.try_send(U32, ch, 7)
    b : Bool <- Chan.try_send(U32, ch, 8)
    Unit <- IO.print("try_send to a parked receiver, then to nobody: " ++ show(a) ++ " " ++ show(b))
    return 0

law buffered:
  for c: Chan(U32)
  IO(U32)

def buffered(c):
  +ch = c
  do IO<U32>:
    a : Bool <- Chan.try_send(U32, ch, 1)
    b : Bool <- Chan.try_send(U32, ch, 2)
    Unit <- IO.print("try_send with room for one: " ++ show(a) ++ " " ++ show(b))
    p : Chan.Poll<&1, U32> <- Chan.try_recv(U32, ch)
    q : Chan.Poll<&1, U32> <- Chan.try_recv(U32, ch)
    Unit <- Chan.close(U32, ch)
    r : Chan.Poll<&1, U32> <- Chan.try_recv(U32, ch)
    Unit <- IO.print("try_recv: " ++ show_poll(p) ++ ", " ++ show_poll(q) ++ ", " ++ show_poll(r))
    IO.bind(Chan(U32), U32, Chan.new(U32, 0), rendezvous)

law main:
  IO(U32)

def main():
  IO.bind(Chan(U32), U32, Chan.new(U32, 1), buffered)

#|try_send with room for one: True False
#|try_recv: got 1, wait, closed
#|try_recv from a parked sender: got 9
#|sender: 9 went
#|try_send to a parked receiver, then to nobody: True False
#|receiver: 7
