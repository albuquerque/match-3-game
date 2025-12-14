# DroidAdMob Plugin Guide

**Plugin Version**: 1.0  
**Godot Version**: 4.5+  
**Status**: ✅ Production Ready

## Overview

DroidAdMob is a custom Java-based AdMob plugin for Godot 4.5+ with full GDPR compliance. It provides banner ads, interstitial ads, and rewarded video ads with built-in EU/EEA consent management.

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

## Installation

The plugin is already installed at `addons/droid_admob/`:
```
addons/droid_admob/
├── admob.gd                      # GDScript wrapper class
├── export_plugin.gd              # Export configuration
├── plugin.cfg                    # Plugin metadata
└── bin/
    ├── debug/DroidAdMob-debug.aar
    └── release/DroidAdMob-release.aar
```

**Plugin is enabled** in `Project > Project Settings > Plugins`

## Quick Start

### 1. Basic Usage (AdMobManager.gd already implemented)

The game already has `AdMobManager.gd` which handles:
- GDPR consent flow
- Ad loading and showing
- Reward callbacks
- Desktop test mode

### 2. Using in Your Code

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

## GDPR Compliance

### How It Works

1. **On first launch**, the plugin requests consent information
2. **If in EU/EEA**, a consent form is shown automatically
3. **User responds** to consent form
4. **Ads initialize** after consent is obtained/not required
5. **Privacy options** available in settings if needed

### Implementation (Already Done)

The `AdMobManager.gd` already implements:
- Consent flow on startup
- Consent form handling
- Ad initialization after consent
- Desktop test mode bypass

### For Settings Menu

Add a privacy settings button if required:

```gdscript
# In your settings menu
func _ready():
    var admob_manager = get_node("/root/AdMobManager")
    
    if admob_manager.is_privacy_options_required():
        # Show privacy settings button
        privacy_button.visible = true
        privacy_button.pressed.connect(_on_privacy_pressed)

func _on_privacy_pressed():
    var admob_manager = get_node("/root/AdMobManager")
    admob_manager.show_privacy_options_form()
```

### Consent Status Codes

| Code | Status | Meaning |
|------|--------|---------|
| 0 | UNKNOWN | Consent status not yet determined |
| 1 | NOT_REQUIRED | User not in EU/EEA, no consent needed |
| 2 | REQUIRED | User in EU/EEA, consent required |
| 3 | OBTAINED | User has provided consent |

## Testing

### Desktop Testing
- Run game in Godot Editor (F5)
- Simulates 2-second ad with automatic reward
- No actual ads shown
- Consent flow skipped

### Android Testing (Test Mode)
```gdscript
# AdMobManager.gd is configured for test mode:
admob.initialize(true)  # true = test ads
admob.request_consent_info_update(false, "")  # Production consent
```

**Test Ad Units** (already configured):
- Rewarded Video: `ca-app-pub-3940256099942544/5224354917`

### Testing EEA Consent Flow

1. Get your device ID from logcat:
```bash
adb logcat | grep "ConsentDebugSettings"
# Look for: addTestDeviceHashedId("YOUR_DEVICE_ID")
```

2. Update `AdMobManager.gd`:
```gdscript
# Change this line:
admob.request_consent_info_update(false, "")

# To this (with your device ID):
admob.request_consent_info_update(true, "YOUR_DEVICE_ID")
```

3. Run on device - consent form will appear

4. Reset consent for testing:
```gdscript
# In Godot debugger or code:
get_node("/root/AdMobManager").reset_consent()
# Then restart app
```

## Production Setup

Before publishing to Play Store:

### 1. Get Real Ad Units
1. Create app in [AdMob Console](https://apps.admob.com/)
2. Create ad units for each ad type
3. Copy ad unit IDs

### 2. Update AdMobManager.gd

```gdscript
# Change test mode to false:
admob.initialize(false)  # false = real ads

# Replace test ad units:
func load_rewarded_ad():
    # Replace this:
    var ad_unit_id = admob.get_test_rewarded_ad_unit()
    
    # With your real ad unit:
    var ad_unit_id = "ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY"
    
    admob.load_rewarded(ad_unit_id)
```

### 3. Update AndroidManifest.xml

Replace test App ID with your real App ID:

```xml
<!-- In android/build/AndroidManifest.xml -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"
    tools:replace="android:value"/>
```

### 4. Consent Configuration

Keep consent in production mode:
```gdscript
# Keep this as is for production:
admob.request_consent_info_update(false, "")  # Production mode
```

### 5. Build & Test

```bash
# Build release APK
./build-android.sh

# Test on real device
adb install builds/match3-game-debug.apk
adb logcat | grep -E "AdMob|DroidAdMob"
```

## Troubleshooting

### Ads Not Showing

**Desktop**: Normal - desktop uses test mode simulation  
**Android**: 
1. Check internet connection
2. Verify ad unit IDs are correct
3. Check consent status: `get_consent_status()`
4. Look for errors in logcat

### Consent Form Not Appearing

1. **Not in EEA**: Consent only shows for EU/EEA users
2. **Already consented**: Consent saved from previous run
3. **Test mode**: Enable EEA test mode (see Testing section)
4. **Reset**: Use `reset_consent()` to test again

### Build Errors

**"DroidAdMob not found"**:
- Plugin not enabled in Godot Editor
- Clear .godot cache and reimport

**"AAR file not found"**:
- Check `addons/droid_admob/bin/` has AAR files
- Rebuild if necessary

## Technical Details

### Architecture
```
Game Code (AdMobManager.gd)
    ↓
AdMob Wrapper (admob.gd)
    ↓
Java Plugin (DroidAdMob.aar)
    ↓
Google Mobile Ads SDK v22.6.0
User Messaging Platform SDK v2.1.0
```

### Dependencies
- `com.google.android.gms:play-services-ads:22.6.0`
- `com.google.android.ump:user-messaging-platform:2.1.0`

### Platform Requirements
- Android API 21+ (Lollipop 5.0)
- Target API 34
- Internet permission (auto-added)

### Plugin Location
- Folder: `addons/droid_admob/`
- Enabled in: `Project > Project Settings > Plugins`
- Export config: `export_presets.cfg` (plugins/DroidAdMob=true)

## Support & Updates

### Updating Plugin

If you need to rebuild the plugin:

1. Navigate to plugin source:
```bash
cd /Users/sal76/src/Godot-Android-Plugin-Template
```

2. Build plugin:
```bash
export JAVA_HOME=/opt/homebrew/Cellar/openjdk@21/21.0.9/
./gradlew clean build
```

3. Copy to game:
```bash
cp plugin/build/outputs/aar/DroidAdMob-release.aar \
   ~/src/match-3-game/addons/droid_admob/bin/release/
cp plugin/build/outputs/aar/DroidAdMob-debug.aar \
   ~/src/match-3-game/addons/droid_admob/bin/debug/
```

### Resources
- [AdMob Console](https://apps.admob.com/)
- [Google UMP SDK Docs](https://developers.google.com/admob/ump/android/quick-start)
- [AdMob Policy](https://support.google.com/admob/answer/6128543)
- [GDPR Compliance](https://support.google.com/admob/answer/10113207)

---

**Last Updated**: December 12, 2024  
**Plugin**: DroidAdMob v1.0  
**Status**: Production Ready ✅

