// Chan
// ====

// Chan.new, send, recv and close share this file.

// A parked receiver holds CHAN_RECV: the C lane parks TERM_HOLE, and a
// program can make neither. A sent value may be null (an erased proof).
const CHAN_RECV = Symbol();

function chan_wake(row, x) {
  const w = row.wait.shift();
  io_push(w.cont, x, false);
  return w.item;
}

function chan_take(row) {
  const v = row.ring.shift();
  if (row.wait.length > 0) {
    row.ring.push(chan_wake(row, true));
  }
  return v;
}

// A handle is the row (a stale copy keeps it, shut).
function chan_shut(row) {
  row.shut = true;
  while (row.wait.length > 0) {
    chan_wake(row, row.wait[0].item === CHAN_RECV ? { $: CID(None) } : false);
  }
}

function chan_new(room) {
  return { room: Number(room), ring: [], wait: [], shut: false };
}

// A send that does not wait: a parked receiver takes the value, else
// the ring while it has room. Answers whether the value went.
function chan_put(row, value) {
  if (row.wait.length > 0 && row.wait[0].item === CHAN_RECV) {
    chan_wake(row, { $: CID(Some), value: value });
    return true;
  }
  if (row.ring.length < row.room) {
    row.ring.push(value);
    return true;
  }
  return false;
}

// A receive that does not wait: a value from the ring, else from a
// parked sender, else CHAN_RECV (a program makes no such value).
function chan_get(row) {
  if (row.ring.length > 0) {
    return chan_take(row);
  }
  if (row.wait.length > 0 && row.wait[0].item !== CHAN_RECV) {
    return chan_wake(row, true);
  }
  return CHAN_RECV;
}

function chan_send(handle, value, k) {
  const row = handle;
  if (row.shut) {
    return false;
  }
  if (chan_put(row, value)) {
    return true;
  }
  row.wait.push({ cont: k, item: value });
  return;
}

function chan_recv(handle, k) {
  const row = handle;
  const v = chan_get(row);
  if (v !== CHAN_RECV) {
    return { $: CID(Some), value: v };
  }
  if (row.shut) {
    return { $: CID(None) };
  }
  row.wait.push({ cont: k, item: CHAN_RECV });
  return;
}

// A send that answers at once: false on a full or closed channel, and
// the value is dropped, as Chan.send drops it on a closed one.
function chan_try_send(handle, value) {
  const row = handle;
  return !row.shut && chan_put(row, value);
}

// A receive that answers at once: Got{value}, Wait{} while nothing is
// ready, Closed{} once the channel is closed and drained.
function chan_try_recv(handle) {
  const row = handle;
  const v = chan_get(row);
  if (v !== CHAN_RECV) {
    return { $: CID(Got), value: v };
  }
  return { $: row.shut ? CID(Closed) : CID(Wait) };
}

function chan_close(handle) {
  const row = handle;
  if (!row.shut) {
    chan_shut(row);
  }
  return { $: CID(Unit) };
}

io_eff(CID(Chan.new), chan_new);
io_eff(CID(Chan.send), chan_send);
io_eff(CID(Chan.recv), chan_recv);
io_eff(CID(Chan.close), chan_close);
io_eff(CID(Chan.try_send), chan_try_send);
io_eff(CID(Chan.try_recv), chan_try_recv);
