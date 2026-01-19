# Gallery — Consolidated Implementation

Merged gallery documentation. For full historical notes see `docs/legacy/GALLERY_SYSTEM.md` and `docs/legacy/GALLERY_IMPLEMENTATION_SUMMARY.md`.

## Overview
Players unlock images by completing milestone levels; unlocked images are cached and viewable in the Gallery UI.

## Unlocks
- Levels: 2,4,6,8,10,12,14,16,18,20 map to images image_01..image_10

## Files
- scripts/GalleryUI.gd — UI and cache logic
- scripts/RewardManager.gd — tracks unlocked images
- scripts/GameUI.gd — menu integration

## Data
`player_progress.json` stores `unlocked_gallery_images` array.

## Testing
- Run `./test_gallery.sh` and verify `player_progress.json` updates.

Date: 2026-01-19
