# ExperienceDirector Architecture Document

## Purpose

The ExperienceDirector is responsible for orchestrating the overall
player journey. It sits above gameplay systems and coordinates story
progression, rewards, and narrative events.

## Responsibilities

-   Control story flow and narrative progression
-   Manage reward triggers and unlocks
-   Coordinate NarrativeStage animations
-   Listen to EventBus gameplay events
-   Drive campaign progression

## Core Components

-   ExperienceDirector.gd
-   RewardManager.gd
-   ProgressionManager.gd
-   StoryboardLoader.gd

## Event Flow

1.  GameManager emits gameplay events
2.  EventBus distributes events
3.  ExperienceDirector listens and evaluates triggers
4.  NarrativeStage and RewardManager respond

## JSON Schema Example

{ "story_arc": "exodus", "levels": \[ { "id": 10, "narrative_stage":
"moses_sea", "rewards": \["gallery_sea_parted"\] } \] }

## Signals

-   level_started
-   objective_progress
-   level_completed
-   reward_unlocked

## Future Extensions

-   Seasonal content
-   Live events
-   AI-driven testing hooks
