APP := build/Meridian.app
BIN_DIR = $(shell swift build -c release --show-bin-path)
# Signs with your first code-signing identity, or ad hoc if you have none. Pick one with `make SIGN_ID="<name or hash>"`.
SIGN_ID ?= $(or $(shell security find-identity -v -p codesigning | awk -F'"' 'NR==1 && NF>1 {print $$2}'),-)

# Command Line Tools 27 lack SwiftUI's macro plugin, so build against their newest macOS 26 SDK and point tests at their Swift Testing plugin.
CLT := /Library/Developer/CommandLineTools
ifeq ($(shell xcode-select -p),$(CLT))
SDK := $(shell ls -d $(CLT)/SDKs/MacOSX26.*.sdk 2>/dev/null | sort -V | tail -1)
ifneq ($(SDK),)
export SDKROOT := $(SDK)
endif
TEST_FLAGS := -Xswiftc -plugin-path -Xswiftc $(CLT)/usr/lib/swift/host/plugins/testing
endif

.PHONY: all build app test install icon clean

all: app

build:
	swift build -c release

app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp "$(BIN_DIR)/Meridian" $(APP)/Contents/MacOS/Meridian
	cp Support/Info.plist $(APP)/Contents/Info.plist
	cp Icon/AppIcon.icns $(APP)/Contents/Resources/AppIcon.icns
	codesign --force --options runtime --sign "$(SIGN_ID)" $(APP)

test:
	swift test $(TEST_FLAGS)

# ~/Applications needs no admin rights.
install: app
	-killall Meridian
	mkdir -p ~/Applications
	rm -rf ~/Applications/Meridian.app
	cp -R $(APP) ~/Applications/
	open ~/Applications/Meridian.app

icon:
	rm -rf .build/AppIcon.iconset
	swift Icon/make-icon.swift .build/AppIcon.iconset
	iconutil -c icns .build/AppIcon.iconset -o Icon/AppIcon.icns

clean:
	rm -rf .build build
