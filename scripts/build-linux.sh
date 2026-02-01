#!/bin/bash
# Build script for Linux AppImage distribution
# Creates a portable AppImage that runs on most Linux distributions
#
# Prerequisites:
#   - wget (for downloading appimagetool)
#   - FUSE (for running appimagetool)
#
# Usage: ./scripts/build-linux.sh [VERSION]

set -e

VERSION="${1:-1.0.0}"
ARCH=$(uname -m)

echo "========================================"
echo "Building Clide $VERSION for Linux ($ARCH)"
echo "========================================"

# Ensure we're in the project root
cd "$(dirname "$0")/.."

# Build with PyInstaller
echo "Building with PyInstaller..."
pyinstaller clide.spec --clean --noconfirm

# Create AppDir structure
echo "Creating AppDir structure..."
rm -rf dist/Clide.AppDir
mkdir -p dist/Clide.AppDir/usr/bin
mkdir -p dist/Clide.AppDir/usr/share/applications
mkdir -p dist/Clide.AppDir/usr/share/icons/hicolor/256x256/apps

# Copy binary
cp dist/clide dist/Clide.AppDir/usr/bin/

# Copy desktop file
cp packaging/clide.desktop dist/Clide.AppDir/
cp packaging/clide.desktop dist/Clide.AppDir/usr/share/applications/

# Create placeholder icon (TODO: Replace with actual icon)
# For now, create a simple placeholder
if [ ! -f packaging/clide.png ]; then
    echo "Note: No icon found at packaging/clide.png, AppImage will have no icon"
else
    cp packaging/clide.png dist/Clide.AppDir/clide.png
    cp packaging/clide.png dist/Clide.AppDir/usr/share/icons/hicolor/256x256/apps/clide.png
fi

# Create AppRun launcher
cat > dist/Clide.AppDir/AppRun << 'EOF'
#!/bin/bash
# AppRun - Entry point for AppImage
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export TERM="${TERM:-xterm-256color}"
exec "${HERE}/usr/bin/clide" "$@"
EOF
chmod +x dist/Clide.AppDir/AppRun

# Download appimagetool if needed
APPIMAGETOOL="appimagetool-${ARCH}.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    echo "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH}.AppImage" \
        -O "$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
fi

# Create AppImage
echo "Creating AppImage..."
rm -f "dist/Clide-$VERSION-linux-$ARCH.AppImage"
ARCH=$ARCH ./"$APPIMAGETOOL" dist/Clide.AppDir "dist/Clide-$VERSION-linux-$ARCH.AppImage"

# Clean up AppDir
rm -rf dist/Clide.AppDir

echo ""
echo "========================================"
echo "Build complete!"
echo "Output: dist/Clide-$VERSION-linux-$ARCH.AppImage"
echo ""
echo "To run: chmod +x dist/Clide-$VERSION-linux-$ARCH.AppImage && ./dist/Clide-$VERSION-linux-$ARCH.AppImage"
echo "========================================"
