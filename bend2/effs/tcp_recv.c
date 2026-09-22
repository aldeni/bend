// TCP
// ===

#ifdef CID(TCP.recv)

static Term tcp_recv_pack(Env e, IoWork* w) {
  Term r = w->code ? io_fail(e, w->code, NULL)
    : io_done(e, io_str(e, w->data, w->size));
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

// The loop parked the request until the socket was readable; a recv that
// still finds nothing (the socket is non-blocking) parks again.
static Term tcp_recv_more(Env e, IoWork* w) {
  int fd  = (int)w->hand;
  w->size = io_sys_end(w, recv(fd, w->data, (size_t)w->made, 0));
  return w->code == EAGAIN ? io_wait_on(w, fd, POLLIN, 0, tcp_recv_more)
    : tcp_recv_pack(e, w);
}

Term tcp_recv_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->made = f[1] < INT32_MAX ? (intptr_t)f[1] : INT32_MAX;
  w->data = io_mem(malloc((size_t)w->made + 1));
  return tcp_recv_more(e, w);
}

static void __attribute__((constructor)) tcp_recv_use(void) {
  io_eff(CID(TCP.recv), tcp_recv_run, IO_READ);
}

#endif

#ifdef CID(TCP.recv_bytes)

// The bytes as they are (0..255), one List cell each, as File.read_bytes
// gives them. TCP.recv decodes the same bytes as UTF-8, one call at a
// time: a body that is not text, and a character the network split across
// two reads, do not survive that.
static Term tcp_recv_bytes_pack(Env e, IoWork* w) {
  Term r;
  if (w->code) {
    r = io_fail(e, w->code, NULL);
  } else {
    Term xs = term_pak(CID(Nil), 0);
    for (u64 i = w->size; i > 0; i -= 1) {
      xs = io_node(e, CID(Con), ((uint8_t*)w->data)[i - 1], xs);
    }
    r = io_done(e, xs);
  }
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

static Term tcp_recv_bytes_more(Env e, IoWork* w) {
  int fd  = (int)w->hand;
  w->size = io_sys_end(w, recv(fd, w->data, (size_t)w->made, 0));
  return w->code == EAGAIN ? io_wait_on(w, fd, POLLIN, 0, tcp_recv_bytes_more)
    : tcp_recv_bytes_pack(e, w);
}

Term tcp_recv_bytes_run(Env e, Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->made = f[1] < INT32_MAX ? (intptr_t)f[1] : INT32_MAX;
  w->data = io_mem(malloc((size_t)w->made + 1));
  return tcp_recv_bytes_more(e, w);
}

static void __attribute__((constructor)) tcp_recv_bytes_use(void) {
  io_eff(CID(TCP.recv_bytes), tcp_recv_bytes_run, IO_READ);
}

#endif
