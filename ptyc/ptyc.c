/*
 * ptyc — spawn a child under a PTY, hand the master fd back.
 *
 * Wire contract (documented in README.md):
 *   stdin  : JSON request   {"argv":[...],"cwd":"...","env":{...},"cols":N,"rows":N}
 *   stdout : JSON response  {"ok":true,"pid":N}  on success
 *   stderr : JSON diagnostic {"ok":false,"error":"...","errno":N}  on failure
 *   fd 3   : unix-domain socket; master fd is sent over SCM_RIGHTS on success
 *
 * Exit codes:
 *   0  success
 *   1  bad request (JSON parse error, missing field, bad value)
 *   2  syscall failed (fork/exec/pty/socket)
 *
 * Dependencies: libc only. POSIX APIs where available (posix_openpt,
 * grantpt, unlockpt, ptsname). Single-threaded, one-shot, ~300 LOC.
 */

#define _POSIX_C_SOURCE 200809L
#define _XOPEN_SOURCE 600

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

/* POSIX exposes `environ` but requires an explicit declaration. We
 * set it to NULL in the child to replace the inherited environment
 * when the caller supplied one — `clearenv()` is GNU-only, not POSIX. */
extern char **environ;

/* Discard write() result without tripping warn_unused_result. We only
 * call this on the exec-failure pipe in the child immediately before
 * _exit(127); the parent either receives the bytes or notices EOF via
 * the CLOEXEC pipe. Nothing useful to do with the return value. */
static void report_errno(int fd, int e) {
  ssize_t r = write(fd, &e, sizeof(e));
  (void)r;
}

#define MAX_ARGV 64
#define MAX_ENV 256
#define MAX_INPUT (64 * 1024)

/* -------------------------------------------------------------------- */
/* error reporting                                                       */
/* -------------------------------------------------------------------- */

static void die_bad_request(const char *msg) {
  fprintf(stderr, "{\"ok\":false,\"error\":\"%s\",\"errno\":0}\n", msg);
  exit(1);
}

static void die_syscall(const char *msg) {
  int e = errno;
  /* Avoid quoting edge cases: strerror results don't contain quotes on
   * any platform we care about; if this ever bites us we'll escape. */
  fprintf(stderr, "{\"ok\":false,\"error\":\"%s: %s\",\"errno\":%d}\n", msg,
          strerror(e), e);
  exit(2);
}

/* -------------------------------------------------------------------- */
/* minimal JSON parser                                                   */
/*                                                                       */
/* Scoped to exactly the shape we accept. String escapes supported for   */
/* the subset we emit (\" \\ \n \r \t \b \f \/ and \uXXXX for ASCII).    */
/* Surrogate pairs, nested arrays, and non-string numbers-as-keys are    */
/* not supported — the daemon never emits them.                          */
/* -------------------------------------------------------------------- */

typedef struct {
  const char *src;
  size_t len;
  size_t pos;
} Parser;

static void p_skip_ws(Parser *p) {
  while (p->pos < p->len) {
    char c = p->src[p->pos];
    if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
      p->pos++;
    } else {
      break;
    }
  }
}

static int p_peek(Parser *p) {
  p_skip_ws(p);
  return p->pos < p->len ? (unsigned char)p->src[p->pos] : -1;
}

static int p_expect(Parser *p, char c) {
  if (p_peek(p) != (unsigned char)c) return 0;
  p->pos++;
  return 1;
}

/* Parse a JSON string into a freshly-allocated NUL-terminated buffer. */
static char *p_string(Parser *p) {
  if (p_peek(p) != '"') return NULL;
  p->pos++;
  size_t start = p->pos;
  /* First pass: find end and compute output length. */
  size_t out_len = 0;
  while (p->pos < p->len && p->src[p->pos] != '"') {
    if (p->src[p->pos] == '\\') {
      if (p->pos + 1 >= p->len) return NULL;
      char esc = p->src[p->pos + 1];
      if (esc == 'u') {
        if (p->pos + 5 >= p->len) return NULL;
        /* We only accept ASCII in \uXXXX. */
        for (int i = 2; i < 6; i++) {
          if (!isxdigit((unsigned char)p->src[p->pos + i])) return NULL;
        }
        p->pos += 6;
      } else {
        p->pos += 2;
      }
      out_len++;
    } else {
      p->pos++;
      out_len++;
    }
  }
  if (p->pos >= p->len || p->src[p->pos] != '"') return NULL;
  size_t end = p->pos;
  p->pos++; /* consume closing quote */

  char *out = malloc(out_len + 1);
  if (!out) return NULL;
  size_t j = 0;
  for (size_t i = start; i < end;) {
    if (p->src[i] == '\\') {
      char esc = p->src[i + 1];
      switch (esc) {
        case '"': out[j++] = '"'; i += 2; break;
        case '\\': out[j++] = '\\'; i += 2; break;
        case '/': out[j++] = '/'; i += 2; break;
        case 'b': out[j++] = '\b'; i += 2; break;
        case 'f': out[j++] = '\f'; i += 2; break;
        case 'n': out[j++] = '\n'; i += 2; break;
        case 'r': out[j++] = '\r'; i += 2; break;
        case 't': out[j++] = '\t'; i += 2; break;
        case 'u': {
          unsigned int cp = 0;
          for (int k = 0; k < 4; k++) {
            char h = p->src[i + 2 + k];
            cp <<= 4;
            if (h >= '0' && h <= '9') cp |= (unsigned)(h - '0');
            else if (h >= 'a' && h <= 'f') cp |= (unsigned)(h - 'a' + 10);
            else if (h >= 'A' && h <= 'F') cp |= (unsigned)(h - 'A' + 10);
          }
          /* ASCII-range only. Anything else is a request-format bug. */
          if (cp > 0x7f) { free(out); return NULL; }
          out[j++] = (char)cp;
          i += 6;
          break;
        }
        default: free(out); return NULL;
      }
    } else {
      out[j++] = p->src[i++];
    }
  }
  out[j] = '\0';
  return out;
}

static int p_int(Parser *p, long *out) {
  p_skip_ws(p);
  size_t start = p->pos;
  if (p->pos < p->len && (p->src[p->pos] == '-' || p->src[p->pos] == '+'))
    p->pos++;
  int digits = 0;
  while (p->pos < p->len && isdigit((unsigned char)p->src[p->pos])) {
    p->pos++;
    digits++;
  }
  if (!digits) {
    p->pos = start;
    return 0;
  }
  char buf[32];
  size_t n = p->pos - start;
  if (n >= sizeof(buf)) return 0;
  memcpy(buf, p->src + start, n);
  buf[n] = '\0';
  *out = strtol(buf, NULL, 10);
  return 1;
}

/* -------------------------------------------------------------------- */
/* request                                                               */
/* -------------------------------------------------------------------- */

typedef struct {
  char *argv[MAX_ARGV + 1]; /* NULL-terminated */
  int argc;
  char *cwd;                    /* optional, NULL means inherit */
  char *env[MAX_ENV + 1];       /* each "KEY=VAL" */
  int envc;
  int cols;
  int rows;
} Request;

static void req_init(Request *r) {
  memset(r, 0, sizeof(*r));
  r->cols = 80;
  r->rows = 24;
}

static void req_free(Request *r) {
  for (int i = 0; i < r->argc; i++) free(r->argv[i]);
  for (int i = 0; i < r->envc; i++) free(r->env[i]);
  free(r->cwd);
}

static void parse_argv(Parser *p, Request *r) {
  if (!p_expect(p, '[')) die_bad_request("argv must be an array");
  if (p_peek(p) == ']') { p->pos++; return; }
  for (;;) {
    if (r->argc >= MAX_ARGV) die_bad_request("argv too long");
    char *s = p_string(p);
    if (!s) die_bad_request("argv element must be a string");
    r->argv[r->argc++] = s;
    if (p_expect(p, ',')) continue;
    if (p_expect(p, ']')) break;
    die_bad_request("malformed argv array");
  }
}

static void parse_env(Parser *p, Request *r) {
  if (!p_expect(p, '{')) die_bad_request("env must be an object");
  if (p_peek(p) == '}') { p->pos++; return; }
  for (;;) {
    if (r->envc >= MAX_ENV) die_bad_request("env too large");
    char *k = p_string(p);
    if (!k) die_bad_request("env key must be a string");
    if (!p_expect(p, ':')) { free(k); die_bad_request("env missing ':'"); }
    char *v = p_string(p);
    if (!v) { free(k); die_bad_request("env value must be a string"); }
    size_t kl = strlen(k), vl = strlen(v);
    char *kv = malloc(kl + 1 + vl + 1);
    if (!kv) { free(k); free(v); die_syscall("malloc"); }
    memcpy(kv, k, kl);
    kv[kl] = '=';
    memcpy(kv + kl + 1, v, vl);
    kv[kl + 1 + vl] = '\0';
    free(k); free(v);
    r->env[r->envc++] = kv;
    if (p_expect(p, ',')) continue;
    if (p_expect(p, '}')) break;
    die_bad_request("malformed env object");
  }
}

static void parse_request(const char *src, size_t len, Request *r) {
  Parser p = { .src = src, .len = len, .pos = 0 };
  if (!p_expect(&p, '{')) die_bad_request("top-level must be an object");
  if (p_peek(&p) == '}') { p.pos++; goto done; }
  for (;;) {
    char *key = p_string(&p);
    if (!key) die_bad_request("key must be a string");
    if (!p_expect(&p, ':')) { free(key); die_bad_request("missing ':'"); }
    if (strcmp(key, "argv") == 0) {
      parse_argv(&p, r);
    } else if (strcmp(key, "cwd") == 0) {
      r->cwd = p_string(&p);
      if (!r->cwd) { free(key); die_bad_request("cwd must be a string"); }
    } else if (strcmp(key, "env") == 0) {
      parse_env(&p, r);
    } else if (strcmp(key, "cols") == 0) {
      long v; if (!p_int(&p, &v)) { free(key); die_bad_request("cols must be an integer"); }
      if (v < 1 || v > 65535) { free(key); die_bad_request("cols out of range"); }
      r->cols = (int)v;
    } else if (strcmp(key, "rows") == 0) {
      long v; if (!p_int(&p, &v)) { free(key); die_bad_request("rows must be an integer"); }
      if (v < 1 || v > 65535) { free(key); die_bad_request("rows out of range"); }
      r->rows = (int)v;
    } else {
      free(key);
      die_bad_request("unknown key");
    }
    free(key);
    if (p_expect(&p, ',')) continue;
    if (p_expect(&p, '}')) break;
    die_bad_request("malformed object");
  }
done:
  if (r->argc == 0) die_bad_request("argv is required and non-empty");
  r->argv[r->argc] = NULL;
  r->env[r->envc] = NULL;
}

/* -------------------------------------------------------------------- */
/* read stdin into a bounded buffer                                      */
/* -------------------------------------------------------------------- */

static char *slurp_stdin(size_t *out_len) {
  char *buf = malloc(MAX_INPUT);
  if (!buf) die_syscall("malloc");
  size_t n = 0;
  while (n < MAX_INPUT) {
    ssize_t r = read(0, buf + n, MAX_INPUT - n);
    if (r == 0) break;
    if (r < 0) {
      if (errno == EINTR) continue;
      die_syscall("read(stdin)");
    }
    n += (size_t)r;
  }
  if (n == MAX_INPUT) die_bad_request("request too large");
  *out_len = n;
  return buf;
}

/* -------------------------------------------------------------------- */
/* PTY open + spawn                                                      */
/* -------------------------------------------------------------------- */

static void send_fd(int sock, int fd) {
  /* sendmsg with SCM_RIGHTS; one byte payload so receiver knows to read. */
  char byte = 'x';
  struct iovec iov = { .iov_base = &byte, .iov_len = 1 };
  union {
    struct cmsghdr hdr;
    char buf[CMSG_SPACE(sizeof(int))];
  } cbuf;
  memset(&cbuf, 0, sizeof(cbuf));

  struct msghdr msg = {0};
  msg.msg_iov = &iov;
  msg.msg_iovlen = 1;
  msg.msg_control = cbuf.buf;
  msg.msg_controllen = sizeof(cbuf.buf);

  struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
  cmsg->cmsg_level = SOL_SOCKET;
  cmsg->cmsg_type = SCM_RIGHTS;
  cmsg->cmsg_len = CMSG_LEN(sizeof(int));
  memcpy(CMSG_DATA(cmsg), &fd, sizeof(int));

  for (;;) {
    ssize_t r = sendmsg(sock, &msg, 0);
    if (r < 0 && errno == EINTR) continue;
    if (r < 0) die_syscall("sendmsg(fd)");
    break;
  }
}

int main(void) {
  Request req;
  req_init(&req);

  size_t in_len = 0;
  char *in = slurp_stdin(&in_len);
  parse_request(in, in_len, &req);
  free(in);

  /* 1. open master */
  int master = posix_openpt(O_RDWR | O_NOCTTY);
  if (master < 0) die_syscall("posix_openpt");
  if (grantpt(master) < 0) die_syscall("grantpt");
  if (unlockpt(master) < 0) die_syscall("unlockpt");

  /* 2. open slave (ptsname is POSIX; we're single-threaded) */
  const char *slave_path = ptsname(master);
  if (!slave_path) die_syscall("ptsname");
  int slave = open(slave_path, O_RDWR | O_NOCTTY);
  if (slave < 0) die_syscall("open(slave)");

  /* 3. apply window size */
  struct winsize ws = {0};
  ws.ws_col = (unsigned short)req.cols;
  ws.ws_row = (unsigned short)req.rows;
  if (ioctl(master, TIOCSWINSZ, &ws) < 0) die_syscall("ioctl(TIOCSWINSZ)");

  /* 4. exec-failure-reporting pipe (CLOEXEC so it auto-closes on success) */
  int ef[2];
  if (pipe(ef) < 0) die_syscall("pipe");
  if (fcntl(ef[1], F_SETFD, FD_CLOEXEC) < 0) die_syscall("fcntl(FD_CLOEXEC)");

  pid_t pid = fork();
  if (pid < 0) die_syscall("fork");

  if (pid == 0) {
    /* ---- child ---- */
    close(master);
    close(ef[0]);

    if (setsid() < 0) { report_errno(ef[1], errno); _exit(127); }
#ifdef TIOCSCTTY
    if (ioctl(slave, TIOCSCTTY, 0) < 0) { report_errno(ef[1], errno); _exit(127); }
#endif
    if (dup2(slave, 0) < 0 || dup2(slave, 1) < 0 || dup2(slave, 2) < 0) {
      report_errno(ef[1], errno);
      _exit(127);
    }
    if (slave > 2) close(slave);

    if (req.cwd && chdir(req.cwd) < 0) { report_errno(ef[1], errno); _exit(127); }

    /* Replace the environment if the caller supplied one; otherwise
     * inherit. Daemon is expected to build the env it wants — this is
     * not a "merge" API. */
    if (req.envc > 0) {
      environ = NULL;
      for (int i = 0; i < req.envc; i++) {
        if (putenv(req.env[i]) != 0) { report_errno(ef[1], errno); _exit(127); }
      }
    }

    execvp(req.argv[0], req.argv);
    /* execvp returned → failure */
    report_errno(ef[1], errno);
    _exit(127);
  }

  /* ---- parent ---- */
  close(slave);
  close(ef[1]);

  int child_errno = 0;
  ssize_t rr;
  for (;;) {
    rr = read(ef[0], &child_errno, sizeof(child_errno));
    if (rr < 0 && errno == EINTR) continue;
    break;
  }
  close(ef[0]);

  if (rr == (ssize_t)sizeof(child_errno)) {
    /* exec failed in child; reap it so we don't leak a zombie. */
    int st;
    (void)waitpid(pid, &st, 0);
    close(master);
    errno = child_errno;
    die_syscall("execvp");
  }
  /* rr == 0: pipe closed via CLOEXEC on successful exec. */

  /* Hand the master fd back to the parent caller over a unix socket.
   * Default fd is 3; callers that can't reliably place the socket at
   * fd 3 (e.g. Python's subprocess with stdout=PIPE shifts pipe fds
   * around fd 3) can override via PTYC_SOCK_FD. */
  int sock_fd = 3;
  const char *sock_env = getenv("PTYC_SOCK_FD");
  if (sock_env && *sock_env) {
    char *endp = NULL;
    long v = strtol(sock_env, &endp, 10);
    if (!endp || *endp != '\0' || v < 0 || v > 65535)
      die_bad_request("PTYC_SOCK_FD must be a non-negative integer");
    sock_fd = (int)v;
  }
  send_fd(sock_fd, master);
  close(master);

  /* Emit success response on stdout and exit. */
  printf("{\"ok\":true,\"pid\":%ld}\n", (long)pid);
  fflush(stdout);

  req_free(&req);
  return 0;
}
