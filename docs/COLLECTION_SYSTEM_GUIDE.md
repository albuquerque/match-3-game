# Collection System - Implementation Guide

**Status:** ✅ Complete  
**Phase:** 8 - Gallery & Collection System  
**Date:** February 8, 2026

---

## Overview

The Collection System allows players to unlock and collect special items (cards, images, videos, etc.) as they progress through the game. Collections are defined in JSON files and managed by the CollectionManager autoload.

---

## Architecture

```
ExperienceDirector (Reward Nodes)
    ↓
CollectionManager (Unlock & Track)
    ↓
RewardManager (Persist to Save File)
    ↓
UI Layer (Display - Future)
```

---

## Components

### 1. CollectionManager (Autoload)
**File:** `scripts/CollectionManager.gd`

**Responsibilities:**
- Load collection definitions from JSON files
- Track player's unlocked items per collection
- Persist unlock state via RewardManager
- Provide progress tracking and completion detection
- Emit signals on unlock and completion

**Key Methods:**
```gdscript
// Unlock an item
func unlock_item(collection_id: String, item_id: String) -> bool

// Check if unlocked
func is_item_unlocked(collection_id: String, item_id: String) -> bool

// Get progress
func get_collection_progress(collection_id: String) -> Dictionary

// Check completion
func is_collection_complete(collection_id: String) -> bool

// Get all collections
func get_all_collections() -> Array

// Get overall progress
func get_total_progress() -> Dictionary
```

**Signals:**
```gdscript
signal collection_item_unlocked(collection_id: String, item_id: String)
signal collection_completed(collection_id: String)
```

### 2. Collection Data Files
**Location:** `data/collections/*.json`

**Format:**
```json
{
  "collection_id": "unique_id",
  "name": "Display Name",
  "description": "Collection description",
  "category": "story|achievements|special",
  "items": [
    {
      "id": "item_unique_id",
      "name": "Item Display Name",
      "description": "Item description",
      "image": "res://path/to/image.svg",
      "unlock_condition": "level_01_complete",
      "rarity": "common|rare|epic|legendary"
    }
  ],
  "completion_reward": {
    "type": "gems",
    "amount": 100,
    "title": "Collection Complete!",
    "description": "Completion message"
  }
}
```

### 3. Save Data Integration
**Stored in:** RewardManager's save data (`player_progress.json`)

**Format:**
```json
{
  "unlocked_collections": {
    "creation_story_cards": [
      "creation_day_1",
      "creation_day_2",
      "creation_day_3"
    ],
    "character_cards": [
      "abraham",
      "moses"
    ]
  }
}
```

---

## Usage Examples

### Unlocking via Experience Flow

**In flow JSON:**
```json
{
  "type": "reward",
  "id": "first_card_reward",
  "rewards": [
    {
      "type": "card",
      "collection_id": "creation_story_cards",
      "card_id": "creation_day_1",
      "card_name": "Day 1: Light"
    },
    {
      "type": "coins",
      "amount": 50
    }
  ]
}
```

**Processing:** ExperienceDirector automatically calls `CollectionManager.unlock_item()` when processing the reward node.

### Manual Unlock (Code)

```gdscript
# Unlock a card
var unlocked = CollectionManager.unlock_item("creation_story_cards", "creation_day_1")

if unlocked:
    print("New card unlocked!")
else:
    print("Already unlocked")

# Check if unlocked
if CollectionManager.is_item_unlocked("creation_story_cards", "creation_day_1"):
    print("Player has this card")

# Get progress
var progress = CollectionManager.get_collection_progress("creation_story_cards")
print("Progress: ", progress.unlocked_items, "/", progress.total_items)
print("Completion: ", progress.completion_percentage, "%")
```

### Listening to Events

```gdscript
func _ready():
    CollectionManager.collection_item_unlocked.connect(_on_item_unlocked)
    CollectionManager.collection_completed.connect(_on_collection_complete)

func _on_item_unlocked(collection_id: String, item_id: String):
    print("Item unlocked: ", collection_id, "/", item_id)
    # Show unlock animation/notification

func _on_collection_complete(collection_id: String):
    print("Collection complete: ", collection_id)
    # Grant completion reward
    # Show celebration animation
```

---

## Collection Types Supported

The system is flexible and supports any type of collectible:

| Type | Description | Example Use |
|------|-------------|-------------|
| **Cards** | Character or story cards | Creation story cards, Character bios |
| **Gallery Images** | Unlockable artwork | Historical scenes, Concept art |
| **Videos** | Unlockable video content | Story cinematics, Tutorials |
| **Achievements** | Achievement badges | Milestones, Challenges |
| **Themes** | Visual themes | Board themes, UI skins |
| **Music** | Unlockable music tracks | Soundtracks, Ambient music |
| **Custom** | Any custom type | Special items, Easter eggs |

---

## Creating a New Collection

### Step 1: Create JSON File

Create `data/collections/your_collection.json`:

```json
{
  "collection_id": "exodus_characters",
  "name": "Exodus Characters",
  "description": "Meet the key figures of the Exodus story",
  "category": "story",
  "items": [
    {
      "id": "moses",
      "name": "Moses",
      "description": "The prophet who led Israel out of Egypt",
      "image": "res://textures/cards/moses.svg",
      "unlock_condition": "level_20_complete",
      "rarity": "legendary"
    },
    {
      "id": "aaron",
      "name": "Aaron",
      "description": "Moses' brother and spokesman",
      "image": "res://textures/cards/aaron.svg",
      "unlock_condition": "level_21_complete",
      "rarity": "epic"
    }
  ],
  "completion_reward": {
    "type": "gems",
    "amount": 200,
    "title": "Exodus Complete!",
    "description": "You've met all the Exodus characters!"
  }
}
```

### Step 2: Add to Experience Flow

In `data/experience_flows/main_story.json`:

```json
{
  "type": "reward",
  "id": "moses_unlock",
  "rewards": [
    {
      "type": "card",
      "collection_id": "exodus_characters",
      "card_id": "moses",
      "card_name": "Moses"
    }
  ]
}
```

### Step 3: Create Card Graphics

Place your SVG/PNG files in:
- `textures/cards/moses.svg`
- `textures/cards/aaron.svg`

### Step 4: Test

1. Run the game
2. CollectionManager auto-loads the collection on startup
3. Complete the level that triggers the reward
4. Card unlocks automatically
5. Progress persists in save file

---

## Progress Tracking

### Individual Collection

```gdscript
var progress = CollectionManager.get_collection_progress("creation_story_cards")

# Returns:
{
  "collection_id": "creation_story_cards",
  "name": "Creation Story Cards",
  "total_items": 7,
  "unlocked_items": 3,
  "is_complete": false,
  "completion_percentage": 42.86
}
```

### Overall Progress

```gdscript
var total = CollectionManager.get_total_progress()

# Returns:
{
  "total_collections": 5,
  "collections_complete": 1,
  "total_items": 35,
  "total_unlocked": 12,
  "completion_percentage": 34.29
}
```

---

## Integration Points

### With Transition Screen

When a card is unlocked via reward node:
1. ExperienceDirector processes reward
2. Card is unlocked in CollectionManager
3. **Bonus Rewards** section on transition screen shows:
   ```
   🃏 Card Unlocked: Day 1: Light
   ```

### With Gallery UI (Future)

The backend is ready for UI implementation:
- Display all collections
- Show unlocked/locked items
- View item details
- Track progress bars
- Celebration animations on unlock

---

## Best Practices

### Unlock Conditions

Use meaningful condition IDs:
- ✅ `"level_05_complete"` - Clear, specific
- ✅ `"defeat_pharaoh"` - Story-based
- ❌ `"condition_1"` - Not descriptive

### Rarity Levels

Distribute rarities for progression:
- **Common** (50-60%): Easy to unlock, early levels
- **Rare** (25-30%): Mid-game unlocks
- **Epic** (10-15%): Late-game challenges
- **Legendary** (5%): Completion rewards, special achievements

### Completion Rewards

Make them worthwhile:
- **Small collections** (5-7 items): 50-100 gems
- **Medium collections** (10-15 items): 100-200 gems
- **Large collections** (20+ items): 200-500 gems
- **Master collections** (all): 1000 gems + special theme

---

## Testing

### Manual Testing

```gdscript
# In debug console or test script

# Unlock specific item
CollectionManager.unlock_item("creation_story_cards", "creation_day_1")

# Unlock all items (for testing UI)
for collection_id in CollectionManager.get_all_collections():
    var collection = CollectionManager.get_collection_data(collection_id)
    for item in collection.items:
        CollectionManager.unlock_item(collection_id, item.id)

# Reset progress
CollectionManager.unlocked_items.clear()
CollectionManager.save_player_progress()
```

### Verify Save/Load

1. Unlock items
2. Exit game
3. Restart game
4. Check progress persists

---

## Future Enhancements

### Phase 11 - UI Implementation

- [ ] Create CollectionScreen.tscn
- [ ] Display grid of collection items
- [ ] Show locked items as silhouettes
- [ ] Detailed view on item click
- [ ] Progress bars per collection
- [ ] Celebration animations
- [ ] Filter by rarity/category

### Additional Features

- [ ] Trading system (swap duplicates)
- [ ] Achievements for collection milestones
- [ ] Daily collection challenges
- [ ] Limited-time collections (events)
- [ ] Collection-based power-ups

---

## Status Summary

✅ **Backend Complete:**
- CollectionManager autoload
- JSON data loading
- Unlock/progress tracking
- Save/load persistence
- ExperienceDirector integration
- Signal system

🔄 **UI Deferred:**
- Collection browser screen
- Card detail view
- Unlock animations
- Progress visualization

**Ready for:** Adding more collections and unlocking cards through gameplay!

---

## Example: Creation Story Cards

**Collection File:** `data/collections/creation_story_cards.json`

**Content:** 7 cards representing the 7 days of creation
- Day 1: Light (Common)
- Day 2: Sky (Common)
- Day 3: Land and Vegetation (Common)
- Day 4: Sun, Moon, Stars (Rare)
- Day 5: Sea Creatures and Birds (Rare)
- Day 6: Land Animals and Humanity (Epic)
- Day 7: Rest (Legendary)

**Completion Reward:** 100 gems + "Creation Complete!" title

**Status:** ✅ Implemented and ready to use!
