# Changelog

All notable changes to the Match-3 Game project.

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

