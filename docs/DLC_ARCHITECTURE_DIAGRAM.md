# DLC System Architecture Diagram

## Level Data vs DLC Content

```
+-------------------------------------------------------------+
|                          YOUR GAME                          |
+-------------------------------------------------------------+
|                                                             |
|  +---------------+          +----------------------+        |
|  | Level Data    |          | DLC Chapter (local)  |        |
|  | (Built-in)    |          | (Downloaded to user) |        |
|  +---------------+          +----------------------+        |
|  | level_01.json |          | chapter_demo/        |        |
|  | - layout      |          | - levels: [61,62]    |        |
|  | - target      |          | - effects:           |        |
|  | - moves       |          |   * spawn_particles   |        |
|  +---------------+          |   * camera_impulse    |        |
|                             +----------------------+        |
|                                                             |
|        \___________________________|________________/        |
|                                    v                        |
|                          +----------------+                 |
|                          |  GameManager   |                 |
|                          |  (combines     |                 |
|                          |   built-in +   |                 |
|                          |   DLC content) |                 |
|                          +----------------+                 |
|                                    |                        |
|                                    v                        |
|                          +----------------+                 |
|                          | Visual Output   |                |
|                          | (Board + Effects)|                |
|                          +----------------+                 |
+-------------------------------------------------------------+
```

## Download Flow (simplified)

```
Player Device                HTTP Server (e.g. 192.168.0.110)
-------------                ---------------------------------
1) Fetch manifest_list.json  -> GET /dlc/manifest_list.json
   <- { chapters: [...] }
2) Download chapter ZIP      -> GET /dlc/chapters/chapter_demo.zip
   <- [zip bytes]
3) Extract to user://dlc/chapters/chapter_demo/
4) EffectResolver.load_effects(manifest)
5) Game uses chapter assets via AssetRegistry
```

## File Locations

```
GAME INSTALLATION (read-only)
res://
├── levels/
│   ├── level_01.json
│   ├── level_02.json
│   └── ...
└── scripts/
    ├── GameManager.gd
    ├── DLCManager.gd
    └── EffectResolver.gd

USER DATA DIRECTORY (writable)
user://
└── dlc/
    └── chapters/
        ├── chapter_demo/
        │   ├── manifest.json
        │   ├── levels/
        │   │   └── level_61.json
        │   └── assets/
        └── chapter_02/
```

## How Effects Enhance Levels

Without DLC: core gameplay runs using built-in levels (res://levels/*.json).
With DLC: additional visual/sound effects and assets are loaded from the chapter manifest and applied at runtime. The core gameplay (level layout, rules) remains unchanged.

## Event Flow (tile destroyed example)

```
GameBoard.gd
  ├─ detects tile matches
  ├─ calls EventBus.emit_tile_destroyed(entity_id, context)
  └─ EventBus broadcasts to listeners
       └─ EffectResolver receives event
           ├─ finds matching effect bindings for "tile_destroyed"
           └─ calls SpawnParticlesExecutor (if bound)
               └─ Particle system is instantiated at target location
```

## Summary

- Levels (res://levels) contain gameplay data and are always present.
- Chapters (user://dlc/chapters) contain optional visual/sound enhancements and are downloaded post-install.
- The EffectResolver maps events to effect executors and uses the AssetRegistry to load chapter assets at runtime.
- DLC only enhances visuals/sounds; it does not change core mechanics unless explicitly designed to do so.
