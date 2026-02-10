# Game Board Screen Elements - Complete Inventory

**Date:** February 7, 2026  
**Purpose:** Documentation of all UI elements visible during active gameplay  
**Status:** ✅ COMPREHENSIVE LIST

---

## Screen Overview

The game board screen consists of several layers and zones:

1. **Top Zone** - HUD/Status Information
2. **Middle Zone** - Game Board
3. **Bottom Zone** - Boosters/Controls
4. **Floating Elements** - Menu, Dialogs, Overlays
5. **Background** - Visual effects and theming

---

## 1. TOP ZONE - HUD (Heads-Up Display)

### HUD Container
- **Component:** `PanelContainer` named "HUD"
- **Background:** Dark translucent (rgba: 0.1, 0.1, 0.15, 0.7)
- **Border:** 2px rounded, color (0.4, 0.4, 0.5, 0.8)
- **Corner Radius:** 12px all corners
- **Padding:** 15-20px content margin
- **Z-Index:** 10 to 100 (on top of game elements)
- **Anchor:** Registered with VisualAnchorManager as `"hud"`

### Level Display
- **Component:** `LevelLabel` in `LevelContainer`
- **Format:** "Lv {number}" (e.g., "Lv 5")
- **Font:** Bangers font
- **Updates:** On level change

### Moves Counter
- **Component:** `MovesLabel` in `MovesContainer`
- **Header:** "MOVES" (small, muted color)
- **Format:** "{number}" (e.g., "12")
- **Color:** 
  - Cyan (0.3, 0.9, 1.0) when moves > 5
  - Red when moves ≤ 5 (with animation warning)
- **Updates:** Real-time after each move

### Score Display
- **Component:** `ScoreLabel` in `ScoreContainer`
- **Header:** "SCORE" (small, muted color)
- **Format:** "{number}" (e.g., "4500")
- **Animation:** Flashes/scales when score increases
- **Updates:** Real-time after each match

### Goal/Target Display
- **Component:** `TargetContainer` containing:
  - **`TargetLabel`** - Text display
  - **`TargetProgress`** - Progress bar
- **Header:** "GOAL" (small, muted color)
- **Format:** Varies by level type:
  - **Score-based:** "Goal: {target_score}"
  - **Collectible-based:** "Coins: {collected}/{target}"
  - **Obstacle-based:** "Obstacles: {cleared}/{target}"
- **Progress Bar:** 
  - Fills from 0-100% based on progress
  - Visual indicator of goal completion
- **Color coding:**
  - Gold flash (1.0, 0.9, 0.2) for collectibles
  - Orange flash (1.0, 0.5, 0.3) for obstacles

---

## 2. CURRENCY PANEL (Top-Right Corner)

### Container
- **Component:** `CurrencyPanel` with `HBoxContainer`
- **Position:** Top-right area
- **Z-Index:** High (above board, below modals)

### Coins Display
- **Component:** `CoinsLabel`
- **Icon:** Coin icon
- **Format:** "{number}" coins
- **Updates:** Real-time when coins change

### Gems Display
- **Component:** `GemsLabel`
- **Icon:** Gem icon
- **Format:** "{number}" gems
- **Updates:** Real-time when gems change

### Lives Display
- **Component:** `LivesLabel`
- **Icon:** Heart/lives icon
- **Format:** "{number}" lives
- **Note:** May be hidden if lives system removed

---

## 3. MIDDLE ZONE - GAME BOARD

**✨ NEW: All middle zone elements are now grouped in a `BoardContainer` for easy show/hide control!**

### Board Container (Master Group) ⭐⭐⭐
- **Component:** `Node2D` named "BoardContainer"
- **Purpose:** Groups ALL game board visual elements for unified control
- **Z-Index:** 0 (standard game layer)
- **Parent:** Added to `GameBoard` (Node2D)
- **Children:** Contains tiles, borders
- **Visibility Control:** Can hide/show entire board with one call

**Control Methods:**
```gdscript
# Hide entire board group (tiles, borders, overlay)
GameBoard.hide_board_group()

# Show entire board group
GameBoard.show_board_group()

# Convenience toggle
GameBoard.set_board_group_visibility(true/false)
```

### Game Board Container
- **Component:** `GameBoard` (Node2D)
- **Position:** Center of screen, below HUD
- **Size:** 8x8 grid (typically)
- **Calculated Size:** Based on screen size with padding
- **Offset:** Dynamic (e.g., ~20px from edges, ~320px from top)
- **Z-Index:** 0 (middle layer)

### Tile Grid
- **Component:** 64 `Tile` nodes (for 8x8 grid)
- **Parent:** Added to `BoardContainer` (grouped with borders)
- **Size:** Calculated based on screen (e.g., 85px each)
- **Features:**
  - Rounded corners shader
  - Theme-based textures (legacy/modern)
  - Type-specific colors (6 different types)
  - Special tiles (striped, wrapped)
  - Collectibles overlay
  - Unmovable tiles overlay (snow, virus spreaders, etc.)

### Board Borders
- **Component:** `Line2D` borders around tiles in `BorderContainer`
- **Parent:** Added to `BoardContainer` (grouped with tiles)
- **Color:** Semi-transparent
- **Purpose:** Visual separation of play area
- **Visibility:** Controlled by `BoardContainer.visible`

### Tile Overlay
- **Component:** Individual tile backgrounds
- **Purpose:** Show valid play area
- **Color:** Semi-transparent
- **Visibility:** Toggleable

### Tile Area Overlay (Translucent Background Behind Tiles) ⭐
- **Component:** `Control` container named "TileAreaOverlay"
- **Purpose:** Creates semi-transparent dark background behind each active tile
- **Z-Index:** -50 (above background image at -100, behind tiles at 0)
- **Mouse Filter:** MOUSE_FILTER_IGNORE (doesn't block clicks)
- **Child Components:** Individual `ColorRect` for each non-blocked tile
  - **Color:** `Color(0.1, 0.15, 0.25, 0.5)` - Dark blue-gray at 50% opacity
  - **Size:** Matches tile size (e.g., 85x85px)
  - **Position:** Aligned exactly with corresponding tile
  - **Count:** One per active tile (e.g., 64 for full 8x8 grid)
- **Visual Effect:** Creates subtle depth - tiles appear to float above a translucent panel
- **Parent:** Added to `MainGame` (Control node), not GameBoard itself
- **Note:** This is what creates the "translucent background" you see behind the tile grid!

### Background Image
- **Component:** `TextureRect` named "BackgroundImage"
- **Path:** `res://textures/background.jpg` (configurable)
- **Size:** Covers entire screen
- **Z-Index:** -100 (bottom layer, behind everything)
- **Stretch Mode:** STRETCH_KEEP_ASPECT_COVERED
- **Parent:** Added to `MainGame` (Control node)
- **Note:** The tile area overlay (-50) sits between this background (-100) and the tiles (0)

---

## 4. BOTTOM ZONE - BOOSTERS & CONTROLS

### Booster Panel
- **Component:** `BoosterPanel` with `HBoxContainer`
- **Position:** Bottom of screen
- **Layout:** Horizontal row of booster buttons

### Booster Buttons (Dynamic - based on level selection)
Each booster has:
- **Button:** 70x70px button
- **Icon:** 48x48px texture (scaled from 256x256)
- **Count Label:** Shows remaining uses
- **Glow Effect:** Pulsing animation when available

**Common Boosters:**
1. **Hammer** - Remove single tile
2. **Shuffle** - Reshuffle board
3. **Swap** - Swap any two tiles
4. **Chain Reaction** - Clear surrounding tiles
5. **Extra Moves** - Add 10 moves

**Advanced Boosters:**
6. **Bomb 3x3** - Clear 3x3 area
7. **Line Blast** - Clear horizontal/vertical line
8. **Tile Squasher** - Remove specific tile type
9. **Row Clear** - Clear entire row
10. **Column Clear** - Clear entire column

### Shop Button
- **Component:** `ShopButton` (if visible)
- **Position:** Bottom panel
- **Icon:** Shop/cart icon
- **Action:** Opens shop UI

---

## 5. FLOATING ELEMENTS

### Floating Menu (Top-Left)
- **Component:** `FloatingMenu` container
- **Z-Index:** High

#### Menu Button
- **Component:** `MenuButton`
- **Icon:** Hamburger/menu icon
- **Animation:** Glow effect
- **Action:** Toggles expandable panel

#### Expandable Panel
- **Component:** `ExpandablePanel`
- **Visibility:** Hidden by default, fades in on menu click
- **Contains:**
  - **Map Button** - Opens world map
  - **Audio Button** - Toggle sound/music
  - **Shop Button** - Opens shop

### Narrative Stage Overlay (When Active)
- **Component:** Dynamically added `TextureRect`
- **Position:** 8-15% from top of screen
- **Height:** 120-200px
- **Z-Index:** -10 (below HUD, above board)
- **Purpose:** Show story narrative during special moments
- **Content:** SVG graphics with text and visuals
- **Anchor:** Registered as `"top_banner"`

### Visual Overlays (Narrative Effects)
- **Progressive Brightness** - Gradual lighting effect
- **Screen Flash** - Victory flash on level complete
- **Background Tint** - Color tinting
- **Fade Effects** - Element fading
- **State Swap** - Visibility/position swapping

---

## 6. MODAL DIALOGS & SCREENS

### Start Page
- **Component:** `StartPage`
- **Size:** Fullscreen
- **Content:**
  - Level number and description
  - Booster selection
  - Start button
  - Settings button
  - Map button
  - Achievements button

### Level Transition Screen
- **Component:** `LevelTransition`
- **Size:** Fullscreen
- **Z-Index:** 100 (top layer)
- **Content:**
  - Level complete title
  - Star rating (1-3 stars)
  - Score display
  - Rewards (coins, gems)
  - Multiplier mini-game
  - Continue button

### Enhanced Game Over Screen
- **Component:** `EnhancedGameOverPanel`
- **Size:** ~720x480px (centered)
- **Z-Index:** 2000 (very top)
- **Content:**
  - "Game Over" title (red, Bangers font, 48px)
  - Final score vs. target
  - Retry button
  - Quit button

### Shop UI
- **Component:** `ShopUI`
- **Display:** Side panel (40% width, max 480px)
- **Z-Index:** 150
- **Content:**
  - Booster purchases
  - Coin packages
  - Gem packages
  - Extra moves purchase
  - Special offers

### World Map
- **Component:** `WorldMap`
- **Size:** Fullscreen
- **Content:**
  - Chapter nodes
  - Level nodes
  - Progress indicators
  - DLC chapters
  - Background theming

### Settings Dialog
- **Component:** `SettingsDialog`
- **Type:** Modal popup
- **Content:**
  - Audio settings
  - Graphics settings
  - Account settings

### About Dialog
- **Component:** `AboutDialog`
- **Type:** Modal popup
- **Content:**
  - Game information
  - Credits
  - Version number

### Out of Lives Dialog
- **Component:** `OutOfLivesDialog`
- **Type:** Modal popup
- **Content:**
  - Lives refill option
  - Cost display
  - Confirm/cancel buttons

### Reward Notification
- **Component:** `RewardNotification`
- **Type:** Toast/popup notification
- **Display:** Temporary overlay
- **Content:**
  - Reward type (coins, gems, booster)
  - Amount
  - Icon

---

## 7. SPECIAL EFFECTS & PARTICLES

### Match Effects
- Particle explosions on tile matches
- Score popup text (floating numbers)
- Combo multiplier text

### Special Tile Effects
- Striped tile activation (line clear)
- Wrapped tile explosion
- Color bomb activation

### Power-Up Effects
- Hammer impact
- Shuffle animation
- Bomb explosion
- Lightning effects

---

## Z-Index Layering Summary

From bottom to top:

- **-100:** Background image (fullscreen texture)
- **-75:** Progressive brightness overlay (narrative effect)
- **-50:** **Tile Area Overlay (translucent backgrounds behind tiles)** ⭐
- **-10:** Narrative banner
- **0:** Game board and tiles
- **10-100:** HUD elements
- **100:** Level transition screen
- **150:** Shop UI
- **1000:** Various overlays
- **2000+:** Modal dialogs (game over, etc.)

---

## Element Visibility States

### Always Visible During Gameplay
- HUD (Moves, Score, Goal)
- Currency panel (Coins, Gems)
- Game board and tiles
- Floating menu button
- Background

### Conditionally Visible
- Booster panel (only if boosters selected)
- Narrative overlays (level-specific)
- Progress effects (on events)
- Low moves warning (≤5 moves)

### Hidden During Gameplay
- Start page
- Level transition screen
- Game over screen
- Shop UI (until opened)
- World map (until opened)
- Settings/About dialogs

---

## Notes

1. **Theme Dependency:** Many visual elements change based on theme (legacy/modern)
2. **Level Dependency:** Some elements only appear for specific level types
3. **DLC Support:** Additional elements for DLC content
4. **Responsive Design:** All elements scale based on screen size
5. **Anchor System:** VisualAnchorManager tracks key elements for effects

---

## Issue to Fix

**Please specify which element(s) need fixing:**
- Layout issue?
- Visibility problem?
- Z-index overlap?
- Missing element?
- Animation issue?
- Other concern?

This comprehensive list covers all elements. What specific issue needs to be addressed?
