# Testing the Exodus Sea Parting Narrative

**Note:** This is a specific testing guide for Level 11. For complete narrative stage system documentation, see **[NARRATIVE_STAGE_GUIDE.md](NARRATIVE_STAGE_GUIDE.md)**.

**Status:** ✅ Ready to Test!  
**Level:** 11  
**File:** `data/narrative_stages/level_11.json`

---

## Quick Test (30 seconds)

### 1. Launch the Game
Run your game normally (GUI or from Godot editor)

### 2. Navigate to Level 11
- From world map, select level 11
- OR use level select if available

### 3. Start Level 11
Click "Start" to begin the level

### 4. Watch the Full Top Area!
The narrative fills the entire area from top of screen to the board (HUD overlays on top):

**At Level Start (0%):**
```
[HUD overlays on top: Score, Moves, Goals]
╔═══════════════════════════════════╗
║  Moses standing before the full   ║
║  sea (Dark blue water, Moses      ║
║  with staff) - FULL HEIGHT!       ║
╚═══════════════════════════════════╝
[Game board starts below]
```

**At 25% Progress:**
```
┌─────────────────────────────────────┐
│  Water begins to ripple             │
│  (Small waves, ripple effects)      │
└─────────────────────────────────────┘
```

**At 50% Progress:**
```
┌─────────────────────────────────────┐
│  Water shifts and parts slightly    │
│  (Small gap in middle, mist)        │
└─────────────────────────────────────┘
```

**At 75% Progress:**
```
┌─────────────────────────────────────┐
│  Water dramatically parting         │
│  (Large gap, water walls on sides)  │
└─────────────────────────────────────┘
```

**At Goal Complete:**
```
┌─────────────────────────────────────┐
│  ✨ Sea fully parted! Path visible ✨│
│  (Dry path, golden light rays)      │
└─────────────────────────────────────┘
```

---

## What to Look For

### Visual Indicators
✅ **Full-height narrative area** - From top of screen to board (~20%)  
✅ **HUD overlays on top** - Scoreboard visible over narrative  
✅ **Immersive presentation** - No gaps, fills entire top area  
✅ **Smooth fade transitions** - Images fade in/out (0.3s)  
✅ **Progressive changes** - Updates as you make progress  
✅ **Final celebration** - Golden victory image at end  
✅ **Board fully visible** - Starts cleanly below narrative  

### Console Messages
When narrative loads, you should see:

```
[NarrativeStageManager] Loading stage for level 11
[NarrativeStageController] Loading stage: exodus_sea_parting
[NarrativeStageController]   State: intro
[NarrativeStageController]   State: progress_25
[NarrativeStageController]   State: progress_50
[NarrativeStageController]   State: progress_75
[NarrativeStageController]   State: goal_complete
[NarrativeStageController]   Transitions: 6
[NarrativeStageController] State:  -> intro
[NarrativeStageRenderer] Loaded bundled asset: res://textures/narrative/moses_full_sea.svg
[NarrativeStageRenderer] Displayed texture
```

When state changes (e.g., 50% progress):

```
[NarrativeStageController] State: intro -> progress_50
[NarrativeStageRenderer] Loaded bundled asset: res://textures/narrative/water_shifting.svg
[NarrativeStageRenderer] Displayed texture
```

---

## Troubleshooting

### Nothing Shows at Top

**Check Console:**
```bash
# Look for these messages:
[NarrativeStageManager] Loading stage for level 11
[NarrativeStageRenderer] Loaded bundled asset...
```

**If you see "File not found":**
- Verify `data/narrative_stages/level_11.json` exists
- Check SVG files exist in `textures/narrative/`

**If you see no messages:**
- Make sure you're on level 11 (not another level)
- Check GameManager integration is working

### Images Don't Change

**Check Progress:**
- Level 11 is a score-based level (target: 8300 points)
- Progress is calculated as: `current_score / target_score`
- Make matches to increase score

**Expected Progress Points:**
- **25%** = 2075 points (1/4 of 8300)
- **50%** = 4150 points (1/2 of 8300)
- **75%** = 6225 points (3/4 of 8300)
- **100%** = 8300 points (goal complete)

### Wrong Images Showing

**Check Asset Paths:**
```bash
ls textures/narrative/
# Should show:
# moses_full_sea.svg
# water_rippling.svg
# water_shifting.svg
# water_parting.svg
# sea_parted.svg
```

---

## Testing Different Levels

### Test on Level 5
```bash
cp data/narrative_stages/level_10.json data/narrative_stages/level_5.json
```

### Test on Level 20
```bash
cp data/narrative_stages/level_10.json data/narrative_stages/level_20.json
```

### Remove from a Level
```bash
rm data/narrative_stages/level_10.json
```

---

## Advanced Testing

### Check All States Work

Play through level 10 slowly and verify each state appears:

1. **Start level** → See intro (Moses + full sea)
2. **Get to ~25% score** → See rippling water
3. **Get to ~50% score** → See parting begin
4. **Get to ~75% score** → See dramatic parting
5. **Complete level** → See victory with golden light

### Check Transitions Are Smooth

- Each state should fade out old image
- New image should fade in
- Transitions should take ~0.3 seconds
- No flashing or jumping

### Check Console for Errors

Watch for:
- ❌ "Asset not found" errors
- ❌ "Failed to load" messages
- ❌ Parse errors in JSON
- ✅ "Loaded bundled asset" success messages

---

## Performance Check

### Memory
- Assets are cached after first load
- Should see "Preloading assets" message
- Subsequent state changes use cached textures

### CPU
- Transitions use Godot's Tween system
- Minimal CPU impact during gameplay
- No frame rate drops expected

---

## Expected Output (Full Flow)

```
[Game Starts]
  ↓
[Load Level 11]
  ↓
[NarrativeStageManager] Loading stage for level 11
[NarrativeStageController] Loading stage: exodus_sea_parting
[NarrativeStageController] Transitions: 6
[NarrativeStageRenderer] Preloaded 5 assets
  ↓
[Level Starts]
  ↓
[NarrativeStageController] State:  -> intro
[NarrativeStageRenderer] Displayed texture
  ↓
[Player Makes Matches - 25% Progress (2075 points)]
  ↓
[NarrativeStageController] State: intro -> progress_25
[NarrativeStageRenderer] Displayed texture
  ↓
[Player Makes Matches - 50% Progress (4150 points)]
  ↓
[NarrativeStageController] State: progress_25 -> progress_50
[NarrativeStageRenderer] Displayed texture
  ↓
[Player Makes Matches - 75% Progress (6225 points)]
  ↓
[NarrativeStageController] State: progress_50 -> progress_75
[NarrativeStageRenderer] Displayed texture
  ↓
[Player Completes Level (8300 points)]
  ↓
[NarrativeStageController] State: progress_75 -> goal_complete
[NarrativeStageRenderer] Displayed texture
  ↓
[Victory Screen Appears]
```

---

## Success Criteria

✅ Narrative appears at top of screen on level 11  
✅ Shows Moses and sea at start  
✅ Changes at 25%, 50%, 75% progress  
✅ Shows victory image at completion  
✅ Smooth fade transitions between states  
✅ No errors in console  
✅ Game remains playable throughout  

---

## Next Steps After Testing

1. **Works perfectly?** → Try creating your own narrative for another level
2. **Need adjustments?** → Edit the JSON or SVG files
3. **Want more levels?** → Copy level_11.json to other level numbers
4. **Ready for DLC?** → See DLC integration guide

---

**You're ready to test!** 🎬

Launch the game, play level 11, and watch the Red Sea part as you progress! The narrative stage should appear as a banner at the top of the screen, updating dynamically as you play.
