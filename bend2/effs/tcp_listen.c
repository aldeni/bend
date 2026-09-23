// TCP
// ===

static int reuse_port(int fd) {
#ifdef SO_REUSEPORT
  int one = 1;
  return setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &one, sizeof(one));
#else
  errno = ENOPROTOOPT;
  return -1;
#endif
}

// TCP.listen owns its port: a second listener on it fails with EADDRINUSE,
// which is how an accidental second instance, or a probe for a free port,
// finds out. TCP.listen_shared (`shared`) sets SO_REUSEPORT first, so the
// listeners that all asked for it share the port, and a plain TCP.listen on
// that port still fails.
uint32_t tcp_listen(uint32_t port, int shared, int* out) {
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return (uint32_t)errno;
  }
  int one = 1;
  setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
  // Before the bind, or the kernel has already refused the second one. A
  // refusal is the call's error, not a silent downgrade to an owned port.
  // On Linux the kernel spreads accepted connections over the listeners;
  // on macOS it permits the bind but the first listener takes them all.
  if (shared && reuse_port(fd) < 0) {
    uint32_t code = (uint32_t)errno;
    close(fd);
    return code;
  }
  struct sockaddr_in at;
  if (io_sys_addr("0.0.0.0", port, &at) < 0) {
    close(fd);
    return EINVAL;
  }
  int bound = bind(fd, (struct sockaddr*)&at, sizeof(at));
  if (bound < 0 || listen(fd, 16) < 0
    || fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0) {
    uint32_t code = (uint32_t)errno;
    close(fd);
    return code;
  }
  *out = fd;
  return 0;
}

static Term tcp_listen_pack(Env e, uint32_t q, int out) {
  return q != 0 ? io_fail(e, q, NULL) : io_done(e, io_hand(out));
}

#ifdef CID_TCP_LISTEN
Term tcp_listen_run(Env e, Term* f, IoWork* w) {
  int out;
  uint32_t q = tcp_listen((uint32_t)f[0], 0, &out);
  return tcp_listen_pack(e, q, out);
}

static void __attribute__((constructor)) tcp_listen_use(void) {
  io_eff(CID_TCP_LISTEN, tcp_listen_run, 0);
}
#endif

#ifdef CID_TCP_LISTEN_SHARED
Term tcp_listen_shared_run(Env e, Term* f, IoWork* w) {
  int out;
  uint32_t q = tcp_listen((uint32_t)f[0], 1, &out);
  return tcp_listen_pack(e, q, out);
}

static void __attribute__((constructor)) tcp_listen_shared_use(void) {
  io_eff(CID_TCP_LISTEN_SHARED, tcp_listen_shared_run, 0);
}
#endif
