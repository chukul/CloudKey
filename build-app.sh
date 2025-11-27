#!/bin/bash

# Build the executable
echo "Building executable..."
swift build -c release

# Create app bundle structure
APP_NAME="CloudKey"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Creating app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy executable
echo "Copying executable..."
cp .build/release/$APP_NAME "$MACOS/"

# Create app icon from Assets.xcassets
echo "Creating app icon..."
if [ -d "Assets.xcassets/AppIcon.appiconset" ]; then
    # Copy the 1024x1024 icon and convert to .icns
    if command -v sips &> /dev/null && command -v iconutil &> /dev/null; then
        ICONSET_DIR="AppIcon.iconset"
        mkdir -p "$ICONSET_DIR"
        
        # Copy and resize icons
        sips -z 16 16 Assets.xcassets/AppIcon.appiconset/16.png --out "$ICONSET_DIR/icon_16x16.png" &> /dev/null
        sips -z 32 32 Assets.xcassets/AppIcon.appiconset/32.png --out "$ICONSET_DIR/icon_16x16@2x.png" &> /dev/null
        sips -z 32 32 Assets.xcassets/AppIcon.appiconset/32.png --out "$ICONSET_DIR/icon_32x32.png" &> /dev/null
        sips -z 64 64 Assets.xcassets/AppIcon.appiconset/64.png --out "$ICONSET_DIR/icon_32x32@2x.png" &> /dev/null
        sips -z 128 128 Assets.xcassets/AppIcon.appiconset/128.png --out "$ICONSET_DIR/icon_128x128.png" &> /dev/null
        sips -z 256 256 Assets.xcassets/AppIcon.appiconset/256.png --out "$ICONSET_DIR/icon_128x128@2x.png" &> /dev/null
        sips -z 256 256 Assets.xcassets/AppIcon.appiconset/256.png --out "$ICONSET_DIR/icon_256x256.png" &> /dev/null
        sips -z 512 512 Assets.xcassets/AppIcon.appiconset/512.png --out "$ICONSET_DIR/icon_256x256@2x.png" &> /dev/null
        sips -z 512 512 Assets.xcassets/AppIcon.appiconset/512.png --out "$ICONSET_DIR/icon_512x512.png" &> /dev/null
        sips -z 1024 1024 Assets.xcassets/AppIcon.appiconset/1024.png --out "$ICONSET_DIR/icon_512x512@2x.png" &> /dev/null
        
        # Create .icns file
        iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES/AppIcon.icns"
        rm -rf "$ICONSET_DIR"
        echo "✅ App icon created"
    else
        echo "⚠️  sips or iconutil not found, skipping icon creation"
    fi
fi

# Create Info.plist
echo "Creating Info.plist..."
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.aws.manager</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "$CONTENTS/PkgInfo"

echo "✅ App bundle created: $APP_BUNDLE"
echo "To run: open $APP_BUNDLE"
