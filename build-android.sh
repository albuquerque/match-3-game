#!/bin/bash

# Android Export Script for Match-3 Game
# This script helps export your Godot match-3 game to Android

echo "🎮 Match-3 Game Android Export Script"
echo "=================================="

# Set Android SDK path
export ANDROID_SDK_ROOT="/opt/homebrew/share/android-commandlinetools"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"

# Function to find Godot executable
find_godot() {
    # Common Godot installation paths on macOS
    local godot_paths=(
        "/Applications/Godot.app/Contents/MacOS/Godot"
        "/Applications/Godot_v4.3-stable_macos.universal.app/Contents/MacOS/Godot"
        "/Applications/Godot_v4.2-stable_macos.universal.app/Contents/MacOS/Godot"
        "/Applications/Godot_v4.1-stable_macos.universal.app/Contents/MacOS/Godot"
        "/Applications/Godot_v4.0-stable_macos.universal.app/Contents/MacOS/Godot"
        "$(which godot 2>/dev/null)"
        "$HOME/Applications/Godot.app/Contents/MacOS/Godot"
        "$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
    )

    # Check each possible path
    for path in "${godot_paths[@]}"; do
        if [[ -n "$path" && -x "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    # Try to find any Godot app bundle
    local found_app=$(find /Applications -name "Godot*.app" -type d 2>/dev/null | head -1)
    if [[ -n "$found_app" ]]; then
        local godot_exec="$found_app/Contents/MacOS/Godot"
        if [[ -x "$godot_exec" ]]; then
            echo "$godot_exec"
            return 0
        fi
    fi

    return 1
}

# Find Godot installation
GODOT_PATH=$(find_godot)

if [[ -z "$GODOT_PATH" ]]; then
    echo "❌ Godot not found. Please install Godot Engine first."
    echo ""
    echo "🔍 Common installation methods:"
    echo "1. Download from: https://godotengine.org/download"
    echo "2. Install via Homebrew: brew install --cask godot"
    echo "3. Download and place Godot.app in /Applications/"
    echo ""
    echo "💡 If Godot is installed elsewhere, create a symlink:"
    echo "   sudo ln -s '/path/to/Godot.app/Contents/MacOS/Godot' /usr/local/bin/godot"
    exit 1
fi

echo "✅ Android SDK: $ANDROID_SDK_ROOT"
echo "✅ Godot Engine: $GODOT_PATH"

# Navigate to project directory
cd "$(dirname "$0")"

echo ""
echo "🔧 Setting up AdMob Plugin..."
echo "=================================="

echo ""
echo "🔨 Building Android APK..."
echo "=================================="

# Export the game to Android
"$GODOT_PATH" --headless --export-debug "Android" "builds/match3-game-debug.apk"

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS! Your match-3 game has been built!"
    echo "=================================="
    echo "📱 APK Location: $(pwd)/builds/match3-game-debug.apk"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Install on device: adb install builds/match3-game-debug.apk"
    echo "2. Or transfer the APK file to your Android device"
    echo "3. Enable 'Install from Unknown Sources' on your device"
    echo "4. Install and enjoy your match-3 game!"
else
    echo ""
    echo "❌ Build failed. Please check the Godot export settings."
    echo "   Make sure you have:"
    echo "   - Downloaded Android export templates in Godot"
    echo "   - Configured Android SDK path in Godot settings"
    echo "   - Created Android export preset in your project"
    echo ""
    echo "🔧 To configure Godot for Android export:"
    echo "1. Open Godot and load your project"
    echo "2. Go to Editor → Manage Export Templates → Download"
    echo "3. Go to Project → Export → Add Android preset"
    echo "4. Set Android SDK path to: $ANDROID_SDK_ROOT"
fi
