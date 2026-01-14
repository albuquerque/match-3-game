# AdMob Integration Guide

**Plugin Version**: 1.0  
**Godot Version**: 4.5+  
**Status**: ✅ Production Ready

## Overview

This game uses Google AdMob for monetization through the DroidAdMob plugin. The implementation includes rewarded video ads in the multiplier mini-game, with full GDPR compliance and cross-platform support (mobile + desktop test mode).

---

## Plugin Features

### Ad Types Supported
- ✅ **Banner Ads** - Multiple sizes and positions
- ✅ **Interstitial Ads** - Full-screen ads between levels
- ✅ **Rewarded Video Ads** - Watch ad to play multiplier game

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

### Plugin Structure
```
addons/droid_admob/
├── admob.gd                      # GDScript wrapper class
├── export_plugin.gd              # Export configuration
├── plugin.cfg                    # Plugin metadata
└── bin/
    ├── debug/DroidAdMob-debug.aar
    └── release/DroidAdMob-release.aar
```

### Enable Plugin
1. In Godot: `Project > Project Settings > Plugins`
2. Ensure `DroidAdMob` is enabled
3. Verify it's enabled in `export_presets.cfg`

### Autoload Configuration
**CRITICAL:** AdMobManager MUST be configured as an autoload singleton:

**In `project.godot`:**
```
[autoload]
AdMobManager="*res://scripts/AdMobManager.gd"
```

**To verify in Godot Editor:**
1. Project > Project Settings > Autoload
2. Ensure AdMobManager is in the list
3. Path should be: `res://scripts/AdMobManager.gd`
4. Enabled checkbox should be checked

---

## Configuration

### Ad Unit IDs

Edit `scripts/AdMobManager.gd`:

```gdscript
# Test IDs (for development)
const TEST_REWARDED_AD_UNIT = "ca-app-pub-3940256099942544/5224354917"

# Production IDs (replace with your own from AdMob console)
const PROD_REWARDED_AD_UNIT = "ca-app-pub-XXXXXXXXXXXXX/YYYYYYYYYY"

# Use test IDs for now
const REWARDED_AD_UNIT_ID = TEST_REWARDED_AD_UNIT
```

### App ID

Set your AdMob App ID in `AndroidManifest.xml` or export settings:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXX~YYYYYYYYYY"/>
```

---

## How It Works

### Mobile (Android/iOS)
1. **Initialization**: AdMobManager detects mobile platform and loads AdMob plugin
2. **GDPR Consent**: Automatically shows consent dialog for EU/EEA users
3. **Ad Loading**: Rewarded ad is preloaded in background
4. **Ad Display**: When player taps to stop multiplier pointer, ad is shown
5. **Signal-Based Reward**: AdMob plugin emits `user_earned_reward` signal when ad completes
6. **Reward Application**: Multiplier is applied to level completion rewards

### Desktop (Test Mode)
1. **Detection**: AdMobManager detects desktop platform (macOS/Windows/Linux)
2. **Simulation**: 2-second timer simulates ad watching
3. **Auto-Signal**: After 2 seconds, `user_earned_reward` signal is emitted
4. **Same Flow**: Rest of the flow is identical to mobile for testing

---

## Implementation Details

### AdMobManager Singleton

**Location**: `scripts/AdMobManager.gd`  
**Autoload Path**: `/root/AdMobManager`

**Key Functions:**
```gdscript
func show_rewarded_ad()                    # Show rewarded ad
func load_rewarded_ad()                    # Preload ad (automatic)
func request_consent_info_update()         # GDPR consent check
```

**Key Signals:**
```gdscript
signal user_earned_reward(reward_type: String, reward_amount: int)
signal rewarded_ad_loaded()
signal rewarded_ad_closed()
signal rewarded_ad_failed_to_show(error_message: String)
signal consent_ready()
```

### LevelTransition Integration

**Location**: `scripts/LevelTransition.gd`

The multiplier mini-game integrates with AdMob:

```gdscript
func _on_multiplier_tapped():
    # Player tapped to stop pointer, calculate multiplier
    _selected_multiplier = calculate_zone()
    
    # Show ad to claim multiplier
    var admob_manager = get_node("/root/AdMobManager")
    admob_manager.show_rewarded_ad()

func _on_ad_reward_earned_signal(reward_type, reward_amount):
    # Ad watched successfully, apply multiplier
    _apply_multiplier()
```

### Signal Connection

Signals are connected in `_ready()` and validated in `show_transition()`:

```gdscript
func _connect_admob_signals():
    var admob_manager = get_node_or_null("/root/AdMobManager")
    if not admob_manager:
        return
    
    # Connect user_earned_reward signal
    var reward_callable = Callable(self, "_on_ad_reward_earned_signal")
    if not admob_manager.user_earned_reward.is_connected(reward_callable):
        admob_manager.user_earned_reward.connect(reward_callable)
    
    # Connect other signals
    # ...
```

**Important:** Check `signal.is_connected()` not `object.is_connected()` to ensure proper connection verification.

---

## Flow Diagrams

### Rewarded Ad Flow
```
Player completes level
    ↓
Multiplier bar shown with moving pointer
    ↓
Player taps to stop pointer
    ↓
Multiplier calculated (1.0x - 3.0x)
    ↓
AdMobManager.show_rewarded_ad() called
    ↓
┌─────────────────┬──────────────────┐
│     Mobile      │     Desktop      │
├─────────────────┼──────────────────┤
│ Real ad shown   │ 2-second timer   │
│ Player watches  │ Auto-complete    │
└─────────────────┴──────────────────┘
    ↓
user_earned_reward signal emitted
    ↓
_on_ad_reward_earned_signal() called
    ↓
Multiplier applied to rewards
    ↓
Display updated, result fades
```

### GDPR Consent Flow (Mobile Only)
```
AdMobManager._initialize_admob()
    ↓
request_consent_info_update()
    ↓
Consent status checked
    ↓
┌────────────────────────┐
│ EU/EEA User?           │
├────────────────────────┤
│ Yes → Show consent form│
│ No  → Skip to SDK init │
└────────────────────────┘
    ↓
User grants/denies consent
    ↓
Initialize AdMob SDK
    ↓
Load rewarded ad
```

---

## Testing

### Desktop Testing
```bash
# Run in Godot editor (F5)
# Complete a level
# Tap to stop multiplier pointer
# Wait 2 seconds (ad simulation)
# Verify multiplier is applied
```

**Expected logs:**
```
[AdMobManager] Running on desktop - test mode enabled
[AdMobManager] Test mode - simulating ad watch
[AdMobManager] Test ad simulation started (2 seconds)...
[AdMobManager] Test mode - Ad watched successfully!
[LevelTransition] Ad reward earned via signal
[LevelTransition] Applying 2.5x multiplier to rewards
```

### Mobile Testing
```bash
# Build and install
./build-android.sh
./install-apk.sh

# Monitor logs
adb logcat -s "godot:I" | grep -E "AdMobManager|LevelTransition"

# Test flow
# 1. Complete level
# 2. Tap to stop pointer
# 3. Watch real test ad
# 4. Verify multiplier applied
```

**Expected logs:**
```
[AdMobManager] AdMob plugin found and loaded successfully
[AdMobManager] Starting GDPR consent flow...
[AdMobManager] Consent flow complete
[AdMobManager] Rewarded ad loaded successfully!
[AdMobManager] Showing rewarded ad...
[AdMobManager] User earned reward: life x1
[LevelTransition] Applying 3.0x multiplier to rewards
```

---

## Troubleshooting

### "AdMobManager not available - using test mode" on Mobile

**Cause**: AdMobManager not configured as autoload

**Solution**:
1. Open Godot Editor
2. Go to Project > Project Settings > Autoload tab
3. Add AdMobManager if not present:
   - Path: `res://scripts/AdMobManager.gd`
   - Node Name: `AdMobManager`
   - Enable checkbox must be checked
4. Save and rebuild the project

### "DroidAdMob plugin singleton not found"

**Cause**: Plugin not properly installed or enabled

**Solution**:
1. Verify plugin files exist in `addons/droid_admob/`
2. Check Project > Project Settings > Plugins
3. Ensure export preset has plugin enabled
4. Rebuild the project

### Ads Not Showing on Mobile

**Possible causes and solutions**:
1. **Ad not preloaded**: Check logs for "Rewarded ad loaded successfully!"
   - If missing, check internet connection
   - Verify ad unit IDs are correct
2. **GDPR consent not granted**: Check consent flow completed
3. **Test device not configured**: Add device ID to AdMob console for test ads
4. **App ID not set**: Verify AndroidManifest.xml has correct App ID

### Rewards Not Doubling

**Possible causes**:
1. **Signal not connected**: Check logs for "✓ Connected user_earned_reward signal"
2. **Ad closed early**: Player must watch ad completely
3. **Already multiplied**: Can only multiply once per level

### Desktop Simulation Not Working

**Solution**:
- Check AdMobManager is in autoload
- Verify test_ad_timer is being created
- Look for "[AdMobManager] Test mode" in logs

---

## Debugging

The implementation includes extensive logging:

### AdMobManager Logs
```
[AdMobManager] Initializing...
[AdMobManager] show_rewarded_ad called
[AdMobManager] is_initialized: true/false
[AdMobManager] admob exists: true/false
[AdMobManager] is_rewarded_ad_loaded: true/false
[AdMobManager] User earned reward: {type} x{amount}
[AdMobManager] Emitting user_earned_reward signal...
```

### LevelTransition Logs
```
[LevelTransition] Found AdMobManager, connecting signals...
[LevelTransition] ✓ Connected user_earned_reward signal
[LevelTransition] Pointer stopped at X% - Multiplier: X.Xx
[LevelTransition] Triggering ad to claim X.Xx multiplier
[LevelTransition] Ad reward earned via signal
[LevelTransition] Applying X.Xx multiplier to rewards
[LevelTransition] Rewards multiplied: X coins, X gems
```

---

## Production Setup

### 1. Get AdMob Account
1. Sign up at https://admob.google.com
2. Create new app
3. Note your App ID: `ca-app-pub-XXXXXXXXXXXXX~YYYYYYYYYY`

### 2. Create Ad Units
1. In AdMob console, create "Rewarded" ad unit
2. Note Ad Unit ID: `ca-app-pub-XXXXXXXXXXXXX/YYYYYYYYYY`

### 3. Update Code
Edit `scripts/AdMobManager.gd`:
```gdscript
# Replace with your production IDs
const PROD_REWARDED_AD_UNIT = "ca-app-pub-XXXXXXXXXXXXX/YYYYYYYYYY"
const REWARDED_AD_UNIT_ID = PROD_REWARDED_AD_UNIT  # Switch to production
```

### 4. Update AndroidManifest.xml
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXX~YYYYYYYYYY"/>
```

### 5. Test with Real Ads
1. Build release version
2. Test on real device (not emulator)
3. Verify ads load and display correctly
4. Verify rewards are granted after watching

### 6. Submit to Google Play
1. Ensure GDPR consent is working
2. Test in multiple regions (EU/non-EU)
3. Upload to Google Play Console
4. Wait for ad serving to activate (24-48 hours)

---

## Files Reference

- `scripts/AdMobManager.gd` - Main ad management singleton
- `scripts/LevelTransition.gd` - Multiplier game integration
- `addons/droid_admob/admob.gd` - Plugin wrapper class
- `addons/droid_admob/bin/` - Plugin AAR files
- `project.godot` - Autoload configuration

---

## Support

For plugin issues:
- Check plugin documentation in `addons/droid_admob/`
- Review AdMob SDK documentation
- Test with Google's test ad units first

For implementation issues:
- Check logs for detailed error messages
- Verify all signals are connected
- Test desktop mode first before mobile

---

## Summary

✨ **Easy integration** - Autoload singleton, simple API
✨ **GDPR compliant** - Automatic consent management
✨ **Cross-platform** - Works on mobile and desktop
✨ **Well tested** - Extensive logging and error handling
✨ **Production ready** - Used in multiplier mini-game

The AdMob integration is fully functional and ready for production use! 🎉

