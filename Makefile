APP_NAME := MouseScrollReverser
BUNDLE_ID := com.gri.MouseScrollReverser
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
EXECUTABLE := $(MACOS_DIR)/$(APP_NAME)
APP_LICENSE := $(RESOURCES_DIR)/LICENSE
TEST_EXECUTABLE := $(BUILD_DIR)/ScrollTapTests

SDK_PATH := $(shell xcrun --sdk macosx --show-sdk-path)
CC := xcrun --sdk macosx clang
ARCHS ?= arm64 x86_64
ARCH_FLAGS := $(foreach arch,$(ARCHS),-arch $(arch))
COMMON_FLAGS := $(ARCH_FLAGS) -isysroot $(SDK_PATH) -mmacosx-version-min=13.0 -I Sources -Wall -Wextra

.PHONY: all app test verify run clean

all: app test verify

app: $(EXECUTABLE) $(CONTENTS_DIR)/Info.plist $(APP_LICENSE)
	codesign --force --sign - --identifier "$(BUNDLE_ID)" --timestamp=none "$(APP_BUNDLE)"

$(EXECUTABLE): Sources/main.m Sources/AppDelegate.m Sources/AppDelegate.h Sources/ScrollTap.c Sources/ScrollTap.h
	mkdir -p "$(MACOS_DIR)"
	$(CC) $(COMMON_FLAGS) -fobjc-arc \
		-framework Cocoa \
		-framework ApplicationServices \
		-framework ServiceManagement \
		Sources/main.m Sources/AppDelegate.m Sources/ScrollTap.c -o "$@"

$(CONTENTS_DIR)/Info.plist: Resources/Info.plist
	mkdir -p "$(CONTENTS_DIR)"
	cp Resources/Info.plist "$@"

$(APP_LICENSE): LICENSE
	mkdir -p "$(RESOURCES_DIR)"
	cp LICENSE "$@"

$(TEST_EXECUTABLE): Tests/ScrollTapTests.c Sources/ScrollTap.c Sources/ScrollTap.h
	mkdir -p "$(BUILD_DIR)"
	$(CC) $(COMMON_FLAGS) -std=c17 \
		-framework ApplicationServices \
		Tests/ScrollTapTests.c Sources/ScrollTap.c -o "$@"

test: $(TEST_EXECUTABLE)
	"$(TEST_EXECUTABLE)"

verify: app
	plutil -lint "$(CONTENTS_DIR)/Info.plist"
	codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"
	file "$(EXECUTABLE)"
	lipo "$(EXECUTABLE)" -verify_arch $(ARCHS)

run: app
	open "$(APP_BUNDLE)"

clean:
	rm -rf "$(BUILD_DIR)"

