# ─── Configuration ───────────────────────────────────────────────────
GAME_NAME    := letdieride
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
LOVE_IOS_SOURCE_URL := https://github.com/love2d/love/releases/download/$(LOVE_VERSION)/love-$(LOVE_VERSION)-ios-source.zip
LOVE_APPLE_LIBS_URL := https://github.com/love2d/love/releases/download/$(LOVE_VERSION)/love-$(LOVE_VERSION)-apple-libraries.zip

EXCLUDE := -x './$(BUILD_DIR)/*' './.git/*' './.github/*' './.vscode/*' './docs/*' './makefile' './README.md' './.DS_Store' './.gitignore'

.PHONY: build build-all build-macos build-windows build-linux build-ios run-ios-sim love run run-verbose dev stickers clean clean-all help

# ─── Help (default) ──────────────────────────────────────────────────
help:
	@echo ""
	@echo "  make build           Build zip for current OS (auto-detected)"
	@echo "  make build-all       Build zips for all platforms"
	@echo "  make build-macos     Build macOS .app zip"
	@echo "  make build-windows   Build Windows .exe zip"
	@echo "  make build-linux     Build Linux AppImage zip"
	@echo "  make build-ios       Build iOS Simulator .app"
	@echo "  make run-ios-sim     Install + run app on iOS Simulator"
	@echo "  make love            Create .love archive only"
	@echo "  make run             Run with love"
	@echo "  make run-verbose     Run with verbose game traces"
	@echo "  make dev             Watch for changes & auto-restart"
	@echo "  make stickers        Render content/stickers/*.svg -> *.png"
	@echo "  make clean           Remove build outputs"
	@echo "  make clean-all       Remove entire build directory"
	@echo ""

# ─── Sticker rasterization ────────────────────────────────────────────
stickers:
	@bash ./scripts/render_stickers.sh

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

$(LOVE_CACHE)/ios/src/love-$(LOVE_VERSION)-ios-source/platform/xcode/love.xcodeproj:
	@mkdir -p $(LOVE_CACHE)/ios/src
	@echo "[setup] Downloading LOVE $(LOVE_VERSION) iOS source ..."
	@curl -sL -o $(LOVE_CACHE)/ios/src/_love-ios-source.zip $(LOVE_IOS_SOURCE_URL)
	@unzip -qo $(LOVE_CACHE)/ios/src/_love-ios-source.zip -d $(LOVE_CACHE)/ios/src
	@rm $(LOVE_CACHE)/ios/src/_love-ios-source.zip

$(LOVE_CACHE)/ios/libs/love-apple-dependencies/iOS/libraries:
	@mkdir -p $(LOVE_CACHE)/ios/libs
	@echo "[setup] Downloading LOVE $(LOVE_VERSION) Apple libraries ..."
	@curl -sL -o $(LOVE_CACHE)/ios/libs/_love-apple-libs.zip $(LOVE_APPLE_LIBS_URL)
	@unzip -qo $(LOVE_CACHE)/ios/libs/_love-apple-libs.zip -d $(LOVE_CACHE)/ios/libs
	@rm $(LOVE_CACHE)/ios/libs/_love-apple-libs.zip

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

# ─── iOS build (Simulator) ────────────────────────────────────────────
build-ios: love | $(LOVE_CACHE)/ios/src/love-$(LOVE_VERSION)-ios-source/platform/xcode/love.xcodeproj $(LOVE_CACHE)/ios/libs/love-apple-dependencies/iOS/libraries
	@echo "[ios] Preparing LOVE iOS project ..."
	@mkdir -p $(BUILD_DIR)/ios
	@rm -rf "$(BUILD_DIR)/ios/src"
	@cp -R "$(LOVE_CACHE)/ios/src/love-$(LOVE_VERSION)-ios-source" "$(BUILD_DIR)/ios/src"
	@rm -rf "$(BUILD_DIR)/ios/src/platform/xcode/ios/libraries"
	@cp -R "$(LOVE_CACHE)/ios/libs/love-apple-dependencies/iOS/libraries" "$(BUILD_DIR)/ios/src/platform/xcode/ios/libraries"
	@DESTINATION_UDID="$$(xcrun simctl list devices available iOS | rg -o '([A-F0-9-]{36})' | head -n 1)"; \
		[ -n "$$DESTINATION_UDID" ] || (echo "[ios] No available iOS Simulator device found." && exit 1); \
		echo "[ios] Using simulator $$DESTINATION_UDID"
	@echo "[ios] Building Simulator app (love-ios, Debug) ..."
	@DESTINATION_UDID="$$(xcrun simctl list devices available iOS | rg -o '([A-F0-9-]{36})' | head -n 1)"; \
		xcodebuild \
			-project "$(BUILD_DIR)/ios/src/platform/xcode/love.xcodeproj" \
			-scheme love-ios \
			-configuration Debug \
			-sdk iphonesimulator \
			-destination "id=$$DESTINATION_UDID" \
			-derivedDataPath "$(BUILD_DIR)/ios/DerivedData" \
			build > /dev/null
	@APP_PATH="$$(echo "$(BUILD_DIR)/ios/DerivedData/Build/Products/Debug-iphonesimulator/"*.app)"; \
		cp "$(LOVE_FILE)" "$$APP_PATH/$(GAME_NAME).love"; \
		echo "[ios] Fused game into $$APP_PATH/$(GAME_NAME).love"; \
		echo "[ios] -> $$APP_PATH"

run-ios-sim: build-ios
	@echo "[ios] Booting iOS Simulator ..."
	@xcrun simctl bootstatus booted -b >/dev/null 2>&1 || \
		(DEVICE="$$(xcrun simctl list devices available iOS | rg -o '([A-F0-9-]{36})' | head -n 1)"; \
		 [ -n "$$DEVICE" ] || (echo "[ios] No available iOS Simulator device found." && exit 1); \
		 xcrun simctl boot "$$DEVICE" >/dev/null 2>&1 || true; \
		 xcrun simctl bootstatus "$$DEVICE" -b >/dev/null)
	@open -a Simulator
	@APP_PATH="$$(echo "$(BUILD_DIR)/ios/DerivedData/Build/Products/Debug-iphonesimulator/"*.app)"; \
		echo "[ios] Installing $$APP_PATH ..."; \
		xcrun simctl install booted "$$APP_PATH"
	@echo "[ios] Launching org.love2d.love ..."
	@xcrun simctl terminate booted org.love2d.love >/dev/null 2>&1 || true
	@xcrun simctl launch booted org.love2d.love

# ─── Run ─────────────────────────────────────────────────────────────
run:
	@love . $(if $(VERBOSE),--verbose,) $(RUN_ARGS)

run-verbose:
	@love . --verbose

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
	@rm -rf $(LOVE_FILE) $(BUILD_DIR)/macos $(BUILD_DIR)/windows $(BUILD_DIR)/linux $(BUILD_DIR)/ios $(BUILD_DIR)/$(GAME_NAME)-*.zip
	@echo "Cleaned build outputs (cached LOVE downloads preserved)."

clean-all:
	@rm -rf $(BUILD_DIR)
	@echo "Removed entire build directory."

lint:
	@stylua .