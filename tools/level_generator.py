#!/usr/bin/env python3
"""
Level generator for match-3-game
Generates level JSON files named level_XX.json in the project's levels/ directory.
Layout format matches existing levels: a single string where each row is concatenated and rows are separated by '\n'.

Usage:
    python3 tools/level_generator.py --start 11 --end 50 --out levels/

This script creates playable levels with proper unmovable tile placement:
- Unmovable tiles are grouped together to form walls/barriers
- Always placed adjacent to playable areas (can be broken)
- Never isolated or in unreachable areas
- Collectibles never spawn in bottom row
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
    "collectible_target": 0,  # Number of collectibles to collect (0 = not required)
    "unmovable_target": 0,  # Number of unmovables to clear (0 = not required)
    "spreader_target": False,  # Boolean: True = must clear all spreaders to win
    "unmovable_type": "snow",  # Type of unmovable_soft (snow, glass, wood, etc.)
    "collectible_type": "coin",
    "spreader_type": "virus",  # Type of spreader (virus, blood, lava, etc.)
    "spreader_grace_moves": 2,  # Grace period before spreaders start spreading
    "max_spreaders": 20,  # Maximum number of spreaders allowed on board
    "spreader_spread_limit": 0  # Max new spreaders per move (0 = unlimited)
}

SPECIAL_CHARS = {
    'blocked': 'X',
    'playable': '0',
    'collectible': 'C',
    'unmovable_soft': 'U',  # Soft unmovable - 1 hit to destroy
    'unmovable_hard': 'H',  # Hard unmovable - multi-hit, serialized as H{hits}:{type} in layout
    'spreader': 'S',  # Spreader tile - converts adjacent tiles
}

# Simple shapes to add variety
SHAPES = [
    # Full rectangle - always safe
    lambda w, h: [['0' for _ in range(w)] for __ in range(h)],
    # Frame (hollow center) - only for larger grids
    lambda w, h: [[('0' if x < 2 or y < 2 or x >= w-2 or y >= h-2 else 'X') for x in range(w)] for y in range(h)],
    # Cross/Plus shape - only for larger grids
    lambda w, h: [[('0' if abs(x - w//2) <= 1 or abs(y - h//2) <= 1 else 'X') for x in range(w)] for y in range(h)],
    # Diamond shape - safe for most sizes
    lambda w, h: [[('0' if abs(x - w//2) + abs(y - h//2) <= min(w,h)//2 + 1 else 'X') for x in range(w)] for y in range(h)],
    # Checkerboard large blocks - only for larger grids
    lambda w, h: [[('0' if (x//2 + y//2) % 2 == 0 else 'X') for x in range(w)] for y in range(h)],
]


def get_suitable_shapes(w, h):
    """Get shapes suitable for the given grid size"""
    # For small grids (6x6 or smaller), only use full rectangle and diamond
    if w <= 6 or h <= 6:
        return [
            SHAPES[0],  # Full rectangle
            SHAPES[3],  # Diamond
        ]

    # For medium grids (7x7 or 8x8), use most shapes
    if w <= 8 and h <= 8:
        return [
            SHAPES[0],  # Full rectangle
            SHAPES[1],  # Frame
            SHAPES[3],  # Diamond
        ]

    # For large grids, use all shapes
    return SHAPES


def has_adjacent_playable(grid, x, y, w, h):
    """Check if position (x,y) has at least one adjacent playable cell"""
    dirs = [(-1,0), (1,0), (0,-1), (0,1)]
    for dx, dy in dirs:
        nx, ny = x + dx, y + dy
        if 0 <= nx < w and 0 <= ny < h:
            if grid[ny][nx] == '0':
                return True
    return False


def count_adjacent_playable(grid, x, y, w, h):
    """Count how many adjacent cells are playable"""
    dirs = [(-1,0), (1,0), (0,-1), (0,1)]
    count = 0
    for dx, dy in dirs:
        nx, ny = x + dx, y + dy
        if 0 <= nx < w and 0 <= ny < h:
            if grid[ny][nx] == '0':
                count += 1
    return count


def is_level_playable(grid, w, h):
    """
    Check if a level is playable by validating:
    1. Enough playable cells (at least 50% of grid)
    2. No isolated single cells
    3. Each row has at least 3 consecutive playable cells
    4. Each column has at least 3 consecutive playable cells
    """
    playable_count = 0
    total_cells = w * h

    # Count playable cells
    for y in range(h):
        for x in range(w):
            if grid[y][x] == '0':
                playable_count += 1

    # Need at least 50% playable cells
    if playable_count < total_cells * 0.5:
        return False, "Not enough playable cells"

    # Check for isolated cells (no adjacent playable cells)
    for y in range(h):
        for x in range(w):
            if grid[y][x] == '0':
                adjacent_count = count_adjacent_playable(grid, x, y, w, h)
                if adjacent_count == 0:
                    return False, f"Isolated cell at ({x},{y})"

    # Check each row has at least 3 consecutive playable cells
    for y in range(h):
        max_consecutive = 0
        current_consecutive = 0
        for x in range(w):
            if grid[y][x] == '0':
                current_consecutive += 1
                max_consecutive = max(max_consecutive, current_consecutive)
            else:
                current_consecutive = 0
        if max_consecutive < 3:
            return False, f"Row {y} doesn't have 3 consecutive playable cells"

    # Check each column has at least 3 consecutive playable cells
    for x in range(w):
        max_consecutive = 0
        current_consecutive = 0
        for y in range(h):
            if grid[y][x] == '0':
                current_consecutive += 1
                max_consecutive = max(max_consecutive, current_consecutive)
            else:
                current_consecutive = 0
        if max_consecutive < 3:
            return False, f"Column {x} doesn't have 3 consecutive playable cells"

    return True, "Playable"


def place_unmovable_barrier(grid, w, h, num_unmovables):
    """
    Place unmovable tiles in a meaningful pattern and return list of placed positions:
    - Grouped together as a barrier/wall
    - Always adjacent to playable areas
    - Creates interesting gameplay challenges
    Returns list of (x,y) positions that were set to 'U'
    """
    if num_unmovables <= 0:
        return []

    # Find all playable cells
    playable_cells = [(x, y) for y in range(h) for x in range(w) if grid[y][x] == '0']

    if len(playable_cells) < num_unmovables:
        num_unmovables = len(playable_cells) // 2

    # Choose a barrier pattern based on level complexity
    barrier_patterns = [
        'horizontal_line',  # Horizontal barrier across middle
        'vertical_line',    # Vertical barrier down middle
        'corner_blocks',    # Unmovables in corners
        'center_cluster',   # Cluster in center
        'scattered_groups', # Multiple small groups
    ]

    pattern = random.choice(barrier_patterns)
    placed = []

    if pattern == 'horizontal_line':
        # Place horizontal line of unmovables across middle
        mid_y = h // 2
        start_x = max(1, (w - num_unmovables) // 2)
        for i in range(min(num_unmovables, w - 2)):
            x = start_x + i
            if x < w and grid[mid_y][x] == '0':
                grid[mid_y][x] = 'U'
                placed.append((x, mid_y))

    elif pattern == 'vertical_line':
        # Place vertical line of unmovables down middle
        mid_x = w // 2
        start_y = max(1, (h - num_unmovables) // 2)
        for i in range(min(num_unmovables, h - 2)):
            y = start_y + i
            if y < h and grid[y][mid_x] == '0':
                grid[y][mid_x] = 'U'
                placed.append((mid_x, y))

    elif pattern == 'corner_blocks':
        # Place small clusters in corners
        corners = [
            (1, 1), (w-2, 1), (1, h-2), (w-2, h-2)
        ]
        random.shuffle(corners)
        per_corner = max(2, num_unmovables // 4)

        for cx, cy in corners:
            if len(placed) >= num_unmovables:
                break
            # Place a small cluster around this corner
            cluster_offsets = [(0,0), (1,0), (0,1), (-1,0), (0,-1), (1,1)]
            for dx, dy in cluster_offsets:
                if len(placed) >= num_unmovables:
                    break
                x, y = cx + dx, cy + dy
                if 0 <= x < w and 0 <= y < h and grid[y][x] == '0':
                    grid[y][x] = 'U'
                    placed.append((x, y))

    elif pattern == 'center_cluster':
        # Place cluster in center
        cx, cy = w // 2, h // 2
        # Spiral outward from center
        placed_set = set()
        queue = [(cx, cy)]
        dirs = [(0,0), (1,0), (0,1), (-1,0), (0,-1), (1,1), (-1,-1), (1,-1), (-1,1)]

        while queue and len(placed) < num_unmovables:
            x, y = queue.pop(0)
            if (x, y) in placed_set:
                continue
            if not (0 <= x < w and 0 <= y < h):
                continue
            if grid[y][x] != '0':
                continue

            grid[y][x] = 'U'
            placed.append((x, y))
            placed_set.add((x, y))

            # Add neighbors to queue
            for dx, dy in dirs:
                nx, ny = x + dx, y + dy
                if (nx, ny) not in placed_set:
                    queue.append((nx, ny))

    else:  # scattered_groups
        # Place multiple small groups (2-3 tiles each)
        group_size = 3
        num_groups = max(1, num_unmovables // group_size)

        for _ in range(num_groups):
            if len(placed) >= num_unmovables:
                break

            # Pick random starting point from playable cells with good adjacency
            candidates = [(x, y) for x, y in playable_cells
                         if grid[y][x] == '0' and count_adjacent_playable(grid, x, y, w, h) >= 2]

            if not candidates:
                candidates = playable_cells

            if candidates:
                start_x, start_y = random.choice(candidates)
                # Place small group
                offsets = [(0,0), (1,0), (0,1), (-1,0)]
                random.shuffle(offsets)

                for dx, dy in offsets:
                    if len(placed) >= num_unmovables:
                        break
                    x, y = start_x + dx, start_y + dy
                    if 0 <= x < w and 0 <= y < h and grid[y][x] == '0':
                        grid[y][x] = 'U'
                        placed.append((x, y))

    return placed


def place_unmovable_hard(grid, w, h, num_hard, max_hits=3, types=None):
    """
    Place hard unmovable tiles on the grid. Marks cells with dict entries like ('H', hits, type)
    We'll later serialize these into the layout string (e.g., H2:rock).
    """
    if num_hard <= 0:
        return []

    if types is None:
        types = ['rock', 'metal', 'ice']

    # Find all playable cells
    playable_cells = [(x, y) for y in range(h) for x in range(w) if grid[y][x] == '0']
    if not playable_cells:
        return []

    placed = []
    attempts = 0
    while len(placed) < num_hard and attempts < num_hard * 10:
        attempts += 1
        x, y = random.choice(playable_cells)
        # ensure not adjacent to existing hard/unmovable to avoid clustering too much
        if grid[y][x] != '0':
            continue
        # require at least one adjacent playable cell so it's reachable
        if not has_adjacent_playable(grid, x, y, w, h):
            continue
        hits = random.randint(1, max_hits)
        htype = random.choice(types)
        # store as a tuple in grid for later serialization
        grid[y][x] = ('H', hits, htype)
        placed.append((x, y, hits, htype))
    return placed


def place_spreaders(grid, w, h, num_spreaders, min_distance=2):
    """
    Place spreader tiles on the grid strategically.
    - Spreaders are placed with minimum distance from each other
    - Not in corners to allow spreading
    - In playable areas with good adjacency

    Args:
        grid: The game grid
        w: Grid width
        h: Grid height
        num_spreaders: Number of spreaders to place (1-5 recommended)
        min_distance: Minimum Manhattan distance between spreaders

    Returns:
        List of placed spreader positions
    """
    if num_spreaders <= 0:
        return []

    # Find all playable cells, excluding corners
    corner_positions = {(0, 0), (w-1, 0), (0, h-1), (w-1, h-1)}
    playable_cells = []
    for y in range(h):
        for x in range(w):
            if grid[y][x] == '0' and (x, y) not in corner_positions:
                # Require good adjacency (at least 2 adjacent playable cells)
                if count_adjacent_playable(grid, x, y, w, h) >= 2:
                    playable_cells.append((x, y))

    if not playable_cells:
        return []

    placed = []
    attempts = 0
    max_attempts = num_spreaders * 20

    while len(placed) < num_spreaders and attempts < max_attempts:
        attempts += 1
        x, y = random.choice(playable_cells)

        # Check if position is valid
        if grid[y][x] != '0':
            continue

        # Check minimum distance from other spreaders
        too_close = False
        for px, py in placed:
            distance = abs(x - px) + abs(y - py)  # Manhattan distance
            if distance < min_distance:
                too_close = True
                break

        if too_close:
            continue

        # Place spreader
        grid[y][x] = 'S'
        placed.append((x, y))

    return placed


def serialize_grid_to_layout(grid, w, h):
    """Convert internal grid (with special tuples) to the layout string used in levels.
    Rules:
      - 'X' stays as 'X'
      - '0' stays as '0'
      - 'C' stays as 'C'
      - 'U' stays as 'U'
      - 'S' stays as 'S' (spreader)
      - ('H', hits, type) becomes 'H{hits}:{htype}'
    Rows are newline-separated strings joined into a single string with '\n' between rows.
    """
    rows = []
    for y in range(h):
        row_items = []
        for x in range(w):
            v = grid[y][x]
            if isinstance(v, tuple) or isinstance(v, list):
                if len(v) >= 3 and v[0] == 'H':
                    hits = v[1]
                    htype = v[2]
                    row_items.append(f"H{hits}:{htype}")
                else:
                    # unknown tuple, fallback to blocked
                    row_items.append('X')
            else:
                row_items.append(str(v))
        rows.append(' '.join(row_items))
    return '\n'.join(rows)


def generate_layout(w, h, shape_func, add_collectibles=True, add_unmovables=True, max_retries=5, unmovable_mode='any'):
    """Generate a level layout, ensuring it's playable

    unmovable_mode: 'any' (default) => place soft barriers and some hard by fraction
                     'soft' => place only soft unmovables
                     'hard' => place only hard unmovables
                     'both' => place soft barriers and ensure some hard replacements
    """

    for attempt in range(max_retries):
        grid = shape_func(w, h)

        # Validate base shape is playable
        is_playable, reason = is_level_playable(grid, w, h)
        if not is_playable:
            print(f"  Attempt {attempt + 1}: Base shape not playable - {reason}, retrying...")
            # Try full rectangle as fallback
            if attempt >= 2:
                grid = SHAPES[0](w, h)  # Full rectangle
            continue

        # Count playable cells
        playable_cells = [(x, y) for y in range(h) for x in range(w) if grid[y][x] == '0']
        num_playable = len(playable_cells)

        hard_placed = []

        # Add unmovable tiles (barriers/walls) - 10-20% of playable area
        if add_unmovables and num_playable > 10:
            num_unmovables = random.randint(max(4, num_playable // 10), num_playable // 5)
            placed_positions = place_unmovable_barrier(grid, w, h, num_unmovables)
            placed_count = len(placed_positions)

            # If mode == 'hard', convert a portion of placed_positions into hard tiles
            if unmovable_mode == 'hard':
                num_hard = max(1, int(placed_count * random.uniform(0.3, 0.6)))
                random.shuffle(placed_positions)
                for i in range(min(num_hard, placed_count)):
                    x, y = placed_positions[i]
                    hits = random.randint(1, 3)
                    htype = random.choice(['rock', 'metal', 'ice'])
                    grid[y][x] = ('H', hits, htype)
                    hard_placed.append((x, y, hits, htype))

            # Optionally add some hard unmovables (10-30% of unmovables) for other modes
            elif unmovable_mode in ('any', 'both'):
                num_hard = max(0, int(placed_count * random.uniform(0.1, 0.3)))
                if num_hard > 0:
                    # Try to place hard unmovables using existing function (it will pick playable cells)
                    extra_hard = place_unmovable_hard(grid, w, h, num_hard, max_hits=3)
                    # extra_hard is list of tuples
                    for hp in extra_hard:
                        hard_placed.append(hp)

            # For 'soft', do nothing (all remain 'U')

            # Validate after adding unmovables
            is_playable, reason = is_level_playable(grid, w, h)
            if not is_playable:
                print(f"  Attempt {attempt + 1}: Unmovables made level unplayable - {reason}, retrying...")
                continue

            print(f"  Placed {placed_count} unmovable tiles")

        # Add collectibles (but not in bottom row, and not where unmovables are)
        num_collectibles = 0
        if add_collectibles:
            bottom_row = h - 1
            collectible_candidates = [
                (x, y) for y in range(h) for x in range(w)
                if (grid[y][x] == '0') and y != bottom_row
            ]

            if collectible_candidates:
                # 1-3 collectibles per level
                num_collectibles = random.randint(1, min(3, len(collectible_candidates)))
                random.shuffle(collectible_candidates)

                for i in range(num_collectibles):
                    x, y = collectible_candidates[i]
                    grid[y][x] = 'C'

        # Final validation
        is_playable, reason = is_level_playable(grid, w, h)
        if is_playable:
            # Convert grid to layout string format using new serializer
            layout = serialize_grid_to_layout(grid, w, h)
            return layout, num_collectibles, hard_placed
        else:
            print(f"  Attempt {attempt + 1}: Final validation failed - {reason}, retrying...")

    # If all retries failed, generate a simple full rectangle (guaranteed playable)
    print(f"  All attempts failed, using safe full rectangle layout")
    grid = SHAPES[0](w, h)  # Full rectangle
    layout = serialize_grid_to_layout(grid, w, h)
    return layout, 0, []


def estimate_target_and_moves(level_index, w, h, has_collectibles, has_unmovables):
    # Base difficulty scales with level index and grid size
    # For smaller grids, use a more reasonable base
    if w * h <= 36:  # 6x6 or smaller
        base = 2000 + level_index * 100
    else:
        base = 5000 + level_index * 300

    size_factor = (w * h) / 64.0
    target = int(base * size_factor)

    # Adjust based on level features
    if has_collectibles:
        # Collectible levels need lower score targets since collecting is the main goal
        target = int(target * 0.6)

    if has_unmovables:
        # Unmovable barriers make levels harder, reduce target slightly
        target = int(target * 0.8)

    # Cap target score based on grid size
    max_target = (w * h) * 500  # Max 500 points per cell
    target = min(target, max_target)

    # More generous moves for better user engagement
    base_moves = 25 + int(level_index * 0.3)

    # Add extra moves for unmovables (need time to break barriers)
    if has_unmovables:
        base_moves += 8

    # Add extra moves for collectibles
    if has_collectibles:
        base_moves += 5

    moves = max(20, min(60, base_moves))

    return target, moves


def write_level(out_dir, level_num, w=8, h=8, level_type='random'):
    print(f"\nGenerating level {level_num}...")

    # Seed RNG for deterministic results per level number
    random.seed(level_num)

    # Get suitable shapes for this grid size
    suitable_shapes = get_suitable_shapes(w, h)
    shape = random.choice(suitable_shapes)

    # Determine level features based on type argument
    # Support new level types for explicit unmovable mode selection
    if level_type == 'collectibles':
        add_collectibles = True
        add_unmovables = False
        add_spreaders = False
        unmovable_mode = 'any'
    elif level_type == 'unmovables':
        add_collectibles = False
        add_unmovables = True
        add_spreaders = False
        unmovable_mode = 'any'
    elif level_type == 'unmovable_soft':
        add_collectibles = False
        add_unmovables = True
        add_spreaders = False
        unmovable_mode = 'soft'
    elif level_type == 'unmovable_hard':
        add_collectibles = False
        add_unmovables = True
        add_spreaders = False
        unmovable_mode = 'hard'
    elif level_type == 'unmovables_both':
        add_collectibles = False
        add_unmovables = True
        add_spreaders = False
        unmovable_mode = 'both'
    elif level_type == 'spreaders':
        add_collectibles = False
        add_unmovables = False
        add_spreaders = True
        unmovable_mode = 'any'
    elif level_type == 'both':
        add_collectibles = True
        add_unmovables = True
        add_spreaders = False
        unmovable_mode = 'any'
    elif level_type == 'score':
        add_collectibles = False
        add_unmovables = False
        add_spreaders = False
        unmovable_mode = 'any'
    else:  # 'random' or any other value
        # Vary level types randomly:
        # 30% - collectibles only
        # 25% - unmovables only
        # 15% - spreaders only
        # 15% - both collectibles and unmovables
        # 10% - spreaders + collectibles
        # 5% - plain score-based
        rand = random.random()
        if rand < 0.30:
            add_collectibles = True
            add_unmovables = False
            add_spreaders = False
            unmovable_mode = 'any'
        elif rand < 0.55:
            add_collectibles = False
            add_unmovables = True
            add_spreaders = False
            unmovable_mode = 'any'
        elif rand < 0.70:
            add_collectibles = False
            add_unmovables = False
            add_spreaders = True
            unmovable_mode = 'any'
        elif rand < 0.85:
            add_collectibles = True
            add_unmovables = True
            add_spreaders = False
            unmovable_mode = 'any'
        elif rand < 0.95:
            add_collectibles = True
            add_unmovables = False
            add_spreaders = True
            unmovable_mode = 'any'
        else:
            add_collectibles = False
            add_unmovables = False
            add_spreaders = False
            unmovable_mode = 'any'

    # Generate layout; for specific levels (51-55) force at least one hard tile
    max_force_attempts = 10
    if 51 <= level_num <= 55:
        layout = None
        hard_placed = []
        num_collectibles = 0
        for attempt in range(max_force_attempts):
            layout, num_collectibles, hard_placed = generate_layout(w, h, shape, add_collectibles, add_unmovables, unmovable_mode=unmovable_mode)
            if 'H' in layout and hard_placed and len(hard_placed) > 0:
                break
            # otherwise retry with a new random variation
            random.seed(level_num + attempt + 1)
        # if still no hard tile, log and proceed (generator may have fallen back to safe layout)
    else:
        layout, num_collectibles, hard_placed = generate_layout(w, h, shape, add_collectibles, add_unmovables, unmovable_mode=unmovable_mode)

    has_unmovables = 'U' in layout or 'H' in layout
    # Count unmovables in layout
    num_unmovables = layout.count('U') + layout.count('H')

    # Add spreaders if requested
    num_spreaders = 0
    if add_spreaders:
        # Parse layout back to grid for spreader placement
        lines = layout.strip().split('\n')
        grid = []
        for line in lines:
            grid.append(list(line.split()))

        # Determine number of spreaders based on level
        if level_num % 10 == 0:  # Boss levels - more spreaders
            num_spreaders_to_place = random.randint(4, 6)
        elif level_num < 40:  # Early levels - fewer spreaders
            num_spreaders_to_place = random.randint(2, 3)
        else:  # Later levels - moderate spreaders
            num_spreaders_to_place = random.randint(3, 5)

        # Place spreaders
        placed_spreaders = place_spreaders(grid, w, h, num_spreaders_to_place, min_distance=2)
        num_spreaders = len(placed_spreaders)

        # Convert grid back to layout string
        layout = serialize_grid_to_layout(grid, w, h)

    has_spreaders = 'S' in layout

    target, moves = estimate_target_and_moves(level_num, w, h, num_collectibles > 0, has_unmovables)

    data = LEVEL_TEMPLATE.copy()
    data['level_number'] = level_num
    data['title'] = f"Level {level_num}"
    data['grid_width'] = w
    data['grid_height'] = h
    data['target_score'] = target
    data['max_moves'] = moves
    data['num_tile_types'] = 6
    data['layout'] = layout

    # Vary themes
    data['theme'] = 'modern' if level_num % 2 == 0 else 'legacy'

    # Vary unmovable types and set unmovable target
    if has_unmovables:
        unmovable_types = ['snow', 'glass', 'wood']
        data['unmovable_type'] = random.choice(unmovable_types)
        # Set unmovable target - must clear all unmovables to complete level
        data['unmovable_target'] = num_unmovables
    else:
        data['unmovable_type'] = 'snow'
        data['unmovable_target'] = 0

    # If hard_placed contains entries, add hard_textures mapping for types found
    hard_textures_map = {}
    if hard_placed and len(hard_placed) > 0:
        # hard_placed may be list of tuples (x,y,hits,htype)
        types_in_level = set([p[3] for p in hard_placed])
        for t in types_in_level:
            # assume max 3 stages (0..2) for generator; filenames are theme-relative
            hard_textures_map[t] = [f"unmovable_hard_{t}_{i}.svg" for i in range(3)]
        data['hard_textures'] = hard_textures_map

    # Configure spreaders
    if has_spreaders:
        data['spreader_target'] = True  # Must clear all spreaders to win
        data['spreader_type'] = random.choice(['virus', 'blood', 'lava'])

        # Configure spread difficulty based on level
        if level_num < 35:
            # Early levels - slow controlled spread
            data['spreader_grace_moves'] = 3
            data['spreader_spread_limit'] = 1
            data['max_spreaders'] = 12
        elif level_num < 60:
            # Mid levels - medium spread
            data['spreader_grace_moves'] = 2
            data['spreader_spread_limit'] = 2
            data['max_spreaders'] = 15
        else:
            # Late levels - exponential spread (challenging!)
            data['spreader_grace_moves'] = 1
            data['spreader_spread_limit'] = 0  # Unlimited
            data['max_spreaders'] = 20
    else:
        data['spreader_target'] = False
        data['spreader_type'] = 'virus'
        data['spreader_grace_moves'] = 2
        data['spreader_spread_limit'] = 0
        data['max_spreaders'] = 20

    # Set collectible target and description based on level type
    if has_spreaders and num_collectibles > 0:
        # Spreaders + collectibles
        data['collectible_target'] = num_collectibles
        data['collectible_type'] = 'coin'
        data['description'] = f"Collect {num_collectibles} coin{'s' if num_collectibles > 1 else ''} and clear all spreaders!"
    elif has_spreaders:
        # Spreaders only
        data['collectible_target'] = 0
        data['description'] = f"Clear all {num_spreaders} spreader{'s' if num_spreaders > 1 else ''}!"
    elif num_collectibles > 0 and has_unmovables:
        # Both collectibles and unmovables
        data['collectible_target'] = num_collectibles
        data['collectible_type'] = 'coin'
        data['description'] = f"Collect {num_collectibles} coin{'s' if num_collectibles > 1 else ''} and clear {num_unmovables} obstacle{'s' if num_unmovables > 1 else ''}!"
    elif num_collectibles > 0:
        # Collectibles only
        data['collectible_target'] = num_collectibles
        data['collectible_type'] = 'coin'
        data['description'] = f"Collect {num_collectibles} coin{'s' if num_collectibles > 1 else ''}!"
    elif has_unmovables:
        # Unmovables only
        data['collectible_target'] = 0
        data['description'] = f"Clear all {num_unmovables} obstacle{'s' if num_unmovables > 1 else ''}!"
    else:
        # Score only
        data['collectible_target'] = 0
        data['description'] = f"Reach {target} points in {moves} moves!"

    os.makedirs(out_dir, exist_ok=True)
    filename = os.path.join(out_dir, f"level_{level_num:02d}.json")
    with open(filename, 'w') as f:
        json.dump(data, f, indent=2)

    print(f"✓ Wrote {filename}")
    print(f"  Size: {w}x{h}, Moves: {moves}, Target: {target}")
    print(f"  Collectibles: {num_collectibles}, Unmovables: {'Yes' if has_unmovables else 'No'}, Spreaders: {num_spreaders if has_spreaders else 'No'}")
    if has_unmovables:
        print(f"  Unmovable type: {data['unmovable_type']}")
    if has_spreaders:
        print(f"  Spreader type: {data['spreader_type']}, Grace: {data['spreader_grace_moves']}, Spread limit: {data['spreader_spread_limit']}")
        print(f"  Spreader objective: Clear all spreaders to win")


def main():
    parser = argparse.ArgumentParser(description='Generate match-3 levels with proper unmovable tile placement')
    parser.add_argument('--start', type=int, default=11, help='Starting level number')
    parser.add_argument('--end', type=int, default=50, help='Ending level number')
    parser.add_argument('--out', type=str, default='levels', help='Output directory')
    parser.add_argument('--width', type=int, default=8, help='Grid width')
    parser.add_argument('--height', type=int, default=8, help='Grid height')
    parser.add_argument('--type', type=str, default='random',
                       choices=['random', 'collectibles', 'unmovables', 'spreaders', 'both', 'score', 'unmovable_soft', 'unmovable_hard', 'unmovables_both'],
                       help='Level type: random (default), collectibles (only collectibles), '
                            'unmovables (only unmovables), spreaders (only spreaders), unmovable_soft (soft only), unmovable_hard (hard only), unmovables_both (both types), '
                            'both (collectibles + unmovables), score (plain score-based)')
    args = parser.parse_args()

    print(f"Generating levels {args.start} to {args.end}...")
    print(f"Output directory: {args.out}")
    print(f"Grid size: {args.width}x{args.height}")
    print(f"Level type: {args.type}")

    for i in range(args.start, args.end + 1):
        write_level(args.out, i, args.width, args.height, args.type)

    print(f"\n✓ Generated {args.end - args.start + 1} levels successfully!")

if __name__ == '__main__':
    main()
