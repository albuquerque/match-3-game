# Match-3 Game

A polished match-3 puzzle game built with Godot 4.5, featuring progressive difficulty levels, reward systems, and AdMob monetization.

## Features

### Core Gameplay
- **10 Progressive Levels** with unique board layouts and challenges
- **Match-3 Mechanics** with intuitive swipe controls
- **Power-Up Tiles** - Horizontal/vertical clearers and bombs
- **9 Unique Boosters** - Hammer, Shuffle, Swap, Chain Reaction, Bomb 3×3, Line Blast, Tile Squasher, Row Clear, Column Clear
- **Auto-Shuffle** when no valid moves remain
- **Move-Based Scoring** with level targets

### Progression System
- **Lives System** - 5 lives with 30-minute regeneration
- **Coins & Gems** earned through gameplay
- **Level Unlocking** - sequential progression through levels
- **Reward System** - Daily bonuses and achievements

### Monetization
- **Rewarded Video Ads** - Watch ads to restore lives
- **AdMob Integration** - Production-ready with custom plugin
- **Test Mode** - Desktop simulation for development

### Customization
- **Theme System** - Multiple visual styles
- **Configurable Levels** - JSON-based level definitions
- **Responsive Design** - Adapts to different screen sizes

## Getting Started

### Prerequisites
- Godot 4.5 or later
- Android SDK (for Android builds)
- Java OpenJDK 21 (for plugin compilation)

### Building for Android

1. **Install dependencies**:
   ```bash
   # Ensure Android SDK is installed
   export ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools
   ```

2. **Build the APK**:
   ```bash
   ./build-android.sh
   ```

3. **Install on device**:
   ```bash
   ./install-apk.sh
   # or manually:
   adb install -r builds/match3-game-debug.apk
   ```

### Development

- **Godot Project**: Open `project.godot` in Godot Editor
- **Main Scene**: `scenes/MainMenu.tscn`
- **Game Scene**: `scenes/MainGame.tscn`
- **Levels**: Edit JSON files in `levels/` directory

## Project Structure

```
match-3-game/
├── addons/
│   └── droid_admob/            # Custom DroidAdMob plugin
│       ├── admob.gd            # GDScript wrapper
│       ├── export_plugin.gd    # Export configuration
│       └── bin/                # Compiled plugin (AAR)
├── scenes/
│   ├── MainMenu.tscn           # Main menu
│   ├── MainGame.tscn           # Game board
│   └── Tile.tscn              # Tile prefab
├── scripts/
│   ├── GameManager.gd          # Core game logic
│   ├── GameBoard.gd            # Board management
│   ├── AdMobManager.gd         # Ad integration
│   └── RewardManager.gd        # Reward system
├── levels/
│   ├── level_01.json           # Level definitions
│   └── ...
├── textures/
│   ├── modern/                 # Modern theme tiles
│   └── legacy/                 # Legacy theme tiles
└── docs/                       # Documentation
```

## AdMob Integration

This game uses a **custom Java-based DroidAdMob plugin** for Godot 4.5 with full GDPR compliance.

### Key Components
- **Java Plugin**: Compiled AAR in `addons/droid_admob/bin/`
- **GDScript Wrapper**: `admob.gd` provides clean API
- **Manager**: `AdMobManager.gd` handles ad loading/showing
- **GDPR Support**: User Messaging Platform (UMP) SDK for EU/EEA consent

### Features
✅ Rewarded video ads for life refills  
✅ Test mode for development  
✅ GDPR/Privacy consent management  
✅ EU/EEA compliance ready  

### Using Test Ads

The game is configured with Google's test ad units:
```gdscript
# Rewarded Video (currently used)
"ca-app-pub-3940256099942544/5224354917"
```

### Production Setup

Before publishing:

1. **Replace test ad units** with your real AdMob IDs in `AdMobManager.gd`
2. **Implement consent flow** (see `docs/GDPR_CONSENT_GUIDE.md`)
3. **Set test mode to false**:
   ```gdscript
   admob.initialize(false)  # Use real ads
   admob.request_consent_info_update(false, "")  # Production consent
   ```

### Documentation
- **Complete Documentation**: [docs/README.md](docs/README.md) - Documentation index
- **Features Overview**: [docs/FEATURES.md](docs/FEATURES.md) - All game features
- **AdMob Integration**: [docs/SUCCESS_REPORT.md](docs/SUCCESS_REPORT.md) - Plugin success story
- **GDPR Compliance**: [docs/GDPR_CONSENT_GUIDE.md](docs/GDPR_CONSENT_GUIDE.md) - Privacy implementation

## Level Configuration

Levels are defined in JSON format in the `levels/` directory:

```json
{
  "level_number": 1,
  "title": "Welcome!",
  "description": "Match 3 tiles to score points.",
  "grid_width": 8,
  "grid_height": 8,
  "target_score": 1000,
  "max_moves": 20,
  "num_tile_types": 6,
  "layout": "XXXXXXXX..."
}
```

Layout codes:
- `X` = Playable tile
- `.` = Hole/blocked space

## Game Systems

### Lives System
- **Maximum**: 5 lives
- **Regeneration**: 1 life per 30 minutes
- **Restore Options**:
  - Wait for regeneration
  - Watch rewarded video ad (+1 life)

### Reward System
- **Coins**: Earned from completing levels
- **Gems**: Premium currency for special purchases
- **Daily Bonuses**: Login rewards (coming soon)
- **Achievements**: Milestone rewards (coming soon)

### Theme System
- **Modern**: Clean, vibrant tile designs
- **Legacy**: Classic match-3 aesthetic
- Switchable in settings menu
## 📚 Documentation

For complete documentation, see the [docs/](docs/) directory:

### Core Documentation
- **[Documentation Index](docs/README.md)** - Complete documentation overview
- **[Features](docs/FEATURES.md)** - All implemented game features
- **[Development Guide](docs/DEVELOPMENT_GUIDE.md)** - Build and deployment instructions

### Game Systems
- **[Boosters Implementation](docs/BOOSTERS_IMPLEMENTATION.md)** - Complete booster system guide
- **[Level System](docs/LEVELS_README.md)** - Level configuration guide
- **[Reward System](docs/REWARD_SYSTEM_README.md)** - Lives, coins, and rewards
- **[Theme System](docs/THEME_SYSTEM_README.md)** - Visual themes

### Integration & Technical
- **[AdMob Guide](docs/ADMOB_GUIDE.md)** - Plugin usage, API, and GDPR compliance
- **[Build Fixes](docs/ANDROID_BUILD_FIXES.md)** - Android build troubleshooting
- **[Error Fixes](docs/ARRAY_ACCESS_FIX.md)** - Common error resolutions

## 🎮 Quick Start

1. Open project in Godot 4.5+
2. Press F5 to run in editor (desktop test mode)
3. Build for Android: `./build-android.sh`
4. Install on device: `./install-apk.sh`
- [docs/LEVELS_README.md](docs/LEVELS_README.md) - Level design guide

## Technical Details

### Engine
- **Godot**: 4.5.stable
- **Language**: GDScript
- **Platform**: Android (iOS-ready)

### Dependencies
- **Google Mobile Ads SDK**: 22.6.0
- **Java**: OpenJDK 21
- **Gradle**: 8.11.1 (via wrapper)

### Build Tools
- `build-android.sh` - Build Android APK
- `install-apk.sh` - Install on connected device

## License

[Add your license here]

## Credits

- Game Engine: [Godot Engine](https://godotengine.org)
- Ad Integration: Google AdMob
- Development: [Your Name/Studio]

---

**Version**: 1.0  
**Status**: Production Ready  
**Last Updated**: December 2024

