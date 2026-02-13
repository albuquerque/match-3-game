# JSON File Architecture and Game Flow

## Overview

This document explains how the game's JSON files work together to create the complete player experience. The architecture follows a hierarchical flow from high-level story progression down to individual level mechanics, with clear separation of concerns.

## Core Architecture

### 1. Experience Flows (`data/experience_flows/`)
**Purpose:** Defines the overall game progression and story structure.

**Files:**
- `main_story.json` - Primary game flow
- `dlc_flows/*.json` - DLC-specific flows

**Structure:**
```json
{
  "experience_id": "main_story",
  "flow": [
    {
      "type": "narrative_stage",
      "id": "creation_day_1",
      "description": "Introduction to creation"
    },
    {
      "type": "level",
      "id": "level_01",
      "description": "First level"
    },
    {
      "type": "reward",
      "id": "level_1_complete",
      "rewards": ["coins", "gems"]
    }
  ]
}
```

**Links to:**
- Narrative Stages (via `narrative_stage` type)
- Levels (via `level` type)
- Rewards (via `reward` type)

### 2. Narrative Stages (`data/narrative_stages/`)
**Purpose:** Handles in-game storytelling and visual effects during gameplay.

**Files:**
- `*.json` - Individual narrative stages (e.g., `exodus_sea_parting.json`)

**Structure:**
```json
{
  "id": "exodus_sea_parting",
  "name": "The Parting of the Red Sea",
  "anchor": "top_banner",
  "states": [
    {
      "name": "intro",
      "asset": "moses_full_sea.png",
      "position": "top_banner"
    }
  ],
  "transitions": [
    {
      "event": "level_start",
      "to": "intro"
    }
  ]
}
```

**Links to:**
- Assets (images/videos via `asset` field)
- Game events (via `transitions[].event`)
- Visual anchors (via `anchor` and `position`)

### 3. Chapters (`data/chapters/`)
**Purpose:** Groups levels and narrative content into themed chapters.

**Files:**
- `chapter_*.json` - Built-in chapters
- `user://dlc/chapters/*/manifest.json` - DLC chapters

**Structure:**
```json
{
  "chapter_id": "creation_story",
  "name": "Creation Story",
  "levels": [
    {
      "number": 1,
      "file": "level_01.json",
      "narrative_stage": "creation_day_1"
    }
  ],
  "effects": [
    {
      "trigger": "level_loaded",
      "effect": "progressive_brightness"
    }
  ]
}
```

**Links to:**
- Levels (via `levels[].file`)
- Narrative Stages (via `levels[].narrative_stage`)
- Effects (via `effects[]`)

### 4. Levels (`levels/`)
**Purpose:** Defines individual level mechanics and configuration.

**Files:**
- `level_*.json` - Individual level files

**Structure:**
```json
{
  "level_number": 1,
  "width": 8,
  "height": 8,
  "target_score": 5300,
  "moves": 25,
  "grid_layout": "...",
  "theme": "legacy",
  "collectible_target": 2,
  "unmovable_target": 6
}
```

**Links to:**
- Themes (via `theme`)
- Assets (backgrounds, tile textures via theme system)

### 5. Collections (`data/collections/`)
**Purpose:** Defines collectible items and rewards.

**Files:**
- `*.json` - Collection definitions

**Structure:**
```json
{
  "id": "creation_story_cards",
  "name": "Creation Story Cards",
  "items": [
    {
      "id": "adam_eve",
      "name": "Adam and Eve",
      "asset": "adam_eve_card.png",
      "rarity": "common"
    }
  ]
}
```

### 6. Flow Step Definitions (`data/flow_step_definitions/`)
**Purpose:** Centralize reusable flow node templates so experience flows stay concise and DRY. Instead of inlining every property on each flow node in `data/experience_flows/*`, you can reference a definition file and override only the properties you need.

**Location:** `data/flow_step_definitions/`

**File format:** Each definition is a JSON object with common node fields. Example:
```json
{
  "id": "narrative_fullscreen",
  "type": "narrative_stage",
  "auto_advance_delay": 3.5,
  "skippable": true,
  "anchor": "fullscreen",
  "metadata": { "description": "Default fullscreen narrative" }
}
```

**How to reference from a flow node:**
```json
// data/experience_flows/main_story.json
{
  "flow": [
    {
      "definition_id": "narrative_fullscreen",
      "id": "creation_day_1",
      "type": "narrative_stage",
      "auto_advance_delay": 4.0          // overrides definition's 3.5
    },
    {
      "definition_id": "level_generic",
      "id": "level_01",
      "type": "level"
    }
  ]
}
```

**Behavior:**
- The engine loads the external definition `res://data/flow_step_definitions/<definition_id>.json`.
- The parser merges the definition with the inline node object, with inline properties taking precedence.
- The merged node is then converted into a PipelineStep by `NodeTypeStepFactory`.

**Benefits:**
- Keep `data/experience_flows/*` clean and human-readable
- Reuse common patterns (e.g., `narrative_fullscreen`, `level_prefab`, `reward_small_pack`)
- Make global updates to behavior by editing a single definition file

**Migration guidance:**
- Find common repeated node blocks in `data/experience_flows/*`.
- Extract them into `data/flow_step_definitions/*.json` with a stable `id` field.
- Replace the inlined nodes with a short node that sets `definition_id` and any overrides.

**Notes:**
- Definitions are loaded from `res://data/flow_step_definitions/` or `user://flow_step_definitions/` allowing runtime overrides during QA.
- Keep definitions small and focused. Avoid putting level-specific identifiers in a generic definition.

## Game Flow

### Startup Flow
```
Game Launch
    ↓
Load ExperienceDirector
    ↓
Load main_story.json (Experience Flow)
    ↓
Load chapter_*.json (Chapters)
    ↓
Load LevelManager (loads level_*.json files)
    ↓
Load NarrativeStageManager
    ↓
Load CollectionManager
    ↓
Ready for gameplay
```

### Level Progression Flow
```
Player starts level
    ↓
ExperienceDirector loads current flow node
    ↓
If narrative_stage: Load narrative_stages/*.json
    ↓
Load level_*.json via LevelManager
    ↓
Apply chapter effects from chapters/*.json
    ↓
Start gameplay with narrative overlays
    ↓
On progress/events: Trigger narrative transitions
    ↓
On level complete: Grant rewards, advance flow
```

### DLC Flow
```
DLC installed
    ↓
AssetRegistry scans user://dlc/chapters/
    ↓
Load manifest.json for each chapter
    ↓
Register assets and levels
    ↓
ExperienceDirector can load DLC flows
    ↓
Levels reference DLC assets
```

## Asset Placement Guide

### Images and Textures (`textures/`)
```
textures/
├── backgrounds/          # Level backgrounds
│   ├── background.jpg
│   └── dlc_backgrounds/  # DLC backgrounds
├── tiles/               # Tile sprites
│   ├── legacy/          # Theme-specific tiles
│   └── modern/
├── narrative/           # Narrative stage images
│   ├── moses_full_sea.png
│   └── water_parting.svg
├── ui/                  # UI elements
│   ├── buttons/
│   └── icons/
└── themes/              # Theme assets
    ├── legacy/
    └── modern/
```

### Audio (`audio/`)
```
audio/
├── music/               # Background music
│   ├── level_1.mp3
│   └── menu_theme.ogg
├── sfx/                 # Sound effects
│   ├── match.wav
│   ├── level_complete.wav
│   └── button_click.wav
└── voice/               # Voice acting
    ├── narrator/
    └── character_lines/
```

### Effects (`data/effects/`)
```
data/
├── effects/             # Effect definitions
│   ├── progressive_brightness.json
│   ├── screen_flash.json
│   └── background_tint.json
└── chapters/            # Chapter-specific effects
    ├── chapter_level_1.json
```

### Videos (`videos/` or integrated)
```
videos/                  # Video files (if used)
├── cutscenes/
└── effects/
```
*Note: Videos are typically handled through the narrative system or as special assets*

### Rewards (`data/rewards/`)
```
data/
├── rewards/             # Reward definitions
│   ├── level_completion.json
│   └── achievement_unlocks.json
└── collections/         # Collectible rewards
    ├── creation_story_cards.json
```

## Linking System

### Experience Flow → Narrative Stages
```json
// experience_flows/main_story.json
{
  "type": "narrative_stage",
  "id": "exodus_sea_parting"
}

// Links to: data/narrative_stages/exodus_sea_parting.json
```

### Experience Flow → Levels
```json
// experience_flows/main_story.json
{
  "type": "level",
  "id": "level_01"
}

// Links to: levels/level_01.json
```

### Chapters → Levels & Effects
```json
// chapters/chapter_creation.json
{
  "levels": [
    {
      "number": 1,
      "file": "level_01.json",
      "narrative_stage": "creation_day_1"
    }
  ],
  "effects": [
    {
      "trigger": "level_loaded",
      "effect": "progressive_brightness"
    }
  ]
}

// Links to:
// - levels/level_01.json
// - data/narrative_stages/creation_day_1.json
// - data/effects/progressive_brightness.json
```

### Narrative Stages → Assets
```json
// narrative_stages/exodus_sea_parting.json
{
  "states": [
    {
      "asset": "moses_full_sea.png",
      "position": "top_banner"
    }
  ]
}

// Links to: textures/narrative/moses_full_sea.png
```

### Levels → Themes
```json
// levels/level_01.json
{
  "theme": "legacy"
}

// Links to: textures/themes/legacy/ (theme assets)
```

## Development Workflow

### Adding a New Level
1. Create `levels/level_XX.json` with level data
2. Add to appropriate chapter in `data/chapters/chapter_*.json`
3. Add to experience flow in `data/experience_flows/main_story.json`
4. Create narrative stage in `data/narrative_stages/` if needed
5. Add assets to appropriate `textures/` subdirectories

### Adding DLC Content
1. Create DLC structure in `user://dlc/chapters/chapter_name/`
2. Create `manifest.json` with chapter metadata
3. Add levels to `levels/` subdirectory
4. Add assets to `assets/` subdirectory
5. Create DLC flow in `data/experience_flows/dlc_*.json`

### Testing Flow
1. Use Godot's debugger to step through ExperienceDirector
2. Check console logs for flow progression
3. Verify asset loading in AssetRegistry
4. Test narrative transitions via EventBus

## File Dependencies

### Critical Path Files
- `data/experience_flows/main_story.json` - Must exist for game to start
- `data/chapters/chapter_builtin.json` - Base game chapters
- `levels/level_01.json` - First level must exist

### Optional Files
- Narrative stages can be missing (game continues without them)
- DLC files are loaded dynamically
- Effect files are loaded on demand

### Error Handling
- Missing experience flows: Game falls back to manual progression
- Missing narrative stages: Warning logged, level continues
- Missing assets: Fallback textures used
- Invalid JSON: Parse errors logged, game continues where possible

This architecture provides flexibility for content creation while maintaining clear separation between story, mechanics, and assets.
