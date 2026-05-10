#!/bin/bash
set -e

APP_NAME="Nest"
BUNDLE_NAME="Nest"
BUILD_DIR=".build"
APP="${BUILD_DIR}/${BUNDLE_NAME}.app"
CONTENTS="${APP}/Contents"
MACOS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "🧹 Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$RESOURCES"

echo "🔨 Compiling Swift sources..."
swiftc \
    Sources/main.swift \
    Sources/AppDelegate.swift \
    Sources/MenubarController.swift \
    Sources/HotKeyManager.swift \
    Sources/FinderTracker.swift \
    Sources/CommandBarWindow.swift \
    Sources/CommandBarView.swift \
    Sources/AIProviderConfig.swift \
    Sources/AIAgent.swift \
    Sources/InstantActions.swift \
    Sources/AutoRunPolicy.swift \
    Sources/ActivityLog.swift \
    Sources/CommandNarrator.swift \
    Sources/CommandExecutor.swift \
    Sources/ToolManager.swift \
    Sources/ActivityLogWindow.swift \
    Sources/PreviewCardWindow.swift \
    Sources/AnswerCardWindow.swift \
    Sources/OnboardingWindow.swift \
    Sources/SettingsWindow.swift \
    -framework AppKit \
    -framework SwiftUI \
    -framework Foundation \
    -framework ApplicationServices \
    -framework Carbon \
    -target arm64-apple-macos13.0 \
    -O \
    -o "${MACOS}/${APP_NAME}"

echo "📋 Copying resources..."
cp Info.plist "${CONTENTS}/Info.plist"
if [ -f AppIcon.icns ]; then
    cp AppIcon.icns "${RESOURCES}/AppIcon.icns"
fi

echo "✅ Built: ${APP}"
echo ""
echo "📦 To install, run:"
echo "   cp -r \"${APP}\" /Applications/"
echo "   open /Applications/\"${BUNDLE_NAME}.app\""
echo ""
echo "⚡ First run: grant Accessibility + Automation permissions when prompted."
echo "   Then open Settings (menubar icon → Settings) and configure your AI provider."
