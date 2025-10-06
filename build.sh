#!/bin/bash

# LocalDash Build Script
# Creates a distributable .app bundle

set -e

APP_NAME="LocalDash"
BUNDLE_ID="com.dangahan.localdash"
VERSION="1.0.0"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

# Build the release binary
swift build -c release

echo "📦 Creating app bundle structure..."

# Create .app bundle structure
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy the executable
cp "$BUILD_DIR/MenuBarInfo" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp Info.plist "$APP_DIR/Contents/Info.plist"

# Make executable
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

echo "✅ $APP_NAME.app created successfully!"
echo "📍 Location: $(pwd)/$APP_DIR"
echo ""
echo "To install: Copy $APP_NAME.app to /Applications"
echo "To run: open $APP_NAME.app"
