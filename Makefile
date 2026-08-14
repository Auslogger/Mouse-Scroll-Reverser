APP_NAME := MouseScrollReverser
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
EXECUTABLE := $(MACOS_DIR)/$(APP_NAME)

.PHONY: all run clean

all: $(EXECUTABLE) $(CONTENTS_DIR)/Info.plist

$(EXECUTABLE): Sources/main.m
	mkdir -p "$(MACOS_DIR)"
	xcrun clang -fobjc-arc -Wall -Wextra \
		-framework Cocoa \
		-framework ApplicationServices \
		Sources/main.m -o "$@"

$(CONTENTS_DIR)/Info.plist: Resources/Info.plist
	mkdir -p "$(CONTENTS_DIR)"
	cp Resources/Info.plist "$@"

run: all
	open "$(APP_BUNDLE)"

clean:
	rm -rf "$(BUILD_DIR)"

