# Development Quick Reference

## Build & Deploy

### Build Android APK
```bash
./build-android.sh
```

### Install on Device
```bash
./install-apk.sh
# or manually:
adb install -r builds/match3-game-debug.apk
```

### View Logs
```bash
adb logcat -s "godot:I"
# For AdMob specific:
adb logcat -s "godot:I DroidAdMob:D" | grep -E "AdMobManager|DroidAdMob"
```

## Project Structure

```
match-3-game/
├── android/              # Android build configuration
│   ├── build/           # Custom Android build template
│   │   ├── src/         # Custom plugin source code
│   │   ├── AndroidManifest.xml
│   │   └── build.gradle
│   └── plugins/         # Android plugin files
├── builds/              # Compiled APKs
├── docs/                # Documentation
│   ├── ADMOB_INTEGRATION_GUIDE.md
│   ├── AUTO_SHUFFLE_FEATURE.md
│   ├── IMPLEMENTATION_SUMMARY.md
│   ├── LEVEL_COMPLETION_FEATURE.md
│   ├── LEVELS_README.md
│   └── THEME_SYSTEM_README.md
├── levels/              # Level configuration JSON files
├── scenes/              # Godot scene files
├── scripts/             # GDScript game logic
│   ├── AdMobManager.gd  # AdMob integration
│   ├── GameBoard.gd     # Main game board
│   ├── GameManager.gd   # Game state management
│   ├── LevelManager.gd  # Level loading
│   └── RewardManager.gd # Reward system
├── textures/            # Game assets
│   ├── modern/          # Modern theme tiles
│   └── legacy/          # Legacy theme tiles
└── project.godot        # Godot project file
```

## Key Scripts

### Game Management
- `GameManager.gd` - Main game state, level loading
- `GameBoard.gd` - Board logic, tile matching
- `LevelManager.gd` - Level configuration loading

### Reward System
- `RewardManager.gd` - Lives, coins, gems management
- `AdMobManager.gd` - Ad integration (test mode + real ads)
- `OutOfLivesDialog.gd` - UI for life refills

### UI
- `GameUI.gd` - HUD, score, moves counter
- `MainMenu.gd` - Main menu screen
- `LevelProgress.gd` - Level selection

## Configuration Files

### export_presets.cfg
Android export configuration, permissions, plugin settings

### project.godot
Godot project settings, autoload singletons

### android/build/build.gradle
Android dependencies including AdMob SDK

### android/build/AndroidManifest.xml
Android app configuration, plugin registration

## Level Creation

Levels are JSON files in `levels/` directory:

```json
{
  "level": 1,
  "rows": 8,
  "cols": 7,
  "moves": 20,
  "target_score": 1000,
  "layout": [
    "1111111",
    "1111111",
    ...
  ],
  "theme": "modern"
}
```

Layout values:
- `1` = Playable tile
- `X` = Hole (no tile)

## Testing

### Desktop Testing
- Run project in Godot Editor (F5)
- Test mode ads work with 2-second delay
- All gameplay features functional

### Android Testing
1. Build APK: `./build-android.sh`
2. Install: `./install-apk.sh`
3. Check logs: `adb logcat -s "godot:I"`
4. Test all features on device

## Troubleshooting

### Build Fails
- Check Godot export templates installed
- Verify Android SDK path configured
- Review build errors in terminal

### Plugin Not Loading
- Check AndroidManifest.xml has plugin registration
- Verify DroidAdMob.java compiles without errors
- Look for plugin initialization in logs

### Ads Not Working
- Verify test mode fallback works (2-second delay)
- Check device logs for "DroidAdMob" messages
- Ensure Internet permission enabled
- See [AdMob Integration Guide](docs/ADMOB_INTEGRATION_GUIDE.md)

## Documentation

- [AdMob Integration](docs/ADMOB_INTEGRATION_GUIDE.md) - Complete AdMob setup guide
- [Theme System](docs/THEME_SYSTEM_README.md) - Visual theme implementation
- [Level System](docs/LEVELS_README.md) - Level configuration guide
- [Features](docs/IMPLEMENTATION_SUMMARY.md) - Complete feature list

## Useful Commands

```bash
# Check device connection
adb devices

# Clear app data
adb shell pm clear com.yourstudio.match3game

# Uninstall app
adb uninstall com.yourstudio.match3game

# Pull logs to file
adb logcat -d > logs/debug.log

# Check APK info
aapt dump badging builds/match3-game-debug.apk
```

## Version Info

- **Godot:** 4.5
- **Android SDK:** API 24-34
- **AdMob SDK:** 23.3.0
- **Game Version:** 1.0

---

*For detailed information, see individual documentation files in the `docs/` directory.*

