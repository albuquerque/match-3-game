#!/bin/bash

# Complete Android Export Setup Script for Match-3 Game
echo "🔧 Setting up Android Export for Match-3 Game"
echo "============================================="

# Set environment variables
export ANDROID_SDK_ROOT="/opt/homebrew/share/android-commandlinetools"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"

# Navigate to project directory
cd "$(dirname "$0")"

echo "📱 Step 1: Downloading and installing export templates manually..."
echo "================================================================"

# Create templates directory
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/4.5.stable"
mkdir -p "$TEMPLATES_DIR"

echo "Downloading Godot 4.5 export templates..."
curl -L -o "/tmp/godot_templates.tpz" "https://github.com/godotengine/godot/releases/download/4.5-stable/Godot_v4.5-stable_export_templates.tpz"

if [ $? -eq 0 ]; then
    echo "✅ Templates downloaded successfully"
    echo "📦 Extracting and installing templates..."

    # Store current directory
    PROJECT_DIR="$(pwd)"

    # Extract templates
    cd "$TEMPLATES_DIR"
    unzip -q "/tmp/godot_templates.tpz"

    # Move templates to correct location
    if [ -d "templates" ]; then
        mv templates/* .
        rmdir templates
    fi

    # Return to project directory
    cd "$PROJECT_DIR"

    echo "✅ Export templates installed successfully"
    rm "/tmp/godot_templates.tpz"
else
    echo "❌ Failed to download templates. Trying alternative method..."

    echo "📱 Opening Godot for manual template installation..."
    echo "Please follow these steps in Godot:"
    echo "1. Godot will open your project"
    echo "2. Go to Editor → Manage Export Templates"
    echo "3. Click 'Download and Install'"
    echo "4. If download fails, click 'Open Template Folder' and manually extract templates"
    echo "5. Wait for installation to complete"
    echo "6. Close the Export Templates window"
    echo ""

    # Open Godot with the project
    godot project.godot &

    read -p "Press Enter after templates are installed..."
fi

echo ""
echo "🔧 Step 2: Configuring Android SDK settings..."
echo "=============================================="

# Create editor settings directory
EDITOR_SETTINGS_DIR="$HOME/.config/godot"
mkdir -p "$EDITOR_SETTINGS_DIR"

# Create or update editor settings
cat > "$EDITOR_SETTINGS_DIR/editor_settings-4.tres" << EOF
[gd_resource type="EditorSettings" format=3]

[resource]
network/android/adb_path = ""
network/android/android_sdk_path = "$ANDROID_SDK_ROOT"
network/android/debug_keystore = "$HOME/.android/debug.keystore"
network/android/debug_keystore_pass = "android"
network/android/debug_keystore_user = "androiddebugkey"
network/android/force_system_user = false
network/android/shutdown_adb_on_exit = true
export/android/java_sdk_path = "/opt/homebrew/Cellar/openjdk/24.0.2/libexec/openjdk.jdk/Contents/Home"
EOF

echo "✅ Android SDK path configured: $ANDROID_SDK_ROOT"

echo ""
echo "📦 Step 3: Building Android APK..."
echo "=================================="

# Try to build the APK
godot --headless --path "$(pwd)" --export-debug "Android" "builds/match3-game-debug.apk"

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 SUCCESS! Your match-3 game has been built!"
    echo "============================================="
    echo "📱 APK Location: $(pwd)/builds/match3-game-debug.apk"
    echo "📊 APK Size: $(ls -lh builds/match3-game-debug.apk | awk '{print $5}')"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Connect your Android device via USB"
    echo "2. Enable USB Debugging on your device"
    echo "3. Install: adb install builds/match3-game-debug.apk"
    echo "4. Or transfer the APK file to your device manually"
    echo ""
    echo "🎮 Your match-3 game is ready for Android!"
else
    echo ""
    echo "❌ Build failed. Let's troubleshoot..."
    echo "====================================="

    # Check if templates are installed
    if [ ! -d "$TEMPLATES_DIR" ] || [ -z "$(ls -A $TEMPLATES_DIR)" ]; then
        echo "❌ Export templates not found or empty"
        echo "🔧 Solution: Run this script again or manually install templates"
    fi

    # Check if Android SDK is accessible
    if [ ! -d "$ANDROID_SDK_ROOT" ]; then
        echo "❌ Android SDK not found at: $ANDROID_SDK_ROOT"
        echo "🔧 Solution: Check Android SDK installation"
    fi

    echo ""
    echo "🔧 Troubleshooting steps:"
    echo "1. Verify export templates are installed: ls -la '$TEMPLATES_DIR'"
    echo "2. Check Android SDK: ls -la '$ANDROID_SDK_ROOT'"
    echo "3. Try opening Godot and manually exporting from Project → Export"
    echo "4. Run this script again after fixing any issues"
fi
