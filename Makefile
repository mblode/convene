SCHEME = Convene
CONFIGURATION = Release
DERIVED_DATA = /tmp/convene-build
ARCHIVE_PATH = $(DERIVED_DATA)/Convene.xcarchive
EXPORT_PATH = $(DERIVED_DATA)/export
APP_NAME = Convene
DMG_PATH = $(DERIVED_DATA)/$(APP_NAME)-$(VERSION).dmg
DMG_BG_SCRIPT = installer/make-dmg-bg.swift
DMG_BG = installer/dmg-background.png
BUNDLE_ID = co.blode.convene
IOS_SCHEME = ConveneMobile
IOS_DERIVED_DATA = /tmp/convene-ios
IOS_SIMULATOR ?= iPhone 17 Pro
VERSION := $(shell tag=`git describe --tags --abbrev=0 2>/dev/null`; if [ -n "$$tag" ]; then printf "%s" "$$tag" | sed 's/^v//'; else printf "0.0.0"; fi)

CODESIGN_IDENTITY ?= Developer ID Application
TEAM_ID ?= $(APPLE_TEAM_ID)
# Local dev builds sign ad-hoc by default: no cert, no keychain writes, no prompts, and it
# works for any contributor. Override with a real identity name to sign with your own cert.
LOCAL_CODE_SIGN_IDENTITY ?= -
LOCAL_KEYCHAIN ?= $(HOME)/Library/Keychains/login.keychain-db
# Hardened runtime is disabled for local builds: an ad-hoc/self-signed app can't satisfy the
# runtime's library-validation Team-ID match against the bundled Sparkle framework and would
# crash on launch. Release (archive/export) keeps hardened runtime on via the project setting.
LOCAL_SIGNING = CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$(LOCAL_CODE_SIGN_IDENTITY)" DEVELOPMENT_TEAM=$(TEAM_ID) ENABLE_DEBUG_DYLIB=NO ENABLE_HARDENED_RUNTIME=NO

.PHONY: project local-signing-identity build debug install test ios ios-run archive export dmg-background dmg notarize clean

# Regenerate Convene.xcodeproj from project.yml. Required after adding Swift files.
project:
	xcodegen generate

local-signing-identity:
	@if [ "$(LOCAL_CODE_SIGN_IDENTITY)" = "-" ]; then \
		echo "Using ad-hoc local signing."; \
	elif security find-identity -v -p codesigning | grep -qF "$(LOCAL_CODE_SIGN_IDENTITY)"; then \
		echo "Using local signing identity: $(LOCAL_CODE_SIGN_IDENTITY)"; \
	else \
		tmpdir=$$(mktemp -d); \
		pass="convene-local"; \
		openssl req -new -newkey rsa:2048 -nodes -x509 -days 3650 \
			-subj "/CN=$(LOCAL_CODE_SIGN_IDENTITY)/" \
			-addext "keyUsage=digitalSignature" \
			-addext "extendedKeyUsage=codeSigning" \
			-keyout "$$tmpdir/key.pem" \
			-out "$$tmpdir/cert.pem"; \
		openssl pkcs12 -export -legacy \
			-out "$$tmpdir/identity.p12" \
			-inkey "$$tmpdir/key.pem" \
			-in "$$tmpdir/cert.pem" \
			-passout "pass:$$pass"; \
		security import "$$tmpdir/identity.p12" \
			-k "$(LOCAL_KEYCHAIN)" \
			-P "$$pass" \
			-A \
			-T /usr/bin/codesign \
			-T /usr/bin/security; \
		security add-trusted-cert \
			-r trustRoot \
			-p codeSign \
			-k "$(LOCAL_KEYCHAIN)" \
			"$$tmpdir/cert.pem"; \
		rm -rf "$$tmpdir"; \
		echo "Created local signing identity: $(LOCAL_CODE_SIGN_IDENTITY)"; \
	fi

build: project local-signing-identity
	xcodebuild -scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED_DATA) \
		MARKETING_VERSION=$(VERSION) \
		$(LOCAL_SIGNING) \
		build

debug: project local-signing-identity
	xcodebuild -scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
		$(LOCAL_SIGNING) \
		build

# Build, replace installed app, relaunch — avoids stale-bundle gotchas during dev.
install: debug
	pkill -x $(APP_NAME) || true
	rsync -a --delete $(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app/ /Applications/$(APP_NAME).app/
	open /Applications/$(APP_NAME).app

test: project
	xcodebuild test -scheme $(SCHEME) \
		-configuration Debug \
		-destination 'platform=macOS' \
		-derivedDataPath $(DERIVED_DATA)

# Build the iPhone app for the simulator. No signing, so it works without a provisioning profile.
ios: project
	xcodebuild -scheme $(IOS_SCHEME) \
		-configuration Debug \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath $(IOS_DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		build

# Build, install, and launch on a booted simulator. Override the device with
# `make ios-run IOS_SIMULATOR="iPhone 17"`. Recording needs a real device — the simulator has no
# microphone input worth transcribing — but everything else is exercisable here.
ios-run: project
	xcodebuild -scheme $(IOS_SCHEME) \
		-configuration Debug \
		-destination 'platform=iOS Simulator,name=$(IOS_SIMULATOR)' \
		-derivedDataPath $(IOS_DERIVED_DATA) \
		CODE_SIGNING_ALLOWED=NO \
		CODE_SIGNING_REQUIRED=NO \
		build
	xcrun simctl boot "$(IOS_SIMULATOR)" || true
	open -a Simulator
	xcrun simctl install booted $(IOS_DERIVED_DATA)/Build/Products/Debug-iphonesimulator/$(IOS_SCHEME).app
	xcrun simctl launch booted co.blode.convene.mobile

archive:
	xcodebuild -scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED_DATA) \
		-archivePath $(ARCHIVE_PATH) \
		CODE_SIGN_STYLE=Manual \
		CODE_SIGN_IDENTITY="$(CODESIGN_IDENTITY)" \
		DEVELOPMENT_TEAM="$(TEAM_ID)" \
		MARKETING_VERSION=$(VERSION) \
		archive

export: archive
	@printf '<?xml version="1.0" encoding="UTF-8"?>\n\
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n\
	<plist version="1.0">\n\
	<dict>\n\
		<key>method</key>\n\
		<string>developer-id</string>\n\
		<key>teamID</key>\n\
		<string>$(TEAM_ID)</string>\n\
		<key>signingStyle</key>\n\
		<string>manual</string>\n\
		<key>signingCertificate</key>\n\
		<string>Developer ID Application</string>\n\
	</dict>\n\
	</plist>' > $(DERIVED_DATA)/ExportOptions.plist
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist $(DERIVED_DATA)/ExportOptions.plist

dmg-background:
	@echo "Generating DMG background..."
	swift $(DMG_BG_SCRIPT)

dmg: export dmg-background
	@rm -f $(DMG_PATH)
	create-dmg \
		--volname "$(APP_NAME)" \
		--background "$(DMG_BG)" \
		--window-pos 200 120 \
		--window-size 700 460 \
		--icon-size 128 \
		--icon "$(APP_NAME).app" 175 230 \
		--app-drop-link 525 230 \
		--hide-extension "$(APP_NAME).app" \
		--text-size 14 \
		--no-internet-enable \
		$(DMG_PATH) \
		$(EXPORT_PATH)/$(APP_NAME).app || test -f $(DMG_PATH)
	@echo "DMG created at $(DMG_PATH)"

notarize: dmg
	xcrun notarytool submit $(DMG_PATH) \
		--apple-id "$(NOTARIZE_APPLE_ID)" \
		--password "$(NOTARIZE_PASSWORD)" \
		--team-id "$(TEAM_ID)" \
		--wait
	xcrun stapler staple $(DMG_PATH)
	@echo "Notarized: $(DMG_PATH)"

clean:
	rm -rf $(DERIVED_DATA) $(IOS_DERIVED_DATA)
