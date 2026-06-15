#!/bin/sh
# Build the C `clide` client with MSVC on Windows (Git Bash / MSYS).
# Wrapped by `make clide-cli` — don't run directly (see CLAUDE.md
# tooling discipline). Finds the VC++ toolset via vswhere, loads the
# x64 dev environment, compiles:
#   native/clide-cli/clide.c -> native/windows-x64/clide.exe
# ws2_32.lib supplies winsock (AF_UNIX socket support).
set -e

VSWHERE="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
if [ ! -x "$VSWHERE" ]; then
  echo "vswhere.exe not found — install Visual Studio (Build Tools) with the C++ workload" >&2
  exit 1
fi
VSROOT=$("$VSWHERE" -products '*' -latest -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath | tr -d '\r')
if [ -z "$VSROOT" ]; then
  echo "no Visual Studio C++ x64 toolset found (vswhere returned nothing)" >&2
  exit 1
fi

mkdir -p native/windows-x64
# A generated .bat sidesteps the unwinnable sh->cmd quote escaping for
# the space-laden VS path. //c keeps MSYS from path-mangling cmd's /c
# switch; /Fo drops the .obj next to the .exe so the repo root stays
# clean.
BAT=$(mktemp --suffix=.bat)
trap 'rm -f "$BAT"' EXIT
cat > "$BAT" <<EOF
@call "$VSROOT\\Common7\\Tools\\VsDevCmd.bat" -arch=amd64 -no_logo
@cl /nologo /O2 /W4 /D_CRT_SECURE_NO_WARNINGS native\\clide-cli\\clide.c /Fonative\\windows-x64\\ /Fe:native\\windows-x64\\clide.exe ws2_32.lib
EOF
cmd.exe //c "$(cygpath -w "$BAT")"
rm -f native/windows-x64/clide.obj
