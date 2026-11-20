#!/bin/bash
set -euo pipefail

echo "========================================="
echo "Building and Packaging Syllabi for macOS"
echo "========================================="

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

RELEASE_VERSION="${RELEASE_VERSION:-${GITHUB_REF_NAME:-1.0}}"
RELEASE_VERSION="${RELEASE_VERSION#v}"
INSTALL_AFTER_BUILD="${INSTALL_AFTER_BUILD:-0}"

DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/Syllabi.app"
DMG_STAGE="$DIST_DIR/dmg_stage"
DMG_OUTPUT="$PROJECT_DIR/Syllabi.dmg"

# 1. Build optimized release binary
echo "==> Building Release executable..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift build -c release

BIN_DIR="$(DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift build -c release --show-bin-path)"
BIN_PATH="$BIN_DIR/Syllabi"
if [ ! -f "$BIN_PATH" ]; then
    echo "Error: Release binary not found at $BIN_PATH"
    exit 1
fi

# 2. Assemble .app bundle
echo "==> Creating Syllabi.app bundle..."
rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/Syllabi"
chmod +x "$APP_BUNDLE/Contents/MacOS/Syllabi"

cp "$PROJECT_DIR/Syllabi/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $RELEASE_VERSION" "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $RELEASE_VERSION" "$APP_BUNDLE/Contents/Info.plist"
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

if [ -f "$PROJECT_DIR/Syllabi/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Syllabi/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

# 3. Ad-hoc codesign with entitlements
echo "==> Signing Syllabi.app..."
codesign --force --deep --sign - \
    --entitlements "$PROJECT_DIR/Syllabi/Syllabi.entitlements" \
    "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if [ "$INSTALL_AFTER_BUILD" = "1" ]; then
    echo "==> Installing Syllabi.app into /Applications..."
    if [ -d "/Applications/Syllabi.app" ]; then
        rm -rf "/Applications/Syllabi.app"
    fi
    ditto --rsrc --extattr --acl "$APP_BUNDLE" "/Applications/Syllabi.app"
fi

# 4. Prepare DMG staging directory
echo "==> Preparing DMG staging..."
rm -rf "$DMG_STAGE" "$DMG_OUTPUT"
mkdir -p "$DMG_STAGE"

cp -R "$APP_BUNDLE" "$DMG_STAGE/Syllabi.app"

# Create /Applications symlink for drag-and-drop install
ln -s /Applications "$DMG_STAGE/Applications"

# Include sample syllabi
mkdir -p "$DMG_STAGE/Sample Syllabi"
cp "$PROJECT_DIR"/Samples/*.md "$DMG_STAGE/Sample Syllabi/"

# Include Quickstart guide
cat << 'EOF' > "$DMG_STAGE/Instructions.txt"
Syllabi — Local-First Notion-Style Syllabus Tracker for macOS

To Install:
1. Drag "Syllabi.app" into the "Applications" folder.
2. Launch Syllabi from your Applications folder or Spotlight (Cmd + Space).
3. Drag and drop any syllabus .md file (see the "Sample Syllabi" folder) into Syllabi to start tracking your courses!

Keyboard Shortcuts:
- Cmd + I: Import syllabus file or paste Markdown
- Cmd + F: Search topics and notes
- Cmd + E: Export syllabus back to .md with updated completion states
EOF

# 5. Create compressed DMG
echo "==> Generating Syllabi.dmg disk image..."
hdiutil create -volname "Syllabi" \
    -srcfolder "$DMG_STAGE" \
    -ov -format UDZO \
    "$DMG_OUTPUT"

# Clean up temporary staging
rm -rf "$DMG_STAGE"

echo "========================================="
echo "Done! Syllabi.app and Syllabi.dmg ready."
echo "App Bundle: $APP_BUNDLE"
echo "DMG Image:  $DMG_OUTPUT"
echo "========================================="
