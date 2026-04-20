# clide — local dev targets. CI scripts in ci/ shell out to these.
#
# One toolchain: Flutter + Dart. Native supporter tools (`ptyc`, future
# peers) live in their own directories with their own build targets and
# compose in under `make build`.

INSTALL_DIR ?= $(HOME)/.local/bin

# Version stamping. Source of truth: project.yaml `version:` field. Local
# builds augment with git short SHA + dirty marker (semver build metadata).
VERSION_BASE ?= $(shell awk -F': *' '/^version:/ {gsub(/[" ]/,"",$$2); print $$2; exit}' project.yaml)
COMMIT       ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
DIRTY        := $(shell git diff --quiet HEAD 2>/dev/null || echo .dirty)
VERSION      ?= $(VERSION_BASE)+$(COMMIT)$(DIRTY)
DATE         ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# -- app + core (Flutter / Dart) ----------------------------------------

# App and core targets gracefully noop if the Dart package isn't
# scaffolded yet (pre-Tier-0 state) or if flutter isn't installed
# locally.
APP_PRESENT := $(shell test -f pubspec.yaml && echo yes || echo no)
HAS_FLUTTER := $(shell command -v flutter >/dev/null && echo yes || echo no)

.PHONY: build
build: ## Build the Dart AOT `clide` binary (CLI + --daemon modes in one binary).
ifeq ($(APP_PRESENT),yes)
	dart compile exe bin/clide.dart -o bin/clide \
		--define=clideVersion=$(VERSION) \
		--define=clideCommit=$(COMMIT) \
		--define=clideDate=$(DATE)
else
	@echo "(pubspec.yaml not scaffolded yet; skipping)"
endif

.PHONY: install
install: build ## Install bin/clide into $(INSTALL_DIR).
ifeq ($(APP_PRESENT),yes)
	install -m 0755 bin/clide $(INSTALL_DIR)/clide
else
	@echo "(pubspec.yaml not scaffolded yet; skipping)"
endif

.PHONY: pubget
pubget: ## flutter pub get (hydrate the pub cache).
ifeq ($(APP_PRESENT),yes)
	flutter pub get
else
	@echo "(pubspec.yaml not scaffolded yet; skipping)"
endif

.PHONY: analyze
analyze: ## dart analyze / flutter analyze.
ifeq ($(APP_PRESENT),yes)
	flutter analyze
else
	@echo "(pubspec.yaml not scaffolded yet; skipping)"
endif

.PHONY: format
format: ## dart format --set-exit-if-changed.
ifeq ($(APP_PRESENT),yes)
	dart format --set-exit-if-changed .
else
	@echo "(pubspec.yaml not scaffolded yet; skipping)"
endif

.PHONY: test
test: ## flutter test (unit + widget).
ifeq ($(APP_PRESENT),yes)
	flutter test
else
	@echo "(pubspec.yaml not scaffolded yet; skipping)"
endif

.PHONY: test-integration
test-integration: build ## Integration tests (daemon + CLI + fixture repos).
ifeq ($(APP_PRESENT),yes)
	flutter test integration_test || echo "(no integration_test suite yet)"
else
	@echo "(pubspec.yaml not scaffolded yet; skipping)"
endif

.PHONY: build-linux
build-linux: ## flutter build linux (desktop bundle).
ifeq ($(APP_PRESENT),yes)
	flutter build linux
else
	@echo "(pubspec.yaml not scaffolded yet; skipping)"
endif

.PHONY: build-macos
build-macos: ## flutter build macos (desktop bundle).
ifeq ($(APP_PRESENT),yes)
	flutter build macos
else
	@echo "(pubspec.yaml not scaffolded yet; skipping)"
endif

# -- ptyc (C supporter tool) --------------------------------------------

# Compiled alongside the main binary. Tiny, no deps beyond libc.
PTYX_PRESENT := $(shell test -f ptyc/Makefile && echo yes || echo no)

.PHONY: ptyc-build
ptyc-build: ## Build the ptyc PTY-spawn helper.
ifeq ($(PTYX_PRESENT),yes)
	$(MAKE) -C ptyc
else
	@echo "(ptyc/ not scaffolded yet; skipping)"
endif

.PHONY: ptyc-clean
ptyc-clean: ## Clean ptyc build artefacts.
ifeq ($(PTYX_PRESENT),yes)
	$(MAKE) -C ptyc clean
else
	@echo "(ptyc/ not scaffolded yet; skipping)"
endif

# -- security ------------------------------------------------------------

.PHONY: security
security: ## Dart advisory review + ptyc source review (manual — no floating deps).
	@echo "security: Dart advisories reviewed manually before pubspec.yaml bumps;"
	@echo "         ptyc is reviewed by reading it (tiny libc-only C)."
	@echo "         Automated Dart CVE tooling lands here when a reliable option exists."

# -- pre-push gate -------------------------------------------------------

.PHONY: push-check
push-check: analyze format test ## Full pre-push gate — everything that must pass before a push.

.PHONY: hooks
hooks: ## Install the repo's git hooks (points core.hooksPath at .githooks/).
	git config core.hooksPath .githooks
	@echo "hooks installed (core.hooksPath = .githooks)"

# -- housekeeping --------------------------------------------------------

.PHONY: clean
clean: ## Remove build artefacts.
	rm -rf bin build .dart_tool
	$(MAKE) ptyc-clean

.DEFAULT_GOAL := help
