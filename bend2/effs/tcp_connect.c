// TCP
// ===

// The socket is non-blocking for life. The connect's outcome is w->code:
// EINPROGRESS parked the computation until the socket was writable, and
// then SO_ERROR says how it ended. TCP.connect_within's park also has a
// deadline, and a wake that finds the socket still not writable came from
// the clock: the connect is still pending, so it fails with ETIMEDOUT, the
// kernel's own timeout error. A connect that has ended by the wake answers
// how it ended, even past the deadline.
static Term tcp_connect_more(Env e, IoWork* w) {
  int           fd  = (int)w->made;
  int           err = (int)w->code;
  socklen_t     len = sizeof(err);
  struct pollfd out = { fd, POLLOUT, 0 };
  if (err == EINPROGRESS && io_wait_time(w) != 0 && poll(&out, 1, 0) < 1) {
    err = ETIMEDOUT;
  }
  if (err == EINPROGRESS && getsockopt(fd, SOL_SOCKET, SO_ERROR, &err, &len)) {
    err = errno;
  }
  if (err != 0 && fd >= 0) {
    close(fd);
  }
  free(w->data);
  return err != 0 ? io_fail(e, (u32)err, NULL) : io_done(e, io_hand(fd));
}

// until is the park's deadline, an io_tick() (0: none).
static Term tcp_connect_start(Env e, Term* f, IoWork* w, u64 until) {
  struct sockaddr_in at;
  w->data = io_cstr(e, f[0], &w->size);
  int fd  = -1;
  errno   = EINVAL;
  if (!io_nul(w->data, w->size) && io_sys_addr(w->data, (u32)f[1], &at) == 0) {
    fd = socket(AF_INET, SOCK_STREAM, 0);
  }
  if (fd >= 0 && fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) < 0) {
    close(fd);
    fd = -1;
  }
  w->made = fd;
  io_sys_end(w, fd < 0 ? fd : connect(fd, (struct sockaddr*)&at, sizeof(at)));
  return w->code == EINPROGRESS ? io_wait_on(w, fd, POLLOUT, until,
    tcp_connect_more) : tcp_connect_more(e, w);
}

#ifdef CID_TCP_CONNECT

Term tcp_connect_run(Env e, Term* f, IoWork* w) {
  return tcp_connect_start(e, f, w, 0);
}

static void __attribute__((constructor)) tcp_connect_use(void) {
  io_eff(CID_TCP_CONNECT, tcp_connect_run, 0);
}

#endif

#ifdef CID_TCP_CONNECT_WITHIN

// TCP.connect with a deadline ms from now, as TCP.poll's.
Term tcp_connect_within_run(Env e, Term* f, IoWork* w) {
  return tcp_connect_start(e, f, w, io_tick() + (u64)f[2] * 1000000ull);
}

static void __attribute__((constructor)) tcp_connect_within_use(void) {
  io_eff(CID_TCP_CONNECT_WITHIN, tcp_connect_within_run, 0);
}

#endif
