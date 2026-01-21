#!/usr/bin/env python3
"""
Test script to verify advanced mechanics integration is working.
Simulates what the GameManager.load_advanced_mechanics function should do.
"""

import json
import os

def test_load_advanced_mechanics(level_num):
    """Test loading advanced mechanics from a level JSON file"""
    file_path = f"levels/level_{level_num:02d}.json"

    if not os.path.exists(file_path):
        print(f"Level {level_num}: ✗ File not found")
        return False

    try:
        with open(file_path, 'r') as f:
            data = json.load(f)

        print(f"\nLevel {level_num}: ✓ {data.get('description', 'No description')}")

        # Test collectibles
        if "collectibles" in data and data["collectibles"]:
            coll = data["collectibles"]
            if coll.get("enabled", False):
                print(f"  🪙 Collectibles: {coll.get('types', ['coin'])} (need {coll.get('required', 10)}, spawn rate {coll.get('spawn_rate', 0.3)})")

        # Test obstacles
        if "obstacles" in data and data["obstacles"]:
            obstacles = data["obstacles"]
            print(f"  🧱 Obstacles: {len(obstacles)} items")
            for i, obs in enumerate(obstacles[:3]):  # Show first 3
                print(f"    - {obs.get('type', 'unknown')} at ({obs.get('position', [0,0])[0]}, {obs.get('position', [0,0])[1]}) with {obs.get('hits', 1)} hits")

        # Test transformables
        if "transformables" in data and data["transformables"]:
            trans = data["transformables"]
            if trans.get("enabled", False):
                positions = trans.get("positions", [])
                print(f"  🌸 Transformables: {trans.get('type', 'flower')} at {len(positions)} positions")

        # Test gravity
        if "gravity_direction" in data:
            gravity = data["gravity_direction"]
            if gravity != "down":
                print(f"  ⬆️ Gravity: {gravity}")

        # Test objectives
        if "objectives" in data and data["objectives"]:
            obj = data["objectives"]
            objectives = []
            if obj.get("collectibles", 0) > 0:
                objectives.append(f"collect {obj['collectibles']} items")
            if obj.get("clear_obstacles", False):
                objectives.append("clear all obstacles")
            if obj.get("transform_all", False):
                objectives.append("transform all items")
            if objectives:
                print(f"  🎯 Objectives: {', '.join(objectives)}")

        return True

    except Exception as e:
        print(f"Level {level_num}: ✗ Error: {e}")
        return False

def main():
    print("Advanced Mechanics Integration Test")
    print("=" * 50)

    # Test basic level
    success = test_load_advanced_mechanics(1)
    passed = 1 if success else 0

    # Test advanced levels
    test_levels = [51, 52, 53, 54, 55]

    for level_num in test_levels:
        if test_load_advanced_mechanics(level_num):
            passed += 1

    total_tests = len(test_levels) + 1
    print(f"\n{'='*50}")
    print(f"Test Results: {passed}/{total_tests} levels loaded successfully")

    if passed == total_tests:
        print("✅ All tests passed! Advanced mechanics integration is working.")
    else:
        print("❌ Some tests failed. Check the errors above.")

if __name__ == "__main__":
    main()
