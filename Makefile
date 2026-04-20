# clide — local dev targets. CI scripts in ci/ shell out to these.
#
# Two components under one Makefile:
#   - Go sidecar/CLI under sidecar/
#   - Flutter desktop app under app/ (scaffolded once Flutter is installed
#     locally; targets gracefully noop when app/ isn't present yet).

GO          ?= go
BIN_DIR     ?= sidecar/bin
INSTALL_DIR ?= $(HOME)/.local/bin

# Version stamping. Source of truth: project.yaml `version:` field. Local
# builds augment with git short SHA + dirty marker (semver build metadata).
# Tagged releases are handled by goreleaser using the git tag instead.
VERSION_BASE ?= $(shell awk -F': *' '/^version:/ {gsub(/[" ]/,"",$$2); print $$2; exit}' project.yaml)
COMMIT       ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo unknown)
DIRTY        := $(shell git diff --quiet HEAD 2>/dev/null || echo .dirty)
VERSION      ?= $(VERSION_BASE)+$(COMMIT)$(DIRTY)
DATE         ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

LDFLAGS := -s -w \
	-X 'git.schweitz.net/jpmschweitzer/clide/sidecar/internal/version.Version=$(VERSION)' \
	-X 'git.schweitz.net/jpmschweitzer/clide/sidecar/internal/version.Commit=$(COMMIT)' \
	-X 'git.schweitz.net/jpmschweitzer/clide/sidecar/internal/version.Date=$(DATE)'

GO_PACKAGES := ./...

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# -- sidecar (Go) --------------------------------------------------------

.PHONY: build
build: ## Build the clide sidecar/CLI binary into sidecar/bin/clide.
	cd sidecar && $(GO) build -ldflags="$(LDFLAGS)" -o bin/clide ./cmd/clide

.PHONY: install
install: build ## Install sidecar/bin/clide into $(INSTALL_DIR).
	install -m 0755 $(BIN_DIR)/clide $(INSTALL_DIR)/clide

.PHONY: test
test: ## Unit tests (Go), fast.
	cd sidecar && $(GO) test $(GO_PACKAGES)

.PHONY: test-race
test-race: ## Unit tests with the race detector.
	cd sidecar && $(GO) test -race $(GO_PACKAGES)

.PHONY: test-integration
test-integration: build ## Integration tests (binary + fixture repos). Tag: integration.
	cd sidecar && $(GO) test -tags=integration ./...

.PHONY: lint
lint: ## golangci-lint run on the sidecar.
	cd sidecar && golangci-lint run

.PHONY: vuln
vuln: ## govulncheck on all sidecar packages — Go CVE gate.
	cd sidecar && govulncheck ./...

.PHONY: fmt
fmt: ## gofmt + goimports on the sidecar.
	cd sidecar && gofmt -w .
	@command -v goimports >/dev/null && cd sidecar && goimports -w . || echo "(goimports not installed; skipping)"

.PHONY: tidy
tidy: ## go mod tidy for the sidecar.
	cd sidecar && $(GO) mod tidy

.PHONY: snapshot
snapshot: ## GoReleaser snapshot build (dry-run, no publish).
	goreleaser release --snapshot --clean

# -- app (Flutter) -------------------------------------------------------

# App targets gracefully noop if app/ doesn't exist yet (pre-Tier-0
# scaffold) or if flutter isn't installed locally.
APP_PRESENT := $(shell test -f app/pubspec.yaml && echo yes || echo no)
HAS_FLUTTER := $(shell command -v flutter >/dev/null && echo yes || echo no)

.PHONY: app-pubget
app-pubget: ## flutter pub get (hydrate the app's pub cache).
ifeq ($(APP_PRESENT),yes)
	cd app && flutter pub get
else
	@echo "(app/ not scaffolded yet; skipping)"
endif

.PHONY: app-analyze
app-analyze: ## dart analyze on the app.
ifeq ($(APP_PRESENT),yes)
	cd app && flutter analyze
else
	@echo "(app/ not scaffolded yet; skipping)"
endif

.PHONY: app-format
app-format: ## dart format on the app.
ifeq ($(APP_PRESENT),yes)
	cd app && dart format --set-exit-if-changed .
else
	@echo "(app/ not scaffolded yet; skipping)"
endif

.PHONY: app-test
app-test: ## flutter test on the app.
ifeq ($(APP_PRESENT),yes)
	cd app && flutter test
else
	@echo "(app/ not scaffolded yet; skipping)"
endif

.PHONY: app-build-linux
app-build-linux: ## flutter build linux.
ifeq ($(APP_PRESENT),yes)
	cd app && flutter build linux
else
	@echo "(app/ not scaffolded yet; skipping)"
endif

.PHONY: app-build-macos
app-build-macos: ## flutter build macos.
ifeq ($(APP_PRESENT),yes)
	cd app && flutter build macos
else
	@echo "(app/ not scaffolded yet; skipping)"
endif

# -- security ------------------------------------------------------------

.PHONY: security
security: vuln ## Run all CVE gates. For now: Go (govulncheck). Dart CVE gate lands when a reliable tooling exists.

# -- tooling -------------------------------------------------------------

# Pinned Go tool versions. Bump deliberately; never floating.
GOVULNCHECK_VERSION     ?= v1.1.4
GOIMPORTS_VERSION       ?= v0.29.0
GOLANGCI_LINT_VERSION   ?= v2.11.4

.PHONY: tools
tools: ## Install Go tooling at pinned versions (govulncheck, goimports, golangci-lint).
	$(GO) install golang.org/x/vuln/cmd/govulncheck@$(GOVULNCHECK_VERSION)
	$(GO) install golang.org/x/tools/cmd/goimports@$(GOIMPORTS_VERSION)
	$(GO) install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)

# -- pre-push gate -------------------------------------------------------

.PHONY: push-check
push-check: lint test test-race test-integration vuln app-analyze app-test ## Full pre-push gate — everything that must pass before a push.

.PHONY: hooks
hooks: ## Install the repo's git hooks (points core.hooksPath at .githooks/).
	git config core.hooksPath .githooks
	@echo "hooks installed (core.hooksPath = .githooks)"

# -- housekeeping --------------------------------------------------------

.PHONY: clean
clean: ## Remove build artefacts.
	rm -rf sidecar/bin sidecar/dist
ifeq ($(APP_PRESENT),yes)
	rm -rf app/build app/.dart_tool
endif

.DEFAULT_GOAL := help
