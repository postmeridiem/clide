# clide — local dev targets. CI scripts in ci/ shell out to these.
#
# Single Flutter package at the repo root. Native supporter tools
# (ptyc, future peers) live in their own directories.

INSTALL_DIR ?= $(HOME)/.local/bin

# -- OS detection ------------------------------------------------------------
# Maps uname to Flutter device/build targets: linux, macos, windows.

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
  FLUTTER_OS := linux
else ifeq ($(UNAME_S),Darwin)
  FLUTTER_OS := macos
else
  # Windows (MSYS2, Git Bash, Cygwin all report variants with "MINGW"/"MSYS"/"CYGWIN")
  FLUTTER_OS := windows
endif

VERSION      ?= $(shell awk -F': *' '/^version:/ {gsub(/[" ]/,"",$$2); print $$2; exit}' pubspec.yaml)
DATE         ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# -- app (Flutter) -------------------------------------------------------

.PHONY: run
run: ## Launch the Flutter desktop app.
ifeq ($(FLUTTER_OS),linux)
	GDK_BACKEND=x11 LD_LIBRARY_PATH=$(CURDIR)/native/linux-x64$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH} flutter run -d linux --dart-define=CLIDE_PROJECT=$(CURDIR)
else
	flutter run -d $(FLUTTER_OS) --dart-define=CLIDE_PROJECT=$(CURDIR)
endif

TESTMODE_CATEGORY ?= all
TESTMODE_TIMEOUT  ?= 60

.PHONY: run-testmode
run-testmode: ## Launch ClideTestApp (TESTMODE_CATEGORY=toolchain|ipc|extensions|all).
ifeq ($(FLUTTER_OS),linux)
	@GDK_BACKEND=x11 LD_LIBRARY_PATH=$(CURDIR)/native/linux-x64$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH} \
	  flutter run -d linux \
	    --dart-define=CLIDE_PROJECT=$(CURDIR) \
	    --dart-define=CLIDE_TESTMODE=$(TESTMODE_CATEGORY) 2>&1 \
	  | tee /tmp/clide-testmode.log & PID=$$!; \
	  (sleep $(TESTMODE_TIMEOUT) && kill $$PID 2>/dev/null) & TIMER=$$!; \
	  wait $$PID 2>/dev/null; kill $$TIMER 2>/dev/null; \
	  grep -q '"failed":0' /tmp/clide-testmode.log
else
	@flutter run -d $(FLUTTER_OS) \
	    --dart-define=CLIDE_PROJECT=$(CURDIR) \
	    --dart-define=CLIDE_TESTMODE=$(TESTMODE_CATEGORY) 2>&1 \
	  | tee /tmp/clide-testmode.log & PID=$$!; \
	  (sleep $(TESTMODE_TIMEOUT) && kill $$PID 2>/dev/null) & TIMER=$$!; \
	  wait $$PID 2>/dev/null; kill $$TIMER 2>/dev/null; \
	  grep -q '"failed":0' /tmp/clide-testmode.log
endif

.PHONY: pubget
pubget: ## flutter pub get.
	flutter pub get

.PHONY: build-check
build-check: ## Verify native + Dart build compiles (no run).
ifeq ($(FLUTTER_OS),linux)
	LD_LIBRARY_PATH=$(CURDIR)/native/linux-x64$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH} flutter build linux
else
	flutter build $(FLUTTER_OS)
endif

.PHONY: analyze
analyze: ## flutter analyze.
	flutter analyze

.PHONY: format
format: ## dart format --set-exit-if-changed.
	dart format --set-exit-if-changed .

.PHONY: test
test: ## Fast: analyze + format + unit + widget + golden (<60s).
	ci/test.sh

.PHONY: test-core
test-core: ## Core subsystem tests (IPC, PTY, git, pane registry).
	ci/test_core.sh

.PHONY: test-a11y
test-a11y: ## A11y contract (semantic coverage + keyboard + contrast + i18n).
	ci/test_a11y.sh

.PHONY: test-integration
test-integration: ## Integration tests (real app boot; xvfb on headless Linux).
	ci/test_integration.sh

.PHONY: test-e2e
test-e2e: ## End-to-end Playwright smoke.
	ci/test_e2e.sh

.PHONY: test-all
test-all: test-core test test-a11y test-integration test-e2e ## Everything, sequentially.

.PHONY: coverage
coverage: ## flutter test --coverage + lcov summary.
	ci/test_coverage.sh

.PHONY: smoke-bundle
smoke-bundle: ## Build Linux release bundle and run it under xvfb for 5s.
	ci/smoke_bundle.sh

# -- web UI harness ------------------------------------------------------

.PHONY: ui-dev
ui-dev: ## Build web WASM + start localhost:4280 in the background.
	tools/ui/build.sh
	tools/ui/serve.sh

.PHONY: ui-stop
ui-stop: ## Stop the background web server.
	tools/ui/stop.sh

.PHONY: ui-smoke
ui-smoke: ## Build + serve + run Playwright smoke + stop.
	tools/ui/build.sh
	tools/ui/serve.sh
	@sh -c 'trap "tools/ui/stop.sh >/dev/null 2>&1" EXIT; cd tools/ui && npx playwright test smoke.spec.ts'

.PHONY: build
build: ## flutter build for the current OS.
	flutter build $(FLUTTER_OS)

.PHONY: build-linux
build-linux: ## flutter build linux (desktop bundle).
	flutter build linux

.PHONY: build-macos
build-macos: ## flutter build macos (desktop bundle).
	flutter build macos

# -- install / uninstall -----------------------------------------------------

# Install prefix. Bundle lands at $(INSTALL_PREFIX)/clide/ with a
# symlink at $(INSTALL_DIR)/clide pointing into it.
INSTALL_PREFIX ?= $(HOME)/.local/lib

ifeq ($(FLUTTER_OS),linux)
  BUNDLE_DIR := build/linux/x64/release/bundle
else ifeq ($(FLUTTER_OS),macos)
  BUNDLE_DIR := build/macos/Build/Products/Release/clide.app
endif

ICON_SIZES := 16 32 48 128 192 256 512

.PHONY: install
install: build ## Build + install clide to ~/.local (INSTALL_PREFIX, INSTALL_DIR).
ifeq ($(FLUTTER_OS),linux)
	@mkdir -p $(INSTALL_PREFIX) $(INSTALL_DIR)
	rm -rf $(INSTALL_PREFIX)/clide
	cp -a $(BUNDLE_DIR) $(INSTALL_PREFIX)/clide
	ln -sf $(INSTALL_PREFIX)/clide/clide $(INSTALL_DIR)/clide
	@for size in $(ICON_SIZES); do \
	  dir=$(HOME)/.local/share/icons/hicolor/$${size}x$${size}/apps; \
	  mkdir -p $$dir; \
	  cp assets/logo/appicon-$${size}.png $$dir/clide.png; \
	done
	@mkdir -p $(HOME)/.local/share/applications
	@sed 's|Exec=clide|Exec=$(INSTALL_PREFIX)/clide/clide|' linux/clide.desktop \
	  > $(HOME)/.local/share/applications/clide.desktop
	@gtk-update-icon-cache -f -t $(HOME)/.local/share/icons/hicolor 2>/dev/null || true
	@update-desktop-database $(HOME)/.local/share/applications 2>/dev/null || true
	@echo "installed: $(INSTALL_DIR)/clide -> $(INSTALL_PREFIX)/clide/clide"
	@echo "desktop:   ~/.local/share/applications/clide.desktop"
	@echo "version:   $(VERSION)"
else ifeq ($(FLUTTER_OS),macos)
	@mkdir -p $(HOME)/Applications
	rm -rf $(HOME)/Applications/clide.app
	cp -a $(BUNDLE_DIR) $(HOME)/Applications/clide.app
	@echo "installed: ~/Applications/clide.app"
	@echo "version:   $(VERSION)"
else
	@echo "install not yet supported on $(FLUTTER_OS)"
	@exit 1
endif

.PHONY: uninstall
uninstall: ## Remove installed clide.
ifeq ($(FLUTTER_OS),linux)
	rm -f $(INSTALL_DIR)/clide
	rm -rf $(INSTALL_PREFIX)/clide
	rm -f $(HOME)/.local/share/applications/clide.desktop
	@for size in $(ICON_SIZES); do \
	  rm -f $(HOME)/.local/share/icons/hicolor/$${size}x$${size}/apps/clide.png; \
	done
	@gtk-update-icon-cache -f -t $(HOME)/.local/share/icons/hicolor 2>/dev/null || true
	@update-desktop-database $(HOME)/.local/share/applications 2>/dev/null || true
	@echo "uninstalled"
else ifeq ($(FLUTTER_OS),macos)
	rm -rf $(HOME)/Applications/clide.app
	@echo "uninstalled"
endif

# -- dugite-native (bundled git) ------------------------------------------

DUGITE_VERSION := v2.53.0-3
DUGITE_COMMIT  := f49d009

ifeq ($(FLUTTER_OS),macos)
  ifeq ($(shell uname -m),arm64)
    DUGITE_PLATFORM := macOS-arm64
  else
    DUGITE_PLATFORM := macOS-x64
  endif
else ifeq ($(FLUTTER_OS),linux)
  DUGITE_PLATFORM := ubuntu-x64
else
  DUGITE_PLATFORM := windows-x64
endif

DUGITE_TAR := dugite-native-v2.53.0-$(DUGITE_COMMIT)-$(DUGITE_PLATFORM).tar.gz
DUGITE_URL := https://github.com/desktop/dugite-native/releases/download/$(DUGITE_VERSION)/$(DUGITE_TAR)
DUGITE_DIR := native/dugite

.PHONY: dugite-fetch
dugite-fetch: ## Download and extract the dugite-native git distribution.
	@if [ -f $(DUGITE_DIR)/bin/git ]; then echo "dugite already present at $(DUGITE_DIR)/bin/git"; exit 0; fi
	@mkdir -p $(DUGITE_DIR)
	curl -sL "$(DUGITE_URL)" | tar xz -C $(DUGITE_DIR)
	@echo "dugite-native $(DUGITE_VERSION) ($(DUGITE_PLATFORM)) extracted to $(DUGITE_DIR)/"

.PHONY: dugite-clean
dugite-clean: ## Remove the dugite-native directory.
	rm -rf $(DUGITE_DIR)

# -- ptyc (C supporter tool) ---------------------------------------------

PTYC_PRESENT := $(shell test -f ptyc/Makefile && echo yes || echo no)

.PHONY: ptyc-build
ptyc-build: ## Build the ptyc PTY-spawn helper.
ifeq ($(PTYC_PRESENT),yes)
	$(MAKE) -C ptyc
else
	@echo "(ptyc/ not scaffolded yet; skipping)"
endif

.PHONY: ptyc-test
ptyc-test: ## Run ptyc smoke tests (SCM_RIGHTS round-trip).
ifeq ($(PTYC_PRESENT),yes)
	$(MAKE) -C ptyc test
else
	@echo "(ptyc/ not scaffolded yet; skipping)"
endif

.PHONY: ptyc-clean
ptyc-clean: ## Clean ptyc build artefacts.
ifeq ($(PTYC_PRESENT),yes)
	$(MAKE) -C ptyc clean
else
	@echo "(ptyc/ not scaffolded yet; skipping)"
endif

# -- security -------------------------------------------------------------

.PHONY: security
security: ## Dart advisory review + ptyc source review.
	@echo "security: Dart advisories reviewed manually before pubspec.yaml bumps;"
	@echo "         ptyc is reviewed by reading it (tiny libc-only C)."

# -- pre-push gate --------------------------------------------------------

.PHONY: decisions-validate
decisions-validate: ## Parser dry-run over decisions/*.md.
	pql decisions validate

.PHONY: push-check
push-check: decisions-validate test-core test test-a11y ## Pre-push gate.

.PHONY: hooks
hooks: ## Install the repo's git hooks.
	git config core.hooksPath .githooks
	@echo "hooks installed (core.hooksPath = .githooks)"

# -- housekeeping ---------------------------------------------------------

.PHONY: clean
clean: ## Remove build artefacts.
	rm -rf build .dart_tool
	$(MAKE) ptyc-clean

.DEFAULT_GOAL := help
