# ─── Configuration ───────────────────────────────────────────────────
GAME_NAME    := mygame
LOVE_VERSION := 11.5
BUILD_DIR    := build

# ─── OS Detection ────────────────────────────────────────────────────
UNAME_S := $(shell uname -s)

# ─── Derived Paths ───────────────────────────────────────────────────
LOVE_FILE  := $(BUILD_DIR)/$(GAME_NAME).love
LOVE_CACHE := $(BUILD_DIR)/.love-cache
LOVE_MACOS_URL := https://github.com/love2d/love/releases/download/$(LOVE_VERSION)/love-$(LOVE_VERSION)-macos.zip
LOVE_WIN64_URL := https://github.com/love2d/love/releases/download/$(LOVE_VERSION)/love-$(LOVE_VERSION)-win64.zip
LOVE_LINUX_URL := https://github.com/love2d/love/releases/download/$(LOVE_VERSION)/love-$(LOVE_VERSION)-x86_64.AppImage

EXCLUDE := -x './$(BUILD_DIR)/*' './.git/*' './.github/*' './.vscode/*' './makefile' './README.md' './.DS_Store' './.gitignore'

.PHONY: build build-all build-macos build-windows build-linux love run dev clean clean-all help

# ─── Help (default) ──────────────────────────────────────────────────
help:
	@echo ""
	@echo "  make build           Build zip for current OS (auto-detected)"
	@echo "  make build-all       Build zips for all platforms"
	@echo "  make build-macos     Build macOS .app zip"
	@echo "  make build-windows   Build Windows .exe zip"
	@echo "  make build-linux     Build Linux AppImage zip"
	@echo "  make love            Create .love archive only"
	@echo "  make run             Run with love"
	@echo "  make dev             Watch for changes & auto-restart"
	@echo "  make clean           Remove build outputs"
	@echo "  make clean-all       Remove entire build directory"
	@echo ""

# ─── Build all platforms ─────────────────────────────────────────────
build-all: build-macos build-windows build-linux
	@echo ""
	@echo "All platform zips:"
	@ls -lh $(BUILD_DIR)/$(GAME_NAME)-*.zip
	@echo ""

# ─── Build for current OS ────────────────────────────────────────────
build:
ifeq ($(UNAME_S),Darwin)
	@$(MAKE) --no-print-directory build-macos
else ifeq ($(UNAME_S),Linux)
	@$(MAKE) --no-print-directory build-linux
else
	@$(MAKE) --no-print-directory build-windows
endif

# ─── .love archive ───────────────────────────────────────────────────
love:
	@mkdir -p $(BUILD_DIR)
	@echo "[love] Creating $(GAME_NAME).love ..."
	@zip -9 -r $(LOVE_FILE) . $(EXCLUDE) > /dev/null
	@echo "[love] -> $(LOVE_FILE)"

# ─── Download targets (run once, cached) ─────────────────────────────
$(LOVE_CACHE)/macos/love.app:
	@mkdir -p $(LOVE_CACHE)/macos
	@echo "[setup] Downloading LOVE $(LOVE_VERSION) for macOS ..."
	@curl -sL -o $(LOVE_CACHE)/macos/_love.zip $(LOVE_MACOS_URL)
	@unzip -qo $(LOVE_CACHE)/macos/_love.zip -d $(LOVE_CACHE)/macos
	@rm $(LOVE_CACHE)/macos/_love.zip

$(LOVE_CACHE)/windows/love-$(LOVE_VERSION)-win64:
	@mkdir -p $(LOVE_CACHE)/windows
	@echo "[setup] Downloading LOVE $(LOVE_VERSION) for Windows ..."
	@curl -sL -o $(LOVE_CACHE)/windows/_love.zip $(LOVE_WIN64_URL)
	@unzip -qo $(LOVE_CACHE)/windows/_love.zip -d $(LOVE_CACHE)/windows
	@rm $(LOVE_CACHE)/windows/_love.zip

$(LOVE_CACHE)/linux/love.AppImage:
	@mkdir -p $(LOVE_CACHE)/linux
	@echo "[setup] Downloading LOVE $(LOVE_VERSION) for Linux ..."
	@curl -sL -o $(LOVE_CACHE)/linux/love.AppImage $(LOVE_LINUX_URL)
	@chmod +x $(LOVE_CACHE)/linux/love.AppImage

# ─── macOS build ─────────────────────────────────────────────────────
build-macos: love | $(LOVE_CACHE)/macos/love.app
	@echo "[macos] Building $(GAME_NAME).app ..."
	@mkdir -p $(BUILD_DIR)/macos
	@rm -rf $(BUILD_DIR)/macos/$(GAME_NAME).app
	@cp -R $(LOVE_CACHE)/macos/love.app $(BUILD_DIR)/macos/$(GAME_NAME).app
	@cp $(LOVE_FILE) "$(BUILD_DIR)/macos/$(GAME_NAME).app/Contents/Resources/"
	@echo "[macos] Zipping ..."
	@cd $(BUILD_DIR)/macos && zip -9 -r -y ../$(GAME_NAME)-macos.zip $(GAME_NAME).app > /dev/null
	@echo "[macos] -> $(BUILD_DIR)/$(GAME_NAME)-macos.zip"

# ─── Windows build ───────────────────────────────────────────────────
build-windows: love | $(LOVE_CACHE)/windows/love-$(LOVE_VERSION)-win64
	@echo "[windows] Building $(GAME_NAME).exe ..."
	@mkdir -p $(BUILD_DIR)/windows/$(GAME_NAME)
	@cat "$(LOVE_CACHE)/windows/love-$(LOVE_VERSION)-win64/love.exe" $(LOVE_FILE) \
		> "$(BUILD_DIR)/windows/$(GAME_NAME)/$(GAME_NAME).exe"
	@cp $(LOVE_CACHE)/windows/love-$(LOVE_VERSION)-win64/*.dll $(BUILD_DIR)/windows/$(GAME_NAME)/
	@cp $(LOVE_CACHE)/windows/love-$(LOVE_VERSION)-win64/license.txt $(BUILD_DIR)/windows/$(GAME_NAME)/ 2>/dev/null || true
	@echo "[windows] Zipping ..."
	@cd $(BUILD_DIR)/windows && zip -9 -r ../$(GAME_NAME)-windows.zip $(GAME_NAME) > /dev/null
	@echo "[windows] -> $(BUILD_DIR)/$(GAME_NAME)-windows.zip"

# ─── Linux build ─────────────────────────────────────────────────────
build-linux: love | $(LOVE_CACHE)/linux/love.AppImage
	@echo "[linux] Building $(GAME_NAME) for Linux ..."
	@mkdir -p $(BUILD_DIR)/linux
	@rm -rf $(BUILD_DIR)/linux/$(GAME_NAME)
	@mkdir -p $(BUILD_DIR)/linux/$(GAME_NAME)
	@cp $(LOVE_FILE) $(BUILD_DIR)/linux/$(GAME_NAME)/$(GAME_NAME).love
	@cp $(LOVE_CACHE)/linux/love.AppImage $(BUILD_DIR)/linux/$(GAME_NAME)/love.AppImage
	@printf '#!/bin/sh\nSCRIPT_DIR="$$(cd "$$(dirname "$$0")" && pwd)"\nexec "$$SCRIPT_DIR/love.AppImage" "$$SCRIPT_DIR/%s.love" "$$@"\n' "$(GAME_NAME)" \
		> $(BUILD_DIR)/linux/$(GAME_NAME)/$(GAME_NAME).sh
	@chmod +x $(BUILD_DIR)/linux/$(GAME_NAME)/$(GAME_NAME).sh
	@chmod +x $(BUILD_DIR)/linux/$(GAME_NAME)/love.AppImage
	@echo "[linux] Zipping ..."
	@cd $(BUILD_DIR)/linux && zip -9 -r ../$(GAME_NAME)-linux.zip $(GAME_NAME) > /dev/null
	@echo "[linux] -> $(BUILD_DIR)/$(GAME_NAME)-linux.zip"

# ─── Run ─────────────────────────────────────────────────────────────
run:
	@love .

# ─── Dev mode (watch & auto-restart) ─────────────────────────────────
dev:
	@echo "[dev] Watching for changes (Ctrl-C to stop) ..."
	@if command -v fswatch >/dev/null 2>&1; then \
		trap 'kill $$LOVE_PID 2>/dev/null; exit 0' INT TERM; \
		while true; do \
			love . & LOVE_PID=$$!; \
			fswatch -1 -r -e '$(BUILD_DIR)' -e '.git' -e '.vscode' .; \
			kill $$LOVE_PID 2>/dev/null; wait $$LOVE_PID 2>/dev/null; \
			echo "[dev] Restarting ..."; \
		done; \
	else \
		echo "[dev] Install fswatch for instant reload: brew install fswatch"; \
		echo "[dev] Falling back to 1-second polling ..."; \
		touch /tmp/.love_dev_marker; \
		trap 'kill $$LOVE_PID 2>/dev/null; rm -f /tmp/.love_dev_marker; exit 0' INT TERM; \
		love . & LOVE_PID=$$!; \
		while true; do \
			sleep 1; \
			CHANGED=$$(find . -path ./$(BUILD_DIR) -prune -o -path ./.git -prune -o \
				-newer /tmp/.love_dev_marker -type f -print -quit); \
			if [ -n "$$CHANGED" ]; then \
				touch /tmp/.love_dev_marker; \
				kill $$LOVE_PID 2>/dev/null; wait $$LOVE_PID 2>/dev/null; \
				echo "[dev] Restarting ..."; \
				love . & LOVE_PID=$$!; \
			fi; \
		done; \
	fi

# ─── Clean ───────────────────────────────────────────────────────────
clean:
	@rm -rf $(LOVE_FILE) $(BUILD_DIR)/macos $(BUILD_DIR)/windows $(BUILD_DIR)/linux $(BUILD_DIR)/$(GAME_NAME)-*.zip
	@echo "Cleaned build outputs (cached LOVE downloads preserved)."

clean-all:
	@rm -rf $(BUILD_DIR)
	@echo "Removed entire build directory."

lint:
	@stylua .