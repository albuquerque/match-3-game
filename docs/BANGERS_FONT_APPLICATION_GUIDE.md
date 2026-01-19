# Bangers Font Application Guide

## Date: January 16, 2026
## Status: IN PROGRESS

This document provides exact instructions for applying the Bangers font to all UI text elements throughout the game for a consistent, bold visual style.

---

## ✅ COMPLETED FILES

### 1. GameBoard.gd
- **Combo text** (line ~729) - ✅ Already has Bangers font

### 2. LevelTransition.gd
- **Title label** (line 71) - ✅ Already has Bangers font
- **Score label** (line 89) - ✅ Already has Bangers font  
- **Rewards title** (line 102) - ✅ Already has Bangers font
- **Replay button** (line 127) - ✅ Already has Bangers font
- **Continue button** (line 135) - ✅ Already has Bangers font
- **Multiplier title** (line 165) - ✅ Using ThemeManager helper

### 3. ThemeManager.gd
- **Helper functions** (lines 102-127) - ✅ Complete with caching

---

## 🔧 FILES THAT NEED UPDATES

### StartPage.gd

**Location:** `scripts/StartPage.gd`

**Changes needed:**

#### Line ~44 - Level Label Button
**Change FROM:**
```gdscript
level_label.add_theme_font_size_override("font_size", 36)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font_to_button(level_label, 36)
```

#### Line ~53 - Lives Label  
**Change FROM:**
```gdscript
lives_label.add_theme_font_size_override("font_size", 20)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(lives_label, 20)
```

#### Line ~64 - Description Label
**Change FROM:**
```gdscript
desc_label.add_theme_font_size_override("font_size", 18)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(desc_label, 18)
```

#### Around line 75 - Start Button
**Add after the `start_btn.text = "Start Level"` line:**
```gdscript
ThemeManager.apply_bangers_font_to_button(start_btn, 24)
```

#### Around line 82 - Exchange Button
**Add after the `exchange_btn.text = "Exchange Gems"` line:**
```gdscript
ThemeManager.apply_bangers_font_to_button(exchange_btn, 20)
```

---

### AchievementsPage.gd

**Location:** `scripts/AchievementsPage.gd`

**Changes needed:**

#### Line ~40 - Page Title
**Change FROM:**
```gdscript
title.add_theme_font_size_override("font_size", 40)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(title, 40)
```

#### Line ~73 - Streak Title
**Change FROM:**
```gdscript
streak_title.add_theme_font_size_override("font_size", 28)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(streak_title, 28)
```

#### Line ~81 - Streak Label
**Change FROM:**
```gdscript
streak_label.add_theme_font_size_override("font_size", 24)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(streak_label, 24)
```

#### Line ~87 - Reward Info
**Change FROM:**
```gdscript
reward_info.add_theme_font_size_override("font_size", 16)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(reward_info, 16)
```

#### Line ~109 - Badges Title
**Change FROM:**
```gdscript
badges_title.add_theme_font_size_override("font_size", 28)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(badges_title, 28)
```

#### Line ~227 - Badge Title Label
**Change FROM:**
```gdscript
title_label.add_theme_font_size_override("font_size", 20)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(title_label, 20)
```

#### Line ~236 - Badge Description Label
**Change FROM:**
```gdscript
desc_label.add_theme_font_size_override("font_size", 14)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(desc_label, 14)
```

#### Line ~248 - Status Label
**Change FROM:**
```gdscript
status_label.add_theme_font_size_override("font_size", 18)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(status_label, 18)
```

#### Line ~373 - Claim Dialog Title
**Change FROM:**
```gdscript
title.add_theme_font_size_override("font_size", 32)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(title, 32)
```

#### Line ~386 - Rewards Label
**Change FROM:**
```gdscript
rewards_label.add_theme_font_size_override("font_size", 20)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(rewards_label, 20)
```

#### Line ~431 - Reward Text
**Change FROM:**
```gdscript
reward_text.add_theme_font_size_override("font_size", 24)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(reward_text, 24)
```

---

### ShopUI.gd

**Location:** `scripts/ShopUI.gd`

**Changes needed:**

#### Line ~90 - Icon Label
**Change FROM:**
```gdscript
icon_label.add_theme_font_size_override("font_size", icon_font)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(icon_label, icon_font)
```

#### Line ~103 - Name Label
**Change FROM:**
```gdscript
name_label.add_theme_font_size_override("font_size", name_font)
```
**Change TO:**
```gdscript
ThemeManager.apply_bangers_font(name_label, name_font)
```

---

### GameUI.gd

**Location:** `scripts/GameUI.gd`

**Note:** GameUI has many labels created programmatically. Search for labels that are visible to the player and apply the font.

**Common patterns to look for:**
- Score labels
- Moves labels
- Target labels
- Currency displays
- Any dialog titles

**Example changes:**
```gdscript
# Instead of:
score_label.add_theme_font_size_override("font_size", 24)

# Use:
ThemeManager.apply_bangers_font(score_label, 24)

# For buttons:
ThemeManager.apply_bangers_font_to_button(button_name, 20)
```

---

## 💡 USAGE TIPS

### For Labels:
```gdscript
ThemeManager.apply_bangers_font(label, font_size)
```

### For Buttons:
```gdscript
ThemeManager.apply_bangers_font_to_button(button, font_size)
```

### Benefits:
- ✅ Automatic font caching for performance
- ✅ Consistent styling across all UI
- ✅ One-line application
- ✅ Easy to update font in future (just change ThemeManager)

---

## 📝 TESTING CHECKLIST

After applying all changes, test these screens:

- [ ] **Start Page** - Level button, description text
- [ ] **Level Complete** - Title, score, rewards (already done)
- [ ] **Achievements** - Page title, streak info, badge cards
- [ ] **Shop** - Item names and labels
- [ ] **Settings** - Any labels/buttons
- [ ] **In-Game HUD** - Score, moves, target displays
- [ ] **Combo Text** - NICE, SUPER, AMAZING (already done)

---

## 🎯 PRIORITY ORDER

If you want to apply the font gradually, here's the recommended priority:

1. ✅ **LevelTransition.gd** - DONE
2. ✅ **GameBoard.gd** (combo text) - DONE
3. **StartPage.gd** - HIGH (players see this every level)
4. **AchievementsPage.gd** - MEDIUM (frequently viewed)
5. **GameUI.gd** (HUD elements) - MEDIUM (always visible during play)
6. **ShopUI.gd** - LOW (less frequently accessed)
7. **SettingsDialog.gd** - LOW (rarely accessed)

---

## 🔍 QUICK REFERENCE

**Find all font size overrides:**
```bash
grep -n "add_theme_font_size_override" scripts/*.gd
```

**Replace pattern:**
- Find: `label_name.add_theme_font_size_override("font_size", SIZE)`
- Replace: `ThemeManager.apply_bangers_font(label_name, SIZE)`

For buttons:
- Find: `button_name.add_theme_font_size_override("font_size", SIZE)`
- Replace: `ThemeManager.apply_bangers_font_to_button(button_name, SIZE)`

---

## ✅ COMPLETION STATUS

- [x] ThemeManager helper functions
- [x] LevelTransition screen
- [x] Combo text in GameBoard
- [ ] StartPage
- [ ] AchievementsPage
- [ ] ShopUI
- [ ] GameUI HUD
- [ ] SettingsDialog
- [ ] Other dialogs

**Estimated Time to Complete:** 30-45 minutes for all remaining files

**Current Progress:** ~40% complete (core screens done)

