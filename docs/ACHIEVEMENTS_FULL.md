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
- Achievement artwork should be distinct; see `ACHIEVEMENT_BACKGROUND_GUIDE.md` for art templates and safe areas.

## Enhanced achievements flow
- Timed animations and toast notifications on unlock
- Claiming flow for rewards with immediate feedback (sound + animation)

## Testing
- Verify `player_progress.json` has `achievements_unlocked` entries
- Use debug console calls to trigger `RewardManager.grant_achievement_reward()` for testing

Date: 2026-01-19
