#!/bin/bash
# Helper script to create DLC chapter ZIP files with correct structure
# Usage: ./create_dlc_zip.sh <chapter_name>

if [ -z "$1" ]; then
    echo "Usage: ./create_dlc_zip.sh <chapter_name>"
    echo "Example: ./create_dlc_zip.sh gospels"
    exit 1
fi

CHAPTER_NAME="$1"
CHAPTERS_DIR="$(dirname "$0")/dlc_server/dlc/chapters"
CHAPTER_DIR="$CHAPTERS_DIR/$CHAPTER_NAME"

if [ ! -d "$CHAPTER_DIR" ]; then
    echo "Error: Chapter directory not found: $CHAPTER_DIR"
    exit 1
fi

echo "Creating ZIP for chapter: $CHAPTER_NAME"
echo "Chapter directory: $CHAPTER_DIR"
echo ""

# Remove old ZIP if it exists
if [ -f "$CHAPTERS_DIR/$CHAPTER_NAME.zip" ]; then
    echo "Removing old ZIP..."
    rm "$CHAPTERS_DIR/$CHAPTER_NAME.zip"
fi

# Create ZIP from inside the chapter folder to avoid nesting
echo "Creating ZIP..."
cd "$CHAPTER_DIR"
zip -r "../$CHAPTER_NAME.zip" . -x "*.DS_Store" -x "__MACOSX/*"

echo ""
echo "✓ ZIP created: $CHAPTERS_DIR/$CHAPTER_NAME.zip"
echo ""
echo "Verifying ZIP structure..."
unzip -l "../$CHAPTER_NAME.zip" | head -20
echo ""
echo "✓ Done! Make sure manifest.json is at root level, not nested."
