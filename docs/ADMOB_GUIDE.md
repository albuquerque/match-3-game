# DroidAdMob Plugin Guide

**Plugin Version**: 1.0  
**Godot Version**: 4.5+  
**Status**: ✅ Production Ready

## Overview

DroidAdMob is a custom Java-based AdMob plugin for Godot 4.5+ with full GDPR compliance. It provides banner ads, interstitial ads, and rewarded video ads with built-in EU/EEA consent management. This guide covers installation, usage, App ID & ad unit configuration, GDPR, testing, production setup, troubleshooting and plugin rebuild instructions.

---

## Features

### Ad Types
- ✅ **Banner Ads** - Multiple sizes and positions
- ✅ **Interstitial Ads** - Full-screen ads between levels
- ✅ **Rewarded Video Ads** - Watch ad to earn rewards (lives, coins, etc.)

### GDPR Compliance
- ✅ **User Messaging Platform (UMP) SDK** v2.1.0
- ✅ **Automatic consent forms** for EU/EEA users
- ✅ **Privacy options** management
- ✅ **Consent status tracking**
- ✅ **Test mode** for EEA simulation

### Development Support
- ✅ **Test mode** with Google test ad units
- ✅ **Desktop simulation** (2-second fake ads)
- ✅ **Easy GDScript API** through wrapper class

---

## Installation

The plugin is installed at `addons/droid_admob/`:

```
addons/droid_admob/
├── admob.gd                      # GDScript wrapper class
├── export_plugin.gd              # Export configuration
├── plugin.cfg                    # Plugin metadata
└── bin/
    ├── debug/DroidAdMob-debug.aar
    └── release/DroidAdMob-release.aar
```

Enable the plugin in Godot: `Project > Project Settings > Plugins` (ensure `DroidAdMob` is enabled in `export_presets.cfg`).

---

## Quick Start

### 1. AdMobManager (already implemented)
The game includes `scripts/AdMobManager.gd` which handles:
- GDPR consent flow
- Ad loading and showing
- Reward callbacks
- Desktop test mode behavior

### 2. Example Usage

```gdscript
# Get the AdMobManager singleton
var admob_manager = get_node("/root/AdMobManager")

# Connect to reward signal
admob_manager.user_earned_reward.connect(_on_ad_reward)

# Show rewarded ad
func request_ad():
    if admob_manager.is_rewarded_ad_ready():
        admob_manager.show_rewarded_ad(_on_reward_granted)
    else:
        print("Ad not ready yet")

func _on_reward_granted():
    print("User watched the ad!")
    # Grant reward (life, coins, etc.)

func _on_ad_reward(reward_type: String, amount: int):
    print("Rewarded: ", amount, " ", reward_type)
```

---

## API Reference

### AdMobManager Methods

#### Ad Management
```gdscript
# Check if rewarded ad is ready
is_rewarded_ad_ready() -> bool

# Show rewarded ad with optional callback
show_rewarded_ad(reward_callback: Callable = Callable())

# Load a new rewarded ad (called automatically)
load_rewarded_ad()
```

#### GDPR/Consent Methods
```gdscript
# Get consent status (0=UNKNOWN, 1=NOT_REQUIRED, 2=REQUIRED, 3=OBTAINED)
get_consent_status() -> int

# Check if privacy options should be shown
is_privacy_options_required() -> bool

# Show privacy settings form
show_privacy_options_form()

# Reset consent (testing only!)
reset_consent()
```

### Signals

```gdscript
# Ad events
signal rewarded_ad_loaded
signal rewarded_ad_failed_to_load(error_message: String)
signal rewarded_ad_opened
signal rewarded_ad_closed
signal rewarded_ad_failed_to_show(error_message: String)
signal user_earned_reward(reward_type: String, reward_amount: int)

# Consent events
signal consent_ready  # Emitted when consent flow completes
```

---

## App ID vs Ad Unit IDs — What goes where

- **App ID (AndroidManifest.xml)** identifies your app to the AdMob SDK and uses the tilde `~` format:
  - `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`
  - This must be present in the merged Android manifest at build time.

- **Ad Unit IDs (GDScript code)** identify specific ad placements and use the slash `/` format:
  - `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY`
  - These are used in `scripts/AdMobManager.gd` when loading ads.

**Notice:** App ID uses `~` (tilde), Ad Unit IDs use `/` (slash).

---

## Where App ID Is Currently Defined (project)

1. **Embedded in plugin AAR** (default/test):
   - `addons/droid_admob/bin/debug/DroidAdMob-debug.aar`
   - `addons/droid_admob/bin/release/DroidAdMob-release.aar`

   Each AAR contains an `AndroidManifest.xml` with a `meta-data` entry for `com.google.android.gms.ads.APPLICATION_ID` (currently set to Google's test App ID inside the provided AARs).

2. **Merged Manifest**
   - During the build the plugin manifest is merged into the app manifest (see `android/build/.../merged_manifests/.../AndroidManifest.xml`).

---

## How to Set Your Real App ID

You have two approaches depending on whether you can rebuild the plugin AAR:

### Option 1 — Rebuild the Plugin AAR (Recommended)

1. Edit the plugin source's `AndroidManifest.xml` and set:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-YOUR_PUBLISHER_ID~YOUR_APP_ID" />
```
2. Rebuild the plugin AARs (`./gradlew assembleDebug` / `assembleRelease`) in the plugin project.
3. Replace AARs in `addons/droid_admob/bin/debug/` and `addons/droid_admob/bin/release/`.

This ensures the correct App ID is embedded in the plugin manifest and merged at build time.

### Option 2 — Override via Godot Android Build Template

If you cannot rebuild the AAR, override the App ID using Godot's Android custom build template:

1. Install Android build template in Godot: `Project > Install Android Build Template` (creates `android/build/`).
2. Edit `android/build/AndroidManifest.xml` and add inside `<application>`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-YOUR_PUBLISHER_ID~YOUR_APP_ID"
    tools:replace="android:value" />
```
3. Ensure the `tools` namespace is declared on the root `<manifest>`:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
```
4. Enable Gradle builds in your export preset (Use Gradle Build).

This will override the plugin-provided App ID during manifest merging.

---

## Complete Setup Checklist

- [ ] Get your AdMob **App ID** (`ca-app-pub-...~...`) from AdMob console
- [ ] Get your Ad Unit IDs (`ca-app-pub-.../...`) for each ad type
- [ ] Choose App ID approach (Rebuild AAR or override manifest)
- [ ] Update Ad Unit IDs in `scripts/AdMobManager.gd` (replace test IDs)
- [ ] Disable test mode in `AdMobManager.gd` (`admob.initialize(false)`)
- [ ] Build and test on real device
- [ ] Verify consent flow and rewarded callbacks

---

## Testing & Development

### Desktop Testing
- Run game in Godot Editor (F5)
- Desktop simulates a 2-second fake ad with automatic reward
- Consent flow is bypassed in desktop mode

### Android Testing (Test Mode)

`AdMobManager.gd` is configured for test mode by default for safe development:
```gdscript
admob.initialize(true)  # true = test ads
admob.request_consent_info_update(false, "")  # Production consent
```

**Test Ad Units** (already configured in code):
- Rewarded Video: `ca-app-pub-3940256099942544/5224354917`

#### Testing EEA consent flow
1. Get device test id (`adb logcat | grep "ConsentDebugSettings"`).
2. Call `admob.request_consent_info_update(true, "YOUR_DEVICE_ID")` to enable debug consent.
3. Reset consent with `get_node("/root/AdMobManager").reset_consent()` to retest.

---

## Production Setup

1. Create your app and ad units in the AdMob Console
2. Update App ID (Option 1 or 2 above)
3. Update Ad Unit IDs in `scripts/AdMobManager.gd`
4. Disable test mode (`admob.initialize(false)`)
5. Keep consent request in production mode: `admob.request_consent_info_update(false, "")`
6. Build release APK and verify on real device

Build & test commands:
```bash
# Build release APK
./build-android.sh

# Install and view logs
adb install -r builds/match3-game-debug.apk
adb logcat | grep -E "AdMob|DroidAdMob"
```

---

## Troubleshooting

### Ads Not Showing
- Desktop: normal (simulation only)
- Android:
  1. Check internet connection
  2. Verify your ad unit IDs
  3. Check consent status via `get_consent_status()`
  4. Inspect `adb logcat` for errors

### Consent Form Not Appearing
- Consent shows only for EU/EEA users
- Use test consent flow to force form for your device

### Common Build Errors
- `DroidAdMob not found` — plugin disabled or missing AAR
- `AAR file not found` — ensure `addons/droid_admob/bin/` contains the AARs

---

## Plugin Rebuild & Update

If you need to rebuild the plugin (have source):

1. Open plugin source repository
2. Set `JAVA_HOME` (example):
```bash
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@21/21.0.9/
```
3. Build plugin:
```bash
./gradlew clean build
```
4. Copy AARs into the project:
```bash
cp plugin/build/outputs/aar/DroidAdMob-release.aar \
   ~/src/match-3-game/addons/droid_admob/bin/release/
cp plugin/build/outputs/aar/DroidAdMob-debug.aar \
   ~/src/match-3-game/addons/droid_admob/bin/debug/
```

---

## Troubleshooting & Support Resources

- [AdMob Console](https://apps.admob.com/)
- [Google UMP SDK Docs](https://developers.google.com/admob/ump/android/quick-start)
- [AdMob Policy](https://support.google.com/admob/answer/6128543)
- [GDPR Compliance](https://support.google.com/admob/answer/10113207)

---

**Last Updated**: December 16, 2025
**Plugin**: DroidAdMob v1.0
**Status**: Production Ready ✅
