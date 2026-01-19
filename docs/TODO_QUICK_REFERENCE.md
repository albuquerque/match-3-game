# Implementation Plan - Quick Reference

## Date: January 15, 2026

## What's Already Done ✅
- Basic gameplay (match-3 mechanics)
- Boosters (hammer, swap, bomb, etc.)
- Lightning beam effects
- Currency system (coins, gems)
- Level progression
- Basic gallery (artwork viewing)
- Basic achievements
- Settings (audio controls)
- Level transition with rewards

## What Needs to Be Built 🚧

### IMMEDIATE (Next 1-2 weeks)
1. **Star Rating System** ⭐⭐⭐
2. **Better Level Complete Screen** (show stars + rewards)
3. **Reposition Boosters** (left side vertical)
4. **Better HUD Layout** (already started)

### SOON (Next 2-4 weeks)
5. **World Map** (level selection with chapters)
6. **Puzzle Pieces** (collectible system)
7. **Story Cards** (Bible heroes album)
8. **Daily Rewards** (login bonuses)

### LATER (Next 1-2 months)
9. **Missions System** (match X tiles, beat X levels)
10. **Chests System** (bronze/silver/gold with timers)
11. **Events** (time-limited challenges)
12. **Enhanced Shop** (better bundles & offers)

## File Reference

| Feature | New Files Needed | Files to Modify |
|---------|------------------|-----------------|
| Star Rating | StarRatingManager.gd | GameManager.gd, LevelTransition.gd |
| World Map | WorldMap.gd, ChapterManager.gd | MainMenu.gd, LevelManager.gd |
| Puzzles | PuzzleManager.gd, PuzzleScreen.gd | RewardManager.gd, GalleryUI.gd |
| Cards | CardManager.gd, CardAlbum.gd | GalleryUI.gd |
| Daily Rewards | DailyRewardManager.gd, RewardsHub.gd | - |
| Missions | MissionManager.gd | RewardsHub.gd, GameManager.gd |
| Chests | ChestManager.gd, ChestOpenScreen.gd | RewardsHub.gd |
| Events | EventManager.gd | RewardsHub.gd |

## Time Estimates
- **Core Features (Must Have):** ~40 hours
- **Nice to Have:** ~45 hours  
- **Polish & Extra:** ~20 hours
- **TOTAL:** ~105 hours (2.5-3 months @ 10 hrs/week)

## Recommended Order
1. Start with Star Rating (foundation for progression)
2. Build World Map (better UX than level list)
3. Add Puzzle Pieces (engagement hook)
4. Implement Daily Rewards (retention)
5. Add remaining features based on feedback

## Data Files Needed
- `data/puzzles.json` - Puzzle definitions
- `data/cards.json` - Story card data
- `data/missions.json` - Mission templates
- `data/events.json` - Event configuration
- `data/chapters.json` - World map chapters

## Assets Needed
- Badge icons (PNG, 256x256)
- Card images (Bible heroes)
- Puzzle piece images
- Chest icons (bronze/silver/gold)
- World map background
- Chapter/node icons

---

**See `docs/TODO_IMPLEMENTATION_PLAN.md` for detailed breakdown**

