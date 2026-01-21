# Level Generation Guide

## Overview
This document describes the level generation system for creating new game levels with varied difficulties and layouts.

## Level Generator Script

**Location:** `tools/generate_levels.py`

### Usage
```bash
python3 tools/generate_levels.py <start_level> <end_level>
```

**Example:**
```bash
python3 tools/generate_levels.py 11 50
```

## Level Configuration

### Difficulty Tiers

#### Easy Levels (Levels 11-20)
- **Grid Size:** 6x6 to 8x8
- **Moves:** 35-45
- **Target Score:** 5,000 - 8,000
- **Complexity:** Minimal obstacles (0-2 per row)
- **Focus:** Learning mechanics, building confidence

#### Medium Levels (Levels 21-35)
- **Grid Size:** 7x7 to 9x9
- **Moves:** 30-40
- **Target Score:** 8,000 - 12,000
- **Complexity:** Moderate obstacles (2-4 per row), corner patterns
- **Focus:** Strategic planning, combo building

#### Hard Levels (Levels 36-50+)
- **Grid Size:** 8x8 to 10x10
- **Moves:** 25-35
- **Target Score:** 12,000 - 18,000
- **Complexity:** Heavy obstacles (2-4 per row), symmetric patterns
- **Focus:** Advanced strategy, efficient moves

### Layout Format

Levels use a string-based layout format where:
- `0` = Playable tile position
- `X` = Blocked/non-playable position
- Rows separated by `\n`
- Cells separated by spaces

**Example:**
```json
{
  "level": 11,
  "width": 6,
  "height": 6,
  "target_score": 7583,
  "moves": 40,
  "description": "Plan your moves carefully!",
  "theme": "candy",
  "layout": "0 0 0 0 0 X\n0 0 0 0 0 0\nX 0 0 0 X 0\n..."
}
```

## Themes

Available themes rotate randomly:
- `classic` - Traditional gem matching
- `ocean` - Water/marine themed
- `space` - Cosmic/star themed
- `forest` - Nature themed
- `candy` - Sweet treats
- `modern` - Contemporary design
- `retro` - Vintage style
- `legacy` - Original game style

## Balance Considerations

### Scoring Balance
- Average score per tile: ~100 points
- Combos add 50% bonus per chain
- Special tiles provide significant bonuses
- Target scores are achievable with 70-80% efficiency

### Move Economy
- Easy: ~1 move per tile cleared
- Medium: ~0.8 moves per tile cleared
- Hard: ~0.6 moves per tile cleared

### Engagement Metrics
- Average completion time: 3-5 minutes per level
- Retry rate: Balanced to encourage but not frustrate
- Progressive difficulty curve maintains engagement

## Regenerating Levels

To update existing levels with new balance:
```bash
cd /Users/sal76/src/match-3-game
python3 tools/generate_levels.py 11 50
```

**Note:** This will overwrite existing level files. Back up important custom levels first.

## Future Enhancements

Potential improvements to the generator:
- [ ] Chapter-specific themes
- [ ] Special objectives (collect specific tiles, clear obstacles)
- [ ] Boss levels with unique mechanics
- [ ] Seasonal/event levels
- [ ] User-generated level validation
