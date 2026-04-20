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
	@printf "$(BLUE)Clide Development Commands$(RESET)\n"
	@printf "\n"
	@printf "$(GREEN)setup$(RESET)          Create venv and install dependencies\n"
	@printf "$(GREEN)run$(RESET)            Run the application\n"
	@printf "$(GREEN)test$(RESET)           Run all tests\n"
	@printf "$(GREEN)test-single$(RESET)    Run single test (TEST=path::test_name)\n"
	@printf "$(GREEN)typecheck$(RESET)      Run mypy type checking\n"
	@printf "$(GREEN)lint$(RESET)           Run ruff linter\n"
	@printf "$(GREEN)format$(RESET)         Run ruff formatter\n"
	@printf "$(GREEN)build$(RESET)          Build executable for current platform\n"
	@printf "$(GREEN)clean$(RESET)          Remove build artifacts and caches\n"
	@printf "\n"
	@printf "$(BLUE)Distribution Builds$(RESET)\n"
	@printf "\n"
	@printf "$(GREEN)build-macos$(RESET)    Build macOS DMG (VERSION=x.x.x)\n"
	@printf "$(GREEN)build-linux$(RESET)    Build Linux AppImage (VERSION=x.x.x)\n"
	@printf "$(GREEN)build-windows$(RESET)  Build Windows installer (VERSION=x.x.x)\n"

setup:
	@echo "Creating virtual environment..."
	$(PYTHON) -m venv $(VENV)
	@echo "Installing dependencies..."
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install -e ".[dev,build]"
	@echo "Installing pre-commit hooks..."
	$(BIN)/pre-commit install || true
	@printf "$(GREEN)Setup complete! Activate with: source $(VENV)/bin/activate$(RESET)\n"

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
	@printf "$(BLUE)Building macOS distribution...$(RESET)\n"
	./scripts/build-macos.sh $(VERSION)

build-linux:
	@printf "$(BLUE)Building Linux AppImage...$(RESET)\n"
	./scripts/build-linux.sh $(VERSION)

build-windows:
	@echo "$(BLUE)Building Windows installer...$(RESET)"
	powershell -ExecutionPolicy Bypass -File scripts/build-windows.ps1 -Version $(VERSION)

build-all: build-linux
	@printf "\n"
	@printf "$(GREEN)Linux build complete.$(RESET)\n"
	@printf "$(BLUE)Note:$(RESET) macOS build requires: make build-macos VERSION=$(VERSION)\n"
	@printf "$(BLUE)Note:$(RESET) Windows build requires Windows: make build-windows VERSION=$(VERSION)\n"
