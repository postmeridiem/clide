.PHONY: setup run test test-single typecheck lint format build build-macos build-linux build-windows build-all clean help

PYTHON := python3.12
VENV := .venv
BIN := $(VENV)/bin
TEST ?= tests/
VERSION ?= 1.0.0

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
RESET := \033[0m

help:
	@echo "$(BLUE)Clide Development Commands$(RESET)"
	@echo ""
	@echo "$(GREEN)setup$(RESET)          Create venv and install dependencies"
	@echo "$(GREEN)run$(RESET)            Run the application"
	@echo "$(GREEN)test$(RESET)           Run all tests"
	@echo "$(GREEN)test-single$(RESET)    Run single test (TEST=path::test_name)"
	@echo "$(GREEN)typecheck$(RESET)      Run mypy type checking"
	@echo "$(GREEN)lint$(RESET)           Run ruff linter"
	@echo "$(GREEN)format$(RESET)         Run ruff formatter"
	@echo "$(GREEN)build$(RESET)          Build executable for current platform"
	@echo "$(GREEN)clean$(RESET)          Remove build artifacts and caches"
	@echo ""
	@echo "$(BLUE)Distribution Builds$(RESET)"
	@echo ""
	@echo "$(GREEN)build-macos$(RESET)    Build macOS DMG (VERSION=x.x.x)"
	@echo "$(GREEN)build-linux$(RESET)    Build Linux AppImage (VERSION=x.x.x)"
	@echo "$(GREEN)build-windows$(RESET)  Build Windows installer (VERSION=x.x.x)"

setup:
	@echo "Creating virtual environment..."
	$(PYTHON) -m venv $(VENV)
	@echo "Installing dependencies..."
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install -e ".[dev,build]"
	@echo "Installing pre-commit hooks..."
	$(BIN)/pre-commit install || true
	@echo "$(GREEN)Setup complete! Activate with: source $(VENV)/bin/activate$(RESET)"

run:
	$(BIN)/python -m clide

test:
	$(BIN)/pytest $(TEST)

test-single:
	$(BIN)/pytest $(TEST) -v

test-cov:
	$(BIN)/pytest --cov=clide/clide --cov-report=html --cov-report=term

test-snapshots:
	$(BIN)/pytest tests/snapshots/

test-snapshots-update:
	$(BIN)/pytest tests/snapshots/ --snapshot-update

typecheck:
	$(BIN)/mypy clide/

lint:
	$(BIN)/ruff check clide/ tests/

format:
	$(BIN)/ruff format clide/ tests/
	$(BIN)/ruff check --fix clide/ tests/

build:
	$(BIN)/pyinstaller clide.spec --clean

build-onefile:
	$(BIN)/pyinstaller \
		--name clide \
		--onefile \
		--clean \
		--noconfirm \
		clide/clide/__main__.py

clean:
	rm -rf $(VENV)
	rm -rf dist/ build/
	rm -rf .pytest_cache/ .mypy_cache/ .ruff_cache/
	rm -rf htmlcov/ .coverage
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

# CI targets (for GitHub Actions)
ci-lint:
	pip install ruff mypy
	ruff check clide/ tests/
	mypy clide/

ci-test:
	pip install -e ".[dev]"
	pytest --cov=clide/clide --cov-report=xml

ci-build:
	pip install -e ".[build]"
	pyinstaller clide.spec --clean

# Distribution builds
build-macos:
	@echo "$(BLUE)Building macOS distribution...$(RESET)"
	./scripts/build-macos.sh $(VERSION)

build-linux:
	@echo "$(BLUE)Building Linux AppImage...$(RESET)"
	./scripts/build-linux.sh $(VERSION)

build-windows:
	@echo "$(BLUE)Building Windows installer...$(RESET)"
	powershell -ExecutionPolicy Bypass -File scripts/build-windows.ps1 -Version $(VERSION)

build-all: build-linux
	@echo ""
	@echo "$(GREEN)Linux build complete.$(RESET)"
	@echo "$(BLUE)Note:$(RESET) macOS build requires: make build-macos VERSION=$(VERSION)"
	@echo "$(BLUE)Note:$(RESET) Windows build requires Windows: make build-windows VERSION=$(VERSION)"
