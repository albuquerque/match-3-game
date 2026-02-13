# Purpose

This document specifies a **generic, extensible system** for narrative visuals and animations in a Match-3 game.

It is designed so that:

* Core animation logic ships **once** in the base game
* Levels, chapters, and future content define **intent via JSON**
* New chapters can be downloaded monthly with **new visuals and animations** without modifying game code

This document is suitable for direct use by an AI coding agent or engineer.

---

## Core Design Principles

1. **Separation of Concerns**

   * Code = systems, animation verbs, execution
   * Data (JSON) = intent, configuration, bindings

2. **Event-Driven**

   * Game emits events (e.g. `level_start`, `tile_destroyed`)
   * JSON reacts to events by declaring effects

3. **Verbs vs Nouns Rule**

   * Verbs (systems): implemented in code, versioned
   * Nouns (assets/config): shipped via chapters

4. **Fail-Safe by Default**

   * Missing effects fall back gracefully
   * Invalid JSON logs warnings, never crashes

---

## System Overview

```
[Game Event]
      ↓
[Effect Resolver]   (code)
      ↓
[Effect Definition] (JSON)
      ↓
[Asset Lookup]      (chapter bundle)
      ↓
[Animator System]
```

---

## Core Runtime Components (Code)

### 1. Event Bus

Responsible for broadcasting gameplay events.

Required events (minimum):

* `level_loaded`
* `level_start`
* `level_complete`
* `level_failed`
* `tile_spawned`
* `tile_matched`
* `tile_destroyed`
* `special_tile_activated`
* `spreader_tick`
* `spreader_destroyed`

Events must carry:

* Event name
* Source entity ID (optional)
* Context payload (JSON-like dictionary)

---

### 2. Effect Resolver

Central dispatcher that maps events to effects.

Responsibilities:

* Listen to all gameplay events
* Load active effect definitions
* Instantiate effect executors
* Pass parameters to executors

The resolver **must not** contain story-specific logic.

---

### 3. Effect Executors (Animation Verbs)

Each executor implements a single reusable behavior.

Required base executors:

* `play_animation`
* `state_swap`
* `timeline_sequence`
* `spawn_particles`
* `shader_param_lerp`
* `camera_impulse`
* `screen_overlay`

Each executor:

* Validates parameters
* Executes animation
* Reports completion (optional)

---

### 4. Visual Anchor System

Defines safe placement zones on the level screen.

Standard anchors:

* `background`
* `left_edge`
* `right_edge`
* `top_overlay`
* `bottom_overlay`
* `fullscreen_overlay`

Anchors map to predefined Node paths in the scene tree.

---

### 5. Asset Registry

Maps string IDs to runtime assets.

Responsibilities:

* Load assets from base game or chapter bundles
* Provide fallbacks
* Cache loaded assets

---

## JSON Data Model

### 1. Level Definition

```json
{
  "level_id": "string",
  "chapter_id": "string",
  "background": "asset_id",
  "effects": [ /* Effect Bindings */ ]
}
```

---

### 2. Effect Binding

Defines a reaction to an event.

```json
{
  "on": "event_name",
  "effect": "effect_type",
  "anchor": "anchor_id",
  "target": "entity|anchor|background",
  "params": { }
}
```

---

### 3. State-Based Visual Definition

Used for progressive visuals (buildings, trees, corruption, etc.).

```json
{
  "visual_id": "string",
  "states": [
    { "threshold": 0, "state": "state_id" },
    { "threshold": 3, "state": "state_id" }
  ],
  "on_destroy": {
    "effect": "effect_type",
    "params": { }
  }
}
```

---

### 4. Timeline Sequence (Composable)

```json
{
  "effect": "timeline_sequence",
  "steps": [
    { "effect": "play_animation", "params": {} },
    { "effect": "camera_impulse", "params": {} }
  ]
}
```

---

## Visual Layering Rules

1. Gameplay grid must never be obscured
2. Persistent story visuals live in edge anchors
3. Background animations must be slow and subtle
4. Cinematic overlays:

   * Max duration: 1–1.5s
   * Pause input briefly

---

## Chapter Bundle Structure

```
chapter_bundle/
 ├─ levels.json
 ├─ effects.json
 ├─ visuals.json
 ├─ assets/
 │   ├─ sprites/
 │   ├─ animations/
 │   ├─ particles/
 │   └─ shaders/
```

---

## Versioning Strategy

Each chapter declares:

```json
{
  "requires_engine_version": "1.2.0"
}
```

Resolver must reject incompatible chapters gracefully.

---

## Error Handling & Fallbacks

* Missing effect → no-op + warning
* Missing asset → placeholder
* Invalid params → default values

Never crash during gameplay.

---

## Extending the System (Future-Proofing)

Allowed without code changes:

* New visual assets
* New state configurations
* New event bindings

Requires code update:

* New effect executors
* New event types
* New animation logic

---

## Summary

This system enables:

* Monthly chapter releases
* Rich narrative visuals
* Minimal code churn
* Designer- and AI-friendly workflows

It deliberately limits power at the data layer to guarantee stability and scalability.
