// TCP
// ===

// TCP.listen owns its port; TCP.listen_shared (`shared`) sets SO_REUSEPORT
// first, so the listeners that all asked for it share the port. The C twin
// says why a refused option is the call's error.
function tcp_listen_with(port, shared) {
  const sys = io_sys();
  const fd = sys.socket(2, 1, 0);
  if (fd < 0) {
    return io_fail(sys.errno());
  }
  const one = new Int32Array([1]);
  const level = sys.mac ? 0xffff : 1;
  sys.setsockopt(fd, level, sys.mac ? 4 : 2, sys.ptr(one), 4);
  const reuse = sys.mac ? 0x200 : 15;
  if (shared && sys.setsockopt(fd, level, reuse, sys.ptr(one), 4) < 0) {
    const code = sys.errno();
    sys.close(fd);
    return io_fail(code);
  }
  const at = io_addr("0.0.0.0", Number(port));
  if (at === null) {
    sys.close(fd);
    return io_fail(22);
  }
  if (sys.bind(fd, sys.ptr(at), 16) < 0 || sys.listen(fd, 16) < 0
    || sys.fcntl(fd, 4, sys.fcntl(fd, 3, 0) | (sys.mac ? 4 : 0x800)) < 0) {
    const code = sys.errno();
    sys.close(fd);
    return io_fail(code);
  }
  return io_done(fd);
}

function tcp_listen(port) {
  return tcp_listen_with(port, false);
}

function tcp_listen_shared(port) {
  return tcp_listen_with(port, true);
}
