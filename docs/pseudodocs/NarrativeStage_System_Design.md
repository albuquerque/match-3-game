tree# NarrativeStage System Design

## Purpose

NarrativeStage provides a dedicated animated storytelling layer above
the game board.

## Responsibilities

-   Display animated story scenes
-   React to gameplay events
-   Play symbolic animations
-   Manage narrative actors and visual transitions

## Scene Structure

MainGame ├ NarrativeStage ├ GameBoard ├ GameUI

## Core Scripts

-   NarrativeStage.gd
-   NarrativeActor.gd
-   StageAnimationController.gd

## Event Integration

NarrativeStage subscribes to EventBus: - level_started -
combo_achieved - objective_progress - level_complete

## JSON Configuration Example

{ "stage": "moses_sea", "states": \[ {"event": "level_start",
"animation": "sea_closed"}, {"event": "goal_50_percent", "animation":
"sea_cracking"}, {"event": "goal_complete", "animation": "sea_parted"}
\] }

## Visual Anchors

-   NARRATIVE_STAGE
-   BACKGROUND_LAYER
-   SYMBOLIC_EFFECT_LAYER

## Supported Effects

-   play_stage_animation
-   spawn_actor
-   change_background
-   trigger_particles

## Future Extensions

-   Cinematic cutscenes
-   Dynamic lighting
-   Procedural storytelling
