# Achievements — Consolidated Documentation

This document consolidates achievements system design, rewards, art guidance, and enhanced features into a single reference.

## Overview
The Achievements system tracks player milestones and grants rewards (coins/gems/boosters). Achievements persist in `player_progress.json` and integrate with RewardManager for granting rewards and updating UI.

## Key components
- Achievement definitions: `scripts/AchievementsData.gd` (mapping of id => criteria, rewards)
- UI: `scenes/AchievementsPage.tscn` with `scripts/AchievementsPage.gd`
- Unlock logic: `scripts/RewardManager.gd` handles awarding and persistence
- Notifications: `RewardNotification` displays unlocks and claimed rewards

## Unlock criteria examples
- Complete Level X with Y stars
- Collect Z coins cumulatively
- Use a booster N times

## Rewards
- Coins, Gems, Boosters, Gallery unlocks
- Use `RewardManager.grant_achievement_reward()` to grant

## Art & Background guidance
The achievements page supports custom background images with automatic fallback to solid biblical-themed colors. Recommended behavior and file locations:

- The system searches these paths (priority):
  - `res://textures/backgrounds/achievements_bg.jpg` / `.png`
  - `res://textures/backgrounds/parchment_bg.jpg` / `.png`
  - fallbacks: `res://textures/achievement_background.jpg`, `res://textures/biblical_background.jpg`

- Image recommendations:
  - Resolution: 1920×1080 or higher
  - Format: JPG (smaller) or PNG (supports transparency)
  - Palette: warm earth tones, golds, creams, soft blues
  - Keep the center area lighter for text readability

- Implementation notes:
  - The page automatically loads the first available image, scales it to cover the screen, and applies a semi-transparent parchment overlay to ensure readable text.
  - Programmatic override available via `AchievementsPage.set_background_image(path)`.

- Overlay & accessibility:
  - Use a semi-transparent overlay color such as `Color(0.96, 0.94, 0.88, 0.7)` to maintain readability.

- Future enhancements:
  - Multiple backgrounds (randomized), seasonal themes, and per-achievement backgrounds.

## Enhanced achievements flow
- Timed animations and toast notifications on unlock
- Claiming flow for rewards with immediate feedback (sound + animation)

## Testing
- Verify `player_progress.json` has `achievements_unlocked` entries
- Use debug console calls to trigger `RewardManager.grant_achievement_reward()` for testing

Date: 2026-01-19
