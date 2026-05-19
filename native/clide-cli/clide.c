/*
 * clide — thin C client for the in-process IPC server hosted by the
 * Flutter app (T-99 / T-126). Third slice of D-56 path (a).
 *
 * What it does:
 *   1. Walks CWD up to a directory containing `.git` (the workspace
 *      root, same definition the Flutter app uses on boot).
 *   2. Hashes that path with FNV-1a 64-bit and resolves the per-
 *      workspace socket path per D-70 (Linux: $XDG_RUNTIME_DIR/clide/
 *      <hash>.sock; macOS: $HOME/Library/Caches/clide/<hash>.sock).
 *   3. Connects, sends `{"v":1,"type":"request","id":"<pid>",
 *      "cmd":"_argv","args":{"argv":[...]}}` (the server runs
 *      parseArgv on it per T-125), reads the JSON-line response,
 *      writes payload to stdout, error message (if any) to stderr,
 *      exits with the response's exit code.
 *
 * Design notes:
 *   - No third-party deps. Standard POSIX + a minimal JSON writer
 *     (string-escape only — we never PARSE JSON, just emit argv into
 *     it; the response is read whole then printed as-is to stdout).
 *   - The argv→IpcRequest translator lives in Dart (T-125). We just
 *     ship argv across the wire under a sentinel cmd `_argv`; the
 *     server unpacks it.
 *   - Workspace-root discovery: we look for `.git` (dir OR file —
 *     submodules use a file). If we don't find one walking upward,
 *     exit with EX_USAGE.
 *
 * Build: `make clide-cli` (see Makefile). Pure C99, builds with
 * any gcc / clang / cc.
 */

#define _POSIX_C_SOURCE 200809L
#include <ctype.h>
#include <errno.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <unistd.h>

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

#define EX_USAGE 64
#define EX_SOFTWARE 70
#define EX_OSERR 71
#define EX_UNAVAILABLE 69

static const uint64_t FNV_OFFSET = 0xcbf29ce484222325ULL;
static const uint64_t FNV_PRIME  = 0x100000001b3ULL;

static void fnv1a64_hex(const char *s, char out[17]) {
    uint64_t h = FNV_OFFSET;
    for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
        h ^= *p;
        h *= FNV_PRIME;
    }
    /* 16 lowercase hex chars + NUL. */
    snprintf(out, 17, "%016" PRIx64, h);
}

/* Walk `start` upward looking for an entry named `.git`. Writes the
 * containing directory into `out` (PATH_MAX). Returns 0 on success,
 * -1 if no .git was found before /. */
static int find_workspace_root(const char *start, char *out, size_t out_size) {
    char cwd[4096];
    if (start) {
        strncpy(cwd, start, sizeof(cwd) - 1);
        cwd[sizeof(cwd) - 1] = '\0';
    } else if (!getcwd(cwd, sizeof(cwd))) {
        return -1;
    }
    while (1) {
        size_t len = strlen(cwd);
        if (len + 6 >= sizeof(cwd)) return -1;
        char probe[4108];
        snprintf(probe, sizeof(probe), "%s/.git", cwd);
        struct stat st;
        if (lstat(probe, &st) == 0) {
            strncpy(out, cwd, out_size - 1);
            out[out_size - 1] = '\0';
            return 0;
        }
        /* Climb one. /foo/bar -> /foo, / -> stop. */
        if (cwd[0] == '/' && cwd[1] == '\0') return -1;
        char *slash = strrchr(cwd, '/');
        if (!slash) return -1;
        if (slash == cwd) cwd[1] = '\0';
        else *slash = '\0';
    }
}

/* Compose `$XDG_RUNTIME_DIR/clide/<hash>.sock` on Linux,
 * `$HOME/Library/Caches/clide/<hash>.sock` on macOS. */
static int socket_path_for(const char *workspace_root, char *out, size_t out_size) {
    char hash[17];
    fnv1a64_hex(workspace_root, hash);
#ifdef __APPLE__
    const char *home = getenv("HOME");
    if (!home || !*home) home = "/tmp";
    return snprintf(out, out_size, "%s/Library/Caches/clide/%s.sock", home, hash);
#else
    const char *xdg = getenv("XDG_RUNTIME_DIR");
    if (!xdg || !*xdg) xdg = "/tmp";
    return snprintf(out, out_size, "%s/clide/%s.sock", xdg, hash);
#endif
}

/* Open a UNIX-domain stream socket connected to `path`. Returns fd
 * on success, -1 on failure (errno set). */
static int connect_unix(const char *path) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (strlen(path) >= sizeof(addr.sun_path)) {
        close(fd);
        errno = ENAMETOOLONG;
        return -1;
    }
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        int saved = errno;
        close(fd);
        errno = saved;
        return -1;
    }
    return fd;
}

/* Emit `s` as a JSON string literal (quotes + standard escapes) to
 * `out`. Caller ensures `out` is large enough — we cap at 8 * input
 * length + 2 (worst case is every byte → \uXXXX). */
static void json_escape(const char *s, char *out, size_t out_size) {
    size_t j = 0;
    out[j++] = '"';
    for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
        if (j + 8 >= out_size) break;
        switch (*p) {
            case '"':  out[j++] = '\\'; out[j++] = '"'; break;
            case '\\': out[j++] = '\\'; out[j++] = '\\'; break;
            case '\b': out[j++] = '\\'; out[j++] = 'b'; break;
            case '\f': out[j++] = '\\'; out[j++] = 'f'; break;
            case '\n': out[j++] = '\\'; out[j++] = 'n'; break;
            case '\r': out[j++] = '\\'; out[j++] = 'r'; break;
            case '\t': out[j++] = '\\'; out[j++] = 't'; break;
            default:
                if (*p < 0x20) {
                    j += snprintf(out + j, out_size - j, "\\u%04x", *p);
                } else {
                    out[j++] = (char)*p;
                }
        }
    }
    if (j + 1 < out_size) out[j++] = '"';
    out[j] = '\0';
}

/* Build the request envelope and write it to `out`. Returns 0 on
 * success, -1 if any input was too large. */
static int build_request(int argc, char **argv, pid_t pid, char *out, size_t out_size) {
    /* Compute argv array size: each arg gets its own escaped JSON. */
    int n = snprintf(out, out_size,
        "{\"type\":\"request\",\"v\":1,\"id\":\"c%lld\",\"cmd\":\"_argv\",\"args\":{\"argv\":[",
        (long long)pid);
    if (n < 0 || (size_t)n >= out_size) return -1;
    for (int i = 0; i < argc; i++) {
        char esc[4096];
        json_escape(argv[i], esc, sizeof(esc));
        n += snprintf(out + n, out_size - n, "%s%s", i ? "," : "", esc);
        if (n < 0 || (size_t)n >= out_size) return -1;
    }
    n += snprintf(out + n, out_size - n, "]}}\n");
    return (n < 0 || (size_t)n >= out_size) ? -1 : 0;
}

/* Read one line (terminated by \n) from fd into out. Returns 0 on
 * success, -1 on EOF / error. The trailing \n is stripped. */
static int read_line(int fd, char *out, size_t out_size) {
    size_t i = 0;
    while (i + 1 < out_size) {
        char c;
        ssize_t r = read(fd, &c, 1);
        if (r <= 0) {
            if (r < 0 && errno == EINTR) continue;
            return -1;
        }
        if (c == '\n') {
            out[i] = '\0';
            return 0;
        }
        out[i++] = c;
    }
    out[i] = '\0';
    /* Line too long; treat as overflow but keep what we have. */
    return -1;
}

/* Minimal JSON peek: locate the bytes between `"key":` and the next
 * sibling separator (`,` or `}`). Returns a pointer into `buf` and
 * writes the length to *out_len. Returns NULL if the key isn't
 * found. This is a deliberately tiny scanner — we never need to
 * fully parse the response, just pick out `ok`, `code`, `message`,
 * `data`. The response is well-formed by construction (the server
 * builds it via Dart's JSON encoder). */
static const char *json_value(const char *buf, const char *key, size_t *out_len) {
    /* Search for `"key": ` (allow optional whitespace). */
    char needle[128];
    snprintf(needle, sizeof(needle), "\"%s\"", key);
    const char *p = strstr(buf, needle);
    if (!p) return NULL;
    p += strlen(needle);
    while (*p == ' ' || *p == '\t') p++;
    if (*p != ':') return NULL;
    p++;
    while (*p == ' ' || *p == '\t') p++;
    const char *start = p;
    int depth = 0;
    int in_str = 0;
    while (*p) {
        if (in_str) {
            if (*p == '\\' && p[1]) { p += 2; continue; }
            if (*p == '"') in_str = 0;
        } else {
            if (*p == '"') in_str = 1;
            else if (*p == '{' || *p == '[') depth++;
            else if (*p == '}' || *p == ']') {
                if (depth == 0) break;
                depth--;
            } else if (*p == ',' && depth == 0) break;
        }
        p++;
    }
    *out_len = (size_t)(p - start);
    return start;
}

int main(int argc, char **argv) {
    /* argv[0] is the program name; everything after is what the user
     * typed after `clide`. */
    if (argc < 2) {
        fprintf(stderr, "usage: clide <subsystem> <verb> [args...]\n"
                        "       clide status | tail | version | ping\n");
        return EX_USAGE;
    }

    char ws_root[4096];
    if (find_workspace_root(NULL, ws_root, sizeof(ws_root)) != 0) {
        fprintf(stderr, "clide: not inside a git repository — no workspace to talk to\n");
        return EX_USAGE;
    }

    char sock_path[4096];
    if (socket_path_for(ws_root, sock_path, sizeof(sock_path)) >= (int)sizeof(sock_path)) {
        fprintf(stderr, "clide: socket path overflow\n");
        return EX_SOFTWARE;
    }

    int fd = connect_unix(sock_path);
    if (fd < 0) {
        fprintf(stderr, "clide: cannot connect to %s: %s\n", sock_path, strerror(errno));
        return EX_UNAVAILABLE;
    }

    /* Build + send request. Worst-case envelope sizing: argv totals
     * plus JSON overhead. 64 KB envelope handles 4 KB args * 16. */
    char req[65536];
    if (build_request(argc - 1, argv + 1, getpid(), req, sizeof(req)) != 0) {
        fprintf(stderr, "clide: request payload too large\n");
        close(fd);
        return EX_USAGE;
    }
    if (write(fd, req, strlen(req)) != (ssize_t)strlen(req)) {
        fprintf(stderr, "clide: write failed: %s\n", strerror(errno));
        close(fd);
        return EX_OSERR;
    }

    /* Read the response — one JSON line. */
    char resp[65536];
    if (read_line(fd, resp, sizeof(resp)) != 0) {
        fprintf(stderr, "clide: response read failed: %s\n",
                errno ? strerror(errno) : "short read");
        close(fd);
        return EX_OSERR;
    }

    /* Pull out `ok`, `data`/`error` from the response. */
    size_t ok_len = 0, data_len = 0, code_len = 0, msg_len = 0;
    const char *ok_v = json_value(resp, "ok", &ok_len);
    int ok = (ok_v && ok_len >= 4 && strncmp(ok_v, "true", 4) == 0);
    if (ok) {
        const char *data = json_value(resp, "data", &data_len);
        if (data) {
            fwrite(data, 1, data_len, stdout);
            fputc('\n', stdout);
            fflush(stdout);
        } else {
            fputs("{}\n", stdout);
            fflush(stdout);
        }
        /* If the server flagged this as a streaming response
         * (`tail --events` per T-129), loop-read event JSON-lines
         * until the connection closes. Detection: look for the
         * literal `"streaming":true` inside the data blob. */
        if (data && data_len > 0) {
            char data_copy[16384];
            size_t copy_len = data_len < sizeof(data_copy) - 1 ? data_len : sizeof(data_copy) - 1;
            memcpy(data_copy, data, copy_len);
            data_copy[copy_len] = '\0';
            if (strstr(data_copy, "\"streaming\":true") != NULL || strstr(data_copy, "\"streaming\": true") != NULL) {
                /* Streaming mode — keep reading event lines. Exit
                 * 0 on EOF (server closed cleanly), non-zero on
                 * read error. */
                char ev[65536];
                while (read_line(fd, ev, sizeof(ev)) == 0) {
                    fputs(ev, stdout);
                    fputc('\n', stdout);
                    fflush(stdout);
                }
                close(fd);
                return 0;
            }
        }
        close(fd);
        return 0;
    }
    close(fd);
    const char *code_v = json_value(resp, "code", &code_len);
    const char *msg_v = json_value(resp, "message", &msg_len);
    int exit_code = code_v ? (int)strtol(code_v, NULL, 10) : EX_SOFTWARE;
    if (msg_v) {
        /* Trim the surrounding quotes from the JSON string literal. */
        if (msg_len >= 2 && msg_v[0] == '"' && msg_v[msg_len - 1] == '"') {
            fwrite(msg_v + 1, 1, msg_len - 2, stderr);
        } else {
            fwrite(msg_v, 1, msg_len, stderr);
        }
        fputc('\n', stderr);
    }
    return exit_code;
}
