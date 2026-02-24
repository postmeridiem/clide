.PHONY: setup run dev test lint format clean help start-server stop-server restart-server status-server install-server logs-server

PYTHON := python3.12
VENV := .venv
BIN := $(VENV)/bin
SERVICE := clide-web

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RESET := \033[0m

help:
	@printf "$(BLUE)clide-web Commands$(RESET)\n\n"
	@printf "$(YELLOW)Development$(RESET)\n"
	@printf "  $(GREEN)setup$(RESET)      Create venv, install deps, run setup wizard\n"
	@printf "  $(GREEN)run$(RESET)        Run the web server (foreground)\n"
	@printf "  $(GREEN)dev$(RESET)        Run with auto-reload\n"
	@printf "  $(GREEN)test$(RESET)       Run tests\n"
	@printf "  $(GREEN)lint$(RESET)       Run ruff linter\n"
	@printf "  $(GREEN)format$(RESET)     Run ruff formatter\n"
	@printf "  $(GREEN)clean$(RESET)      Remove build artifacts\n"
	@printf "\n$(YELLOW)Service$(RESET)\n"
	@printf "  $(GREEN)install-server$(RESET)  Install systemd service (requires sudo)\n"
	@printf "  $(GREEN)start-server$(RESET)    Start the systemd service\n"
	@printf "  $(GREEN)stop-server$(RESET)     Stop the systemd service\n"
	@printf "  $(GREEN)restart-server$(RESET)  Restart the systemd service\n"
	@printf "  $(GREEN)status-server$(RESET)   Show service status\n"
	@printf "  $(GREEN)logs-server$(RESET)     Tail service logs\n"

# --- Development ---

setup:
	$(PYTHON) -m venv $(VENV)
	$(BIN)/pip install --upgrade pip
	$(BIN)/pip install -e ".[dev]"
	$(BIN)/clide-web-setup
	@printf "$(GREEN)Setup complete!$(RESET)\n"

run:
	$(BIN)/clide-web

dev:
	$(BIN)/uvicorn clide_web.server:app --reload --host 0.0.0.0 --port 8888

test:
	$(BIN)/pytest tests/

lint:
	$(BIN)/ruff check clide_web/

format:
	$(BIN)/ruff format clide_web/
	$(BIN)/ruff check --fix clide_web/

clean:
	rm -rf $(VENV) dist/ build/
	rm -rf .pytest_cache/ .mypy_cache/ .ruff_cache/
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# --- Service ---

install-server:
	@if [ "$$(id -u)" -ne 0 ]; then printf "$(YELLOW)Run with sudo: sudo make install-server$(RESET)\n"; exit 1; fi
	cp ../deploy/clide-web.service /etc/systemd/system/$(SERVICE).service
	systemctl daemon-reload
	systemctl enable $(SERVICE)
	@printf "$(GREEN)Service installed. Run 'make start-server' to start.$(RESET)\n"

start-server:
	sudo systemctl start $(SERVICE)
	@systemctl is-active --quiet $(SERVICE) && printf "$(GREEN)$(SERVICE) started$(RESET)\n" || printf "$(YELLOW)Failed to start. Check: make logs-server$(RESET)\n"

stop-server:
	sudo systemctl stop $(SERVICE)
	@printf "$(GREEN)$(SERVICE) stopped$(RESET)\n"

restart-server:
	sudo systemctl restart $(SERVICE)
	@systemctl is-active --quiet $(SERVICE) && printf "$(GREEN)$(SERVICE) restarted$(RESET)\n" || printf "$(YELLOW)Failed to restart. Check: make logs-server$(RESET)\n"

status-server:
	@systemctl status $(SERVICE) --no-pager || true

logs-server:
	journalctl -u $(SERVICE) -f --no-pager
