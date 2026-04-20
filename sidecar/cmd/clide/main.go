// Command clide is the CLI and sidecar-daemon entry point.
//
// One binary, two modes:
//   - One-shot CLI (default):   clide <subcommand> [args...]
//   - Long-running sidecar:     clide --daemon
//
// See docs/initial-plan.md and docs/ADRs/ for the architecture.
package main

import (
	"os"

	"git.schweitz.net/jpmschweitzer/clide/sidecar/internal/cli"
)

func main() {
	os.Exit(cli.Run(os.Args[1:]))
}
