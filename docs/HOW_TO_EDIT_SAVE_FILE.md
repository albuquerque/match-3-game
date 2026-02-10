# Quick Guide: Editing Save File for Testing

**Purpose:** Jump to any level without playing through all previous levels

---

## Finding the Save File

**Location:** `user://game_save.json`

**Actual Path (macOS):**
```
~/Library/Application Support/Godot/app_userdata/Match3Game/game_save.json
```

**Actual Path (Windows):**
```
%APPDATA%\Godot\app_userdata\Match3Game\game_save.json
```

**Actual Path (Linux):**
```
~/.local/share/godot/app_userdata/Match3Game/game_save.json
```

---

## Quick Edit Methods

### Method 1: From In-Game (Easiest)

1. Open the game
2. In StartPage, you should see a path to save file in console
3. Close game
4. Open the file in a text editor
5. Edit and save
6. Relaunch game

### Method 2: Direct Path (macOS)

```bash
# Open save file in TextEdit
open ~/Library/Application\ Support/Godot/app_userdata/Match3Game/game_save.json

# Or use nano in terminal
nano ~/Library/Application\ Support/Godot/app_userdata/Match3Game/game_save.json
```

### Method 3: Delete Save File (Fresh Start)

```bash
# macOS/Linux
rm ~/Library/Application\ Support/Godot/app_userdata/Match3Game/game_save.json

# Windows
del %APPDATA%\Godot\app_userdata\Match3Game\game_save.json
```

---

## What to Edit

Find this line in the JSON file:
```json
"levels_completed": 0,
```

Change the number to jump to different levels:

### Test Scenarios

**Start fresh (Level 1):**
```json
"levels_completed": 0,
```

**Jump to Level 16:**
```json
"levels_completed": 15,
```
(15 levels completed = next level is 16)

**Jump to Level 31 (mid-game):**
```json
"levels_completed": 30,
```

**Jump to Level 62 (final level):**
```json
"levels_completed": 61,
```

---

## Example: Full Save File

```json
{
	"coins": 5000,
	"gems": 100,
	"lives": 5,
	"last_life_regen_time": 1707516000,
	"boosters": {
		"hammer": 5,
		"shuffle": 3,
		"swap": 2,
		"chain_reaction": 1,
		"bomb_3x3": 2,
		"line_blast": 1,
		"row_clear": 0,
		"column_clear": 0,
		"extra_moves": 2,
		"tile_squasher": 0
	},
	"levels_completed": 15,    ← EDIT THIS LINE
	"level_stars": {},
	"total_stars": 45,
	"unlocked_themes": [],
	"selected_theme": "",
	"unlocked_gallery_images": [],
	"achievements_unlocked": [],
	"is_premium_user": false
}
```

---

## After Editing

1. **Save the file** (Ctrl+S / Cmd+S)
2. **Launch the game**
3. **Check console** for migration messages
4. **Verify** the correct level is available

---

## Tips

**Make a backup first:**
```bash
# macOS/Linux
cp ~/Library/Application\ Support/Godot/app_userdata/Match3Game/game_save.json ~/Desktop/backup_save.json
```

**If something breaks:**
- Delete the save file to start fresh
- Restore from backup
- Game will create a new valid save on next launch

**Common mistakes:**
- ❌ Forgetting to close the game before editing
- ❌ Invalid JSON syntax (missing comma, bracket)
- ❌ Putting a number > 62 (game only has 62 levels)

**Valid JSON check:**
Use [jsonlint.com](https://jsonlint.com) to verify your JSON is valid before saving.

---

## Quick Test Commands

```bash
# Test 1: Fresh start
rm ~/Library/Application\ Support/Godot/app_userdata/Match3Game/game_save.json
# Then launch game

# Test 2: Jump to level 16
# Edit file, change levels_completed to 15
# Then launch game

# Test 3: Jump to level 31
# Edit file, change levels_completed to 30
# Then launch game

# Test 4: Jump to level 62
# Edit file, change levels_completed to 61
# Then launch game
```

---

**Testing Phase 12.4 should take ~15-20 minutes, not hours!**
