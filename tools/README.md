# Game Development Tools

This folder contains utility scripts for game development and content creation.

## Level Generator

### generate_levels.py

Python script to automatically generate match-3 game levels with varied shapes and objectives.

**Features:**
- Multiple grid shapes: rectangle, diamond, cross, hourglass, hexagon, corners
- Progressive difficulty scaling
- Biblical-themed level names
- Automatic target score calculation
- Customizable starting level and output directory
- Reproducible generation with seed support

**Usage:**

```bash
# Generate 40 levels starting from level 11
python3 tools/generate_levels.py 40

# Generate 20 levels starting from level 51
python3 tools/generate_levels.py 20 --start 51

# Generate 10 levels with random seed for reproducibility
python3 tools/generate_levels.py 10 --seed 42

# Generate to custom output directory
python3 tools/generate_levels.py 5 --output data/test_levels
```

**Options:**
- `count` (required): Number of levels to generate
- `--start N`: Starting level number (default: 11)
- `--output DIR`: Output directory (default: levels)
- `--seed N`: Random seed for reproducible generation

**Level Configuration:**
Each generated level includes:
- Level number and biblical name
- Grid layout (8x8 or 9x9 with varying shapes)
- Move count (20-40 based on difficulty)
- Target score (auto-calculated based on grid size)
- Description text

**Examples:**

Generate levels 11-50 (40 levels):
```bash
python3 tools/generate_levels.py 40
```

Generate levels 100-199 (100 levels):
```bash
python3 tools/generate_levels.py 100 --start 100
```

Generate test levels with reproducible output:
```bash
python3 tools/generate_levels.py 10 --seed 12345 --output test_levels
```

**Output Format:**

Generates JSON files in the format `level_NN.json`:

```json
{
  "level_number": 15,
  "name": "Manna Rain",
  "description": "Match tiles to reach 5500 points in 30 moves!",
  "moves": 30,
  "target": 5500,
  "layout": [
    [0, 0, 1, 1, 1, 1, 0, 0],
    [0, 1, 1, 1, 1, 1, 1, 0],
    ...
  ]
}
```

Where:
- `1` = playable tile position
- `0` = blocked/empty position

## Adding New Tools

To add new development tools:

1. Create your script in this `tools/` folder
2. Make it executable: `chmod +x tools/your_script.py`
3. Add documentation to this README
4. Include usage examples

## Requirements

Python 3.6+ (uses standard library only, no external dependencies)
