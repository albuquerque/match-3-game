# Experience Director Architecture

## Purpose

The Experience Director is the high level orchestrator responsible for:

* Story progression
* Reward delivery
* Narrative stage triggering
* Level transitions
* Monetisation hooks
* Gallery and Collection unlocks
* DLC content injection

It operates above GameManager and LevelManager and drives the overall player journey.

---

## Core Responsibilities

### 1. Progression Control

Controls the player journey through:

* Worlds
* Chapters
* Levels
* Story Beats

Reads configuration from JSON:

```json
{
  "experience_flow": [
    { "type": "narrative_stage", "id": "creation_day_1_intro" },
    { "type": "level", "id": "level_001" },
    { "type": "reward", "id": "card_light_unlocked" }
  ]
}
```

---

### 2. Reward Orchestration

Does NOT replace RewardManager.

Instead:

ExperienceDirector -> RewardOrchestrator -> RewardManager

RewardOrchestrator responsibilities:

* Batch rewards
* Handle unlock timing
* Trigger animations
* Manage post-level reward pipelines

---

### 3. Narrative Trigger Integration

Listens to:

* Level Complete
* Match Events
* Boss Events
* DLC Events

Publishes:

* NarrativeStageStart
* NarrativeStageUpdate
* NarrativeStageComplete

via EventBus.

---

### 4. Monetisation Hooks

Supports:

* Ad reward triggers
* Premium unlock gating
* Booster unlock pacing

Integrates with:

AdMobManager
DLCManager

---

### 5. Collection and Gallery System

Unlockable Assets:

* Story Cards
* Historical Scenes
* Character Entries
* Animated Panels

Unlock flow:

Level Complete -> ExperienceDirector -> RewardOrchestrator -> RewardManager -> Gallery Unlock

---

## Architecture Placement

Layer Model:

UI Layer
NarrativeStage System
Experience Director
Game Systems
Engine

---

## Core Modules

### ExperienceDirector.gd

Responsibilities:

* Load experience JSON
* Maintain progression index
* Trigger next step
* Queue narrative stages
* Queue rewards
* Dispatch level transitions

---

### RewardOrchestrator.gd

Responsibilities:

* Translate reward JSON
* Batch reward animations
* Prevent duplicates
* Sync gallery unlock state

---

### ExperienceState

Stores:

* Current World
* Current Chapter
* Level Index
* Unlocked Rewards
* Seen Narrative Stages

Persisted via Save System.

---

## Integration Points

GameManager:

* startLevel(levelID)
* endLevel(result)

LevelManager:

* loadLevelData()

NarrativeStageSystem:

* playStage(stageID)

RewardManager:

* grantReward(rewardData)

EventBus:

* publish events

---

## JSON Driven Philosophy

All experience is data driven.

Designers should be able to modify:

* Story pacing
* Rewards
* Monetisation
* Narrative triggers

without code changes.

---

## Example Flow

Player completes level.

EventBus -> LevelCompleted

ExperienceDirector:

* Reads experience flow
* Triggers narrative stage
* Dispatches reward
* Loads next level

