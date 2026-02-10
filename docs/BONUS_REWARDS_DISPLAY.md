# Bonus Rewards Display on Transition Screen

## Enhancement

When flow rewards (from reward nodes) are granted, they are now **clearly highlighted** on the transition screen so users can see they received something special!

---

## The Display

### Regular Rewards (from level performance)
```
Rewards Earned:
Coins: +150
Gems: +25
```

### Bonus Rewards (from flow reward nodes)
```
Rewards Earned:
Coins: +150
Gems: +25

🎁 BONUS REWARDS! 🎁  ← Pulsing gold text!
+100 💰              ← Coins (larger, gold)
+50 💎               ← Gems (larger, bright)
🖼️ Gallery Unlocked: Creation Day 1  ← Images (pink)
🎬 Video Unlocked: The Beginning      ← Videos (purple)
🚀 +2 Hammer Booster                  ← Boosters (orange)
🃏 Card Unlocked: Abraham             ← Cards (yellow)
🎨 Theme Unlocked: Biblical Legacy    ← Themes (green)
```

---

## How It Works

### 1. ExperienceDirector Provides Info
**New method:** `get_next_node_rewards()`

```gdscript
// Check what's coming next in the flow
var next_node_info = ExperienceDirector.get_next_node_rewards()

// Returns (example with multiple reward types):
{
    "has_rewards": true,
    "rewards": [
        { "type": "coins", "amount": 100 },
        { "type": "gems", "amount": 50 },
        { "type": "gallery_image", "image_name": "Creation Day 1" },
        { "type": "video", "video_name": "The Beginning" },
        { "type": "booster", "booster_type": "hammer", "amount": 2 },
        { "type": "card", "card_name": "Abraham" },
        { "type": "theme", "theme_name": "Biblical Legacy" }
    ],
    "reward_id": "first_level_complete"
}
```

### 2. GameUI Passes Info to Transition
**Updated:** `_on_level_complete()`

```gdscript
// Get bonus rewards from flow
var bonus_rewards = ExperienceDirector.get_next_node_rewards()

// Pass to transition screen
level_transition.show_transition_with_bonus(
    level,
    score,
    base_coins,  // From level performance
    base_gems,   // From level performance
    has_next,
    stars,
    bonus_rewards  // From flow reward nodes
)
```

### 3. Transition Screen Displays Both
**New method:** `show_transition_with_bonus()`

Shows:
1. **Regular rewards** (calculated from score/performance)
2. **Separator** (visual break)
3. **"🎁 BONUS REWARDS!" header** (pulsing gold)
4. **Bonus items** (larger icons, bright colors)

---

## Visual Hierarchy

**Layout:**
```
╔══════════════════════════════════════╗
║    🎉 Level 1 Complete! 🎉          ║
║                                      ║
║         ⭐ ⭐ ⭐                      ║
║                                      ║
║      Final Score: 5500               ║
║                                      ║
║    Rewards Earned:                   ║
║    Coins: +150                       ║ ← Base rewards
║    Gems: +25                         ║
║                                      ║
║    ─────────────────────             ║
║                                      ║
║    🎁 BONUS REWARDS! 🎁              ║ ← SPECIAL! (pulsing)
║    +100 💰                           ║ ← Bonus coins (gold)
║    +50 💎                            ║ ← Bonus gems (cyan)
║    🖼️ Gallery: Creation Day 1       ║ ← Image unlock (pink)
║    🎬 Video: The Beginning           ║ ← Video unlock (purple)
║                                      ║
║   [▶ CONTINUE]  [🔄 REPLAY]         ║
╚══════════════════════════════════════╝
```

---

## Supported Reward Types

The bonus rewards display supports all reward types with appropriate icons and colors:

| Type | Icon | Color | Display Format | Example |
|------|------|-------|----------------|---------|
| `coins` | 💰 | Gold (#FFD700) | +{amount} with coin icon | +100 💰 |
| `gems` | 💎 | Bright Cyan (#4DE6FF) | +{amount} with gem icon | +50 💎 |
| `booster` | 🚀 | Orange (#FF8033) | +{amount} {name} Booster | 🚀 +2 Hammer Booster |
| `gallery_image` | 🖼️ | Pink (#FFB3E6) | Gallery Unlocked: {name} | 🖼️ Gallery Unlocked: Creation Day 1 |
| `video` | 🎬 | Purple (#E64DE6) | Video Unlocked: {name} | 🎬 Video Unlocked: The Beginning |
| `card` | 🃏 | Yellow (#E6E64D) | Card Unlocked: {name} | 🃏 Card Unlocked: Abraham |
| `theme` | 🎨 | Green (#80E680) | Theme Unlocked: {name} | 🎨 Theme Unlocked: Biblical Legacy |
| `unknown` | 🎁 | White (#FFFFFF) | {type} Unlocked! | 🎁 Special Unlocked! |

### Reward Data Format

Each reward type has specific data fields:

**Coins & Gems:**
```json
{ "type": "coins", "amount": 100 }
{ "type": "gems", "amount": 50 }
```

**Boosters:**
```json
{ "type": "booster", "booster_type": "hammer", "amount": 2 }
```

**Gallery Images:**
```json
{ "type": "gallery_image", "image_name": "Creation Day 1" }
```

**Videos:**
```json
{ "type": "video", "video_name": "The Beginning" }
```

**Cards:**
```json
{ "type": "card", "card_name": "Abraham" }
```

**Themes:**
```json
{ "type": "theme", "theme_name": "Biblical Legacy" }
```

---

## Implementation

### Files Modified

1. **scripts/ExperienceDirector.gd**
   - Added `get_next_node_rewards()` method
   - Checks if next node is a reward node
   - Returns reward details or empty dict

2. **scripts/GameUI.gd**
   - `_on_level_complete()`: Gets bonus rewards before showing transition
   - Calls `show_transition_with_bonus()` if available

3. **scripts/LevelTransition.gd**
   - Added `_bonus_rewards` variable
   - Added `show_transition_with_bonus()` method
   - Updated `_update_rewards_display()` to show bonus section
   - Added pulsing animation to bonus header
   - Larger icons and brighter colors for bonus items

---

## User Experience

### Before (Unclear)
```
Rewards Earned:
Coins: +250
Gems: +75
```
User thinks: "Is this from the level or something special?"

### After (Clear!)
```
Rewards Earned:
Coins: +150    ← From level
Gems: +25      ← From level

🎁 BONUS REWARDS! 🎁  ← Special milestone!
+100 💰  ← Extra coins for completing milestone
+50 💎   ← Extra gems for completing milestone
```
User thinks: "Awesome! I got bonus rewards for this milestone!"

---

## Benefits

✅ **Clear distinction** between base and bonus rewards  
✅ **Special highlighting** makes bonuses feel rewarding  
✅ **Pulsing animation** draws attention  
✅ **Larger icons** emphasize importance  
✅ **User knows** they achieved something special  
✅ **No confusion** about where rewards came from  

---

## Testing

### Test Case 1: Level with Bonus Rewards
1. Complete Level 1
2. **See:** Transition shows base rewards + "🎁 BONUS REWARDS!" section
3. **Verify:** Bonus section is clearly visible and pulsing

### Test Case 2: Level without Bonus Rewards
1. Complete Level 2 (no reward node after)
2. **See:** Transition shows only base rewards
3. **Verify:** No bonus section (clean display)

### Test Case 3: Multiple Bonus Items
1. If flow has reward with multiple items
2. **See:** All bonus items listed under bonus header
3. **Verify:** Each displays with proper icon and amount

---

## Status: ✅ IMPLEMENTED

Bonus flow rewards are now **clearly visible and highlighted** on the transition screen!

Users will immediately know when they've earned special milestone rewards.
