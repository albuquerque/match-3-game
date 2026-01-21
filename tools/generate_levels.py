#!/usr/bin/env python3
"""
Level Generator for Match-3 Game
Generates level JSON files with varied layouts, difficulties, and objectives.
Format matches level_10.json with string-based layouts.

Usage:
    python3 tools/generate_levels.py 11 50    # Generate levels 11 to 50
"""

import json
import random
import os
import sys
from typing import Dict, Any


class LevelGenerator:
    """Generates varied level configurations for match-3 game."""

    THEMES = ['classic', 'ocean', 'space', 'forest', 'candy', 'modern', 'retro', 'legacy']

    DESCRIPTIONS = [
        "Match gems to reach the target!",
        "Clear the board strategically!",
        "Can you beat this level?",
        "A tricky challenge awaits!",
        "Master this puzzle!",
        "Test your matching skills!",
        "Navigate the obstacles!",
        "Reach the goal efficiently!",
        "Plan your moves carefully!",
        "A puzzling challenge!",
        "Show your matching prowess!",
        "Conquer this level!"
    ]

    @staticmethod
    def generate_layout(width: int, height: int, complexity: str) -> str:
        """
        Generate a layout string with playable (0) and non-playable (X) cells.
        Returns a string with rows separated by \\n, matching level_10.json format.
        """
        layout_rows = []

        if complexity == 'easy':
            # Mostly playable, minimal obstacles
            for i in range(height):
                row = ['0'] * width
                # Add a few random obstacles
                num_obstacles = random.randint(0, 2)
                if num_obstacles > 0:
                    positions = random.sample(range(width), min(num_obstacles, width))
                    for pos in positions:
                        row[pos] = 'X'
                layout_rows.append(' '.join(row))

        elif complexity == 'medium':
            # Moderate obstacles with some patterns
            for i in range(height):
                row = ['0'] * width
                # Add corner obstacles on first/last rows
                if i == 0 or i == height - 1:
                    if random.random() > 0.6:
                        row[0] = 'X'
                    if random.random() > 0.6:
                        row[-1] = 'X'
                # Random obstacles
                num_obstacles = random.randint(2, 4)
                available_positions = [j for j in range(width) if row[j] == '0']
                if available_positions:
                    positions = random.sample(available_positions,
                                            min(num_obstacles, len(available_positions)))
                    for pos in positions:
                        row[pos] = 'X'
                layout_rows.append(' '.join(row))

        else:  # hard
            # Complex patterns with more obstacles - similar to level_10
            for i in range(height):
                row = ['0'] * width

                # Create symmetric patterns for aesthetics
                if i == 0 or i == height - 1:
                    # Top and bottom rows with corner obstacles
                    row[0] = 'X'
                    row[-1] = 'X'
                elif i == 1 or i == height - 2:
                    # Second and second-to-last rows
                    num_obstacles = random.randint(2, 3)
                    available = list(range(1, width - 1))
                    if available:
                        positions = random.sample(available,
                                                min(num_obstacles, len(available)))
                        for pos in positions:
                            row[pos] = 'X'
                else:
                    # Middle rows with varied obstacles
                    num_obstacles = random.randint(2, 4)
                    positions = random.sample(range(width),
                                            min(num_obstacles, width))
                    for pos in positions:
                        row[pos] = 'X'

                layout_rows.append(' '.join(row))

        return '\n'.join(layout_rows)

    def __init__(self, output_dir: str = "levels"):
        """Initialize generator with output directory."""
        self.output_dir = output_dir
        os.makedirs(self.output_dir, exist_ok=True)


    def generate_level(self, level_num: int, start_level: int = 11) -> Dict[str, Any]:
        """Generate a single level configuration matching level_10.json format."""
        # Vary difficulty based on level number
        relative_level = level_num - start_level

        if relative_level < 10:
            complexity = 'easy'
            width = random.choice([6, 7, 8])
            height = random.choice([6, 7, 8])
            moves = random.randint(35, 45)
            target_score = random.randint(5000, 8000)
        elif relative_level < 25:
            complexity = 'medium'
            width = random.choice([7, 8, 9])
            height = random.choice([7, 8, 9])
            moves = random.randint(30, 40)
            target_score = random.randint(8000, 12000)
        else:
            complexity = 'hard'
            width = random.choice([8, 9, 10])
            height = random.choice([8, 9, 10])
            moves = random.randint(25, 35)
            target_score = random.randint(12000, 18000)

        theme = random.choice(self.THEMES)
        layout = self.generate_layout(width, height, complexity)

        level = {
            "level": level_num,
            "width": width,
            "height": height,
            "target_score": target_score,
            "moves": moves,
            "description": random.choice(self.DESCRIPTIONS),
            "theme": theme,
            "layout": layout
        }

        return level

    def generate_levels(self, start_level: int, end_level: int) -> None:
        """Generate multiple levels and save them as JSON files."""
        print(f"Generating levels {start_level} to {end_level}...")
        print(f"Output directory: {self.output_dir}")
        print("-" * 70)

        for level_num in range(start_level, end_level + 1):
            level = self.generate_level(level_num, start_level)

            filename = f"level_{level_num:02d}.json"
            filepath = os.path.join(self.output_dir, filename)

            with open(filepath, 'w') as f:
                json.dump(level, f, indent=2)

            print(f"✓ {filename:20s} - {level['width']}x{level['height']}, "
                  f"{level['moves']:2d} moves, target: {level['target_score']:5d}, "
                  f"theme: {level['theme']}")

        print("-" * 70)
        print(f"Successfully generated {end_level - start_level + 1} levels!")


def main():
    """CLI entry point."""
    if len(sys.argv) != 3:
        print("Usage: python3 generate_levels.py <start_level> <end_level>")
        print("Example: python3 generate_levels.py 11 50")
        sys.exit(1)

    try:
        start = int(sys.argv[1])
        end = int(sys.argv[2])

        if start > end:
            print("Error: start_level must be less than or equal to end_level")
            sys.exit(1)

        if start < 1:
            print("Error: level numbers must be positive")
            sys.exit(1)

        generator = LevelGenerator(output_dir="levels")
        generator.generate_levels(start, end)

    except ValueError:
        print("Error: start_level and end_level must be integers")
        sys.exit(1)



if __name__ == '__main__':
    main()
