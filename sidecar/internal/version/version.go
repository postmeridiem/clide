// Package version exposes build-info stamped via -ldflags at build time.
// See the root Makefile's LDFLAGS for the -X targets.
package version

import "runtime"

var (
	Version = "dev"
	Commit  = "unknown"
	Date    = "unknown"
)

// SchemaVersion tracks the app↔sidecar IPC contract. Bump when the wire
// format changes in a way that requires coordinated app and sidecar
// updates. Mirror in project.yaml `schema_version:` when that field is
// added there.
const SchemaVersion = 0

type BuildInfo struct {
	Version       string `json:"version"`
	Commit        string `json:"commit"`
	Date          string `json:"date"`
	GoVersion     string `json:"go_version"`
	SchemaVersion int    `json:"schema_version"`
}

func Info() BuildInfo {
	return BuildInfo{
		Version:       Version,
		Commit:        Commit,
		Date:          Date,
		GoVersion:     runtime.Version(),
		SchemaVersion: SchemaVersion,
	}
}
