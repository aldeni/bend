// TCP
// ===

// The loop parked the request until the socket was readable; a recv that
// still finds nothing (the socket is non-blocking) parks again, on `more`,
// the caller's own wake. `pack` turns what was read into the answer: text
// for TCP.recv, bytes for TCP.recv_bytes. The rest is the same for both.
static Term tcp_recv_step(Env e, IoWork* w, Term (*more)(Env, IoWork*),
    Term (*pack)(Env, IoWork*)) {
  int fd  = (int)w->hand;
  w->size = io_sys_end(w, recv(fd, w->data, (size_t)w->made, 0));
  if (w->code == EAGAIN) {
    return io_wait_on(w, fd, POLLIN, 0, more);
  }
  Term r = w->code ? io_fail(e, w->code, NULL) : pack(e, w);
  free(w->data);
  return io_tup(e, io_hand(w->hand), r);
}

static void tcp_recv_start(Term* f, IoWork* w) {
  w->hand = (intptr_t)io_hand_v(f[0]);
  w->made = f[1] < INT32_MAX ? (intptr_t)f[1] : INT32_MAX;
  w->data = io_mem(malloc((size_t)w->made + 1));
}

#ifdef CID(TCP.recv)

static Term tcp_recv_text(Env e, IoWork* w) {
  return io_done(e, io_str(e, w->data, w->size));
}

static Term tcp_recv_more(Env e, IoWork* w) {
  return tcp_recv_step(e, w, tcp_recv_more, tcp_recv_text);
}

Term tcp_recv_run(Env e, Term* f, IoWork* w) {
  tcp_recv_start(f, w);
  return tcp_recv_more(e, w);
}

static void __attribute__((constructor)) tcp_recv_use(void) {
  io_eff(CID(TCP.recv), tcp_recv_run, IO_READ);
}

#endif

#ifdef CID(TCP.recv_bytes)

// TCP.recv decodes the same bytes as UTF-8, one call at a time: a body
// that is not text, and a character the network split across two reads,
// do not survive that.
static Term tcp_recv_list(Env e, IoWork* w) {
  return io_done(e, io_list(e, w->data, w->size));
}

static Term tcp_recv_bytes_more(Env e, IoWork* w) {
  return tcp_recv_step(e, w, tcp_recv_bytes_more, tcp_recv_list);
}

Term tcp_recv_bytes_run(Env e, Term* f, IoWork* w) {
  tcp_recv_start(f, w);
  return tcp_recv_bytes_more(e, w);
}

static void __attribute__((constructor)) tcp_recv_bytes_use(void) {
  io_eff(CID(TCP.recv_bytes), tcp_recv_bytes_run, IO_READ);
}

#endif
