#!/usr/bin/env python3
"""
Test script to verify level format parsing works correctly.
Tests both string and array layout formats.
"""

import json

# Test data - both formats
test_levels = {
    "string_format": {
        "level": 1,
        "width": 4,
        "height": 4,
        "target_score": 1000,
        "moves": 10,
        "description": "String format test",
        "theme": "modern",
        "layout": "0 0 0 0\nX 0 0 X\n0 0 0 0\nX 0 0 X"
    },
    "array_format": {
        "level": 2,
        "width": 4,
        "height": 4,
        "target_score": 1000,
        "moves": 10,
        "description": "Array format test",
        "theme": "modern",
        "layout": [
            "0000",
            "X00X",
            "0000",
            "X00X"
        ]
    }
}

def parse_layout_string(layout_str, width, height):
    """Parse string format layout"""
    grid = []
    for x in range(width):
        grid.append([0] * height)

    lines = layout_str.split("\n")
    for y in range(min(len(lines), height)):
        cells = lines[y].strip().split(" ")
        for x in range(min(len(cells), width)):
            cell = cells[x].strip()
            if cell == "X":
                grid[x][y] = -1
            elif cell.isdigit():
                grid[x][y] = int(cell)
            else:
                grid[x][y] = 0
    return grid

def parse_layout_array(layout_array, width, height):
    """Parse array format layout"""
    grid = []
    for x in range(width):
        grid.append([0] * height)

    for y in range(min(len(layout_array), height)):
        row = layout_array[y]
        for x in range(min(len(row), width)):
            cell = row[x]
            if cell == "X":
                grid[x][y] = -1
            elif cell.isdigit():
                grid[x][y] = int(cell)
            else:
                grid[x][y] = 0
    return grid

def print_grid(grid, format_name):
    """Print grid in readable format"""
    print(f"\n{format_name}:")
    height = len(grid[0]) if grid else 0
    width = len(grid)

    for y in range(height):
        row = []
        for x in range(width):
            val = grid[x][y]
            if val == -1:
                row.append("X")
            else:
                row.append(str(val))
        print("  " + " ".join(row))

def main():
    print("Level Format Parser Test")
    print("=" * 50)

    # Test string format
    string_level = test_levels["string_format"]
    string_grid = parse_layout_string(
        string_level["layout"],
        string_level["width"],
        string_level["height"]
    )
    print_grid(string_grid, "String Format Result")

    # Test array format
    array_level = test_levels["array_format"]
    array_grid = parse_layout_array(
        array_level["layout"],
        array_level["width"],
        array_level["height"]
    )
    print_grid(array_grid, "Array Format Result")

    # Verify both produce same result
    if string_grid == array_grid:
        print("\n✓ SUCCESS: Both formats produce identical grids!")
    else:
        print("\n✗ FAILED: Grids do not match!")

    print("\nExpected grid:")
    print("  0 0 0 0")
    print("  X 0 0 X")
    print("  0 0 0 0")
    print("  X 0 0 X")

if __name__ == "__main__":
    main()
