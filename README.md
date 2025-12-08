# Match-3 Game

A feature-rich match-3 puzzle game built with Godot 4.5, featuring dynamic level layouts, special tiles, combo mechanics, and a flexible theme system.

## 🎮 Features

### Core Gameplay
- **Classic Match-3 Mechanics** - Match 3 or more tiles horizontally or vertically to clear them
- **Swipe Controls** - Intuitive touch and mouse controls for swapping tiles
- **Gravity Physics** - Tiles fall naturally when matches are cleared
- **Combo System** - Chain matches for higher scores and multipliers
- **Move-Based Challenges** - Complete levels within a limited number of moves

### Level System
- **10+ Unique Levels** - Each with custom layouts and increasing difficulty
- **Dynamic Layouts** - Blocked cells, holes, and special patterns (corners, crosses, diamonds, hourglasses, etc.)
- **Progressive Difficulty** - Target scores and move limits increase with each level
- **Level Selection** - Progress through levels with persistent progress tracking

### Special Tiles
- **Power-Ups** - Special tiles with unique clearing abilities:
  - Horizontal Arrow (Tile 7) - Clears entire row
  - Vertical Arrow (Tile 8) - Clears entire column
  - Bomb (Tile 9) - Clears 3x3 area around it
- **Auto-Generation** - Power-ups spawn randomly during gameplay

### Visual Features
- **Theme System** - Multiple visual themes for different levels
  - Legacy theme - Classic colorful tiles
  - Modern theme - High-resolution 1024x1024 artwork
- **Smooth Animations** - Tile swapping, falling, matching, and destruction effects
- **Responsive UI** - Adaptive board sizing for different screen resolutions
- **Visual Feedback** - Hover effects, selection rings, and match highlights

### Progression & Rewards
- **Currency System** - Earn coins and gems from gameplay
- **Star Ratings** - 1-3 stars per level based on performance
- **Daily Login Rewards** - Consecutive login bonuses
- **Lives System** - 5 lives with 30-minute regeneration
- **Booster Inventory** - Collect and manage power-up boosters
- **Persistent Progress** - All progress automatically saved

### Technical Features
- **JSON-Based Level Configuration** - Easy level creation and modification
- **Modular Architecture** - Separate managers for game logic, levels, and themes
- **Mobile-Ready** - Touch controls and portrait orientation support
- **Android Export** - Build scripts and configurations for Android deployment

## 🏗️ Project Structure

```
match-3-game/
├── scripts/
│   ├── GameManager.gd          # Core game logic and state management
│   ├── LevelManager.gd         # Level loading and progression
│   ├── ThemeManager.gd         # Visual theme management
│   ├── RewardManager.gd        # Currency, progression & rewards system
│   ├── GameBoard.gd            # Board rendering and tile management
│   ├── GameUI.gd               # UI elements and HUD
│   ├── Tile.gd                 # Individual tile behavior
│   └── ...
├── scenes/
│   ├── MainGame.tscn           # Main game scene
│   ├── MainMenu.tscn           # Menu scene
│   ├── Tile.tscn               # Tile node template
│   └── ...
├── levels/
│   ├── level_01.json           # Level 1 configuration
│   ├── level_02.json           # Level 2 configuration
│   └── ...                     # Up to level_10.json
├── textures/
│   ├── modern/                 # Modern theme tiles (1024x1024)
│   ├── legacy/                 # Legacy theme tiles
│   └── ...
├── android/                    # Android build configuration
└── builds/                     # Export outputs
```

## 🎯 Level Format

Levels are defined in JSON files with the following structure:

```json
{
  "level": 1,
  "width": 8,
  "height": 8,
  "target_score": 5000,
  "moves": 30,
  "description": "Welcome! Match 3 tiles to score points.",
  "theme": "legacy",
  "layout": "0 0 0 0 0 0 0 0\n0 0 0 0 0 0 0 0\n..."
}
```

**Layout Symbols:**
- `0` - Empty cell (filled with random tiles)
- `X` - Blocked cell (hole in the board)
- `1-6` - Specific tile types
- `7-9` - Special power-up tiles

## 🎨 Theme System

The game supports multiple visual themes that can be assigned per level:

- **Legacy Theme** - Original colorful tiles
- **Modern Theme** - High-resolution artistic tiles

Themes can be easily extended by:
1. Creating a new texture folder in `textures/`
2. Adding the theme to `ThemeManager.gd`
3. Setting the `"theme"` field in level JSON files

See `THEME_SYSTEM_README.md` for detailed documentation.

## 🚀 Getting Started

### Prerequisites
- Godot Engine 4.5 or later
- (Optional) Android SDK for mobile builds

### Running the Game
1. Open the project in Godot Editor
2. Press F5 or click "Play" to run
3. The game starts at the main menu

### Building for Android
```bash
./build-android.sh
```

The APK will be generated in `builds/match3-game-debug.apk`

## 🛠️ Development

### Adding New Levels
1. Create a new JSON file in `levels/` (e.g., `level_11.json`)
2. Follow the level format structure
3. The level will automatically be loaded by `LevelManager`

### Creating Custom Themes
1. Create a folder in `textures/` with your theme name
2. Add tiles named `tile_1.png` through `tile_11.png`
3. Update `ThemeManager.gd` to register the new theme

### Modifying Game Logic
- **Scoring** - Edit `GameManager.gd` scoring functions
- **Match Detection** - Modify `GameBoard.gd` match-finding algorithms
- **Special Tile Behavior** - Update `GameBoard.gd` special tile activation

## 📱 Platform Support

- **Desktop** - Windows, macOS, Linux
- **Mobile** - Android (with touch controls)
- **Portrait Orientation** - Optimized for mobile devices (720x1280)

## 📄 Additional Documentation

- `REWARD_SYSTEM_README.md` - Currency, progression & rewards system
- `THEME_SYSTEM_README.md` - Detailed theme system documentation
- `LEVEL_COMPLETION_FEATURE.md` - Level completion and progression features
- `AUTO_SHUFFLE_FEATURE.md` - Auto-shuffle system documentation
- `IMPLEMENTATION_SUMMARY.md` - Technical implementation details

## 🎮 Controls

**Desktop:**
- Click and drag to swap tiles
- Click on special tiles to activate them

**Mobile:**
- Swipe to swap tiles
- Tap on special tiles to activate them

## 🏆 Scoring System

- **Basic Match (3 tiles)** - 100 points × tile type
- **Extended Match (4+ tiles)** - Bonus multiplier
- **Combo Matches** - Cascading matches increase combo multiplier
- **Special Tiles** - Bonus points for clearing multiple tiles

### Level Rewards
- **Coins** - Base reward: 100 + (50 × level number)
- **Star Ratings** - 1-3 stars based on score performance:
  - ⭐ 1 star: 100%-149% of target
  - ⭐⭐ 2 stars: 150%-199% of target
  - ⭐⭐⭐ 3 stars: 200%+ of target
- **Bonus Gems** - 5 gems for first 3-star completion per level

## 📝 License

[Add your license information here]

## 👥 Credits

[Sam Albuquerque]
---

**Version:** 1.0  
**Engine:** Godot 4.5  
**Last Updated:** December 2024

