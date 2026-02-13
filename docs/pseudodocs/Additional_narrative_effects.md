# Minimum Narrative Effects – Pre-Storyboard Implementation Spec

## Purpose

This document defines the **minimum required narrative effects** to implement *before* building the storyboard pipeline. These effects are intentionally small in scope, reuse existing systems, and provide maximum leverage for cinematic storytelling, pacing, and emotional control.

This spec is designed to be fed directly into an AI coding agent.

---

## Design Goals

* No gameplay rule changes
* Fully data-driven (JSON / `.tres` compatible)
* Composable via `timeline_sequence`
* Safe to trigger mid-level
* Graceful fallback if assets are missing

---

## Required Effects (Minimum Set)

### 1. `gameplay_pause`

#### Intent

Temporarily halt gameplay logic while allowing visual, camera, shader, and UI effects to continue.

Used to create **story panels**, dramatic pauses, and narrative emphasis.

#### Responsibilities

* Freeze board input and simulation
* Allow effects, camera, dialogue, overlays to continue
* Resume gameplay cleanly

#### Parameters

```json
{
  "effect": "gameplay_pause",
  "duration": 2.5,
  "resume_mode": "auto"
}
```

#### Notes

* Must stack safely (nested pauses resolve correctly)
* Must not reset timers or animation states

---

### 2. `camera_lerp` (Framing & Focus)

#### Intent

Gently guide player attention by reframing the camera.

Used for emphasis, reveals, and visual storytelling.

#### Responsibilities

* Smooth camera movement
* Optional zoom
* Optional soft-focus outside focal area

#### Parameters

```json
{
  "effect": "camera_lerp",
  "target": "board|region|tile|ui",
  "zoom": 1.1,
  "duration": 1.2,
  "easing": "ease_in_out"
}
```

#### Notes

* Extend existing camera system (`camera_impulse`)
* No sudden motion; narrative-friendly only

---

### 3. `narrative_dialogue` – Text Emphasis Extension

#### Intent

Enhance narrative dialogue with **kinetic typography** to reinforce emotional beats.

Used for iconic phrases and story moments.

#### Responsibilities

* Word-by-word reveal
* Emphasis on key words
* Sync with other effects

#### Extended Parameters

```json
{
  "effect": "narrative_dialogue",
  "title": "Creation",
  "message": "Let there be LIGHT",
  "reveal_mode": "typewriter",
  "emphasis": [
    { "word": "LIGHT", "style": "glow" }
  ]
}
```

#### Notes

* Backward compatible with existing dialogue
* Emphasis styles should be extensible

---

### 4. `symbolic_overlay`

#### Intent

Provide reusable **visual metaphors** (light, darkness, corruption, divinity) without gameplay impact.

Used to establish themes across multiple story beats.

#### Responsibilities

* Spawn semi-transparent symbolic textures
* Animate slowly (float, pulse, dissolve)
* Layer above board, below UI

#### Parameters

```json
{
  "effect": "symbolic_overlay",
  "asset": "light_rays.png",
  "blend": "additive",
  "motion": "slow_pulse",
  "opacity": 0.4,
  "duration": 4.0
}
```

#### Notes

* Implement as an extension of `screen_overlay`
* Long lifetime, low visual noise

---

## Composition Pattern

All effects must be composable via `timeline_sequence`.

### Example

```json
{
  "effect": "timeline_sequence",
  "steps": [
    { "effect": "gameplay_pause", "duration": 3.0 },
    { "effect": "camera_lerp", "zoom": 1.15, "duration": 1.0 },
    { "effect": "symbolic_overlay", "asset": "light_rays.png" },
    { "effect": "narrative_dialogue", "message": "Let there be LIGHT" }
  ]
}
```

---

## Non-Goals (Explicitly Out of Scope)

* Branching narrative logic
* Player choices
* Character animation rigs
* Cutscene timelines
* Voice acting systems

These belong **after** storyboard validation.

---

## Acceptance Criteria

* Effects trigger via data only
* No gameplay regressions
* All effects interrupt-safe
* Missing assets fail gracefully
* Can be reused across levels and DLC

---

## Outcome

With this minimum set implemented, the storyboard pipeline can be expressed as:

> **Storyboard Panel → Effect Stack → Emotional Beat**

No additional engine changes required.
