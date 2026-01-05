# Testing the Achievements & Daily Rewards System

## File Location
The player progress data is stored at:
```
~/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json
```

## Quick Access Command
```bash
# View the file
cat "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json"

# Edit the file (using nano)
nano "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json"

# Edit the file (using vim)
vim "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json"

# Edit the file (using VSCode)
code "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json"
```

## Testing Different Streak Scenarios

### Test Scenario 1: Test Day 1 Rewards
**Objective:** Test first-time login reward claim

**Steps:**
1. Close the game if running
2. Edit `player_progress.json` and set:
   ```json
   "daily_streak": 1,
   "last_login_date": "2025-12-20",
   "last_daily_reward_claim": ""
   ```
3. Save and launch the game
4. Go to Achievements page
5. Click "Claim Daily Reward"
6. **Expected Result:** Popup shows "💰 Coins x60" and "⭐ Hammer x1"

### Test Scenario 2: Test Day 3 Rewards
**Objective:** Test small booster tier (days 1-3)

**Steps:**
1. Close the game
2. Edit `player_progress.json`:
   ```json
   "daily_streak": 3,
   "last_login_date": "2025-12-20",
   "last_daily_reward_claim": "2025-12-19"
   ```
3. Save and launch the game
4. Go to Achievements and claim reward
5. **Expected Result:** Popup shows Hammer x1, Swap x1, Shuffle x1, plus coins

### Test Scenario 3: Test Day 7 Rewards
**Objective:** Test special booster tier (day 7+)

**Steps:**
1. Close the game
2. Edit `player_progress.json`:
   ```json
   "daily_streak": 7,
   "last_login_date": "2025-12-20",
   "last_daily_reward_claim": "2025-12-19"
   ```
3. Save and launch the game
4. Go to Achievements and claim reward
5. **Expected Result:** Line Blast x2, Bomb 3x3 x2, Chain Reaction x1, 10 gems, 120 coins

### Test Scenario 4: Test Week 2 Bonus
**Objective:** Verify bonus gems for multiple weeks

**Steps:**
1. Close the game
2. Edit `player_progress.json`:
   ```json
   "daily_streak": 14,
   "last_login_date": "2025-12-20",
   "last_daily_reward_claim": "2025-12-19"
   ```
3. Save and launch the game
4. Go to Achievements and claim reward
5. **Expected Result:** Same as Day 7 but with 15 gems instead of 10 (10 + 5 bonus)

### Test Scenario 5: Test Already Claimed
**Objective:** Verify can't claim twice in one day

**Steps:**
1. Close the game
2. Edit `player_progress.json`:
   ```json
   "daily_streak": 5,
   "last_login_date": "2025-12-20",
   "last_daily_reward_claim": "2025-12-20"
   ```
3. Save and launch the game
4. Go to Achievements page
5. **Expected Result:** Button shows "✓ Reward Claimed Today" and is disabled

### Test Scenario 6: Test Badge Unlocks
**Objective:** Verify milestone badges appear unlocked

**Steps:**
1. Close the game
2. Test different streak values to see badge unlocks:

**For 3-day badge:**
```json
"daily_streak": 3
```
Expected: 🌟 Consistent Player badge unlocked

**For 7-day badge:**
```json
"daily_streak": 7
```
Expected: 🔥 Week Warrior badge unlocked

**For 14-day badge:**
```json
"daily_streak": 14
```
Expected: 💎 Dedicated badge unlocked

**For 30-day badge:**
```json
"daily_streak": 30
```
Expected: 👑 Legend badge unlocked

### Test Scenario 7: Test Streak Break
**Objective:** Verify streak resets when a day is missed

**Steps:**
1. Close the game
2. Edit `player_progress.json`:
   ```json
   "daily_streak": 5,
   "last_login_date": "2025-12-18"
   ```
   (Note: last_login_date is 2 days ago)
3. Save and launch the game
4. **Expected Result:** Streak resets to 1 on next login

## Sample Complete JSON for Testing

### Day 7 with Claimable Reward
```json
{
  "achievements_unlocked": [],
  "audio": {
    "music_enabled": true,
    "music_volume": 0.7,
    "muted": false,
    "sfx_enabled": true,
    "sfx_volume": 0.8
  },
  "boosters": {
    "bomb_3x3": 0,
    "chain_reaction": 0,
    "column_clear": 0,
    "extra_moves": 0,
    "hammer": 0,
    "line_blast": 0,
    "row_clear": 0,
    "shuffle": 0,
    "swap": 0,
    "tile_squasher": 0
  },
  "coins": 100,
  "daily_streak": 7,
  "gems": 10,
  "last_daily_reward_claim": "2025-12-19",
  "last_life_regen_time": 1766192705.34983,
  "last_login_date": "2025-12-20",
  "levels_completed": 0,
  "lives": 5,
  "selected_theme": "legacy",
  "total_matches": 0,
  "total_special_tiles_used": 0,
  "total_stars": 0,
  "unlocked_themes": ["legacy"]
}
```

## Key Fields for Testing

| Field | Purpose | Values |
|-------|---------|--------|
| `daily_streak` | Current login streak | 1, 3, 7, 14, 30, etc. |
| `last_login_date` | Last day player logged in | "YYYY-MM-DD" format |
| `last_daily_reward_claim` | Last day reward was claimed | "YYYY-MM-DD" or "" for never claimed |
| `coins` | Player's coin balance | Any integer |
| `gems` | Player's gem balance | Any integer |
| `boosters` | Booster inventory | Object with booster counts |

## Testing Tips

1. **Always close the game before editing** - Changes won't apply if game is running
2. **Use valid JSON syntax** - One missing comma breaks everything
3. **Keep backups** - Copy the file before testing:
   ```bash
   cp "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json" "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json.backup"
   ```
4. **Test incrementally** - Change one thing at a time
5. **Check console output** - Look for "[RewardManager] Daily login streak: X days"

## Restore Backup
If you mess up the JSON file:
```bash
# Restore from backup
cp "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json.backup" "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json"

# Or delete and let game create fresh
rm "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json"
```

## Quick Test Script

Create a file called `test_rewards.sh`:

```bash
#!/bin/bash

SAVE_FILE="$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json"

# Backup
cp "$SAVE_FILE" "${SAVE_FILE}.backup"

# Test Day 7
cat > "$SAVE_FILE" << 'EOF'
{
  "achievements_unlocked": [],
  "audio": {"music_enabled": true, "music_volume": 0.7, "muted": false, "sfx_enabled": true, "sfx_volume": 0.8},
  "boosters": {"bomb_3x3": 0, "chain_reaction": 0, "column_clear": 0, "extra_moves": 0, "hammer": 0, "line_blast": 0, "row_clear": 0, "shuffle": 0, "swap": 0, "tile_squasher": 0},
  "coins": 100,
  "daily_streak": 7,
  "gems": 10,
  "last_daily_reward_claim": "2025-12-19",
  "last_life_regen_time": 1766192705.34983,
  "last_login_date": "2025-12-20",
  "levels_completed": 0,
  "lives": 5,
  "selected_theme": "legacy",
  "total_matches": 0,
  "total_special_tiles_used": 0,
  "total_stars": 0,
  "unlocked_themes": ["legacy"]
}
EOF

echo "✅ Set to Day 7 streak - reward ready to claim!"
echo "Launch the game and check Achievements page"
```

Make it executable and run:
```bash
chmod +x test_rewards.sh
./test_rewards.sh
```

## Common Issues

### Issue: Button still disabled after editing
**Solution:** Make sure `last_daily_reward_claim` is set to yesterday or empty string `""`

### Issue: Streak doesn't match
**Solution:** Make sure `last_login_date` is set to today's date (2025-12-20)

### Issue: JSON syntax error
**Solution:** Validate your JSON at https://jsonlint.com/ or use:
```bash
cat "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json" | python3 -m json.tool
```

### Issue: Changes don't take effect
**Solution:** 
1. Make sure game is completely closed (check Activity Monitor)
2. Verify file permissions are correct
3. Check file was actually saved

## Automated Testing Scenarios

You can create multiple test files and swap them:

```bash
# Create test scenarios
mkdir ~/achievements_tests

# Day 1 scenario
echo '{...}' > ~/achievements_tests/day1.json

# Day 7 scenario  
echo '{...}' > ~/achievements_tests/day7.json

# Swap to Day 7 test
cp ~/achievements_tests/day7.json "$HOME/Library/Application Support/Godot/app_userdata/Match-3 Game/player_progress.json"
```

---

**Remember:** Always close the game before editing the save file, and keep backups!

