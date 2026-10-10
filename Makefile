SHELL := /bin/zsh

APP_NAME := MouseScrollReverser
BUNDLE_ID := com.gri.MouseScrollReverser
EXECUTABLE_NAME := MouseScrollReverser
BUILD_DIR := build
OBJECT_DIR := $(BUILD_DIR)/objects
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
CONTENTS_DIR := $(APP_BUNDLE)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
APP_EXECUTABLE := $(MACOS_DIR)/$(EXECUTABLE_NAME)
APP_INFO_PLIST := $(CONTENTS_DIR)/Info.plist
APP_LICENSE := $(RESOURCES_DIR)/LICENSE
TEST_EXECUTABLE := $(BUILD_DIR)/ScrollTapTests

SDK_PATH := $(shell xcrun --sdk macosx --show-sdk-path)
CC := xcrun --sdk macosx clang
ARCHS ?= arm64 x86_64
ARCH_FLAGS := $(foreach arch,$(ARCHS),-arch $(arch))

COMMON_FLAGS := \
	$(ARCH_FLAGS) \
	-isysroot $(SDK_PATH) \
	-mmacosx-version-min=13.0 \
	-I Sources \
	-Wall \
	-Wextra \
	-Wpedantic \
	-Werror=implicit-function-declaration \
	-O2

OBJC_FLAGS := $(COMMON_FLAGS) -fobjc-arc
C_FLAGS := $(COMMON_FLAGS) -std=c17

APP_OBJECTS := \
	$(OBJECT_DIR)/main.o \
	$(OBJECT_DIR)/AppDelegate.o \
	$(OBJECT_DIR)/ScrollTap.o

.PHONY: all app test verify run clean

all: app test verify

app: $(APP_EXECUTABLE) $(APP_INFO_PLIST) $(APP_LICENSE)
	codesign --force --sign - --identifier "$(BUNDLE_ID)" --options runtime --timestamp=none "$(APP_BUNDLE)"

$(APP_EXECUTABLE): $(APP_OBJECTS)
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	$(CC) $(COMMON_FLAGS) $(APP_OBJECTS) \
		-framework Cocoa \
		-framework ApplicationServices \
		-framework ServiceManagement \
		-o "$@"

$(APP_INFO_PLIST): Resources/Info.plist
	mkdir -p "$(CONTENTS_DIR)"
	cp Resources/Info.plist "$@"

$(APP_LICENSE): LICENSE
	mkdir -p "$(RESOURCES_DIR)"
	cp LICENSE "$@"

$(OBJECT_DIR)/%.o: Sources/%.m
	mkdir -p "$(OBJECT_DIR)"
	$(CC) $(OBJC_FLAGS) -c "$<" -o "$@"

$(OBJECT_DIR)/%.o: Sources/%.c
	mkdir -p "$(OBJECT_DIR)"
	$(CC) $(C_FLAGS) -c "$<" -o "$@"

$(TEST_EXECUTABLE): Tests/ScrollTapTests.c Sources/ScrollTap.c Sources/ScrollTap.h
	mkdir -p "$(BUILD_DIR)"
	$(CC) $(C_FLAGS) Tests/ScrollTapTests.c Sources/ScrollTap.c \
		-framework ApplicationServices \
		-o "$@"

test: $(TEST_EXECUTABLE)
	"$(TEST_EXECUTABLE)"

verify: app
	plutil -lint "$(APP_INFO_PLIST)"
	codesign --verify --deep --strict --verbose=2 "$(APP_BUNDLE)"
	file "$(APP_EXECUTABLE)"
	lipo "$(APP_EXECUTABLE)" -verify_arch $(ARCHS)

run: app
	open "$(APP_BUNDLE)"

clean:
	rm -rf "$(BUILD_DIR)"

