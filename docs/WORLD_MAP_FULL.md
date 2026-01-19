# World Map — Implementation & Responsive Design

This document consolidates world map implementation details, responsive design guidelines, and redesign notes into a single reference.

## Redesign status
- ✅ REDESIGN COMPLETED — January 18, 2026
- The World Map uses a chapter-based layout with JSON-driven configuration and per-chapter backgrounds.

---

## Features & Overview
- JSON-driven configuration: `/levels/world_map.json` stores chapters, level positions, and metadata.
- Chapter-based design with themed backgrounds and progress gating.
- Responsive vertical top-to-bottom layout for each chapter with winding paths.
- Level names, star display, locked/unlocked visuals, responsive sizing for multi-resolution support.

---

## UI hierarchy (runtime)
```
WorldMap (Control)
├── Background (TextureRect) - Full screen
├── TopUI (Control) - Title, progress, back button
└── MapContainer (Control)
    └── ChaptersScroll (ScrollContainer)
        └── ChaptersVBox (VBoxContainer)
            ├── Chapter1-4 (Control) - Individual themed chapters
            │   ├── ChapterBackground (TextureRect)
            │   ├── ChapterTitle (Label)
            │   ├── LevelsContainer (Control)
            │   └── NextChapterButton (Button)
```

---

## JSON structure & coordinate system
- Positions are defined relative to a base canvas of 720x1280 (mobile portrait).
- Example JSON snippet:
```json
{
  "chapters": [
    {
      "name": "Genesis",
      "background": "res://textures/backgrounds/chapters/chapter_genesis.jpg",
      "levels": [
        { "level": 1, "pos": [360, 180], "name": "First Light" },
        ...
      ]
    }
  ]
}
```

- Use `scale_factor = Vector2(screen_size.x / 720.0, screen_size.y / 1280.0)` to translate JSON positions to screen coordinates.
- Button sizes and font sizes scale by `min(scale_factor.x, scale_factor.y)` to keep consistent proportions.

---

## Responsive layout guidelines
- Base design resolution: 720x1280.
- Safe horizontal margins: 5% each side (x from 36 to 684).
- Chapter title safe area: y = 30 to y = 110.
- Level interactive area: 65px radius around each center.
- Vertical spacing: ~70px between levels (scaled).
- For wider screens: center content and increase horizontal spacing; for taller screens: increase vertical spacing.

---

## Implementation notes (WorldMap.gd)
- `_load_world_map_data()` — parse `world_map.json`, validate entries.
- `_setup_ui()` — build the dynamic node hierarchy at runtime.
- `_populate_chapters()` — instantiate chapter containers and background nodes.
- `_create_level_button(level_info)` — create interactive level button with star overlay and label.
- `_scale_position(pos)` — utility to translate JSON coordinates to canvas coordinates.
- Connect `level_selected(level_number)` signal to `GameUI` for loading the selected level.

---

## Chapter backgrounds
- `textures/backgrounds/chapters/chapter_genesis.jpg` (blue)
- `chapter_exodus.jpg` (golden)
- `chapter_psalms.jpg` (green)
- `chapter_proverbs.jpg` (purple)

---

## Testing notes & debug
- Print scale factor and loaded chapter count on ready.
- Verify positions for multiple screen sizes using Godot's simulated viewport.
- Example debug log: `[WorldMap] Screen size: (720.0, 1280.0), Scale factor: (1.0, 1.0)`

---

## Known issues & fixes
- Fixed `LevelManager` JSON parsing issue by excluding `world_map.json` from level file lists (see changelog/history, Jan 18, 2026).

---

## Background generation prompt
Included in `WORLD_MAP_RESPONSIVE_DESIGN.md` (SVG overlay and generator prompt) — use the overlay when creating backgrounds that align to the interactive level circles.

---

Date: 2026-01-19
