# Implementation TODO - GamePlayHUD.txt Specification

## Date: January 16, 2026 (Last Updated)

## Overview
This document outlines the implementation plan for all features and screens described in `docs/pseudodocs/GamePlayHUD.txt`. Items are categorized by priority and complexity.

## 🎉 Phase 1: COMPLETE! 🎉 (January 16, 2026)

### Completed in Phase 1:
1. ✅ **Star Rating System** - Full implementation with 1-3 star ratings
2. ✅ **Bonus Moves System** - "Sugar Crush" style conversion with progressive bonuses
3. ✅ **Skip Bonus Feature** - Tap to skip animation and instant calculation
4. ✅ **Level Completion Fixes** - Proper transition to reward screen
5. ✅ **Input Blocking** - Prevents continued gameplay after completion
6. ✅ **Enhanced Logging** - Comprehensive debug output
7. ✅ **Enhanced Level Complete Screen** - REPLAY button + performance summary
8. ✅ **Enhanced Level Failed Screen** - Encouraging messages + retry/give up options
9. ✅ **Combo Text Enhancement** - Bangers font + glow effects + pulsing animations
10. ✅ **Bangers Font System** - ThemeManager helpers for consistent typography

### Phase 1 Status: ✅ 100% COMPLETE!
- [x] Star Rating System ✅
- [x] Bonus Moves System ✅
- [x] Skip Bonus Animation ✅
- [x] Enhanced Level Complete Screen ✅
- [x] Enhanced Level Failed Screen ✅
- [x] Visual Polish (Combo Text + Fonts) ✅

**Total Time:** ~15 hours (estimated: 12-17 hours)
**Status:** Production Ready!

---

## 🎨 Phase 1.5: UI POLISH (IN PROGRESS) - 40% Complete

### Recently Completed:
1. ✅ **Combo Text Enhancement**
   - Bangers font applied to combo messages
   - Enhanced glow effects (20px shadow outline)
   - Pulsing animations with rotation and bounce
   - 4-phase animation (pop, settle, pulse, float)

2. ✅ **Font System**
   - ThemeManager.get_bangers_font() - Cached font loading
   - ThemeManager.apply_bangers_font() - One-line label styling
   - ThemeManager.apply_bangers_font_to_button() - Button styling
   - Applied to LevelTransition screen (all elements)

### In Progress:
- [ ] **Apply Bangers Font to All UI** (40% complete)
  - [x] LevelTransition.gd - ✅ Complete
  - [x] GameBoard.gd (combo text) - ✅ Complete
  - [ ] StartPage.gd - Pending (5 labels/buttons)
  - [ ] AchievementsPage.gd - Pending (11 labels)
  - [ ] ShopUI.gd - Pending (2 labels)
  - [ ] GameUI.gd (HUD) - Pending (multiple elements)
  - [ ] SettingsDialog.gd - Pending

**Files to Complete:**
- See `docs/BANGERS_FONT_APPLICATION_GUIDE.md` for detailed instructions

**Estimated Time Remaining:** 30-45 minutes
**Benefits:** Consistent bold visual style across entire game

---

## CURRENTLY IMPLEMENTED ✅

### Screens
- ✅ Main Menu (Start Page)
- ✅ Gameplay HUD (partially - basic version)
- ✅ Level Complete Screen (LevelTransition)
- ✅ Level Failed Screen (GameOver)
- ✅ Gallery Hub (basic artwork viewing)
- ✅ Achievements Screen (basic badges)
- ✅ Shop Screen (basic)
- ✅ Settings Screen (basic)

### Features
- ✅ Coins & Gems currency system
- ✅ Score tracking
- ✅ Moves counter
- ✅ Basic boosters (Hammer, Swap, etc.)
- ✅ Level progression
- ✅ Image gallery with unlocking
- ✅ Basic achievements tracking
- ✅ Audio settings (music/sfx toggle)

---

## HIGH PRIORITY - CORE GAMEPLAY 🔴

### 1. Enhanced Booster Panel ✅ COMPLETE
**Current Status:** Fully implemented and tested

**Completed:**
- [x] Implement random booster selection (3-5 boosters per level)
- [x] Add visual background panel with rounded corners and styling
- [x] Improve spacing between booster icons (16px)
- [x] Add better visual feedback (grey out when count = 0)
- [x] Show booster count badges prominently (top-right corner with Bangers font)
- [x] Give starter boosters to new players (12 total)
- [x] Dynamic panel creation based on selected boosters
- [x] Proper timing (boosters selected before level_loaded signal)

**Features Delivered:**
- Random 3-5 boosters per level (seeded by level number for consistency)
- Weighted tier system: Common (60%), Uncommon (30%), Rare (10%)
- Styled panel with rounded background, gradient, and border
- 64x64 icons in 80x80 buttons with proper spacing
- Bangers font count badges
- Starter inventory: 3 hammers, 2 shuffles, 2 swaps, 2 extra moves, 1 of each uncommon

**Design Notes:**
- Current position kept (combo/feedback system works well)
- Panel auto-populates on level load
- Fallback to legacy display if needed
- Fully responsive and visually polished

**Design Notes:**
- Keep current position (combo/feedback system is good as-is)
- Each level randomly selects 3-5 boosters from available pool
- Selection can be weighted (common vs rare boosters)
- Panel should have rounded corners, subtle gradient background
- Icons should be larger and more spaced out

**Files to Modify:**
- `scripts/GameUI.gd` - Random booster selection logic, visual improvements
- `scripts/LevelManager.gd` - Define booster selection per level
- `scripts/GameManager.gd` - Pass selected boosters to UI

**Estimated Time:** 2-3 hours
**Priority:** Medium-High (visual polish + gameplay variety)

---

### 2. Star Rating System ⭐⭐⭐
**Current Status:** ✅ IMPLEMENTED

**Completed:**
- [x] **Backend:** Add star calculation logic
  - 1 star: Complete level
  - 2 stars: Exceed target by 50%
  - 3 stars: Exceed target by 100% or use < 50% moves
- [x] **Storage:** Save star count per level in player_progress.json
- [x] **Display:** Show stars on Level Complete screen
- [x] **UI:** Animated star display with gold/grey colors

**New Files Created:**
- ✅ `scripts/StarRatingManager.gd` - Calculate and track stars

**Files Modified:**
- ✅ `scripts/GameManager.gd` - Calculate star rating on level complete
- ✅ `scripts/LevelTransition.gd` - Display star rating with animations
- ✅ `scripts/GameUI.gd` - Pass stars to transition screen
- ✅ `project.godot` - Added StarRatingManager autoload

**Notes:**
- Star rating is calculated based on score AND move efficiency
- Best star rating is saved per level
- Total stars tracked for future chapter unlocking
- Animated star reveal (⭐ for earned, ☆ for unearned)

**Estimated Time:** 3-4 hours
**Actual Time:** 3 hours
**Status:** ✅ COMPLETE

---

### 3. Enhanced Level Complete Screen ✅ COMPLETE
**Current Status:** Fully enhanced, polished, and production-ready

**Completed:**
- [x] Display 1-3 stars based on performance (with animations)
- [x] Show rewards breakdown (coins, gems with icons)
- [x] Add "REPLAY" button alongside "NEXT"
- [x] Improve visual presentation with animations
- [x] Add title pulsing animation
- [x] Bangers font throughout
- [x] Multiplier challenge mini-game
- [x] Performance summary display

**Features:**
- Pulsing title animation for extra impact
- Staggered star reveal with scale animations
- Clear rewards display with currency icons
- Smooth transitions and professional polish
- All text uses Bangers font for consistency

**Status:** Production ready! 🎉

---

### 4. Enhanced Level Failed Screen ✅ COMPLETE & OLD PANEL REMOVED
**Current Status:** Fully enhanced, polished, old panel removed, production-ready

**Completed:**
- [x] Better messaging based on performance (4 tiers)
- [x] Show score achieved vs target
- [x] Add "GIVE UP" option to quit level
- [x] Improve visual design with styled progress bar
- [x] Bangers font throughout
- [x] Color-coded feedback
- [x] Larger, clearer buttons
- [x] Fix game_over signal emission (critical bug fix)
- [x] Remove old GameOverPanel from scene
- [x] Clean up all old panel references

**Critical Fix:**
- GameManager now emits `game_over` signal (was changing scenes instead)
- Enhanced screen now shows correctly when level fails

**Features:**
- **Performance-based messages:**
  - 90%+: "So Close! You almost had it! 🎯"
  - 75%+: "Great effort! One more try! 💪"
  - 50%+: "You're getting there! Keep going! ⭐"
  - <50%: "Don't give up! You can do it! 🚀"
- Styled progress bar with rounded corners (500x40px)
- Large, clear buttons (220x90px)
- Title with outline for depth
- Color psychology (green for retry, red for quit)
- Old panel completely removed from project

**Documentation:**
- `docs/OLD_PANEL_REMOVAL.md` - Panel cleanup
- `docs/ENHANCED_LEVEL_SCREENS.md` - Overall enhancements

**Status:** Production ready! 🎉

---

## MEDIUM PRIORITY - PROGRESSION SYSTEMS 🟡

### 5. World Map / Level Select ✅ COMPLETE
**Current Status:** ✅ IMPLEMENTED & PRODUCTION READY

**Completed Features:**
- [x] **Visual Map Screen:**
  - [x] Level nodes displayed on a zigzag path (1-2-3-4...)
  - [x] Show star count per level (0-3 stars with ⭐/☆ display)
  - [x] Lock/unlock levels based on progression
  - [x] Show current chapter (e.g., "Genesis - The Beginning")
- [x] **Biblical Chapter System:**
  - [x] Define 4 chapters (Genesis, Exodus, Psalms, Proverbs)
  - [x] Lock chapters until star requirement met (15, 40, 75 stars)
  - [x] Display: "Collect X Stars to unlock Chapter Y"
  - [x] Themed background colors per chapter
- [x] **Navigation:**
  - [x] Tap level node to select level for play
  - [x] Show level objectives before starting (via StartPage)
  - [x] Back button to return to main menu
  - [x] Map button added to StartPage navigation

**Implementation Highlights:**
- **4 Biblical Chapters** with progressive unlock requirements
- **Visual level progression** with zigzag path layout
- **Star-based unlocking** integrated with RewardManager
- **Responsive design** adapting to different screen sizes
- **Bangers font integration** for consistent typography
- **Full StartPage integration** with 🗺️ Map button

**New Files Created:**
- `scripts/WorldMap.gd` - Complete map screen logic (350+ lines)
- `scenes/WorldMap.tscn` - Scene file for world map
- `docs/WORLD_MAP_IMPLEMENTATION.md` - Comprehensive implementation guide

**Files Modified:**
- `scripts/StartPage.gd` - Added map button and signal
- `scripts/GameUI.gd` - Added map navigation handlers
- `scripts/LevelManager.gd` - Added get_current_level_data() method

**Estimated Time:** 8-10 hours
**Actual Time:** ~3 hours
**Status:** ✅ PRODUCTION READY

---

### 6. Puzzle Pieces System
**Current Status:** NOT IMPLEMENTED

**Required:**
- [ ] **Backend:**
  - [ ] Define puzzles (Noah's Ark, Creation, etc.)
  - [ ] Track pieces collected per puzzle
  - [ ] Save in player_progress.json
- [ ] **Collection:**
  - [ ] Award pieces on level complete (random chance)
  - [ ] Award pieces from chests (future)
  - [ ] Award pieces for achievements
- [ ] **Display:**
  - [ ] Puzzle screen showing grid layout
  - [ ] Grey out missing pieces
  - [ ] Show progress: "7/12 Pieces"
  - [ ] Unlock reward when puzzle complete
- [ ] **Integration:**
  - [ ] Mention in Level Complete rewards
  - [ ] Link from Gallery tab

**New Files:**
- `scripts/PuzzleManager.gd` - Puzzle tracking
- `scripts/PuzzleScreen.gd` - UI for puzzle view
- `scenes/PuzzleScreen.tscn` - Puzzle display

**Files to Modify:**
- `scripts/RewardManager.gd` - Add puzzle piece rewards
- `scripts/GalleryUI.gd` - Add Puzzle tab

**Estimated Time:** 6-8 hours

---

### 7. Story Cards Album
**Current Status:** NOT IMPLEMENTED

**Required:**
- [ ] **Card System:**
  - [ ] Define cards (Bible Heroes: Adam, Eve, Noah, Abraham, etc.)
  - [ ] Card data: Name, image, story text, unlock condition
  - [ ] Track collected cards
- [ ] **Unlocking:**
  - [ ] Unlock cards by completing chapters
  - [ ] Unlock cards from special achievements
  - [ ] Show unlock conditions for locked cards
- [ ] **Display:**
  - [ ] Scrollable card album
  - [ ] Tap card to view details (flip animation)
  - [ ] Show story/description on card back
- [ ] **Integration:**
  - [ ] Add "Cards" tab to Gallery

**New Files:**
- `scripts/CardManager.gd` - Card tracking
- `scripts/CardAlbum.gd` - Album UI
- `scenes/CardAlbum.tscn` - Card display
- `data/cards.json` - Card definitions

**Files to Modify:**
- `scripts/GalleryUI.gd` - Add Cards tab
- `scripts/RewardManager.gd` - Award cards

**Estimated Time:** 6-8 hours

---

### 8. Enhanced Badges & Achievements ✅ COMPLETE
**Current Status:** Fully implemented with comprehensive tracking and visual improvements

**Completed:**
- [x] Add more achievement types:
  - [x] Match-based: "Make 100/500/1000 matches"
  - [x] Level-based: "Complete 10/25/50 levels"
  - [x] Star-based: "Earn 10/25/50 stars"
  - [x] Special: "Use 5 different booster types", "Reach 10+ combo", "Get perfect streak", "Earn 100k score"
  - [x] Daily streak: Enhanced from 3/7/14/30 day milestones
- [x] Visual improvements:
  - [x] Progress bars for incomplete achievements (0/100, 25/50, etc.)
  - [x] Color-coded panels (green for complete, dark for incomplete)
  - [x] Category organization with headers
  - [x] Claim buttons with reward preview
- [x] Enhanced tracking system:
  - [x] Track total matches, boosters used, score earned, combo reached
  - [x] Progress saved in player_progress.json
  - [x] Real-time updates during gameplay
- [x] Reward system:
  - [x] Tiered rewards based on difficulty (100-1000 coins, 1-10 gems)
  - [x] Claim buttons for completed achievements
  - [x] Reward previews shown on each achievement

**Features Delivered:**
- **5 Achievement Categories:** Match Master, Level Progress, Star Collector, Daily Streak, Special Challenges
- **15 Total Achievements** with varying difficulties and rewards
- **Real-time Tracking:** Integrated into GameManager, RewardManager, and gameplay systems
- **Progress Bars:** Visual feedback showing current progress (e.g., "47/100 matches")
- **Professional UI:** Bangers font, color coding, organized categories
- **Reward System:** 50-1000 coins and 1-10 gems based on achievement difficulty
- **Persistent Storage:** All progress automatically saved and loaded

**Integration Points Added:**
- GameManager.remove_matches() → track_match_made(), track_tiles_cleared(), track_combo_reached()
- GameManager.on_level_complete() → track_level_completed()
- RewardManager.use_booster() → track_booster_used()
- Enhanced save/load system for all new tracking data

**New Tracking Variables:**
- total_matches, total_boosters_used, total_score_earned
- max_combo_reached, total_tiles_cleared, perfect_levels
- achievements_progress dictionary with 12 achievement types

**Files Modified:**
- `scripts/AchievementsPage.gd` - Complete UI overhaul with categories and progress bars
- `scripts/RewardManager.gd` - Added comprehensive tracking system (140+ lines)
- `scripts/GameManager.gd` - Added achievement tracking calls
- Enhanced save/load system with backward compatibility

**Status:** Production ready! 🎉

---

## MEDIUM PRIORITY - ENGAGEMENT SYSTEMS 🟡

### 9. Rewards Hub - Daily System
**Current Status:** NOT IMPLEMENTED

**Required:**
- [ ] **Daily Blessing:**
  - [ ] Daily login reward (coins/gems)
  - [ ] "Claim" button
  - [ ] Reset at midnight
- [ ] **Devotion Buffs:**
  - [ ] Active buffs display (e.g., "+3 Moves")
  - [ ] Buff duration tracking
  - [ ] Apply buffs to gameplay
- [ ] **Streak Meter:**
  - [ ] Track consecutive login days
  - [ ] Display: "Day 3/7"
  - [ ] Bonus reward at 7 days
- [ ] **UI:**
  - [ ] Rewards Hub screen with tabs
  - [ ] Daily tab as default

**New Files:**
- `scripts/DailyRewardManager.gd` - Daily rewards logic
- `scripts/RewardsHub.gd` - Hub UI
- `scenes/RewardsHub.tscn` - Rewards screen

**Estimated Time:** 6-7 hours

---

### 10. Rewards Hub - Missions System
**Current Status:** NOT IMPLEMENTED

**Required:**
- [ ] **Mission Types:**
  - [ ] Match X colored tiles
  - [ ] Beat X levels
  - [ ] Use X boosters
  - [ ] Achieve X stars
- [ ] **Tracking:**
  - [ ] Track progress for each mission
  - [ ] Save in player_progress.json
- [ ] **Rewards:**
  - [ ] Award coins, gems, puzzle pieces
  - [ ] Show reward preview
- [ ] **UI:**
  - [ ] Mission list with progress bars
  - [ ] "Claim" buttons for completed missions
  - [ ] Missions tab in Rewards Hub

**New Files:**
- `scripts/MissionManager.gd` - Mission tracking
- `data/missions.json` - Mission definitions

**Files to Modify:**
- `scripts/RewardsHub.gd` - Add Missions tab
- `scripts/GameManager.gd` - Track mission-relevant actions

**Estimated Time:** 8-10 hours

---

### 11. Rewards Hub - Chests System
**Current Status:** NOT IMPLEMENTED

**Required:**
- [ ] **Chest Types:**
  - [ ] Bronze, Silver, Gold chests
  - [ ] Different unlock times (instant, 3h, 19h)
  - [ ] Different reward tiers
- [ ] **Collection:**
  - [ ] Award chests for level completion
  - [ ] Award chests for missions
  - [ ] Max 4 chests at a time
- [ ] **Opening:**
  - [ ] Timer countdown
  - [ ] Option to unlock instantly with gems
  - [ ] Reveal animation
- [ ] **UI:**
  - [ ] Chests tab showing all chests
  - [ ] Timer displays
  - [ ] "Open" button when ready

**New Files:**
- `scripts/ChestManager.gd` - Chest logic
- `scripts/ChestOpenScreen.gd` - Opening UI
- `scenes/ChestOpenScreen.tscn`

**Files to Modify:**
- `scripts/RewardsHub.gd` - Add Chests tab

**Estimated Time:** 8-10 hours

---

### 12. Rewards Hub - Events System
**Current Status:** NOT IMPLEMENTED

**Required:**
- [ ] **Event Framework:**
  - [ ] Time-limited events
  - [ ] Event start/end dates
  - [ ] Event-specific levels or challenges
- [ ] **Event Types:**
  - [ ] "Noah's Rescue Week"
  - [ ] "Moses Miracle Trials"
  - [ ] Seasonal events
- [ ] **Rewards:**
  - [ ] Exclusive rewards for events
  - [ ] Leaderboards (optional)
- [ ] **UI:**
  - [ ] Events tab showing active/upcoming
  - [ ] Countdown timers
  - [ ] Event-specific screens

**New Files:**
- `scripts/EventManager.gd` - Event logic
- `data/events.json` - Event definitions

**Files to Modify:**
- `scripts/RewardsHub.gd` - Add Events tab

**Estimated Time:** 10-12 hours

---

## LOW PRIORITY - MONETIZATION & POLISH 🟢

### 13. Enhanced Shop Screen
**Current Status:** Basic shop exists

**Required Updates:**
- [ ] **Currency Packs:**
  - [ ] Visual pack displays
  - [ ] Price labels (£0.99, etc.)
  - [ ] Purchase buttons
- [ ] **Booster Bundles:**
  - [ ] Coin-based bundles (200 coins for 3 hammers)
  - [ ] Gem-based bundles
  - [ ] Bundle icons
- [ ] **Special Offers:**
  - [ ] Welcome bundle
  - [ ] Limited-time offers
  - [ ] "Best Value" badges
- [ ] **Better UI:**
  - [ ] Categorized sections
  - [ ] Scroll view
  - [ ] Purchase confirmation dialogs

**Files to Modify:**
- `scripts/ShopUI.gd` - Expand shop items
- Add IAP integration (if real purchases)

**Estimated Time:** 6-8 hours

---

### 14. Main Menu Enhancements
**Current Status:** Basic start page exists

**Required Updates:**
- [ ] **Visual Improvements:**
  - [ ] Game title/logo
  - [ ] Better background art
  - [ ] Animated elements
- [ ] **Navigation Buttons:**
  - [ ] Gallery button with icon (🎨)
  - [ ] Map button with icon (🌍)
  - [ ] Rewards button with icon (⭐)
  - [ ] Shop button with icon (🛒)
- [ ] **Layout:**
  - [ ] Coins/gems display at top
  - [ ] Centered PLAY button
  - [ ] Icon buttons at bottom
- [ ] **Animations:**
  - [ ] Button hover effects
  - [ ] Transition animations

**Files to Modify:**
- `scripts/StartPage.gd` - Add navigation buttons
- `scripts/MainMenu.gd` - Route to different screens
- Add icon assets

**Estimated Time:** 4-5 hours

---

### 15. Enhanced Gallery Hub
**Current Status:** Basic artwork gallery exists

**Required Updates:**
- [ ] **Tab System:**
  - [ ] Artwork tab (current)
  - [ ] Puzzle tab → link to Puzzle Screen
  - [ ] Cards tab → link to Card Album
  - [ ] Badges tab → link to Achievements
  - [ ] Story tab (optional - text stories)
- [ ] **Better Artwork Display:**
  - [ ] Unlock conditions shown for locked items
  - [ ] Better thumbnails
  - [ ] Full-screen view improvements
- [ ] **Story Tab (Optional):**
  - [ ] Text-based Bible stories
  - [ ] Unlock via levels
  - [ ] Reading progress tracking

**Files to Modify:**
- `scripts/GalleryUI.gd` - Add tab navigation
- Link to new Puzzle/Card screens

**Estimated Time:** 3-4 hours

---

### 16. Settings Enhancements
**Current Status:** Basic settings exist

**Required Updates:**
- [ ] **Additional Settings:**
  - [ ] Notifications toggle
  - [ ] Language selection dropdown
- [ ] **Information:**
  - [ ] Credits screen
  - [ ] Privacy Policy link
  - [ ] Restore Purchases button (for IAP)
- [ ] **Better UI:**
  - [ ] Organized sections
  - [ ] Better toggle switches
  - [ ] Version info display

**Files to Modify:**
- `scripts/SettingsDialog.gd` - Add new options

**Estimated Time:** 2-3 hours

---

## INFRASTRUCTURE & DATA 🔧

### 17. Enhanced Progress System
**Current Status:** Basic player_progress.json exists

**Required Additions:**
```json
{
  "stars": {
    "level_1": 3,
    "level_2": 2
  },
  "puzzle_pieces": {
    "noahs_ark": [1, 3, 5, 7],
    "creation": [1, 2]
  },
  "cards_collected": ["adam", "eve"],
  "chests": [
    {"type": "bronze", "unlock_time": 0},
    {"type": "silver", "unlock_time": 1705334400}
  ],
  "daily_rewards": {
    "last_claim": "2026-01-15",
    "streak": 3
  },
  "missions": {
    "match_yellow_50": {"progress": 32, "claimed": false}
  },
  "events": {
    "noahs_rescue": {"progress": 5}
  }
}
```

**Files to Modify:**
- `scripts/RewardManager.gd` - Handle new data structures

**Estimated Time:** 2-3 hours

---

### 18. Data Files Creation
**Required New Files:**
- [ ] `data/puzzles.json` - Puzzle definitions
- [ ] `data/cards.json` - Story card data
- [ ] `data/missions.json` - Mission definitions
- [ ] `data/events.json` - Event data
- [ ] `data/chapters.json` - Chapter/world map data
- [ ] Asset files: Card images, puzzle images, badge icons

**Estimated Time:** 4-6 hours

---

## IMPLEMENTATION ORDER (Recommended)

### Phase 1: Core Gameplay Polish (Week 1)
1. Enhanced Gameplay HUD positioning
2. Star Rating System
3. Enhanced Level Complete/Failed screens

### Phase 2: Progression Systems (Week 2-3)
4. World Map / Level Select
5. Puzzle Pieces System
6. Enhanced Badges

### Phase 3: Engagement Features (Week 3-4)
7. Daily Rewards
8. Missions System
9. Story Cards Album

### Phase 4: Advanced Features (Week 4-5)
10. Chests System
11. Events System
12. Enhanced Shop

### Phase 5: Polish & Refinement (Week 5-6)
13. Main Menu enhancements
14. Gallery Hub tabs
15. Settings enhancements
16. UI/UX polish

---

## TESTING CHECKLIST

For each feature:
- [ ] Unit tests for data persistence
- [ ] UI responsiveness on different screen sizes
- [ ] Save/load functionality
- [ ] Error handling
- [ ] Performance optimization
- [ ] User feedback (animations, sounds)

---

## TOTAL ESTIMATED TIME
- High Priority: 10-14 hours
- Medium Priority (Progression): 24-31 hours
- Medium Priority (Engagement): 30-37 hours
- Low Priority: 15-20 hours
- Infrastructure: 6-9 hours

**GRAND TOTAL: 85-111 hours (~2.5-3 months at 10 hours/week)**

---

## NOTES

- Some features can be implemented in parallel
- Start with high-priority items to maintain playability
- Test thoroughly after each phase
- Consider player feedback between phases
- Some features (Events, IAP) may require backend/server support
- Asset creation (images, icons) not included in time estimates

---

## NEXT STEPS

1. Review this plan with stakeholders
2. Prioritize which features are MVP (Minimum Viable Product)
3. Create detailed design docs for complex features (Map, Missions, Chests)
4. Begin Phase 1 implementation
5. Set up testing framework
6. Create asset list and commission/create assets

---

# UPDATED ROADMAP & NEXT STEPS (2026-01-18)

This section captures the current project state and recommends the next priorities after Phase 1 / Phase 1.5 work. It is intended to be actionable (tasks, owners, estimates, acceptance criteria, tests).

## Current snapshot
- Phase 1: COMPLETE ✅
- Phase 1.5 (UI polish): 40% complete — font work and combo text done, remaining UIs pending.
- World Map / Level Select: IMPLEMENTED & responsive ✅
- Enhanced Level Complete / Failed screens: IMPLEMENTED ✅
- Achievements & Badges: IMPLEMENTED ✅
- Booster panel: IMPLEMENTED ✅

All of the above have been integrated and smoke-tested via the headless checks and manual runs described in the project logs.

## Prioritized next work (short horizon)
These are recommended next tasks to maintain momentum and deliver high-impact features for retention and monetization.

1) Puzzle Pieces System (Phase 2 - HIGH)
- Why: Adds long-term engagement mechanics, integrates with Gallery, and provides another reward type to drive repeat play
- Estimated effort: 6-8 hours
- Files to create / modify: `scripts/PuzzleManager.gd`, `scenes/PuzzleScreen.tscn`, `scripts/GalleryUI.gd`, `scripts/RewardManager.gd` (award pieces)
- Key steps:
  1. Define `data/puzzles.json` format and example (puzzle id, total slots, image, unlock reward)
  2. Implement `PuzzleManager` API (get_progress, add_piece, is_complete, persist)
  3. Add UI scene `PuzzleScreen.tscn` with grid, collected pieces, and unlock flow
  4. Hook puzzle awards into RewardManager (on level complete probability or chest)
- Acceptance criteria:
  - `player_progress.json` contains `puzzle_pieces` entries after awarding
  - Puzzle screen loads, shows progress and unlocked art when complete
  - Pieces awarded are reflected in Gallery
- Tests:
  - Unit: add_piece increments saved progress and persists
  - Manual: complete a level that awards a piece → open Gallery → Puzzle card shows progress

2) Story Cards Album (Phase 2 - MEDIUM)
- Why: Narrative engagement, cosmetic rewards, cross-links to chapters
- Estimated effort: 6-8 hours
- Files: `scripts/CardManager.gd`, `scenes/CardAlbum.tscn`, `data/cards.json`, `scripts/GalleryUI.gd`
- Steps: define card JSON, implement manager, create album UI, hook rewards
- Acceptance: Cards persist, unlock animations run, album accessible from Gallery

3) Daily Rewards (Phase 3 - MEDIUM)
- Why: Increases daily active users; a small engineering cost with large retention impact
- Estimated effort: 6-7 hours
- Files: `scripts/DailyRewardManager.gd`, `scenes/RewardsHub.tscn`, `scripts/RewardsHub.gd`
- Steps: implement daily logic (resets at midnight), UI with claim button, integrate with RewardManager
- Acceptance: daily claim stored, streak increments, UI shows next reward

## Short-list (pick next 1 or 2 to execute)
- Option A (engagement-first): Puzzle Pieces System → Story Cards Album
- Option B (retention-first): Daily Rewards → Missions System (next)

My recommended immediate next work: **Puzzle Pieces System (Option A, item 1)** — it unlocks integration across Gallery and Rewards and gives a visible sense of progress for players.

## Immediate implementation plan for Puzzle Pieces (concrete 6-step sprint)
1. Create `data/puzzles.json` with 2 example puzzles (noah_ark, creation). (30-45m)
2. Implement `scripts/PuzzleManager.gd` with public API:
   - `func load()` `func save()` `func add_piece(puzzle_id, piece_index)` `func get_progress(puzzle_id)` `func is_complete(puzzle_id)`
   - persist into `player_progress.json` under `puzzle_pieces`
   (2.5-3h)
3. Create `scenes/PuzzleScreen.tscn` with a grid and placeholder pieces, and `scripts/PuzzleScreen.gd` (UI only). (1.5-2h)
4. Hook into `scripts/RewardManager.gd` to award puzzle pieces on level completion or chest openings (configurable probability). (30-60m)
5. Expose Puzzle screen from Gallery UI (`GalleryUI.gd`) and add a button to open it. (30-45m)
6. Tests and manual QA: unit tests for PuzzleManager save/load + manual flow. (30-60m)

Acceptance tests (smoke):
- Run game, simulate awarding a piece → open Gallery → Puzzle screen shows updated piece
- Inspect `player_progress.json` entry for `puzzle_pieces`
- Ensure no regressions in RewardManager save/load

## Implementation conventions and notes
- Use the existing `RewardManager` save/load mechanics as the canonical persistence path; write backward-compatible changes
- Keep data files under `data/` where possible (create `data/puzzles.json`, `data/cards.json`)
- UI must use `ThemeManager.apply_bangers_font` for all new labels
- Stick to the responsive layout utilities used by `WorldMap.gd` for screens that should adapt to viewport size

## Risk & mitigation
- Race conditions writing `player_progress.json` — use RewardManager (single writer) or a small queue to serialize writes
- UX design for puzzle piece drop rate — start with deterministic test mode, then tune probabilities after analytics

## Do you want me to start implementing the Puzzle Pieces System now?
- If yes, I will: create `data/puzzles.json`, implement `scripts/PuzzleManager.gd`, wire RewardManager, and create `scenes/PuzzleScreen.tscn`.
- I will run quick unit tests and a manual smoke test, report back with PR-ready changes.

---

*End of update — roadmap section appended 2026-01-18.*
