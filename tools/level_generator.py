#!/usr/bin/env python3
"""
Level generator for match-3-game
Generates level JSON files named level_XX.json in the project's levels/ directory.
Layout format matches existing levels: a single string where each row is concatenated and rows are separated by '\n' or simply concatenated in the string (existing files use a single string without explicit newlines in JSON). We'll follow the format used in docs: layout is a string of length width*height using '0' for playable cell, 'X' for blocked cell and other letters for special tiles (e.g., 'U' for unmovable soft, 'H' for hard unmovable, 'C' for collectible spawn marker).

Usage:
    python3 tools/level_generator.py --start 11 --end 50 --out levels/

This script will attempt to keep targets and moves reasonable.
"""
import json
import os
import random
import argparse

LEVEL_TEMPLATE = {
    "level_number": 0,
    "title": "Generated Level",
    "description": "Auto-generated level",
    "grid_width": 8,
    "grid_height": 8,
    "target_score": 3000,
    "max_moves": 30,
    "num_tile_types": 6,
    "theme": "legacy",
    "layout": "",
    "collectible_target": 0  # Number of collectibles to collect (0 = score-based level)
}

SPECIAL_CHARS = {
    'blocked': 'X',
    'playable': '0',
    'collectible': 'C',
    'unmovable_soft': 'U',
    'unmovable_hard': 'H'
}

# Simple shapes to add variety
SHAPES = [
    # Full rectangle
    lambda w, h: [['0' for _ in range(w)] for __ in range(h)],
    # Hollow center
    lambda w, h: [[('0' if x==0 or y==0 or x==w-1 or y==h-1 else 'X') for x in range(w)] for y in range(h)],
    # Cross
    lambda w, h: [[('0' if x==w//2 or y==h//2 else 'X') for x in range(w)] for y in range(h)],
    # Diagonal playable
    lambda w, h: [[('0' if x==y or x==w-y-1 else 'X') for x in range(w)] for y in range(h)],
]


def generate_layout(w, h, shape_func, special_density=0.05):
    grid = shape_func(w, h)
    # Replace some playable cells with collectibles or unmovable tiles
    playable_cells = [(x,y) for y in range(h) for x in range(w) if grid[y][x]=='0']

    # Filter out bottom row from collectible candidates
    bottom_row = h - 1
    collectible_candidates = [(x,y) for (x,y) in playable_cells if y != bottom_row]

    random.shuffle(collectible_candidates)
    # Add collectibles (but not in bottom row)
    num_collect = max(1, int(len(playable_cells) * special_density))
    for i in range(min(num_collect, len(collectible_candidates))):
        x,y = collectible_candidates[i]
        grid[y][x] = SPECIAL_CHARS['collectible']

    # Add a few unmovable tiles (can be anywhere)
    random.shuffle(playable_cells)
    for i in range(int(len(playable_cells)*special_density/2)):
        x,y = playable_cells[i]
        # Don't overwrite collectibles
        if grid[y][x] == '0':
            grid[y][x] = random.choice([SPECIAL_CHARS['unmovable_soft'], SPECIAL_CHARS['unmovable_hard']])
    # Convert grid rows to string - use '0' for playable, 'X' for blocked, special chars left as-is
    rows = [''.join(grid[y]) for y in range(h)]
    # Join with newlines and add spaces between cells to match existing level format
    layout_rows = []
    for row_str in rows:
        # Add space between each character
        spaced_row = ' '.join(row_str)
        layout_rows.append(spaced_row)
    # Join rows with newline
    layout = '\n'.join(layout_rows)
    return layout


def estimate_target_and_moves(level_index, w, h):
    # base difficulty scales with level index and grid size
    # Increased for better engagement
    base = 5000 + level_index * 250
    size_factor = (w*h) / 64.0
    target = int(base * size_factor)
    # More generous moves for better user engagement
    moves = max(20, int(25 + level_index * 0.5))
    return target, moves


def write_level(out_dir, level_num, w=8, h=8):
    shape = random.choice(SHAPES)
    layout = generate_layout(w, h, shape, special_density=0.06)
    target, moves = estimate_target_and_moves(level_num, w, h)

    # Count collectibles in layout
    num_collectibles = layout.count('C')

    data = LEVEL_TEMPLATE.copy()
    data['level_number'] = level_num
    data['title'] = f"Level {level_num}"
    data['grid_width'] = w
    data['grid_height'] = h
    data['target_score'] = target
    data['max_moves'] = moves
    data['num_tile_types'] = 6
    data['layout'] = layout

    # Set collectible target and description based on level type
    if num_collectibles > 0:
        data['collectible_target'] = num_collectibles
        data['collectible_type'] = 'coin'  # Default to coin, can be changed manually
        data['description'] = f"Collect {num_collectibles} coin{'s' if num_collectibles > 1 else ''}!"
    else:
        data['collectible_target'] = 0
        data['description'] = f"Reach {target} points in {moves} moves!"

    os.makedirs(out_dir, exist_ok=True)
    filename = os.path.join(out_dir, f"level_{level_num:02d}.json")
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)
    print(f"Wrote {filename} (w={w}, h={h}, moves={moves}, target={target}, collectibles={num_collectibles})")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--start', type=int, default=11)
    parser.add_argument('--end', type=int, default=50)
    parser.add_argument('--out', type=str, default='levels')
    parser.add_argument('--width', type=int, default=8)
    parser.add_argument('--height', type=int, default=8)
    args = parser.parse_args()

    for i in range(args.start, args.end+1):
        write_level(args.out, i, args.width, args.height)

if __name__ == '__main__':
    main()
