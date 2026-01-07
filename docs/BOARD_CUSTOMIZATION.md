# Board Appearance & Background — Customization and Implementation Guide

This document consolidates the board appearance customization guide and the implementation notes for the board and background systems.

Goals covered here:
- How to configure border color and background image
- What the code implements and where (quick implementation summary)
- Runtime API for changing appearance
- Small troubleshooting / tips section (concise)

---

## Quick Customization (what you’ll usually change)

### Border color
Change the color of the board border by setting the `border_color` variable or calling `set_border_color()` at runtime.

Examples:
```gdscript
# In scripts/GameBoard.gd (in _ready or before draw_board_borders())
border_color = Color(1.0, 0.8, 0.2, 1.0)  # Gold

# Or at runtime from another script:
get_node("/root/MainGame/GameBoard").set_border_color(Color(0.2, 0.8, 1.0, 1.0))
```

Alpha controls translucency (1.0 = opaque).

### Background image
Add a fullscreen background image that fills the screen and sits behind the UI and board.

- Put your image into `textures/` (PNG, JPG/JPEG, WebP recommended)
- Set the path in `scripts/GameBoard.gd` by setting `background_image_path` in `_ready()` or at runtime

Example:
```gdscript
# In scripts/GameBoard.gd _ready()
background_image_path = "res://textures/background.jpg"

# Or at runtime
get_node("/root/MainGame/GameBoard").set_background_image("res://textures/background.jpg")
```

Behavior:
- The image is presented with `TextureRect` using `STRETCH_KEEP_ASPECT_COVERED` and sized to cover the visible viewport
- The background is added to the `MainGame` (Control) node so it participates correctly in the UI tree
- Board overlay and tiles render above the background

---

## Implementation summary (what the code does, and where)

Primary file changed: `scripts/GameBoard.gd`

Key additions and changes:
- `border_color: Color` — configurable color used by border lines and corner arcs
- `background_image_path: String` and `background_sprite` — background image support
- `setup_background_image()` — loads/creates `TextureRect`, scales it to cover the viewport, and adds it to `MainGame` (deferred)
- Overlay system:
  - a `tile_area_overlay` container that holds semi-transparent `ColorRect`s per active tile so the board area is translucent while holes remain transparent
- Border drawing uses the configurable `border_color` and draws straight segments + quarter-circle arcs
- Tiles use `shaders/rounded_tile.gdshader` to clip tile textures to rounded rectangles (applied in `scripts/Tile.gd`)

Other touched files (brief):
- `scripts/Tile.gd` — applies `rounded_tile.gdshader` to tile sprites and updates collision shapes
- `shaders/rounded_tile.gdshader` — simple canvas_item shader that clips sprite pixels to a rounded rectangle

---

## Runtime API

From any script, you can do:
```gdscript
var board = get_node("/root/MainGame/GameBoard")
board.set_border_color(Color(0.9, 0.9, 1.0, 0.9))
board.set_background_image("res://textures/background.jpg")
```

If you need to update appearance immediately, call `board.draw_board_borders()` after changing `border_color` (although `set_border_color()` already triggers a redraw).

---

## Visual Behavior & Notes

- Tiles: rounded corners via a shader. The shader parameter `corner_radius` (set in `Tile.gd`) controls visual roundness.
- Board overlay: semi-transparent per-tile `ColorRect`s placed above the background so the active area is translucent while blocked cells are fully transparent.
- Border lines and corner arcs are drawn with `Line2D` using `border_color` and `BORDER_WIDTH`.

Performance notes:
- The per-tile overlay is straightforward and performant for typical grid sizes; if you have very large grids consider a shader-based mask approach.
- Background images should be reasonable in size (recommendations below) to avoid high memory usage on constrained devices.

Recommended background specs:
- Resolution: >= 1920x1080 for HD targets
- Format: PNG/JPEG/WebP
- File size: keep under ~2MB for mobile builds

---

## Brief Troubleshooting & Tips (concise)

If you don’t see the background image:
- Confirm `background_image_path` is correct and the file is present in `textures/`
- Check Godot console for `[GameBoard]` debug messages — code prints load/size/position diagnostics
- Ensure the project’s `MainGame` scene contains `GameBoard` as a child at runtime (background is added to the parent of `GameBoard`)

If the board looks fully transparent or opaque:
- Adjust the overlay alpha in `GameBoard.gd` at the line that creates the per-tile ColorRect:
  - `tile_overlay.color = Color(0.1, 0.15, 0.25, 0.5)` — change `0.5` to taste

If borders don’t show the chosen color:
- Call `set_border_color()` or `draw_board_borders()` after changing `border_color`

---

## Files touched by this feature

- `scripts/GameBoard.gd` — main implementation (borders, background, overlay)
- `scripts/Tile.gd` — applies rounded-corner shader and updates collision shape
- `shaders/rounded_tile.gdshader` — shader for rounded tile visuals
- `textures/*` — place background images here

---

## Example (complete snippet)

```gdscript
func _ready():
    # Custom border color
    border_color = Color(1.0, 0.8, 0.2, 1.0)

    # Background (put the file in textures/)
    background_image_path = "res://textures/background.jpg"

    # Ensure setup is run (GameBoard already does this in _ready())
    setup_background_image()
```

---

If you'd like, I can:
- Reduce this doc to a single one-page quickstart, or
- Add an example screenshot and default configuration block to the repo
