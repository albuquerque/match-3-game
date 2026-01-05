# Achievements and Daily Login System

## Overview
The game now features an **Achievements Page** with a **Daily Login Streak** system and associated rewards. Players are incentivized to login daily to build their streak and earn increasingly valuable rewards.

## Features Implemented

### 1. Daily Login Streak Tracking
- **Automatic Tracking**: The system automatically tracks consecutive daily logins
- **Streak Counter**: Displays current streak (e.g., "Current Streak: 7 days")
- **Streak Breaks**: If a player misses a day, the streak resets to 1
- **Persistent Storage**: Streak data is saved in `player_progress.json`

### 2. Daily Rewards System
Players can claim rewards once per day based on their login streak:

#### Reward Tiers

**Days 1-3: Small Boosters**
- Day 1: 50 coins + Hammer booster x1
- Day 2: 60 coins + Hammer x1 + Swap x1  
- Day 3: 70 coins + Hammer x1 + Swap x1 + Shuffle x1

**Days 4-6: Medium Boosters**
- Day 4: 80 coins + Row Clear x1 + Column Clear x1
- Day 5: 90 coins + Row Clear x1 + Column Clear x1 + Bomb 3x3 x1
- Day 6: 100 coins + Row Clear x1 + Column Clear x1 + Bomb 3x3 x1 + 5 gems

**Day 7+: Special Boosters**
- Day 7+: 110+ coins + Line Blast x2 + Bomb 3x3 x2 + Chain Reaction x1 + 10 gems
- **Bonus**: Every additional week adds +5 gems to the reward

### 3. Achievement Badges
Visual milestone badges are displayed for reaching streak goals:

- 🌟 **Consistent Player**: Login 3 days in a row
- 🔥 **Week Warrior**: Login 7 days in a row  
- 💎 **Dedicated**: Login 14 days in a row
- 👑 **Legend**: Login 30 days in a row

Badges show as:
- **Locked** (grayed out) until unlocked
- **Unlocked** (colored with checkmark) when earned

### 4. Achievements Page UI

#### Access
- Available from **StartPage** via the "🏆 Achievements" button
- Located on a separate row below Start Level and Exchange Gems buttons
- Positioned next to Settings button for easy access

#### Layout
- **Header**: "Achievements" title
- **Streak Section**: 
  - 🔥 Daily Login Streak display
  - Current streak count with color coding (orange for 7+, green for 4-6, white for 1-3)
  - "Claim Daily Reward" button (enabled once per day)
  - Status message (shows if reward was already claimed today)
- **Badges Section**:
  - Scrollable list of milestone badges
  - Each badge shows title, description, and locked/unlocked status
- **Back Button**: Returns to previous screen

#### Reward Notification
When claiming a daily reward, a beautiful popup appears showing:
- **Title**: "🎁 Day X Reward Claimed!"
- **Reward List**: All items received with icons (💰 for coins, 💎 for gems, ⭐ for boosters)
- **Formatted Display**: Each reward shows name and quantity (e.g., "Row Clear x1")
- **Close Button**: "Awesome!" button to dismiss the popup
- **Animations**: Smooth fade-in animation for visual appeal

## Technical Implementation

### Files Created
- `scripts/AchievementsPage.gd` - Full achievements page implementation

### Files Modified
- `scripts/RewardManager.gd`:
  - Added `daily_streak` tracking
  - Added `last_login_date` for consecutive day detection
  - Added `last_daily_reward_claim` to prevent multiple claims per day
  - Updated `check_daily_login()` to increment/reset streaks
  - Removed automatic reward grants (now manual via UI)
  
- `scripts/StartPage.gd`:
  - Added `achievements_pressed` signal
  - Added "🏆 Achievements" button
  - Connected button to signal handler

- `scripts/GameUI.gd`:
  - Added `_on_startpage_achievements_pressed()` handler
  - Added `_show_achievements_page()` to instance and display page
  - Added `_on_achievements_back_pressed()` to handle page closure

### Data Persistence
All achievement data is saved in `user://player_progress.json`:

```json
{
  "daily_streak": 7,
  "last_login_date": "2025-12-20",
  "last_daily_reward_claim": "2025-12-20",
  "achievements_unlocked": [],
  ...
}
```

## User Experience Flow

### First Time Login
1. Player opens game → `daily_streak` set to 1
2. Player navigates to Achievements page
3. Sees "Current Streak: 1 days"
4. Clicks "🎁 Claim Daily Reward"
5. **Beautiful popup appears** showing all rewards received:
   - Displays "🎁 Day 1 Reward Claimed!"
   - Lists: "💰 Coins x50" and "⭐ Hammer x1"
   - "Awesome!" button to close
6. Rewards are automatically added to inventory
7. Button changes to "✓ Reward Claimed Today"
8. Player returns to game with new boosters ready to use

### Consecutive Logins
1. Player opens game next day → `daily_streak` increments to 2
2. Player can claim new rewards
3. Streak continues building

### Missed Day
1. Player skips a day → `daily_streak` resets to 1
2. Must rebuild streak from Day 1

### Milestone Unlocks
- As streak reaches 3, 7, 14, 30 days, corresponding badges unlock
- Visual feedback shows badges changing from locked to unlocked state

## Reward Claiming Logic

The `_get_daily_rewards()` method in `AchievementsPage.gd` determines rewards:

```gdscript
func _get_daily_rewards(streak: int) -> Dictionary:
    var rewards = {}
    
    # Base coin reward
    rewards["coins"] = 50 + (streak * 10)
    
    # Streak-based boosters
    if streak >= 1 and streak <= 3:
        # Days 1-3: Small boosters
        # ...
    elif streak >= 4 and streak <= 6:
        # Days 4-6: Medium boosters
        # ...
    elif streak >= 7:
        # Day 7+: Special boosters
        # Bonus gems increase with weeks
        var weeks = int(streak / 7)
        rewards["gems"] = 10 + ((weeks - 1) * 5)
    
    return rewards
```

## Future Enhancements (Optional)

### Potential Additions
1. **More Achievement Types**:
   - Total levels completed
   - Total special tiles created
   - Total matches made
   - High score achievements

2. **Streak Rewards Expansion**:
   - Monthly streak bonuses
   - Special avatar frames for high streaks
   - Exclusive boosters at 30/60/90 days

3. **Social Features**:
   - Share achievements to social media
   - Compare streaks with friends
   - Leaderboards for longest streaks

4. **Animations**:
   - Particle effects when claiming rewards
   - Badge unlock animations
   - Streak milestone celebrations

5. **Notifications**:
   - Daily reminder to claim reward
   - Streak at-risk warning if 22+ hours since last login
   - Push notifications for mobile builds

## Testing

✅ Daily streak increments on consecutive logins  
✅ Streak resets when day is skipped  
✅ Rewards can only be claimed once per day  
✅ Badges unlock at correct milestones  
✅ Reward notifications display correctly  
✅ Data persists across sessions  
✅ Achievements page accessible from StartPage  
✅ Back button returns to StartPage

## Summary

The achievements system successfully:
- Encourages daily player engagement through streak tracking
- Provides escalating rewards to retain players
- Offers visual progression through badge system
- Integrates seamlessly with existing reward infrastructure
- Maintains clean separation between UI and data logic
- Persists all data reliably

