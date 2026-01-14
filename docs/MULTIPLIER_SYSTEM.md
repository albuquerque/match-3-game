# Multiplier Mini-Game System

## Overview
The level completion screen features an interactive multiplier mini-game where players earn reward multipliers (1.0x to 3.0x) based on timing. After watching a rewarded ad, players tap to stop a moving pointer and claim their chosen multiplier.

## Player Flow
1. Complete level → Rewards screen shows
2. Pointer auto-starts moving across multiplier bar
3. Player taps to stop pointer on desired zone
4. Rewarded ad is shown
5. After watching ad, multiplier is applied to rewards
6. Result message auto-fades after 3 seconds
7. Next level resets with fresh moving pointer

## Multiplier Zones

The bar has 7 symmetric colored zones:

- **0-15%** and **85-100%**: 1.0x (Gray) - Edge zones
- **15-30%** and **70-85%**: 1.5x (Green) - Good
- **30-45%** and **55-70%**: 2.0x (Blue) - Better
- **45-55%**: 3.0x (Purple) - JACKPOT (center)

Expected average with random timing: ~1.7x

## Key Features

- Auto-start - Pointer moves immediately, no button needed
- Skill-based - Better timing = better rewards (up to 3x)
- Fair preview - Player sees zones before tapping
- Clean UI - Result auto-fades, no clutter between levels
- AdMob integrated - Seamless rewarded ad integration
- Test mode - 2-second simulation on desktop

## Technical Details

**File**: `scripts/LevelTransition.gd`

**Key Variables**:
- `_pointer_speed = 200.0` - pixels per second
- `_multiplier_active` - game running state
- `_selected_multiplier` - chosen multiplier (1.0-3.0)

**Implementation**:
- Pointer movement in `_process(delta)` - bounces at edges
- Input handling in `_input(event)` - touch and mouse
- Auto-fade using `_schedule_label_fade()` - 3 second delay, 0.5 second fade

## Customization

**Make easier**: Decrease `_pointer_speed` or increase jackpot zone size
**Make harder**: Increase speed or decrease jackpot zone
**Change zones**: Edit `_multiplier_config` array in LevelTransition.gd

## Integration

See [ADMOB_INTEGRATION.md](ADMOB_INTEGRATION.md) for AdMob setup and configuration.

## Testing

**Desktop**: F5 in Godot → Complete level → Tap to stop → Wait 2 seconds
**Mobile**: Build APK → Install → Complete level → Tap → Watch real ad

