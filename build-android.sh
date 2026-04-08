#!/bin/bash

# Android Export Script for Match-3 Game
# This script helps export your Godot match-3 game to Android

echo "🎮 Match-3 Game Android Export Script"
echo "=================================="

# Set Android SDK path
export ANDROID_SDK_ROOT="/opt/homebrew/share/android-commandlinetools"
export PATH="$ANDROID_SDK_ROOT/platform-tools:$PATH"

# Root directory (script directory) -- ensure we always operate relative to the project root
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Prefer a compatible JAVA_HOME for Android Gradle (try Java 24, then 21, then 17)
# This is conservative: it only sets JAVA_HOME if the variable is not already set.
if [[ -z "$JAVA_HOME" ]]; then
	for ver in 24 21 17; do
		# First try macOS java_home lookup
		candidate=$(/usr/libexec/java_home -v "$ver" 2>/dev/null || true)
		# If java_home didn't find it, try common Homebrew and system locations
		if [[ -z "$candidate" ]]; then
			# Search Homebrew Cellar for openjdk installs (optimize for /opt/homebrew on Apple Silicon)
			for cell in "/opt/homebrew/Cellar" "/usr/local/Cellar"; do
				if [[ -d "$cell" ]]; then
					found=$(find "$cell" -maxdepth 2 -type d -name "openjdk*" 2>/dev/null | sort -V | tail -1 || true)
					if [[ -n "$found" ]]; then
						cand="$found/libexec/openjdk.jdk/Contents/Home"
						if [[ -x "$cand/bin/java" ]]; then
							candidate="$cand"
							break
						fi
					fi
				fi
			done
			# Also try system JVMs under /Library/Java/JavaVirtualMachines (only once, outside the Homebrew loop)
			if [[ -z "$candidate" && -d "/Library/Java/JavaVirtualMachines" ]]; then
				found_sys=$(find /Library/Java/JavaVirtualMachines -maxdepth 1 -type d -name "*jdk*" -print 2>/dev/null | sort -V | tail -1 || true)
				if [[ -n "$found_sys" ]]; then
					cand2="$found_sys/Contents/Home"
					if [[ -x "$cand2/bin/java" ]]; then
						candidate="$cand2"
					fi
				fi
			fi
		fi
		if [[ -n "$candidate" && -x "$candidate/bin/java" ]]; then
			export JAVA_HOME="$candidate"
			export PATH="$JAVA_HOME/bin:$PATH"
			echo "✅ JAVA_HOME set to detected Java $ver: $JAVA_HOME"
			break
		fi
	done
	if [[ -z "$JAVA_HOME" ]]; then
		echo "⚠️ JAVA_HOME not detected. Android Gradle may fail. Please install a JDK or set JAVA_HOME (prefer Java 24 or 17)."
	fi
else
	echo "✅ JAVA_HOME already set: $JAVA_HOME"
fi

# Show selected java version for debugging
if [[ -n "$JAVA_HOME" ]]; then
	echo "Using java at: $(which java 2>/dev/null || echo 'not-in-path')"
	java -version 2>&1 | sed -n '1,2p' || true
fi

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

# Navigate to project directory (use ROOT_DIR so we don't lose it later)
cd "$ROOT_DIR"

echo ""
echo "🔧 Setting up AdMob Plugin..."
echo "=================================="

echo ""
echo "🔨 Building Android APK..."
echo "=================================="

# Create builds directory if it doesn't exist
mkdir -p "$ROOT_DIR/builds"

# Export the game to Android
"$GODOT_PATH" --headless --export-debug "Android" "$ROOT_DIR/builds/match3-game-debug.apk"
GODOT_EXIT=$?

if [ $GODOT_EXIT -eq 0 ]; then
	echo ""
	echo "🎉 SUCCESS! Your match-3 game has been built via Godot export!"
	echo "=================================="
	echo "📱 APK Location: $ROOT_DIR/builds/match3-game-debug.apk"
	echo ""
	echo "📋 Next Steps:"
	echo "1. Install on device: adb install $ROOT_DIR/builds/match3-game-debug.apk"
	echo "2. Or transfer the APK file to your Android device"
	echo "3. Enable 'Install from Unknown Sources' on your device"
	echo "4. Install and enjoy your match-3 game!"
else
	echo ""
	echo "⚠️ Godot export failed (exit code: $GODOT_EXIT). Attempting Gradle fallback..."
	# Attempt Gradle fallback: build the Android project directly using Gradle wrapper.
	if [[ -d "$ROOT_DIR/android/build" ]]; then
		(
			cd "$ROOT_DIR/android/build" || exit 1
			# Ensure JAVA_HOME is set for gradle run
			if [[ -n "$JAVA_HOME" ]]; then
				echo "Running Gradle with JAVA_HOME=$JAVA_HOME"
				GRADLE_JAVA_HOME_ARG=("-Dorg.gradle.java.home=$JAVA_HOME")
			else
				GRADLE_JAVA_HOME_ARG=()
			fi
			./gradlew "${GRADLE_JAVA_HOME_ARG[@]}" assembleDebug --no-daemon
			GRADLE_EXIT=$?
			if [ $GRADLE_EXIT -eq 0 ]; then
				# locate built APK (search for the newest .apk under outputs/apk)
				APK_PATH=""
				latest_mtime=0
				# Use find -print0 and portable stat to pick newest file
				while IFS= read -r -d '' f; do
					# try macOS stat first, then GNU stat
					if stat_out=$(stat -f "%m" "$f" 2>/dev/null); then
						m=$stat_out
					elif stat_out=$(stat -c "%Y" "$f" 2>/dev/null); then
						m=$stat_out
					else
						m=0
					fi
					if [[ $m -gt $latest_mtime ]]; then
						latest_mtime=$m
						APK_PATH="$f"
					fi
				done < <(find . -type f -path "*outputs/apk/*" -name "*.apk" -print0)
				if [[ -n "$APK_PATH" ]]; then
					cp "$APK_PATH" "$ROOT_DIR/builds/match3-game-debug.apk"
					echo "✅ Gradle build succeeded. Copied APK to: $ROOT_DIR/builds/match3-game-debug.apk (source: $APK_PATH)"
				else
					echo "✅ Gradle build succeeded but APK not found in expected locations. Listing outputs for debugging:"
					find . -type f -path "*outputs/apk/*" -print
				fi
			else
				echo "❌ Gradle fallback failed (exit code: $GRADLE_EXIT). See gradle output above for details."
			fi
		)
	else
		echo "❌ No android/build directory found; cannot attempt Gradle fallback."
	fi
fi
