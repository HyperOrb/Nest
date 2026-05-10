#!/bin/bash

APP_NAME="Finder AI Agent"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Building ${APP_NAME}..."

# Create structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Compile Swift app
# Note: We use -framework SwiftUI -framework AppKit
swiftc FinderAgent.swift -o "${MACOS_DIR}/${APP_NAME}" -framework SwiftUI -framework AppKit -parse-as-library

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed."
    exit 1
fi

# Copy scripts
cp agent.py tools.py "${RESOURCES_DIR}/"

# Setup venv in Resources
echo "📦 Setting up Python environment..."
python3 -m venv "${RESOURCES_DIR}/venv"
source "${RESOURCES_DIR}/venv/bin/activate"
pip install google-generativeai Pillow pypdf exifread

# Create Info.plist
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.agent.finderai</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "✅ App bundle created at ${APP_DIR}"

# Instructions for Service
echo ""
echo "🚀 To finish installation:"
echo "1. Move '${APP_DIR}' to your /Applications folder."
echo "2. I will now try to create the Quick Action workflow..."

# Create a simple Automator workflow for Quick Action
SERVICE_PATH="${HOME}/Library/Services/AI Agent.workflow"
mkdir -p "${SERVICE_PATH}/Contents"

cat <<EOF > "${SERVICE_PATH}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>AI Agent</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSSendFileTypes</key>
			<array>
				<string>public.item</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
EOF

# Note: Creating a full .workflow via shell is tricky as it's a binary/plist mix.
# A better way is to provide an AppleScript that users can save as a Quick Action.
echo "⚠️  Final Step: Create a Quick Action in 'Shortcuts' app that runs 'Shell Script':"
echo "   /Applications/Finder\ AI\ Agent.app/Contents/MacOS/Finder\ AI\ Agent \"\$@\""
