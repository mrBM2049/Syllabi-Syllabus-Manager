#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

plist=dist/Syllabi.app/Contents/Info.plist
repository=$(/usr/libexec/PlistBuddy -c 'Print :SyllabiGitHubRepository' "$plist")
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
prefix="https://github.com/$repository/releases/download/v$version/"
tools="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin"
run_signing_tool() {
    local tool=$1
    shift
    if [[ -n "${SPARKLE_PRIVATE_ED_KEY:-}" ]]; then
        printf '%s\n' "$SPARKLE_PRIVATE_ED_KEY" | "$tools/$tool" --ed-key-file - "$@"
    else
        "$tools/$tool" --account "${SPARKLE_KEYCHAIN_ACCOUNT:-syllabi}" "$@"
    fi
}

if [[ -n "${SPARKLE_PRIVATE_ED_KEY:-}" &&
      ! "$SPARKLE_PRIVATE_ED_KEY" =~ ^[A-Za-z0-9+/]{43}=$ &&
      ! "$SPARKLE_PRIVATE_ED_KEY" =~ ^[A-Za-z0-9+/]{128}$ ]]; then
    echo "Error: SPARKLE_PRIVATE_ED_KEY does not match Sparkle’s export format."
    exit 1
fi

stage=$(mktemp -d "$PROJECT_DIR/dist/appcast-stage.XXXXXXXX")
cp Syllabi.dmg "$stage/Syllabi.dmg"

run_signing_tool generate_appcast \
    --maximum-deltas 0 --download-url-prefix "$prefix" -o "$stage/appcast.xml" "$stage"

enclosure="//*[local-name()='enclosure'][@url='${prefix}Syllabi.dmg'][@*[local-name()='edSignature']]"
if [[ "$(xmllint --xpath "count($enclosure)" "$stage/appcast.xml")" != 1 ]]; then
    echo "Error: The appcast does not contain the signed Syllabi installer. Check that the public and private keys match."
    exit 1
fi
run_signing_tool sign_update --verify "$stage/appcast.xml"
mv "$stage/appcast.xml" dist/appcast.xml
rm "$stage/Syllabi.dmg"
rmdir "$stage"
