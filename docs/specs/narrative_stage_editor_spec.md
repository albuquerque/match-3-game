# AI Agent Specification: Narrative Stage Visual Editor

## 1. Objective

Build an Android visual editor application that allows users to design
narrative stages for a game using a canvas-based interface, and export
the result as: - A JSON configuration file - Associated image assets -
Packaged together as a ZIP archive

## 2. Core Concepts

### 2.1 Stage

A Stage represents a single narrative screen in the game.

Each stage contains: - Background image - Visual elements (text,
images) - Effects (gameplay or visual triggers)

### 2.2 Element Types

#### Text Element

-   Content string
-   Position (x, y)
-   Font size
-   Color
-   Alignment
-   Rotation (optional)
-   Scale (optional)

#### Image Element

-   Image reference
-   Position (x, y)
-   Scale
-   Rotation
-   Opacity

### 2.3 Effects

Effects are metadata attached to a stage.

Examples: - unlock_shard - play_animation - apply_blur - trigger_event

Each effect has: - Type - Trigger condition

## 3. UI/UX Requirements

### 3.1 Main Layout

#### Canvas Area (Primary)

-   Displays stage visually
-   Supports drag, scale, rotate
-   Layered rendering

#### Timeline Panel

-   Horizontal list of stages
-   Add, delete, reorder, select

#### Properties Panel

Context-sensitive editing panel

### 3.2 Interactions

-   Tap: Select
-   Drag: Move
-   Pinch: Scale
-   Long press: Duplicate/Delete

### 3.3 Modes

-   Edit Mode
-   Preview Mode

## 4. Data Model (JSON Output)

### Root

``` json
{
  "version": "1.0",
  "stages": []
}
```

### Stage

``` json
{
  "id": "stage_1",
  "background": "images/bg_stage_1.png",
  "elements": [],
  "effects": []
}
```

### Text Element

``` json
{
  "id": "el_1",
  "type": "text",
  "x": 0.5,
  "y": 0.7,
  "scale": 1.0,
  "rotation": 0,
  "text": "The journey begins...",
  "fontSize": 18,
  "color": "#FFFFFF",
  "alignment": "center"
}
```

### Image Element

``` json
{
  "id": "el_2",
  "type": "image",
  "x": 0.3,
  "y": 0.4,
  "scale": 1.2,
  "rotation": 0,
  "opacity": 1.0,
  "source": "images/overlay_1.png"
}
```

### Effects

``` json
{
  "type": "unlock_shard",
  "trigger": "on_complete",
  "params": {}
}
```

## 5. Asset Management

-   Import images
-   Store locally
-   Avoid filename collisions

Structure:

    /project/
      /images/
      stages.json

## 6. Export Requirements

ZIP structure:

    project_export.zip
      stages.json
      images/

-   Validate JSON
-   Ensure image references exist
-   Normalize coordinates

## 7. Internal State Model

-   Current stage
-   Selected element
-   Undo/Redo stack
-   Asset registry

## 8. Functional Requirements

-   Add/remove elements
-   Modify properties
-   Reorder layers
-   Stage management
-   Undo/Redo
-   Autosave

## 9. Technical Constraints

-   Android
-   Jetpack Compose
-   Kotlin

## 10. Validation Rules

-   No missing images
-   Valid positions
-   Valid effects
-   Unique IDs

## 11. Optional Enhancements

-   Snap-to-grid
-   Layer ordering
-   Animation preview
-   Cloud sync
-   Templates

## 12. Deliverables

-   Android app code
-   Visual editor
-   ZIP export
-   Sample project (3 stages)

## 13. Success Criteria

-   Non-technical user can create stages visually
-   Export works without manual fixes
