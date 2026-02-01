#!/bin/bash
# Build script for macOS distribution
# Creates a signed and notarized DMG installer
#
# Prerequisites:
#   - Xcode Command Line Tools: xcode-select --install
#   - create-dmg: brew install create-dmg
#   - Apple Developer ID certificate installed in Keychain
#   - Keychain profile for notarytool: xcrun notarytool store-credentials
#
# Usage: ./scripts/build-macos.sh [VERSION]

set -e

VERSION="${1:-1.0.0}"
DEVELOPER_ID="${DEVELOPER_ID:-Developer ID Application: Your Name (TEAMID)}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-AC_PASSWORD}"

echo "========================================"
echo "Building Clide $VERSION for macOS"
echo "========================================"

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Check for required tools
if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg not found. Install with: brew install create-dmg"
    exit 1
fi

# Build with PyInstaller
echo "Building with PyInstaller..."
pyinstaller clide.spec --clean --noconfirm

# Check if signing is configured
if [[ "$DEVELOPER_ID" == *"Your Name"* ]]; then
    echo ""
    echo "Warning: DEVELOPER_ID not configured. Skipping code signing."
    echo "To enable signing, set DEVELOPER_ID environment variable."
    echo ""
    SKIP_SIGNING=true
else
    SKIP_SIGNING=false
fi

if [[ "$SKIP_SIGNING" == "false" ]]; then
    # Code sign the app
    echo "Code signing..."
    codesign --deep --force --verify --verbose \
        --sign "$DEVELOPER_ID" \
        --options runtime \
        --entitlements packaging/entitlements.plist \
        --timestamp \
        "dist/Clide.app"

    # Create ZIP for notarization
    echo "Creating ZIP for notarization..."
    ditto -c -k --sequesterRsrc --keepParent \
        "dist/Clide.app" "dist/Clide-$VERSION.zip"

    # Notarize
    echo "Submitting for notarization (this may take a few minutes)..."
    xcrun notarytool submit "dist/Clide-$VERSION.zip" \
        --keychain-profile "$KEYCHAIN_PROFILE" \
        --wait

    # Staple the notarization ticket
    echo "Stapling notarization ticket..."
    xcrun stapler staple "dist/Clide.app"

    # Clean up ZIP
    rm "dist/Clide-$VERSION.zip"
fi

# Create DMG
echo "Creating DMG..."
# Remove existing DMG if present
rm -f "dist/Clide-$VERSION-macos.dmg"

create-dmg \
    --volname "Clide $VERSION" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "Clide.app" 150 190 \
    --hide-extension "Clide.app" \
    --app-drop-link 450 185 \
    "dist/Clide-$VERSION-macos.dmg" \
    "dist/Clide.app" || true  # create-dmg returns non-zero even on success sometimes

echo ""
echo "========================================"
echo "Build complete!"
echo "Output: dist/Clide-$VERSION-macos.dmg"
if [[ "$SKIP_SIGNING" == "true" ]]; then
    echo ""
    echo "Note: App was NOT signed or notarized."
    echo "Users will see Gatekeeper warnings."
fi
echo "========================================"
