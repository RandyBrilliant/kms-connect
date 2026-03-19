#!/bin/bash
# Run KMS Connect on iOS Simulator (bypasses Flutter's signing issues)

set -e

SIMULATOR_NAME="${1:-iPhone 16e}"
BUNDLE_ID="id.kmsconnect.app"

echo "Building for iOS Simulator..."
cd "$(dirname "$0")"

# Ensure dependencies are up to date
flutter pub get

# Build with xcodebuild (bypasses Flutter's provisioning flags)
cd ios
xcodebuild -workspace Runner.xcworkspace \
    -scheme Runner \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    CODE_SIGNING_ALLOWED=NO \
    build | grep -E "^(Build|Compile|Link|\*\*)" || true

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Debug-iphonesimulator -name "Runner.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built app"
    exit 1
fi

echo "Installing to $SIMULATOR_NAME..."
xcrun simctl install "$SIMULATOR_NAME" "$APP_PATH"

echo "Launching app..."
xcrun simctl launch "$SIMULATOR_NAME" "$BUNDLE_ID"

echo ""
echo "App launched! Take screenshots with Cmd+S in the Simulator."
echo "To see logs: xcrun simctl spawn '$SIMULATOR_NAME' log stream --predicate 'subsystem contains \"$BUNDLE_ID\"'"
