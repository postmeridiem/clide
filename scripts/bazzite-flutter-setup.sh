#!/usr/bin/env bash
# Bazzite / Fedora Silverblue Flutter setup.
#
# Does two things:
#   1. Installs the Flutter SDK tarball into $HOME/opt/flutter and wires
#      $HOME/opt/flutter/bin onto PATH via ~/.bashrc / ~/.zshrc.
#   2. Layers Flutter's Linux desktop build deps onto the immutable base
#      via `rpm-ostree install`. This change only takes effect on the
#      next reboot.
#
# After this script: reboot (if rpm-ostree staged a new deployment),
# then `flutter doctor` to verify. See the final message for specifics.
#
# Env overrides:
#   FLUTTER_PREFIX   install path (default: $HOME/opt/flutter)
#   FLUTTER_VERSION  pin a specific stable version (default: auto-detect latest)
set -euo pipefail

FLUTTER_PREFIX="${FLUTTER_PREFIX:-$HOME/opt/flutter}"
FLUTTER_VERSION="${FLUTTER_VERSION:-}"
RELEASES_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"

info()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m==>\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31m==>\033[0m %s\n' "$*" >&2; exit 1; }

# --- sanity ------------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
  die "don't run this as root; it will sudo only where needed."
fi

if ! command -v rpm-ostree >/dev/null 2>&1; then
  warn "rpm-ostree not found — this script targets Bazzite/Silverblue/Kinoite."
  warn "on a mutable Fedora you'd use dnf; on another distro, translate the package list."
  die  "aborting; adapt the script if that's really what you want."
fi

for tool in curl tar python3; do
  command -v "$tool" >/dev/null 2>&1 || die "required tool missing: $tool"
done

# --- resolve Flutter version -------------------------------------------------
if [ -z "$FLUTTER_VERSION" ]; then
  info "querying Flutter's releases feed for current stable…"
  FLUTTER_VERSION="$(
    curl -fsSL "$RELEASES_URL" | python3 -c '
import sys, json
j = json.load(sys.stdin)
h = j["current_release"]["stable"]
rel = next(r for r in j["releases"] if r["hash"] == h)
print(rel["version"])
'
  )" || die "couldn'\''t discover current stable Flutter version; set FLUTTER_VERSION=x.y.z and re-run."
fi
ok "target: Flutter $FLUTTER_VERSION (stable)"

# --- install Flutter to $FLUTTER_PREFIX --------------------------------------
if [ -d "$FLUTTER_PREFIX" ]; then
  warn "$FLUTTER_PREFIX already exists; skipping download."
  warn "delete it first if you want a clean reinstall."
else
  mkdir -p "$(dirname "$FLUTTER_PREFIX")"
  tarball="$(mktemp -t flutter-XXXXXX.tar.xz)"
  trap 'rm -f "$tarball"' EXIT

  url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  info "downloading: $url"
  curl -fSL --progress-bar -o "$tarball" "$url"

  info "extracting to $(dirname "$FLUTTER_PREFIX")"
  tar -xf "$tarball" -C "$(dirname "$FLUTTER_PREFIX")"
  ok "Flutter installed at $FLUTTER_PREFIX"
fi

# --- PATH wiring -------------------------------------------------------------
wire_path() {
  local rc="$1"
  [ -f "$rc" ] || return 0
  if grep -q 'opt/flutter/bin' "$rc" 2>/dev/null; then
    warn "$rc already references opt/flutter/bin; leaving it alone."
    return 0
  fi
  {
    printf '\n'
    printf '# Flutter (added by bazzite-flutter-setup-pre-reboot.sh on %s)\n' "$(date -u +%Y-%m-%d)"
    printf 'export PATH="%s/bin:$PATH"\n' "$FLUTTER_PREFIX"
  } >> "$rc"
  ok "appended PATH export to $rc"
}
wire_path "$HOME/.bashrc"
wire_path "$HOME/.zshrc"

# Make it visible for the rest of this script.
export PATH="$FLUTTER_PREFIX/bin:$PATH"

# --- pre-cache Linux desktop artifacts --------------------------------------
# Downloading the engine + tools cache now means the first `flutter build`
# after reboot doesn't blow up with a network fetch. Mobile / web / Windows
# / macOS caches are skipped — not targets here.
info "pre-caching Linux desktop artifacts (skipping mobile/web/windows/macos)…"
"$FLUTTER_PREFIX/bin/flutter" precache --linux --no-ios --no-android --no-web --no-windows --no-macos || \
  warn "precache failed or partial; post-reboot script will surface anything still missing."

# --- layer native build deps via rpm-ostree ---------------------------------
BUILD_DEPS=(
  clang
  cmake
  ninja-build
  pkg-config
  gtk3-devel
  xz-devel
)

info "layering build deps onto the base image via rpm-ostree:"
printf '    %s\n' "${BUILD_DEPS[@]}"
warn "this requires sudo and only takes effect after the next reboot."

if ! sudo rpm-ostree install --idempotent "${BUILD_DEPS[@]}"; then
  die "rpm-ostree install failed; fix the error above and re-run."
fi

# --- wrap up -----------------------------------------------------------------
ok "setup complete."

cat <<'EOF'

Next steps:

  1. Check whether a reboot is required:
         rpm-ostree status

     If a new deployment is staged, reboot to activate it:
         systemctl reboot

     If no new deployment is staged, the build deps were already layered
     and you can skip straight to step 2.

  2. Open a new shell (or `source ~/.bashrc` / `source ~/.zshrc`) so PATH
     picks up Flutter, then verify:
         flutter config --enable-linux-desktop
         flutter doctor -v

     Fix anything marked [!] or [x] under "Flutter" or "Linux toolchain".

  3. Scaffold the Flutter app per ADR 0005 (Option B — mini-monorepo),
     from the repo root:
         flutter create app \
           --project-name clide_app \
           --org net.schweitz.clide \
           --platforms linux,macos \
           --empty
EOF
