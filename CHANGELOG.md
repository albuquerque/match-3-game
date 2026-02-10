# Changelog

All notable changes to the Match-3 Game project.

## [Unreleased] - February 10, 2026

### Added - Phase 12 Complete ✅

#### Experience Director System
- **Complete Biblical Narrative Progression** - 62 levels from Genesis through Exodus
  - `ExperienceDirector.gd` - Main flow controller with state management
  - `ExperienceState.gd` - Persistent state tracking and save integration
  - `ExperienceFlowParser.gd` - JSON flow parsing and validation
  - `RewardOrchestrator.gd` - Centralized reward timing and distribution
  - `CollectionManager.gd` - Collectible cards system
  - Main story flow: `data/experience_flows/main_story.json`
  - 62 narrative stages: `data/narrative_stages/*.json`
  - Automatic migration of existing player saves
  - Seamless integration with existing game systems

#### Haptic Vibration System (Mobile)
- **VibrationManager** - Complete mobile vibration feedback system
  - Global autoload singleton with platform detection
  - Multiple vibration patterns (light, medium, heavy, double, triple)
  - User-configurable toggle in Settings dialog (📳 Vibration: On/Off)
  - Persistent preference storage
  - Android/iOS platform detection
  - Integrated with screen shake effects
  - Integrated with lightning/flash effects
  - Android VIBRATE permission added to manifest
  - Verified working on Android devices

#### Settings Enhancements
- Vibration toggle with haptic feedback when enabling
- Dynamic UI creation for mobile-specific settings
- Persistent user preferences across restarts

### Fixed - Critical Bugs ✅

#### Dynamic Button Signal Workaround
- **Godot 4.5 Button Bug Fix** - Manual click detection for all dynamic buttons
  - Booster buttons now 100% reliable (GameUI)
  - Continue button fixed (LevelTransition)
  - Multiplier tap button fixed (LevelTransition)
  - Implemented `_input()` handler pattern for rect-based click detection
  - Bypasses broken `pressed` signal emission in Godot 4.5

#### UI/UX Improvements
- **Clean Level Transitions** - Eliminated UI artifacts during level transitions
  - Hide gameplay UI (HUD, booster bar) on level complete
  - Show gameplay UI when level ready
  - Hide board group and overlay during transitions
  - Professional, polished transition experience

#### Gameplay Fixes
- **Swap Booster Collectibles** - Collectibles now properly collected when swapped to bottom row
- **Ghost Button Fix** - Old buttons immediately removed to prevent click interception
- **Platform Detection** - Fixed mobile detection (android/ios instead of "mobile")

### Changed

#### Android Configuration
- Added VIBRATE permission to AndroidManifest.xml
- Platform detection updated for Godot 4.5 compatibility

#### Code Quality
- Enhanced debug logging throughout for troubleshooting
- Proper error handling in all new systems
- Platform-aware implementations (auto-disable on desktop)
- Comprehensive documentation

### Documentation
- `docs/VIBRATION_SYSTEM.md` - Complete vibration system guide
- `docs/COMPLETE_SESSION_SUMMARY_FEB_10.md` - Phase 12 session summary

---

## [Previous] - February 2026

### Added
- **Phase 12.1: ExperienceDirector Production Integration** ✅
  - Replaced hardcoded level progression with ExperienceDirector routing
  - Auto-loads main_story flow when completing levels
  - Maintains backward compatibility with fallback mechanism
  - All "Continue" button presses now route through ExperienceDirector
  - Documentation: `docs/PHASE_12_1_IMPLEMENTATION.md`
  - Testing guide: `docs/PHASE_12_1_TESTING_GUIDE.md`

- **Narrative Effects System** - Complete implementation for local and DLC levels
  - 14 effect executors (background_dim, vignette, screen_flash, camera_impulse, shader_param_lerp, play_animation, timeline_sequence, state_swap, screen_overlay, narrative_dialogue, spawn_particles, foreground_dim, background_tint, progressive_brightness)
  - Screen overlay with texture and tint support
  - Narrative dialogue system with title/message parameters
  - Timeline sequence for multi-step chained effects
  - State swap for visibility/position swapping
  - All effects working on both local and DLC levels
  - Demo levels (1-6, 31) showcasing various effects

- **Sample Overlay Textures** - 3 SVG textures for screen overlays
  - `overlay_vignette.svg` - Dark edges effect
  - `overlay_victory_rays.svg` - Radiating golden light
  - `overlay_sparkles.svg` - Scattered stars celebration

- **Spreader Tiles System** - Special mechanic tiles
  - Configurable grace moves before spreading (1-2 moves)
  - Controlled spread rate (1 tile per turn or all adjacent)
  - Track spreader count for level completion goals
  - Spreader-specific narrative effects integration
  - Level 31 demo implementation

- **HUD Enhancements**
  - Rounded translucent background panel for HUD elements
  - Registered as VisualAnchor "hud" for narrative effects targeting
  - Professional polished appearance with subtle borders

### Fixed
- **Godot 4.5 Compatibility** - All narrative effects updated for Godot 4 APIs
  - `Animation.loop_mode = Animation.LOOP_NONE` instead of `loop = false`
  - `AnimationLibrary + add_animation_library()` instead of `add_animation()`
  - Shader loading via `FileAccess` + `Shader.new().code` pattern
  - SVG texture loading via `FileAccess.file_exists()` + `load()`
  - Removed all deprecated `find_node()` calls
  - Safe tree access patterns via viewport
  - Lambda callbacks in timeline_sequence instead of unsafe await

- **State Management Between Levels**
  - HUD visibility automatically restored on every level load
  - GameBoard position reset to (0,0) on level transitions
  - Visual overlays properly cleaned up between levels
  - No state leakage from previous levels

- **Level Transition Screen** - Visibility timing issues
  - Transition screen appears immediately on level complete
  - Fixed `await` blocking visibility change
  - Proper effect cleanup before transition

- **Particle System** - Coordinate system and positioning
  - Particles spawn at correct tile world positions
  - Fixed top-left corner spawning bug
  - Proper tile-to-world coordinate conversion

- **Gravity System** - Tile refill and animation
  - Tiles animate smoothly when dropping after matches
  - No flying upward tiles
  - Proper cascade refill behavior
  - Fixed empty gaps on board

- **Unmovable Tiles** - Consolidated implementation
  - Removed UNMOVABLE_SOFT (use UNMOVABLE_HARD with H1 notation)
  - All level files updated to H1/H2/H3 notation
  - Fixed destruction counting and tracking
  - Proper adjacent match detection and clearing

- **Lightning Special Tiles** - Immediate tile destruction
  - Tiles destroyed instantly as lightning beam passes
  - Cascading lightning activation works correctly
  - No delayed destruction animations

- **Bonus Moves Counter** - Negative value prevention
  - Counter stops at 0 instead of going negative
  - Proper move counting during special tile chains
  - Accurate move display during bonus cascade

- **Narrative Dialogue** - Parameter support
  - Supports both `title`/`message` AND `character`/`text` parameters
  - Backward compatible with both naming conventions
  - Messages display correctly in dialog boxes

- **Screen Overlay** - Tint persistence bug
  - Fixed tint overlays staying on screen permanently
  - Proper fade-in → hold → fade-out → cleanup sequence
  - ColorRect correctly animated and removed

### Changed
- **Documentation Structure** - Reorganized per coding guidelines
  - All documentation moved to `docs/` directory
  - Only `README.md` and `CHANGELOG.md` remain in root
  - Created `docs/archive/fixes_2026_02_01/` for Feb 1 fixes
  - Created `docs/archive/fixes_2026_02_02/` for Feb 2 fixes
  - Updated `DOCUMENTATION_INDEX.md` with current structure
  - Consolidated 20 individual fix docs into comprehensive guides

- **Level Configuration Files** - Updated formats
  - Levels 1-6 configured with narrative effect demos
  - Level 31 showcases spreader mechanics
  - All levels use H1/H2/H3 notation for unmovables
  - Removed legacy "U" notation for soft unmovables

- **Effect Naming** - Standardized across system
  - `narrative_dialogue` (not `narrative_dialog`)
  - Consistent parameter names throughout
  - Clear documentation of supported parameters

### Documentation
- ✅ `COMPLETE_TESTING_SUMMARY.md` - Comprehensive testing status
- ✅ `NARRATIVE_EFFECTS_COMPLETE_SUMMARY.md` - System implementation guide
- ✅ `NARRATIVE_SYSTEM_COMPLETE.md` - Technical reference
- ✅ `BUILTIN_NARRATIVE_QUICKSTART.md` - Quick tutorial
- ✅ `SPREADER_TILES.md` - Spreader implementation guide
- ✅ `CLEANUP_SUMMARY_2026_02_02.md` - Documentation cleanup summary
- ✅ All fix documents archived with explanatory READMEs

## [1.0.0] - 2024-12-11

### Added - AdMob Integration
- ✅ Custom Java-based AdMob plugin for Godot 4.5
- ✅ GDScript wrapper class for clean API (`admob.gd`)
- ✅ Rewarded video ads to restore lives
- ✅ AdMobManager for centralized ad handling
- ✅ Test mode simulation for desktop development
- ✅ Production-ready with Google test ad units

### Added - Lives System
- ✅ 5 lives maximum
- ✅ 30-minute regeneration timer per life
- ✅ Out-of-lives dialog with "Watch Ad" option
- ✅ Lives display in UI
- ✅ Persistent lives across sessions

### Added - Reward System
- ✅ Coins earned from level completion
- ✅ Gems as premium currency
- ✅ RewardManager for centralized reward handling
- ✅ Persistent save/load system
- ✅ Daily streak tracking (framework)

### Added - Game Features
- ✅ 10 unique levels with progressive difficulty
- ✅ Custom board layouts (holes, blocked cells)
- ✅ Power-up tiles (horizontal/vertical clearers, bombs)
- ✅ Auto-shuffle when no moves available
- ✅ Move-based scoring system
- ✅ Level completion detection
- ✅ Theme system (Modern/Legacy)

### Technical Improvements
- ✅ Godot 4.5 v2 plugin architecture (EditorExportPlugin)
- ✅ Java-based plugin (better compatibility than Kotlin)
- ✅ Wrapper class pattern for JNI method calls
- ✅ Cleaned caching system for reliable builds
- ✅ Proper signal handling between plugin and game

### Build System
- ✅ `build-android.sh` - Automated Android APK build
- ✅ `install-apk.sh` - Device installation script
- ✅ Gradle integration for plugin compilation
- ✅ Android SDK configuration

### Documentation
- ✅ Comprehensive README
- ✅ SUCCESS_REPORT.md - Complete integration journey
- ✅ WRAPPER_CLASS_SOLUTION.md - Plugin architecture guide
- ✅ Level design documentation
- ✅ Reward system documentation
- ✅ Development guides

### Known Issues
- None critical - production ready

## [0.3.0] - Earlier Development

### Added
- Basic game mechanics
- Level system
- Tile matching logic
- UI framework

## [0.2.0] - Initial Development

### Added
- Project setup
- Core Godot structure
- Basic tile system

## [0.1.0] - Project Start

### Added
- Initial repository
- Godot project initialization

---

**Key Achievement**: Successfully integrated custom AdMob plugin after extensive debugging and architecture understanding. The game is now production-ready with working monetization.

