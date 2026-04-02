# Iterative Implementation Guide: Gallery & Reward System

Purpose: Provide a strict step‑by‑step implementation plan for an AI
coding agent so the system is built in small, verifiable slices. Each
step must produce a visible or testable result before moving forward.

Rules: - Do NOT implement future steps early. - Each step must
compile/run without errors. - Maximum file size: 400 lines. - If a step
fails, fix it before proceeding.

------------------------------------------------------------------------

# Phase 1 -- Gallery UI Foundation

## Step 1: Create Gallery Scene

Goal: Create a basic gallery UI that shows placeholder collectibles.

Tasks: - Create scene: `ui/gallery/gallery_screen.tscn` - Create
reusable item scene: `ui/gallery/gallery_item.tscn` - Display a grid of
9 items. - Each item shows: - silhouette image - title: "Unknown
Artifact" - shard progress label: "0 / 9"

Constraints: - No game logic - No systems - No JSON loading

Verification: - Gallery screen opens in game. - 9 placeholder tiles
appear.

------------------------------------------------------------------------

## Step 2: Add Visual Progress

Goal: Demonstrate shard progress visually.

Tasks: Hardcode progress values:

Item 1 → 3 / 9\
Item 2 → 7 / 12\
Item 3 → 0 / 6

Verification: Progress values render correctly.

------------------------------------------------------------------------

# Phase 2 -- Data Driven Gallery

## Step 3: Add Data File

Create:

`data/gallery_items.json`

Example entry:

{ "id": "artifact_001", "name": "Ancient Relic", "rarity": "rare",
"shards_required": 9, "art_asset": "res://assets/gallery/relic.png",
"silhouette_asset": "res://assets/gallery/relic_silhouette.png" }

Tasks: - Add at least 9 items.

Verification: File loads without errors.

------------------------------------------------------------------------

## Step 4: Load Data Into Gallery

Create:

`systems/gallery_data_loader.gd`

Responsibilities: - load JSON - create in-memory gallery item objects

Update UI: - populate grid using loaded data.

Verification: Gallery shows data from JSON instead of placeholders.

------------------------------------------------------------------------

# Phase 3 -- Gallery System

## Step 5: Create Gallery System

File:

`systems/gallery_system.gd`

Responsibilities: - track shard counts - store item state

Functions:

add_shard(item_id) get_progress(item_id) get_items()

Verification: System initializes successfully.

------------------------------------------------------------------------

## Step 6: Connect UI To Gallery System

Replace hardcoded progress values with values from the system.

Verification: UI reflects system data.

------------------------------------------------------------------------

# Phase 4 -- Debug Shard Collection

## Step 7: Debug Button

Add button to gallery screen:

"Add Shard"

Behavior: - randomly select item - call `gallery_system.add_shard()`

Verification: Shard counter increases.

------------------------------------------------------------------------

## Step 8: Unlock Logic

When shard count reaches requirement:

-   mark item as unlocked
-   replace silhouette with real art

Verification: Item visually unlocks.

------------------------------------------------------------------------

# Phase 5 -- Reward Popups

## Step 9: Reward Popup Scene

Create:

`ui/rewards/reward_popup.tscn`

Displays: - unlocked artwork - item name - rarity indicator

Verification: Popup opens when item unlocks.

------------------------------------------------------------------------

# Phase 6 -- Event System

## Step 10: Event Bus

File:

`systems/event_bus.gd`

Responsibilities: - register listeners - emit events

Events:

ShardCollected GalleryItemUnlocked

Verification: Events emit correctly.

------------------------------------------------------------------------

## Step 11: Convert Unlock To Event

Instead of UI polling:

Emit:

GalleryItemUnlocked

UI listens and shows popup.

Verification: Unlock popup triggered by event.

------------------------------------------------------------------------

# Phase 7 -- Shard Drop System

## Step 12: Create Shard Drop System

File:

`systems/shard_drop_system.gd`

Responsibilities: - choose which item gets shard - emit ShardCollected

Verification: Drop system selects items correctly.

------------------------------------------------------------------------

## Step 13: Targeted Drop Logic

Implement weighted drop algorithm.

Weighting:

\<30% → weight 1\
\<70% → weight 2\
\<90% → weight 5\
≥90% → weight 10

Verification: Items close to completion drop more frequently.

------------------------------------------------------------------------

# Phase 8 -- Gameplay Integration

## Step 14: Trigger Drops From Gameplay

Integrate with tile destruction.

Example triggers:

-   breaking special tile
-   treasure tile reveal
-   combo reward

Verification: Shard appears during gameplay.

------------------------------------------------------------------------

# Phase 9 -- Hero Card Rewards

## Step 15: Hero Card System

File:

`systems/card_system.gd`

Responsibilities: - random card drops - duplicate detection

Verification: Cards appear as rewards.

------------------------------------------------------------------------

## Step 16: Duplicate Conversion

Duplicate cards convert to shards.

Verification: Duplicate card increases shard progress.

------------------------------------------------------------------------

# Completion Criteria

System is complete when:

-   Gallery loads from JSON
-   Shards collected during gameplay
-   Items unlock with animation
-   Reward popup displays
-   Codebase remains modular

------------------------------------------------------------------------

# AI Agent Implementation Rules

The AI agent must:

-   implement only one step at a time
-   verify each step runs without errors
-   never exceed 400 lines per file
-   never merge systems together
-   never implement future steps early

If a step fails verification, stop and fix before continuing.

------------------------------------------------------------------------

End of Guide
