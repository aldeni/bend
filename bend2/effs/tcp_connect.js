// TCP
// ===

// The socket is non-blocking for life: EINPROGRESS parks the computation
// until the socket is writable, and then SO_ERROR says how the connect ended.
// TCP.connect_within's park also has a deadline (until): a wake that finds
// the socket still not writable came from the clock, so the connect fails
// with ETIMEDOUT, and one that has ended by the wake answers how it ended.
function tcp_connect_with(host, port, until, k) {
  const sys = io_sys();
  const at = io_addr(host, Number(port));
  if (at === null) {
    return io_fail(22);
  }
  const fd = sys.socket(2, 1, 0);
  if (fd < 0) {
    return io_fail(sys.errno());
  }
  const end = (code) => {
    if (code !== 0) {
      sys.close(fd);
      return io_fail(code);
    }
    return io_done(fd);
  };
  const error = () => {
    const v = new Int32Array([0]);
    const l = new Uint32Array([4]);
    return sys.getsockopt(fd, sys.mac ? 0xffff : 1, sys.mac ? 0x1007 : 4,
      sys.ptr(v), sys.ptr(l)) < 0 ? sys.errno() : v[0];
  };
  // a select on the one fd that does not wait, its set sized as io_wait's
  const ready = () => {
    const out = new Uint8Array((fd >> 6 << 3) + 8);
    const tv = new BigInt64Array(2);
    out[fd >> 3] = 1 << (fd & 7);
    return sys.select(fd + 1, null, sys.ptr(out), null, sys.ptr(tv)) > 0;
  };
  const set = sys.fcntl(fd, 4, sys.fcntl(fd, 3, 0) | (sys.mac ? 4 : 0x800));
  const ok = set >= 0 && sys.connect(fd, sys.ptr(at), 16) >= 0;
  const code = ok ? 0 : sys.errno();
  if (code !== (sys.mac ? 36 : 115)) {
    return end(code);
  }
  io_park_on(fd, true, k, () => end(until === undefined || ready() ? error()
    : sys.mac ? 60 : 110), until);
  return undefined;
}

function tcp_connect(host, port, k) {
  return tcp_connect_with(host, port, undefined, k);
}

// TCP.connect with a deadline ms from now, as TCP.poll's.
function tcp_connect_within(host, port, ms, k) {
  return tcp_connect_with(host, port, performance.now() + Number(ms), k);
}
