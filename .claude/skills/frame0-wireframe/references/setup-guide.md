# Frame0 Setup Guide

## Installation (Fedora)

Download from https://frame0.app/download and install the RPM:

```bash
sudo dnf install ./frame0-*.x86_64.rpm
```

Requires: Fedora 40 or later (x86_64).

## Starting Frame0

Launch the desktop application:

```bash
frame0 &
```

Frame0 exposes an HTTP API at `localhost:58320` when running.

## Verify API Access

```bash
.claude/skills/frame0-wireframe/scripts/frame0-cmd.sh health
```

Expected output: `Frame0 is running on port 58320`

## Port Configuration

Default port: **58320**

To use a different port, set the environment variable:

```bash
export FRAME0_PORT=58321
```

Or pass `--port` to any script:

```bash
.claude/skills/frame0-wireframe/scripts/frame0-cmd.sh --port 58321 health
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Connection refused" | Frame0 not running | Start the desktop app |
| "Port in use" | Another instance running | Close duplicate or use different port |
| Script hangs | API unresponsive | Restart Frame0 |
