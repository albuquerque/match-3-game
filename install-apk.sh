#!/bin/bash

# Install APK on Android Device
# Waits for device authorization and installs the game

ADB="/opt/homebrew/share/android-commandlinetools/platform-tools/adb"
APK="builds/match3-game-debug.apk"

echo "📱 Installing Match-3 Game with AdMob"
echo "====================================="
echo ""

# Check if APK exists
if [ ! -f "$APK" ]; then
    echo "❌ APK not found: $APK"
    echo "Run ./build-android.sh first!"
    exit 1
fi

echo "✅ APK found: $APK ($(ls -lh $APK | awk '{print $5}'))"
echo ""

# Check device connection
echo "Checking for connected devices..."
DEVICE_STATUS=$($ADB devices | grep -v "List of devices" | grep -v "^$" | awk '{print $2}')

if [ -z "$DEVICE_STATUS" ]; then
    echo "❌ No device connected!"
    echo ""
    echo "📱 Connect your device:"
    echo "1. Plug in USB cable"
    echo "2. On device: Settings → About Phone"
    echo "3. Tap 'Build Number' 7 times"
    echo "4. Go to Settings → System → Developer Options"
    echo "5. Enable 'USB Debugging'"
    echo "6. Connect and run this script again"
    exit 1
fi

if [ "$DEVICE_STATUS" = "unauthorized" ]; then
    echo "⚠️  Device is UNAUTHORIZED"
    echo ""
    echo "📱 On your device:"
    echo "   Look for popup: 'Allow USB debugging?'"
    echo "   Tap 'Allow' or 'OK'"
    echo ""
    echo "Waiting for authorization..."

    # Wait for authorization (max 30 seconds)
    for i in {1..30}; do
        sleep 1
        DEVICE_STATUS=$($ADB devices | grep -v "List of devices" | grep -v "^$" | awk '{print $2}')
        if [ "$DEVICE_STATUS" = "device" ]; then
            echo "✅ Device authorized!"
            break
        fi
        echo -n "."
    done
    echo ""

    # Check again
    DEVICE_STATUS=$($ADB devices | grep -v "List of devices" | grep -v "^$" | awk '{print $2}')
    if [ "$DEVICE_STATUS" != "device" ]; then
        echo "❌ Device still not authorized"
        echo "Please accept the USB debugging prompt and run this script again."
        exit 1
    fi
fi

echo "✅ Device ready!"
DEVICE_MODEL=$($ADB shell getprop ro.product.model 2>/dev/null | tr -d '\r')
ANDROID_VERSION=$($ADB shell getprop ro.build.version.release 2>/dev/null | tr -d '\r')
echo "   Model: $DEVICE_MODEL"
echo "   Android: $ANDROID_VERSION"
echo ""

# Check if game is already installed
if $ADB shell pm list packages | grep -q "com.godot.game"; then
    echo "📦 Game is already installed - upgrading..."
    $ADB install -r "$APK"
else
    echo "📦 Installing game for the first time..."
    $ADB install "$APK"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 Installation successful!"
    echo ""
    echo "📱 On your device:"
    echo "   1. Open the game"
    echo "   2. Play until 0 lives"
    echo "   3. Click 'Watch Ad'"
    echo "   4. You should see a REAL VIDEO AD! 🎬"
    echo ""
    echo "🔍 To see logs:"
    echo "   ./debug-admob.sh"
else
    echo ""
    echo "❌ Installation failed!"
    echo "Check the error messages above."
fi

