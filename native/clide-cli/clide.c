/*
 * clide — thin C client for the in-process IPC server hosted by the
 * Flutter app (T-99 / T-126). Third slice of D-56 path (a).
 *
 * What it does:
 *   1. Walks CWD up to a directory containing `.git` (the workspace
 *      root, same definition the Flutter app uses on boot).
 *   2. Hashes that path with FNV-1a 64-bit and resolves the per-
 *      workspace socket path per D-70 (Linux: $XDG_RUNTIME_DIR/clide/
 *      <hash>.sock; macOS: $HOME/Library/Caches/clide/<hash>.sock;
 *      Windows: %LOCALAPPDATA%\clide\<hash>.sock — AF_UNIX works on
 *      Windows 10 1803+ via afunix.h).
 *   3. Connects, sends `{"v":1,"type":"request","id":"<pid>",
 *      "cmd":"_argv","args":{"argv":[...]}}` (the server runs
 *      parseArgv on it per T-125), reads the JSON-line response,
 *      writes payload to stdout, error message (if any) to stderr,
 *      exits with the response's exit code.
 *
 * Design notes:
 *   - No third-party deps. Standard POSIX / Win32 + a minimal JSON
 *     writer (string-escape only — we never PARSE JSON, just emit argv
 *     into it; the response is read whole then printed as-is).
 *   - The argv→IpcRequest translator lives in Dart (T-125). We just
 *     ship argv across the wire under a sentinel cmd `_argv`; the
 *     server unpacks it.
 *   - Workspace-root discovery: we look for `.git` (dir OR file —
 *     submodules use a file). If we don't find one walking upward,
 *     exit with EX_USAGE.
 *   - Windows hashes the CANONICAL workspace key: backslash
 *     separators + ASCII-lower-cased UTF-8 bytes, matching
 *     `canonicalWorkspaceKey` in lib/src/ipc/paths.dart. NTFS is
 *     case-insensitive, so the same workspace can be spelled many
 *     ways; both sides fold to one spelling before hashing.
 *
 * Build: `make clide-cli` (see Makefile). Pure C99: gcc / clang / cc
 * on POSIX, MSVC cl (+ ws2_32.lib) on Windows.
 */

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <afunix.h>
#include <windows.h>
#include <process.h>
#else
#define _POSIX_C_SOURCE 200809L
#include <dirent.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/un.h>
#include <unistd.h>
#endif

#include <ctype.h>
#include <errno.h>
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef __APPLE__
#include <TargetConditionals.h>
#endif

#define EX_USAGE 64
#define EX_SOFTWARE 70
#define EX_OSERR 71
#define EX_UNAVAILABLE 69

/* -- tiny platform shim ------------------------------------------------- */

#ifdef _WIN32
typedef SOCKET sock_t;
#define NET_INVALID INVALID_SOCKET
static int net_read(sock_t s, char *buf, int n) { return recv(s, buf, n, 0); }
static int net_write(sock_t s, const char *buf, int n) { return send(s, buf, n, 0); }
static void net_close(sock_t s) { closesocket(s); }
static int net_errno(void) { return WSAGetLastError(); }
static const char *net_strerror(int e) {
    static char msg[256];
    snprintf(msg, sizeof(msg), "winsock error %d", e);
    return msg;
}
#define clide_getpid _getpid
#else
typedef int sock_t;
#define NET_INVALID (-1)
static int net_read(sock_t s, char *buf, int n) { return (int)read(s, buf, (size_t)n); }
static int net_write(sock_t s, const char *buf, int n) { return (int)write(s, buf, (size_t)n); }
static void net_close(sock_t s) { close(s); }
static int net_errno(void) { return errno; }
static const char *net_strerror(int e) { return strerror(e); }
#define clide_getpid getpid
#endif

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

#ifdef _WIN32

/* Walk CWD upward looking for `.git` using the wide API (the path can
 * contain anything; ANSI getcwd would mangle non-ACP characters), then
 * emit the CANONICAL UTF-8 key: backslashes + ASCII-folded lower case.
 * Mirrors `canonicalWorkspaceKey` in lib/src/ipc/paths.dart. */
static int find_workspace_root(const char *start, char *out, size_t out_size) {
    (void)start; /* CWD-only on Windows; start override is unused. */
    wchar_t cwd[4096];
    DWORD n = GetCurrentDirectoryW(4096, cwd);
    if (n == 0 || n >= 4096) return -1;
    while (1) {
        size_t len = wcslen(cwd);
        wchar_t probe[4200];
        _snwprintf(probe, 4200, (len > 0 && cwd[len - 1] == L'\\') ? L"%s.git" : L"%s\\.git", cwd);
        probe[4199] = L'\0';
        if (GetFileAttributesW(probe) != INVALID_FILE_ATTRIBUTES) {
            int r = WideCharToMultiByte(CP_UTF8, 0, cwd, -1, out, (int)out_size, NULL, NULL);
            if (r <= 0) return -1;
            /* Canonical fold: '/' -> '\', ASCII upper -> lower. UTF-8
             * continuation bytes have the high bit set, so the ASCII
             * fold never touches multi-byte sequences. */
            for (char *p = out; *p; p++) {
                if (*p == '/') *p = '\\';
                else if (*p >= 'A' && *p <= 'Z') *p = (char)(*p + 32);
            }
            return 0;
        }
        /* Climb one. `C:\foo` -> `C:\`; stop once the drive/UNC root
         * itself has been probed. */
        wchar_t *slash = wcsrchr(cwd, L'\\');
        if (!slash) return -1;
        if (len <= 3 && cwd[1] == L':') return -1; /* at "X:\" already */
        if (slash == cwd + 2 && cwd[1] == L':') {
            cwd[3] = L'\0'; /* keep the root's backslash: "X:\" */
        } else if (slash == cwd) {
            return -1;
        } else {
            *slash = L'\0';
        }
    }
}

/* `%LOCALAPPDATA%\clide\<hash>.sock` */
static int socket_path_for(const char *workspace_root, char *out, size_t out_size) {
    char hash[17];
    fnv1a64_hex(workspace_root, hash);
    const char *local = getenv("LOCALAPPDATA");
    if (!local || !*local) {
        const char *prof = getenv("USERPROFILE");
        if (!prof || !*prof) return -1;
        return snprintf(out, out_size, "%s\\AppData\\Local\\clide\\%s.sock", prof, hash);
    }
    return snprintf(out, out_size, "%s\\clide\\%s.sock", local, hash);
}

#else /* !_WIN32 */

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
            snprintf(out, out_size, "%s", cwd);
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

#endif /* _WIN32 */

/* Open a UNIX-domain stream socket connected to `path`. Returns the
 * socket on success, NET_INVALID on failure (net_errno() set). */
static sock_t connect_unix(const char *path) {
#ifdef _WIN32
    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) return NET_INVALID;
    SOCKADDR_UN addr;
#else
    struct sockaddr_un addr;
#endif
    sock_t fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd == NET_INVALID) return NET_INVALID;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    if (strlen(path) >= sizeof(addr.sun_path)) {
        net_close(fd);
#ifndef _WIN32
        errno = ENAMETOOLONG;
#endif
        return NET_INVALID;
    }
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        int saved = net_errno();
        net_close(fd);
#ifndef _WIN32
        errno = saved;
#else
        WSASetLastError(saved);
#endif
        return NET_INVALID;
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
static int build_request(int argc, char **argv, long long pid, char *out, size_t out_size) {
    /* Compute argv array size: each arg gets its own escaped JSON. */
    int n = snprintf(out, out_size,
        "{\"type\":\"request\",\"v\":1,\"id\":\"c%lld\",\"cmd\":\"_argv\",\"args\":{\"argv\":[",
        pid);
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

/* Read one line (terminated by \n) from the socket into out. Returns
 * 0 on success, -1 on EOF / error. The trailing \n is stripped. */
static int read_line(sock_t fd, char *out, size_t out_size) {
    size_t i = 0;
    while (i + 1 < out_size) {
        char c;
        int r = net_read(fd, &c, 1);
        if (r <= 0) {
#ifndef _WIN32
            if (r < 0 && errno == EINTR) continue;
#endif
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

/* `clide instances` (T-247): probe every *.sock in the runtime dir, ask each
 * live one who it is (`instance`), and print its identity JSON one per line
 * (jsonl). Dead sockets are skipped — this is also how you find which instance
 * to point CLIDE_SOCK at. */
#ifndef _WIN32
static int list_instances(void) {
    char dir[4096];
#ifdef __APPLE__
    const char *home = getenv("HOME");
    if (!home || !*home) home = "/tmp";
    snprintf(dir, sizeof(dir), "%s/Library/Caches/clide", home);
#else
    const char *xdg = getenv("XDG_RUNTIME_DIR");
    if (!xdg || !*xdg) xdg = "/tmp";
    snprintf(dir, sizeof(dir), "%s/clide", xdg);
#endif
    DIR *d = opendir(dir);
    if (!d) return 0; /* no dir yet → no instances; not an error */
    char *qargv[] = {(char *)"instance"};
    struct dirent *ent;
    while ((ent = readdir(d)) != NULL) {
        size_t nlen = strlen(ent->d_name);
        if (nlen < 5 || strcmp(ent->d_name + nlen - 5, ".sock") != 0) continue;
        char path[4096];
        if (snprintf(path, sizeof(path), "%s/%s", dir, ent->d_name) >= (int)sizeof(path)) continue;
        sock_t fd = connect_unix(path);
        if (fd == NET_INVALID) continue; /* dead socket — skip */
        char req[1024];
        if (build_request(1, qargv, (long long)clide_getpid(), req, sizeof(req)) == 0 &&
            net_write(fd, req, (int)strlen(req)) == (int)strlen(req)) {
            char resp[65536];
            if (read_line(fd, resp, sizeof(resp)) == 0) {
                size_t dlen = 0;
                const char *data = json_value(resp, "data", &dlen);
                if (data) {
                    fwrite(data, 1, dlen, stdout);
                    fputc('\n', stdout);
                }
            }
        }
        net_close(fd);
    }
    closedir(d);
    fflush(stdout);
    return 0;
}
#else
static int list_instances(void) {
    fprintf(stderr, "clide: `instances` is not supported on Windows yet\n");
    return EX_USAGE;
}
#endif

int main(int argc, char **argv) {
    /* argv[0] is the program name; everything after is what the user
     * typed after `clide`. */
    if (argc < 2) {
        fprintf(stderr, "usage: clide <subsystem> <verb> [args...]\n"
                        "       clide instances | status | tail | version | ping\n");
        return EX_USAGE;
    }

    /* `instances` scans the runtime dir rather than connecting to one socket
     * (T-247) — handle it before the single-target resolution below. */
    if (strcmp(argv[1], "instances") == 0) {
        return list_instances();
    }

    /* CLIDE_SOCK is an explicit target that beats workspace discovery (T-247):
     * a spawned agent inherits the parent app's socket path here, and a human
     * can pin a specific instance. When it's set we connect to it and FAIL
     * LOUDLY if it's dead — never silently fall back to discovering a different
     * instance (that's the split-brain footgun this fixes). Unset → the
     * deterministic per-workspace path (D-70). */
    char sock_path[4096];
    const char *env_sock = getenv("CLIDE_SOCK");
    if (env_sock && *env_sock) {
        if (strlen(env_sock) >= sizeof(sock_path)) {
            fprintf(stderr, "clide: CLIDE_SOCK path too long\n");
            return EX_USAGE;
        }
        strncpy(sock_path, env_sock, sizeof(sock_path) - 1);
        sock_path[sizeof(sock_path) - 1] = '\0';
    } else {
        char ws_root[4096];
        if (find_workspace_root(NULL, ws_root, sizeof(ws_root)) != 0) {
            fprintf(stderr, "clide: not inside a git repository — no workspace to talk to "
                            "(set CLIDE_SOCK to target a specific instance)\n");
            return EX_USAGE;
        }
        if (socket_path_for(ws_root, sock_path, sizeof(sock_path)) >= (int)sizeof(sock_path)) {
            fprintf(stderr, "clide: socket path overflow\n");
            return EX_SOFTWARE;
        }
    }

    sock_t fd = connect_unix(sock_path);
    if (fd == NET_INVALID) {
        fprintf(stderr, "clide: cannot connect to %s: %s\n", sock_path, net_strerror(net_errno()));
        return EX_UNAVAILABLE;
    }

    /* Build + send request. Worst-case envelope sizing: argv totals
     * plus JSON overhead. 64 KB envelope handles 4 KB args * 16. */
    char req[65536];
    if (build_request(argc - 1, argv + 1, (long long)clide_getpid(), req, sizeof(req)) != 0) {
        fprintf(stderr, "clide: request payload too large\n");
        net_close(fd);
        return EX_USAGE;
    }
    if (net_write(fd, req, (int)strlen(req)) != (int)strlen(req)) {
        fprintf(stderr, "clide: write failed: %s\n", net_strerror(net_errno()));
        net_close(fd);
        return EX_OSERR;
    }

    /* Read the response — one JSON line. */
    char resp[65536];
    if (read_line(fd, resp, sizeof(resp)) != 0) {
        fprintf(stderr, "clide: response read failed: %s\n", net_strerror(net_errno()));
        net_close(fd);
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
                net_close(fd);
                return 0;
            }
        }
        net_close(fd);
        return 0;
    }
    net_close(fd);
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
