# Gallery & Reward System Architecture

Purpose: Provide implementation instructions for an AI agent to build a
scalable gallery and reward system without creating giant files or
falling into God Orchestrator Syndrome.

------------------------------------------------------------------------

# 1. Design Principles

## Small Modules

-   Maximum file size: 400 lines
-   Preferred size: 150--300 lines
-   One responsibility per file

## No God Classes

Avoid controllers that manage: - shards - gallery - cards - rewards -
UI - animations

Use **event-driven composition** instead.

## Data Driven Content

All collectibles must live in data files.

Examples: data/gallery_items.json data/hero_cards.json

Adding new content must not require logic changes.

------------------------------------------------------------------------

# 2. Core Systems

The architecture is composed of several small systems:

EventBus ShardDropSystem RewardSystem GallerySystem CardSystem

UI components subscribe to events and render state.

------------------------------------------------------------------------

# 3. High Level Flow

Gameplay ↓ ShardDropSystem ↓ EventBus ↓ RewardSystem ↓ GallerySystem
CardSystem UI

Systems must not directly manipulate each other's state.

------------------------------------------------------------------------

# 4. Event Bus

File: systems/event_bus.py

Responsibilities:

-   register listeners
-   publish events
-   allow multiple subscribers

Example events:

ShardDiscovered ShardCollected GalleryItemUnlocked CardUnlocked
LevelCompleted

Keep the implementation very small.

------------------------------------------------------------------------

# 5. Data Models

## GalleryItem

Fields:

id name rarity shards_required current_shards category art_asset
silhouette_asset state

Example:

{ "id": "hanuman_flying", "rarity": "rare", "shards_required": 9,
"category": "artifacts" }

## HeroCard

Fields:

id name rarity owned

Example:

{ "id": "hanuman", "rarity": "rare", "owned": false }

------------------------------------------------------------------------

# 6. Shard Drop System

File: systems/shard_drop_system.py

Responsibilities:

-   determine which item receives shard
-   apply targeted shard algorithm
-   emit ShardDiscovered events

Inputs:

-   tile destruction
-   treasure tiles
-   combo triggers

Outputs: ShardDiscovered

------------------------------------------------------------------------

# 7. Targeted Shard Algorithm

Prefer items near completion.

Steps:

1.  Gather locked gallery items
2.  Calculate progress ratio
3.  Assign weighted probability
4.  Select item via weighted random

Example weight table:

progress \< 30% → weight 1 progress \< 70% → weight 2 progress \< 90% →
weight 5 progress ≥ 90% → weight 10

This ensures frequent unlock moments.

------------------------------------------------------------------------

# 8. Reward System

File: systems/reward_system.py

Responsibilities:

-   receive shard events
-   update player progress
-   trigger unlock events

Flow:

ShardDiscovered → RewardSystem → GallerySystem.add_shard

Reward system must not contain UI logic.

------------------------------------------------------------------------

# 9. Gallery System

File: systems/gallery_system.py

Responsibilities:

-   track shard progress
-   unlock items
-   expose gallery state

Functions:

add_shard(item_id) get_items() get_progress(item_id)

When shard requirement is reached: Emit GalleryItemUnlocked.

------------------------------------------------------------------------

# 10. Card System

File: systems/card_system.py

Responsibilities:

-   hero card drops
-   duplicate detection
-   duplicate → shard conversion

Events emitted:

CardUnlocked DuplicateCardConverted

This system must remain independent of gallery logic.

------------------------------------------------------------------------

# 11. Silhouette Gallery

Locked items appear as silhouettes.

Item states:

UNKNOWN DISCOVERED UNLOCKED

Transitions:

UNKNOWN → DISCOVERED when first shard obtained DISCOVERED → UNLOCKED
when shard requirement reached

------------------------------------------------------------------------

# 12. UI Layer

UI must be read-only regarding game state.

UI subscribes to:

ShardCollected GalleryItemUnlocked CardUnlocked

UI must never directly modify systems.

------------------------------------------------------------------------

# 13. File Structure

systems/ event_bus.py shard_drop_system.py reward_system.py
gallery_system.py card_system.py

models/ gallery_item.py hero_card.py

data/ gallery_items.json hero_cards.json

ui/ gallery_screen.py reward_popup.py

tests/

------------------------------------------------------------------------

# 14. Preventing Large Files

Rules:

-   one system per file
-   no UI logic in systems
-   split modules approaching 400 lines

------------------------------------------------------------------------

# 15. Testing

Required tests:

ShardDropSystem - weighted selection - targeted bias

GallerySystem - shard accumulation - unlock triggering

CardSystem - duplicate conversion

------------------------------------------------------------------------

# 16. Content Expansion

To add a new collectible:

1.  Add JSON entry
2.  Add artwork
3.  No code changes required

If code changes are needed, the architecture must be fixed.

------------------------------------------------------------------------

# 17. Future Extensions

Architecture must support:

-   seasonal items
-   special events
-   daily shard bonuses
-   secret collectibles

without modifying core systems.

------------------------------------------------------------------------

# 18. AI Implementation Rules

AI agents implementing this system must:

-   never create files larger than 400 lines
-   never merge systems into one class
-   keep systems event-driven
-   separate UI from logic
-   prefer composition over inheritance

------------------------------------------------------------------------

# End of Document
