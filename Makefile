# clide — local dev targets. CI scripts in ci/ shell out to these.
#
# Single Flutter package at the repo root. Native supporter tools
# (ptyc, future peers) live in their own directories.

INSTALL_DIR ?= $(HOME)/.local/bin

VERSION_BASE ?= $(shell awk -F': *' '/^version:/ {gsub(/[" ]/,"",$$2); print $$2; exit}' pubspec.yaml)
COMMIT       ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
DIRTY        := $(shell git diff --quiet HEAD 2>/dev/null || echo .dirty)
VERSION      ?= $(VERSION_BASE)+$(COMMIT)$(DIRTY)
DATE         ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# -- app (Flutter) -------------------------------------------------------

.PHONY: run
run: ## Launch the Flutter desktop app.
	LD_LIBRARY_PATH=$(CURDIR)/native/linux-x64$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH} flutter run -d linux

.PHONY: pubget
pubget: ## flutter pub get.
	flutter pub get

.PHONY: build-check
build-check: ## Verify native + Dart build compiles (no run).
	LD_LIBRARY_PATH=$(CURDIR)/native/linux-x64$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH} flutter build linux

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

.PHONY: build-linux
build-linux: ## flutter build linux (desktop bundle).
	flutter build linux

.PHONY: build-macos
build-macos: ## flutter build macos (desktop bundle).
	flutter build macos

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
