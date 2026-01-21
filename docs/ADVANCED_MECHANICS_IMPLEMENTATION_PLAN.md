# Advanced Game Mechanics Implementation Plan

## Overview
This document outlines the implementation plan for advanced game mechanics that will significantly enhance gameplay variety and engagement.

## Mechanics to Implement

### Phase 1: Collectible Items (Priority: High)
**Description:** Items drop from top and must reach the bottom to be collected.

**Implementation Steps:**
1. Create `CollectibleItem` class extending `Node2D`
2. Add collectible tracking to `GameManager`
3. Update gravity/falling logic to handle collectibles
4. Add UI counter for collected items
5. Update level format to support collectibles
6. Add win condition: collect X items

**Technical Details:**
- Collectibles spawn at top when tiles are cleared
- Follow gravity but cannot be matched or destroyed
- Track collection count in level progress
- Visual: distinct sprite (coins, gems, artifacts)

**Level JSON Format:**
```json
{
  "collectibles": {
    "enabled": true,
    "types": ["coin"],
    "required": 10,
    "spawn_rate": 0.3
  }
}
```

---

### Phase 2: Obstacle Tiles (Priority: High)
**Description:** Unmovable tiles that require matches to destroy.

#### 2.1 Soft Obstacles (Single Hit)
- **Examples:** Wooden crate, snow, vines
- **Behavior:** Destroyed by 1 match adjacent or special tile effect
- **Implementation:** `ObstacleTile` with `hits_remaining = 1`

#### 2.2 Hard Obstacles (Multiple Hits)
- **Examples:** Metal crate, rock, ice
- **Behavior:** Requires 3+ match adjacent, special tiles count as 1 hit
- **Implementation:** `ObstacleTile` with `hits_remaining = 3`

#### 2.3 Chained Objects (Advanced)
- **Examples:** Blocks on chains/ropes
- **Behavior:** Move toward anchor point when adjacent tiles cleared
- **Implementation:** `ChainedObstacle` with directional movement
- **Win Condition:** All chained objects reach edges

**Implementation Steps:**
1. Create `ObstacleTile` class with hit tracking
2. Add visual state changes (damage progression)
3. Update match detection to ignore obstacles
4. Add adjacent match detection for obstacle damage
5. Create chain/rope system with anchor points
6. Add chain movement logic
7. Update level format for obstacles

**Level JSON Format:**
```json
{
  "obstacles": [
    {"type": "crate_soft", "position": [2, 3], "hits": 1},
    {"type": "rock_hard", "position": [4, 5], "hits": 3},
    {
      "type": "chained",
      "position": [3, 3],
      "chain_direction": "down",
      "anchor": [3, 7],
      "required_distance": 4
    }
  ]
}
```

---

### Phase 3: Reverse Gravity (Priority: Medium)
**Description:** Tiles fall upward instead of downward.

**Implementation Steps:**
1. Add `gravity_direction` property to level config
2. Update `apply_gravity()` in `GameManager`
3. Reverse spawn position (bottom instead of top)
4. Update tile animations for upward movement
5. Adjust collectible behavior for reverse gravity

**Level JSON Format:**
```json
{
  "gravity_direction": "up"
}
```

---

### Phase 4: Transformable Tiles (Priority: Medium)
**Description:** Special tiles that transform when matched nearby.

**Examples:**
- Light bulb: off → on
- Flower: bud → bloom
- Egg: unhatched → hatched

**Implementation Steps:**
1. Create `TransformableTile` class
2. Add transformation state tracking
3. Create transformation animations
4. Add proximity match detection
5. Track transformation progress
6. Win condition: all tiles transformed

**Level JSON Format:**
```json
{
  "transformable_tiles": {
    "enabled": true,
    "type": "flower",
    "positions": [[2,2], [4,4], [6,6]],
    "states": ["bud", "bloom"],
    "required_matches_nearby": 1
  }
}
```

---

## Implementation Priority

### Phase 1 (Week 1-2): Foundation
- [ ] Create base classes for new tile types
- [ ] Update level JSON schema
- [ ] Implement collectible items system
- [ ] Add soft obstacles (single hit)

### Phase 2 (Week 3-4): Advanced Obstacles
- [ ] Implement hard obstacles (multiple hits)
- [ ] Create chain/rope system
- [ ] Add obstacle visual states
- [ ] Update level generator for obstacles

### Phase 3 (Week 5): Alternative Physics
- [ ] Implement reverse gravity
- [ ] Test and balance
- [ ] Create sample levels

### Phase 4 (Week 6): Transformations
- [ ] Implement transformable tiles
- [ ] Create transformation animations
- [ ] Add UI feedback for transformations

---

## Technical Architecture

### New Classes

```gdscript
# scripts/CollectibleItem.gd
class_name CollectibleItem extends Node2D
- var item_type: String
- var grid_position: Vector2
- func collect() -> void

# scripts/ObstacleTile.gd
class_name ObstacleTile extends Node2D
- var obstacle_type: String
- var hits_remaining: int
- var is_chained: bool
- var chain_anchor: Vector2
- func take_damage(amount: int) -> void
- func is_destroyed() -> bool

# scripts/TransformableTile.gd
class_name TransformableTile extends Node2D
- var transformation_type: String
- var current_state: int
- var max_states: int
- func transform_next() -> bool
```

### Updated Systems

**GameManager Updates:**
```gdscript
- var collectibles_required: int = 0
- var collectibles_collected: int = 0
- var obstacles: Array[ObstacleTile] = []
- var transformables: Array[TransformableTile] = []
- var gravity_direction: String = "down"

func check_win_condition() -> bool:
    # Check score, collectibles, obstacles cleared, transformations
```

**Level Format Extensions:**
```json
{
  "level": 51,
  "width": 8,
  "height": 8,
  "target_score": 10000,
  "moves": 30,
  "layout": "...",
  "objectives": {
    "score": 10000,
    "collectibles": 10,
    "clear_obstacles": true,
    "transform_all": false
  },
  "collectibles": {...},
  "obstacles": [...],
  "transformables": {...},
  "gravity_direction": "down"
}
```

---

## UI Updates Needed

1. **Objective Panel:** Show multiple win conditions
   - Score progress bar
   - Collectibles counter (e.g., "Coins: 7/10")
   - Obstacles remaining
   - Transformations completed

2. **In-Game Feedback:**
   - Collectible collection animation
   - Obstacle damage indicators
   - Transformation effects
   - Progress notifications

3. **Level Select:** Show level objectives preview

---

## Asset Requirements

### Collectibles
- Gold coin sprite
- Gem sprite
- Artifact sprite
- Collection particle effects

### Obstacles
- Wooden crate (intact + damaged)
- Metal crate (intact + 2 damage states)
- Rock/ice (intact + 2 damage states)
- Chain/rope sprites
- Breaking animations

### Transformables
- Light bulb (off/on)
- Flower (bud/bloom)
- Egg (whole/cracked/hatched)

---

## Testing Strategy

1. **Unit Tests:**
   - Collectible spawning and collection
   - Obstacle damage calculation
   - Chain movement logic
   - Transformation state tracking

2. **Integration Tests:**
   - Multiple mechanics in one level
   - Edge cases (no valid moves with obstacles)
   - Performance with many objects

3. **Playtest Levels:**
   - Pure collectible level
   - Pure obstacle level
   - Mixed mechanics level
   - Reverse gravity level

---

## Implementation Status

### Phase 1: Collectible Items - COMPLETED ✓

**Progress:**
- [x] Implementation plan created
- [x] CollectibleItem class created
- [x] GameManager integration for collectible tracking
- [x] Level JSON format updates
- [x] Test level created (level_51.json)
- [x] GameBoard integration for spawning/collecting
- [x] Collectible gravity and collection at bottom
- [ ] UI counter implementation (NEXT)

### Phase 2: Obstacle Tiles - COMPLETED ✓

**Progress:**
- [x] ObstacleTile class created
- [x] GameManager integration for obstacle tracking
- [x] Level JSON format updates
- [x] Test level created (level_52.json)
- [x] GameBoard integration for obstacle placement
- [x] Damage detection from adjacent matches
- [ ] Chain system implementation (FUTURE)
- [ ] UI display for obstacles remaining (NEXT)

### Phase 3: Reverse Gravity - COMPLETED ✓

**Progress:**
- [x] Gravity direction property added to GameManager
- [x] apply_gravity_up() implemented
- [x] apply_gravity_left() implemented
- [x] apply_gravity_right() implemented
- [x] Level JSON format updates
- [x] Test level created (level_53.json)
- [x] Collectible gravity respects gravity direction
- [ ] GameBoard visual updates for different gravity (FUTURE)

### Phase 4: Transformable Tiles - COMPLETED ✓

**Progress:**
- [x] TransformableTile class created
- [x] GameManager integration for transformable tracking
- [x] Level JSON format updates
- [x] Test level created (level_54.json)
- [x] GameBoard integration for transformable placement
- [x] Proximity match detection
- [ ] Transformation animations (FUTURE)
- [ ] UI display for transformation progress (NEXT)

### Mixed Mechanics Level - CREATED ✓
- [x] Level 55 with collectibles + obstacles created

**Next Immediate Steps:**
1. Update GameBoard to spawn and manage CollectibleItem instances
2. Update GameBoard to spawn and manage ObstacleTile instances
3. Update GameBoard to spawn and manage TransformableTile instances
4. Implement collectible spawning on tile removal
5. Implement obstacle damage from adjacent matches
6. Implement transformable proximity detection
7. Create UI displays for objectives (collectibles counter, obstacles remaining, etc.)
8. Add visual feedback for new mechanics
9. Create placeholder textures for collectibles, obstacles, and transformables
10. Test all mechanics in gameplay

## Next Steps

1. ~~Review and approve implementation plan~~ ✓ APPROVED
2. ~~Create base classes~~ ✓ COMPLETED
3. ~~Update GameManager~~ ✓ COMPLETED
4. ~~Create test levels~~ ✓ COMPLETED
5. Update GameBoard integration (IN PROGRESS)
6. Create UI displays for objectives
7. Create placeholder textures
8. Playtest and balance

