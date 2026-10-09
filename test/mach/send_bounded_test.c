// ─────────────────────────────────────────────────────────────────────────────
// test/mach/send_bounded_test.c — the mach send contract the bar depends on.
//
// WHY THIS EXISTS: the bar froze because sketchybar and its Lua client each
// blocked sending to the other while neither drained its own port. The obvious
// fix -- give the send a timeout -- was WRONG, and wrong in a way that looked
// right in code review, in the disassembly, and in a unit test that did not
// model signals. It shipped, and the bar still wedged for hours inside a send
// that was supposedly capped at one second.
//
// The reason is documented behaviour: "If MACH_SEND_TIMEOUT is used without
// MACH_SEND_INTERRUPT, then the timeout duration might not be accurate, because
// when the call is interrupted and automatically retried, the original timeout
// is used" (Mach Reference Manual, Message Send). xnu's mach_msg2_internal only
// runs its `while (mr == MACH_SEND_INTERRUPTED)` retry loop when
// MACH64_SEND_INTERRUPT is clear -- so every signal silently restarts the clock
// and the wall-clock wait is unbounded.
//
// These tests pin all four properties the patches rely on. Test 1 is the one
// that matters: it asserts the NAIVE flags really do hang, so nobody can
// "simplify" MACH_SEND_INTERRUPT back out and have a green suite.
//
// Self-contained: no sketchybar, no bar process, no macOS UI. ~3 seconds.
// ─────────────────────────────────────────────────────────────────────────────
#include <mach/mach.h>
#include <mach/message.h>
#include <pthread.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define QLIMIT 2
#define BUDGET_MS 100

#ifndef NSEC_PER_MSEC
#define NSEC_PER_MSEC 1000000ull
#endif

static int failures = 0;

static void check(const char* what, bool ok) {
  printf("  %s %s\n", ok ? "\033[0;32m✔\033[0m" : "\033[0;31m✘\033[0m", what);
  if (!ok) failures++;
}

struct mach_message {
  mach_msg_header_t header;
  mach_msg_size_t msgh_descriptor_count;
  mach_msg_ool_descriptor_t descriptor;
};

struct mach_buffer {
  struct mach_message message;
  mach_msg_trailer_t trailer;
};

static volatile sig_atomic_t sigcount = 0;
static void on_alarm(int s) { (void)s; sigcount++; }

static double now_ms(void) {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return tv.tv_sec * 1000.0 + tv.tv_usec / 1000.0;
}

// The shipped logic, kept byte-identical in intent to the patched
// mach_send_bounded in darwin/patches/. budget 0 => one attempt, then drop.
static mach_msg_return_t mach_send_bounded(struct mach_message* msg,
                                           uint32_t budget_ms) {
  uint64_t deadline = clock_gettime_nsec_np(CLOCK_MONOTONIC)
                      + (uint64_t)budget_ms * NSEC_PER_MSEC;
  mach_msg_timeout_t left = budget_ms;

  for (;;) {
    mach_msg_return_t ret = mach_msg(&msg->header,
                                     MACH_SEND_MSG | MACH_SEND_TIMEOUT
                                                   | MACH_SEND_INTERRUPT,
                                     sizeof(struct mach_message),
                                     0,
                                     MACH_PORT_NULL,
                                     left,
                                     MACH_PORT_NULL);
    if (ret != MACH_SEND_INTERRUPTED) return ret;

    uint64_t now = clock_gettime_nsec_np(CLOCK_MONOTONIC);
    if (now >= deadline) return MACH_SEND_TIMED_OUT;
    left = (mach_msg_timeout_t)((deadline - now) / NSEC_PER_MSEC);
  }
}

static mach_port_t g_port;

static struct mach_message make_msg(char* payload) {
  struct mach_message m = { 0 };
  m.header.msgh_remote_port = g_port;
  m.header.msgh_bits = MACH_MSGH_BITS_SET(
      MACH_MSG_TYPE_COPY_SEND & MACH_MSGH_BITS_REMOTE_MASK, 0, 0,
      MACH_MSGH_BITS_COMPLEX);
  m.header.msgh_size = sizeof(struct mach_message);
  m.msgh_descriptor_count = 1;
  m.descriptor.address = payload;
  m.descriptor.size = strlen(payload) + 1;
  m.descriptor.copy = MACH_MSG_VIRTUAL_COPY;
  m.descriptor.deallocate = false;
  m.descriptor.type = MACH_MSG_OOL_DESCRIPTOR;
  return m;
}

static void setup_full_port(char* payload) {
  mach_port_name_t task = mach_task_self();
  mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE, &g_port);
  mach_port_insert_right(task, g_port, g_port, MACH_MSG_TYPE_MAKE_SEND);

  struct mach_port_limits limits = { 0 };
  limits.mpl_qlimit = QLIMIT;
  mach_port_set_attributes(task, g_port, MACH_PORT_LIMITS_INFO,
                           (mach_port_info_t)&limits,
                           MACH_PORT_LIMITS_INFO_COUNT);

  for (int i = 0; i < QLIMIT; i++) {
    struct mach_message m = make_msg(payload);
    mach_msg(&m.header, MACH_SEND_MSG, sizeof(struct mach_message), 0,
             MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
  }
}

static void start_signal_storm(void) {
  struct sigaction sa = { 0 };
  sa.sa_handler = on_alarm;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = 0;  // deliberately NOT SA_RESTART: interrupt the send
  sigaction(SIGALRM, &sa, NULL);

  struct itimerval it = { 0 };
  it.it_interval.tv_usec = 10000;  // 10ms, far faster than the 100ms budget
  it.it_value.tv_usec = 10000;
  setitimer(ITIMER_REAL, &it, NULL);
}

static void* drainer(void* arg) {
  (void)arg;
  usleep(40000);
  for (int i = 0; i < QLIMIT; i++) {
    struct mach_buffer buf = { 0 };
    mach_msg(&buf.message.header, MACH_RCV_MSG, 0, sizeof(struct mach_buffer),
             g_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
  }
  return NULL;
}

int main(void) {
  char* payload = strdup("hello");

  printf("\n══ 1. the naive flags MUST hang (guards MACH_SEND_INTERRUPT) ══\n");
  {
    // Fork: if MACH_SEND_TIMEOUT alone were sufficient, the child would exit
    // promptly. It must NOT -- that is the whole bug. Surviving the watchdog is
    // the pass condition.
    pid_t pid = fork();
    if (pid == 0) {
      setup_full_port(payload);
      start_signal_storm();
      struct mach_message m = make_msg(payload);
      mach_msg(&m.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT,
               sizeof(struct mach_message), 0, MACH_PORT_NULL, BUDGET_MS,
               MACH_PORT_NULL);
      _exit(0);  // reached only if the timeout were honoured across interrupts
    }
    usleep(1500000);  // 15x the budget
    int status = 0;
    bool still_running = (waitpid(pid, &status, WNOHANG) == 0);
    check("MACH_SEND_TIMEOUT alone still hangs under signals "
          "(retry restarts the clock)", still_running);
    kill(pid, SIGKILL);
    waitpid(pid, &status, 0);
  }

  printf("\n══ 2. the shipped logic returns, at the deadline ══\n");
  {
    pid_t pid = fork();
    if (pid == 0) {
      setup_full_port(payload);
      start_signal_storm();
      struct mach_message m = make_msg(payload);
      double t0 = now_ms();
      mach_msg_return_t r = mach_send_bounded(&m, BUDGET_MS);
      double dt = now_ms() - t0;
      // must time out at the deadline, not bail on the first signal
      _exit((r == MACH_SEND_TIMED_OUT && dt >= BUDGET_MS * 0.9
             && dt <= BUDGET_MS * 3 && sigcount >= 5) ? 0 : 1);
    }
    usleep(1500000);
    int status = 0;
    bool exited = (waitpid(pid, &status, WNOHANG) == pid);
    check("returns despite the signal storm", exited);
    check("timed out AT the deadline, not on the first signal",
          exited && WIFEXITED(status) && WEXITSTATUS(status) == 0);
    if (!exited) { kill(pid, SIGKILL); waitpid(pid, &status, 0); }
  }

  printf("\n══ 3. a signal must not cost us the message ══\n");
  {
    pid_t pid = fork();
    if (pid == 0) {
      setup_full_port(payload);
      start_signal_storm();
      pthread_t th;
      pthread_create(&th, NULL, drainer, NULL);
      struct mach_message m = make_msg(payload);
      mach_msg_return_t r = mach_send_bounded(&m, BUDGET_MS);
      _exit((r == MACH_MSG_SUCCESS && sigcount >= 1) ? 0 : 1);
    }
    usleep(1500000);
    int status = 0;
    bool exited = (waitpid(pid, &status, WNOHANG) == pid);
    check("still delivers once the peer drains, having ridden signals",
          exited && WIFEXITED(status) && WEXITSTATUS(status) == 0);
    if (!exited) { kill(pid, SIGKILL); waitpid(pid, &status, 0); }
  }

  printf("\n══ 4. budget 0 never blocks (how the bar hands out events) ══\n");
  {
    setup_full_port(payload);
    struct mach_message m = make_msg(payload);
    double t0 = now_ms();
    mach_msg_return_t r = mach_send_bounded(&m, 0);
    double dt = now_ms() - t0;
    check("attempts once and gives up immediately on a full queue",
          r == MACH_SEND_TIMED_OUT && dt < 20);

    // and it must still SEND when there is room, not just always bail
    mach_port_t fresh;
    mach_port_name_t task = mach_task_self();
    mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE, &fresh);
    mach_port_insert_right(task, fresh, fresh, MACH_MSG_TYPE_MAKE_SEND);
    g_port = fresh;
    struct mach_message m2 = make_msg(payload);
    check("still delivers when the peer has room",
          mach_send_bounded(&m2, 0) == MACH_MSG_SUCCESS);
  }

  if (failures) {
    printf("\n\033[0;31m══ %d MACH SEND TEST(S) FAILED ══\033[0m\n\n", failures);
    return 1;
  }
  printf("\n\033[0;32m══ ALL MACH SEND TESTS PASSED ══\033[0m\n\n");
  return 0;
}
