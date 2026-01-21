#!/bin/bash

# Test script to check gallery unlock status

SAVE_FILE=~/Library/Application\ Support/Godot/app_userdata/Match-3\ Game/player_progress.json

echo "=== Gallery Unlock Test ==="
echo ""
echo "Checking save file: $SAVE_FILE"
echo ""

if [ -f "$SAVE_FILE" ]; then
    echo "Save file exists!"
    echo ""
    echo "=== Unlocked Gallery Images ==="
    cat "$SAVE_FILE" | python3 -m json.tool | grep -A 10 "unlocked_gallery_images"
    echo ""
    echo "=== Levels Completed ==="
    cat "$SAVE_FILE" | python3 -m json.tool | grep "levels_completed"
    echo ""
else
    echo "ERROR: Save file not found!"
    echo "Expected location: $SAVE_FILE"
fi

