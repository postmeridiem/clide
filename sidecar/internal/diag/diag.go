// Package diag defines the exit-code contract and emits structured
// diagnostics to stderr as line-delimited JSON.
//
// Mirrors pql's diag contract so Claude (and any other tool that
// consumes both CLIs) sees a single shape.
package diag

import (
	"encoding/json"
	"io"
	"os"
)

// Exit codes. Same numeric space as pql's.
const (
	OK       = 0  // success
	NoMatch  = 2  // success with zero matches / nothing to do
	Usage    = 64 // EX_USAGE — bad CLI flag or missing subcommand
	DataErr  = 65 // EX_DATAERR — malformed request
	NoInput  = 66 // EX_NOINPUT — missing required resource (repo, socket, file)
	Unavail  = 69 // EX_UNAVAILABLE — sidecar unreachable / subsystem down
	Software = 70 // EX_SOFTWARE — internal error
)

type Level string

const (
	LevelWarn  Level = "warn"
	LevelError Level = "error"
)

// Diagnostic is one entry in the stderr JSON-per-line stream.
type Diagnostic struct {
	Level Level  `json:"level"`
	Code  string `json:"code"`
	Msg   string `json:"msg"`
	Hint  string `json:"hint,omitempty"`
}

// Emit writes a diagnostic as one JSON line to w.
func Emit(w io.Writer, d Diagnostic) {
	b, err := json.Marshal(d)
	if err != nil {
		_, _ = io.WriteString(w, `{"level":"error","code":"diag.marshal","msg":"failed to marshal diagnostic"}`+"\n")
		return
	}
	_, _ = w.Write(append(b, '\n'))
}

// Warn emits a warning diagnostic to stderr.
func Warn(code, msg string) {
	Emit(os.Stderr, Diagnostic{Level: LevelWarn, Code: code, Msg: msg})
}

// Error emits an error diagnostic to stderr.
func Error(code, msg, hint string) {
	Emit(os.Stderr, Diagnostic{Level: LevelError, Code: code, Msg: msg, Hint: hint})
}
