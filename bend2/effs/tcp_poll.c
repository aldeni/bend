// TCP
// ===

// TCP.poll(sock, max, ms) is recv with a deadline: the park waits on the
// socket and on the clock, whichever fires first. A wake that finds data
// answers Some{data} ("" is the peer's close, as TCP.recv answers it); one
// that finds nothing parks again until the deadline, then answers None{}.
static Term tcp_poll_end(Env e, IoWork* w, Term r) {
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

#ifdef CID(TCP.poll)

static Term tcp_poll_more(Env e, IoWork* w) {
  int fd  = (int)w->hand;
  u64 at  = io_wait_time(w);
  w->size = io_sys_end(w, recv(fd, w->data, (size_t)w->made, 0));
  if (w->code == EAGAIN) {
    return io_tick() < at ? io_wait_on(w, fd, POLLIN, at, tcp_poll_more)
      : tcp_poll_end(e, w, io_done(e, term_pak(CID(None), 0)));
  }
  return tcp_poll_end(e, w, w->code ? io_fail(e, w->code, NULL) : io_done(e,
    io_box(e, CID(Some), io_str(e, w->data, w->size))));
}

Term tcp_poll_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->made = f[1] < INT32_MAX ? (intptr_t)f[1] : INT32_MAX;
  w->data = io_mem(malloc((size_t)w->made + 1));
  return io_wait_on(w, (int)w->hand, POLLIN,
    io_tick() + (u64)f[2] * 1000000ull, tcp_poll_more);
}

static void __attribute__((constructor)) tcp_poll_use(void) {
  io_eff(CID(TCP.poll), tcp_poll_run, 0);
}

#endif

#ifdef CID(TCP.poll_bytes)

// TCP.poll with the bytes as they are, the pair of TCP.recv_bytes: the
// deadline is the same, only the answer's shape differs.
static Term tcp_poll_bytes_more(Env e, IoWork* w) {
  int fd  = (int)w->hand;
  u64 at  = io_wait_time(w);
  w->size = io_sys_end(w, recv(fd, w->data, (size_t)w->made, 0));
  if (w->code == EAGAIN) {
    return io_tick() < at
      ? io_wait_on(w, fd, POLLIN, at, tcp_poll_bytes_more)
      : tcp_poll_end(e, w, io_done(e, term_pak(CID(None), 0)));
  }
  if (w->code) {
    return tcp_poll_end(e, w, io_fail(e, w->code, NULL));
  }
  Term xs = term_pak(CID(Nil), 0);
  for (u64 i = w->size; i > 0; i -= 1) {
    xs = io_node(e, CID(Con), ((uint8_t*)w->data)[i - 1], xs);
  }
  return tcp_poll_end(e, w, io_done(e, io_box(e, CID(Some), xs)));
}

Term tcp_poll_bytes_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->made = f[1] < INT32_MAX ? (intptr_t)f[1] : INT32_MAX;
  w->data = io_mem(malloc((size_t)w->made + 1));
  return io_wait_on(w, (int)w->hand, POLLIN,
    io_tick() + (u64)f[2] * 1000000ull, tcp_poll_bytes_more);
}

static void __attribute__((constructor)) tcp_poll_bytes_use(void) {
  io_eff(CID(TCP.poll_bytes), tcp_poll_bytes_run, 0);
}

#endif
