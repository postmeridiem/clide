// Package cli is the CLI front-end. cmd/clide/main.go calls Run with
// os.Args[1:]. Subcommands land here one file per command once Tier 2
// begins (see docs/initial-plan.md).
//
// Stdlib-only for the pre-Tier-0 scaffold. Cobra arrives with the first
// real subcommand surface.
package cli

import (
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"git.schweitz.net/jpmschweitzer/clide/sidecar/internal/diag"
	"git.schweitz.net/jpmschweitzer/clide/sidecar/internal/version"
)

// Run dispatches CLI args. Returns the process exit code per the diag
// contract.
func Run(args []string) int {
	fs := flag.NewFlagSet("clide", flag.ContinueOnError)
	fs.SetOutput(os.Stderr)

	daemon := fs.Bool("daemon", false, "run as the long-running sidecar daemon")
	showVersion := fs.Bool("version", false, "print build info and exit")

	if err := fs.Parse(args); err != nil {
		return diag.Usage
	}

	if *showVersion {
		b, _ := json.Marshal(version.Info())
		fmt.Println(string(b))
		return diag.OK
	}

	if *daemon {
		diag.Error("cli.not-implemented", "daemon mode not yet implemented", "tier 0 — sidecar scaffold lands next")
		return diag.Software
	}

	// No subcommand yet. Surface the pql-style exit 64 so callers can tell
	// the difference between "no instructions" and a successful run.
	rest := fs.Args()
	if len(rest) == 0 {
		diag.Error("cli.usage", "no subcommand given", "see docs/initial-plan.md — Tier 2 defines the CLI surface")
		return diag.Usage
	}

	diag.Error("cli.not-implemented", fmt.Sprintf("subcommand %q not yet implemented", rest[0]), "tier 2 lands the CLI surface")
	return diag.Software
}
