# Exodus Narrative - Level 11 Setup Complete

**Note:** This is a specific setup guide for Level 11. For complete narrative stage system documentation, see **[NARRATIVE_STAGE_GUIDE.md](NARRATIVE_STAGE_GUIDE.md)**.

✅ **Status:** Ready to Test  
📍 **Level:** 11  
🎬 **Narrative:** Exodus Sea Parting  

---

## Quick Start

**Just launch the game and play Level 11!**

The narrative stage will automatically:
1. Load when level 11 starts
2. Display Moses before the full sea
3. Update progressively as you score points:
   - **2,075 pts** (25%) → Water rippling
   - **4,150 pts** (50%) → Sea begins parting  
   - **6,225 pts** (75%) → Dramatic parting
   - **8,300 pts** (100%) → Victory with golden light!

---

## Files Verified

✅ `data/narrative_stages/level_11.json` - Configuration  
✅ `textures/narrative/moses_full_sea.svg` - 1.3 KB  
✅ `textures/narrative/water_rippling.svg` - 1.4 KB  
✅ `textures/narrative/water_shifting.svg` - 1.6 KB  
✅ `textures/narrative/water_parting.svg` - 1.6 KB  
✅ `textures/narrative/sea_parted.svg` - 2.1 KB  

---

## What to Expect

### Visual Experience

**Position:**
Full-height area from the top of screen down to the game board (~20% of screen).

**Size:**
Full width, fills entire top area (~256px on 1280px screen).

**Placement:**
- Starts at very top of screen (0%)
- Extends down to top of board (~20%)
- HUD overlays on top (can be hidden with narrative effects)
- Z-index: -10 (behind HUD, in front of board)
- Immersive full-area design

**Transitions:**
Smooth fade effects (0.3 seconds) between each state.

**States:**
5 progressive images that update based on your score.

### Performance

- **Memory:** ~8 KB total (all 5 SVG images)
- **CPU:** Minimal (tween-based animations)
- **Load Time:** Instant (assets preloaded)

---

## Console Output to Watch

```
[NarrativeStageManager] Loading stage for level 11
[NarrativeStageController] Loading stage: exodus_sea_parting
[NarrativeStageRenderer] Preloaded 5 assets
[NarrativeStageController] State:  -> intro
```

Then as you score:
```
[NarrativeStageController] State: intro -> progress_25
[NarrativeStageController] State: progress_25 -> progress_50
[NarrativeStageController] State: progress_50 -> progress_75
[NarrativeStageController] State: progress_75 -> goal_complete
```

---

## Testing Checklist

- [ ] Launch game
- [ ] Navigate to Level 11
- [ ] Start level
- [ ] See Moses + sea at top (intro state)
- [ ] Score ~2,075 points → See rippling water
- [ ] Score ~4,150 points → See sea parting
- [ ] Score ~6,225 points → See dramatic parting
- [ ] Complete level (8,300 points) → See victory image
- [ ] Check smooth fade transitions
- [ ] Verify no errors in console

---

## Troubleshooting

**Nothing shows?**
- Check console for "[NarrativeStage]" messages
- Verify you're on Level 11
- Confirm files exist (see Files Verified above)

**Images don't change?**
- Make matches to increase score
- Watch console for state transitions
- Progress milestones: 2075, 4150, 6225, 8300 points

**Wrong images?**
- Verify SVG files in textures/narrative/
- Check JSON references correct filenames
- Clear asset cache (restart game)

---

## Quick Commands

**Test on different level (e.g., Level 5):**
```bash
cp data/narrative_stages/level_11.json data/narrative_stages/level_5.json
```

**Remove from Level 11:**
```bash
rm data/narrative_stages/level_11.json
```

**Restore original:**
```bash
cp data/narrative_stages/exodus_sea_parting.json data/narrative_stages/level_11.json
```

---

## Documentation

📖 **Full Test Guide:** `docs/TESTING_EXODUS_NARRATIVE.md`  
📖 **Implementation Guide:** `docs/NARRATIVE_STAGE_IMPLEMENTATION.md`  
📖 **Quick Start:** `docs/NARRATIVE_STAGE_QUICK_START.md`  

---

**Everything is ready! Launch the game and enjoy the dynamic storytelling on Level 11!** 🎬🌊✨
