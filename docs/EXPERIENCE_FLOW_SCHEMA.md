# Experience Flow JSON Schema Documentation

**Version:** 1.0.0  
**Last Updated:** 2026-02-06

---

## Overview

Experience Flows are JSON files that define the player's journey through the game. They specify the sequence of levels, narrative stages, rewards, and other content that the player experiences.

**Location:** `data/experience_flows/`

---

## Schema Structure

### Root Object

```json
{
  "experience_id": "string (required)",
  "version": "string (required)",
  "name": "string (optional)",
  "description": "string (optional)",
  "flow": [ /* array of nodes (required) */ ]
}
```

**Fields:**

- `experience_id` - Unique identifier for this flow (e.g., "main_story", "exodus_arc")
- `version` - Semantic version string (e.g., "1.0.0")
- `name` - Human-readable name for the flow
- `description` - Brief description of what this flow contains
- `flow` - Array of flow nodes (see Node Types below)

---

## Node Types

### 1. Level Node

Triggers a match-3 level to be loaded and played.

```json
{
  "type": "level",
  "id": "level_01",
  "description": "First tutorial level"
}
```

**Fields:**

- `type` - Must be `"level"`
- `id` - Level identifier (format: `level_XX` where XX is a two-digit level number, e.g., `level_01`, `level_02`, `level_10`)
- `description` - Optional description for documentation

**Important:** Use the format `level_01`, `level_02`, etc. to match the actual level file naming convention (`level_01.json`, `level_02.json`). The ExperienceDirector will extract the number and load the corresponding level.

**Behavior:**

- Loads the specified level via GameManager
- Waits for `level_complete` event before advancing
- On `level_failed`, stays on current node (allows retry)

---

### 2. Narrative Stage Node

Triggers a narrative stage to be displayed.

```json
{
  "type": "narrative_stage",
  "id": "creation_day_1_intro",
  "description": "Introduction to creation story"
}
```

**Fields:**

- `type` - Must be `"narrative_stage"`
- `id` - Narrative stage identifier (should match a file in `data/narrative_stages/`)
- `description` - Optional description

**Behavior:**

- Loads narrative stage via NarrativeStageManager
- Marks stage as "seen" in ExperienceState
- Waits for narrative completion before advancing

---

### 3. Reward Node

Grants rewards to the player with optional animation.

```json
{
  "type": "reward",
  "id": "first_level_complete",
  "animation": "coin_burst",
  "rewards": [
    { "type": "coins", "amount": 100 },
    { "type": "gems", "amount": 5 },
    { "type": "booster", "booster_type": "hammer", "amount": 1 },
    { "type": "card", "id": "creation_card_1" },
    { "type": "theme", "id": "desert_theme" },
    { "type": "gallery_image", "id": "moses_parting_sea" }
  ]
}
```

**Fields:**

- `type` - Must be `"reward"`
- `id` - Unique reward identifier (prevents duplicate unlocks)
- `animation` - Optional animation type (see Reward Animations below)
- `rewards` - Array of reward objects

**Reward Types:**

1. **Coins:** `{ "type": "coins", "amount": 100 }`
2. **Gems:** `{ "type": "gems", "amount": 5 }`
3. **Booster:** `{ "type": "booster", "booster_type": "hammer", "amount": 1 }`
4. **Card:** `{ "type": "card", "id": "card_identifier" }`
5. **Theme:** `{ "type": "theme", "id": "theme_identifier" }`
6. **Gallery Image:** `{ "type": "gallery_image", "id": "image_identifier" }`

**Behavior:**

- Checks if reward already unlocked (via `id`)
- Grants rewards via RewardOrchestrator
- Plays animation if specified
- Marks reward as unlocked in ExperienceState

**Reward Animations:**

- `card_reveal` - Dramatic card flip reveal
- `coin_burst` - Coins exploding from center
- `theme_unlock` - Theme preview animation
- `gallery_unlock` - Gallery image reveal
- `simple` - Simple notification popup

---

### 4. Cutscene Node

Plays a pre-rendered cutscene or animated sequence.

```json
{
  "type": "cutscene",
  "id": "exodus_intro",
  "video": "res://videos/exodus_intro.webm",
  "skippable": true
}
```

**Fields:**

- `type` - Must be `"cutscene"`
- `id` - Cutscene identifier
- `video` - Path to video file (optional)
- `skippable` - Whether player can skip (default: true)

**Behavior:**

- Plays video or triggers cutscene system
- Waits for completion before advancing
- Can be skipped if `skippable` is true

---

### 5. Unlock Node

Unlocks game features (themes, boosters, etc.) without immediate reward.

```json
{
  "type": "unlock",
  "id": "hammer_booster",
  "unlock_type": "booster",
  "notify": true
}
```

**Fields:**

- `type` - Must be `"unlock"`
- `id` - Feature identifier to unlock
- `unlock_type` - Type of unlock (`booster`, `theme`, `feature`)
- `notify` - Show notification (default: true)

**Behavior:**

- Unlocks feature for purchase/use
- Shows notification if enabled
- Advances immediately

---

### 6. Ad Reward Node

Triggers an ad with reward on completion.

```json
{
  "type": "ad_reward",
  "id": "bonus_coins_offer",
  "ad_type": "rewarded",
  "reward": {
    "type": "coins",
    "amount": 500
  },
  "optional": true
}
```

**Fields:**

- `type` - Must be `"ad_reward"`
- `id` - Ad event identifier
- `ad_type` - Type of ad (`rewarded`, `interstitial`)
- `reward` - Single reward object
- `optional` - Whether player can skip (default: false)

**Behavior:**

- Triggers ad via AdMobManager
- Waits for ad completion
- Grants reward on success
- If `optional` is true, player can decline

---

### 7. Premium Gate Node

Checks for premium content unlock before continuing.

```json
{
  "type": "premium_gate",
  "id": "premium_chapter_2",
  "required": true,
  "offer_purchase": true,
  "fallback": "skip"
}
```

**Fields:**

- `type` - Must be `"premium_gate"`
- `id` - Gate identifier
- `required` - Whether premium is required (default: true)
- `offer_purchase` - Show purchase dialog if not premium
- `fallback` - Behavior if not premium (`skip`, `end_flow`, `continue`)

**Behavior:**

- Checks if player has premium unlock
- If not and `offer_purchase` is true, shows purchase dialog
- If not and `required` is true, applies fallback
- If premium, continues immediately

---

### 8. DLC Flow Node

Injects a DLC flow into the current experience.

```json
{
  "type": "dlc_flow",
  "id": "christmas_event_2026",
  "required": false,
  "fallback": "continue"
}
```

**Fields:**

- `type` - Must be `"dlc_flow"`
- `id` - DLC flow identifier
- `required` - Whether DLC is required (default: false)
- `fallback` - Behavior if DLC missing (`continue`, `skip`, `end_flow`)

**Behavior:**

- Checks if DLC flow exists
- If exists, pushes current flow to stack and loads DLC flow
- When DLC flow completes, returns to main flow
- If missing and not required, applies fallback

---

### 9. Conditional Node

Executes different branches based on conditions.

```json
{
  "type": "conditional",
  "condition": {
    "type": "level_stars",
    "level": 5,
    "min_stars": 3
  },
  "then": {
    "type": "reward",
    "id": "perfect_level_5",
    "rewards": [{ "type": "gems", "amount": 10 }]
  },
  "else": {
    "type": "reward",
    "id": "level_5_basic",
    "rewards": [{ "type": "coins", "amount": 100 }]
  }
}
```

**Fields:**

- `type` - Must be `"conditional"`
- `condition` - Condition object (see Condition Types below)
- `then` - Node to execute if condition is true
- `else` - Node to execute if condition is false (optional)

**Condition Types:**

1. **Level Stars:** `{ "type": "level_stars", "level": 5, "min_stars": 3 }`
2. **Total Stars:** `{ "type": "total_stars", "min_stars": 50 }`
3. **Currency:** `{ "type": "currency", "currency": "coins", "min_amount": 1000 }`
4. **Reward Unlocked:** `{ "type": "reward_unlocked", "reward_id": "card_1" }`
5. **Premium Status:** `{ "type": "premium", "value": true }`
6. **Achievement:** `{ "type": "achievement", "achievement_id": "combo_master" }`

**Behavior:**

- Evaluates condition
- Executes `then` branch if true
- Executes `else` branch if false (or continues if no else)
- Advances after branch completes

---

## Complete Example

```json
{
  "experience_id": "creation_arc_chapter_1",
  "version": "1.0.0",
  "name": "Creation Story - Chapter 1",
  "description": "The first chapter covering levels 1-10 with creation narrative",
  "flow": [
    {
      "type": "narrative_stage",
      "id": "creation_intro",
      "description": "God creates the heavens and earth"
    },
    {
      "type": "level",
      "id": "level_001",
      "description": "Tutorial: Basic matching"
    },
    {
      "type": "reward",
      "id": "first_level_reward",
      "animation": "coin_burst",
      "rewards": [
        { "type": "coins", "amount": 100 }
      ]
    },
    {
      "type": "unlock",
      "id": "hammer_booster",
      "unlock_type": "booster",
      "notify": true
    },
    {
      "type": "level",
      "id": "level_002"
    },
    {
      "type": "conditional",
      "condition": {
        "type": "level_stars",
        "level": 2,
        "min_stars": 3
      },
      "then": {
        "type": "reward",
        "id": "perfect_level_2",
        "rewards": [{ "type": "gems", "amount": 5 }]
      }
    },
    {
      "type": "narrative_stage",
      "id": "creation_day_2"
    },
    {
      "type": "level",
      "id": "level_003"
    },
    {
      "type": "reward",
      "id": "chapter_1_complete",
      "animation": "card_reveal",
      "rewards": [
        { "type": "coins", "amount": 500 },
        { "type": "gems", "amount": 10 },
        { "type": "card", "id": "creation_complete" }
      ]
    }
  ]
}
```

---

## Best Practices

### 1. Flow Organization

- Keep flows focused on a single story arc or chapter
- Use descriptive IDs and names
- Add descriptions to document designer intent

### 2. Reward Pacing

- Don't overwhelm players with too many rewards at once
- Space out major rewards (cards, themes) across multiple levels
- Use smaller rewards (coins, boosters) more frequently

### 3. Narrative Integration

- Place narrative stages at natural story beats
- Don't interrupt gameplay flow with too many narrative stages
- Use narrative stages to bookend level sequences

### 4. Conditional Logic

- Use conditionals to reward skilled play
- Provide fallback rewards for players who don't meet conditions
- Keep conditions simple and clear

### 5. DLC Integration

- Always make DLC optional unless it's required content
- Provide reasonable fallbacks for missing DLC
- Test flows with and without DLC present

### 6. Testing

- Test complete flows from start to finish
- Test all conditional branches
- Test failure and retry scenarios
- Test with different player states (new vs. returning)

---

## Validation

The ExperienceFlowParser validates:

1. Required fields present (`experience_id`, `version`, `flow`)
2. Flow is an array
3. Each node has a valid `type`
4. Type-specific required fields are present
5. References to external files exist (optional, warning only)

---

## File Naming Conventions

- Use lowercase with underscores: `creation_arc_chapter_1.json`
- Use descriptive names that indicate content
- Prefix with arc/story name for organization
- Test flows should be prefixed with `test_`

**Examples:**

- `main_story.json`
- `creation_arc_chapter_1.json`
- `exodus_arc_complete.json`
- `test_flow_simple.json`
- `christmas_event_2026.json`

---

## Version History

- **1.0.0** (2026-02-06) - Initial schema definition
