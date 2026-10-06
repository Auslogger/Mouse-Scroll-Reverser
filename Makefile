APP_NAME := MouseScrollReverser
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
EXECUTABLE := $(MACOS_DIR)/$(APP_NAME)
TEST_EXECUTABLE := $(BUILD_DIR)/ScrollTapTests

SDK_PATH := $(shell xcrun --sdk macosx --show-sdk-path)
CC := xcrun --sdk macosx clang
ARCHS ?= arm64 x86_64
ARCH_FLAGS := $(foreach arch,$(ARCHS),-arch $(arch))
COMMON_FLAGS := $(ARCH_FLAGS) -isysroot $(SDK_PATH) -mmacosx-version-min=13.0 -I Sources -Wall -Wextra

.PHONY: all test run clean

all: $(EXECUTABLE) $(CONTENTS_DIR)/Info.plist

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

$(TEST_EXECUTABLE): Tests/ScrollTapTests.c Sources/ScrollTap.c Sources/ScrollTap.h
	mkdir -p "$(BUILD_DIR)"
	$(CC) $(COMMON_FLAGS) -std=c17 \
		-framework ApplicationServices \
		Tests/ScrollTapTests.c Sources/ScrollTap.c -o "$@"

test: $(TEST_EXECUTABLE)
	"$(TEST_EXECUTABLE)"

run: all
	open "$(APP_BUNDLE)"

clean:
	rm -rf "$(BUILD_DIR)"

