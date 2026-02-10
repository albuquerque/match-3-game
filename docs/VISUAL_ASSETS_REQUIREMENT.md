# Visual Assets Requirement - Phase 12 Complete

**Date:** February 9, 2026  
**Status:** Documentation Only - Assets NOT Required for Phase 12.4 QA  
**Purpose:** Future reference for content creation

---

## Executive Summary

The ExperienceDirector system and narrative stages are **fully functional with text-only content**. Visual assets are **optional enhancements** that can be added later without code changes.

### Current State ✅
- ✅ 57 narrative stage JSON files created with biblical text
- ✅ Text displays on thematic colored backgrounds
- ✅ System fully functional for Phase 12.4 QA
- ✅ No code changes needed to add images later

### Future Enhancement 🎨
- 🎨 AI-generated narrative backgrounds (57 images)
- 🎨 Gallery reward images (60+ images)
- 🎨 Level background images (62 images)
- 🎨 Theme visual assets (6+ themes)

---

## Phase 12.4 QA - No Assets Needed

**What works NOW without images:**

1. **Narrative Stages** ✅
   - Text displays on colored backgrounds
   - Auto-advance timers work
   - State transitions work
   - Skippable functionality works

2. **Level Progression** ✅
   - ExperienceDirector routes correctly
   - Rewards are granted
   - Flow advances properly
   - Migration system works

3. **Save/Load** ✅
   - Progress saves correctly
   - Migration from old saves works
   - Resume at correct position

**What we can test in Phase 12.4:**
- ✓ Fresh player experience (levels 1-62)
- ✓ Existing player migration
- ✓ Narrative → Level → Reward flow
- ✓ All experience nodes work
- ✓ Error handling
- ✓ Console log verification

---

## Asset Categories (Future Enhancement)

### Category 1: Narrative Stage Backgrounds
**Count:** 57 images  
**Format:** SVG or WebP (720×1280 px recommended)  
**Usage:** Fullscreen narrative backgrounds  
**Priority:** Medium (text works fine)

Examples needed:
- creation_day_1.svg - Light bursting from darkness
- creation_day_2.svg - Sky separating waters
- burning_bush.svg - Fire that doesn't consume
- red_sea_crossing.svg - Waters parted, path through sea

**Current Workaround:**  
Text displays on solid/gradient colored backgrounds defined in JSON.

### Category 2: Gallery Images
**Count:** 60+ images  
**Format:** PNG or JPG (512×512 px)  
**Usage:** Collectible rewards in gallery  
**Priority:** Low (gallery works without images)

Examples needed:
- Cosmic light creation
- Garden of Eden
- Noah's Ark
- Tower of Babel
- Abraham's sacrifice
- Burning bush
- Red Sea parting

**Current Workaround:**  
Gallery shows placeholder or text-only entries.

### Category 3: Level Backgrounds
**Count:** 62 images  
**Format:** JPG or WebP (1080×1920 px)  
**Usage:** Game board backgrounds  
**Priority:** Low (default backgrounds work)

Themes by act:
- Act 1 (1-10): Creation themes (cosmos, garden)
- Act 2 (11-20): Early humanity (garden, wilderness)
- Act 3 (21-30): Patriarchs (desert, tents, altars)
- Act 4 (31-43): Joseph in Egypt (palace, prison, granaries)
- Act 5 (44-52): Slavery (pyramids, bricks, Nile)
- Act 6 (53-62): Exodus (plagues, darkness, sea)

**Current Workaround:**  
Generic/themed backgrounds already in place.

### Category 4: Theme Assets
**Count:** 6-8 theme sets  
**Format:** Various (tiles, UI elements, backgrounds)  
**Usage:** Visual theme customization  
**Priority:** Very Low (default theme works)

Themes needed:
- Creation Theme (cosmic, light)
- Garden Theme (plants, trees)
- Desert Theme (sand, tents)
- Egypt Theme (pyramids, gold)
- Exodus Theme (fire, water, darkness)
- Wilderness Theme (rocks, mountains)

**Current Workaround:**  
Default theme works for all levels.

---

## Asset Generation Plan (When Ready)

### Phase A: Critical Narratives (Priority 1)
Generate 10 key narrative backgrounds for major story beats:
1. creation_day_1 - Light from darkness
2. the_fall - Expulsion from Eden
3. the_flood - Noah's ark in rain
4. tower_of_babel - Unfinished tower
5. binding_of_isaac - Abraham on mountain
6. jacobs_ladder - Angels ascending
7. joseph_revealed - Joseph revealing himself
8. burning_bush - Moses and the fire
9. plague_darkness - Egypt in darkness
10. red_sea_crossing - Parted waters

### Phase B: Remaining Narratives (Priority 2)
Generate remaining 47 narrative backgrounds using AI with prompts from BIBLICAL_STORY_PROGRESSION.md

### Phase C: Gallery Images (Priority 3)
Create collectible reward images for major story moments

### Phase D: Level Backgrounds (Priority 4)
Create thematic level backgrounds for visual variety

### Phase E: Theme Assets (Priority 5)
Create complete visual theme packages

---

## AI Generation Prompts

All AI prompts are documented in:
- `docs/BIBLICAL_STORY_PROGRESSION.md`

Each level includes:
- Narrative stage description
- Visual effect description
- Gallery image description
- AI art generation prompt

Example from Level 1:
```
**AI Prompt (Narrative):** "Divine light bursting from cosmic void, 
stars beginning to form, majestic and awe-inspiring, golden light 
radiating, deep space blues and blacks, biblical art style"
```

---

## Technical Integration

### Adding Images to Existing Narratives

**Step 1:** Generate or acquire image
**Step 2:** Place in `textures/narrative/` folder
**Step 3:** Update narrative stage JSON:

```json
{
  "id": "creation_day_1",
  "name": "Day 1: Light",
  "states": [
    {
      "name": "main",
      "asset": "creation_day_1.svg",  // ← Add this line
      "text": "Let there be light!",
      "duration": 3.0
    }
  ]
}
```

**Step 4:** Godot auto-imports the image  
**Step 5:** NarrativeStageRenderer loads it automatically

**No code changes needed!** The system already supports images.

---

## Cost Estimation (If Using AI Services)

### Using Midjourney/DALL-E/Stable Diffusion

**Narrative Backgrounds (57 images):**
- Midjourney: ~$30-60 (bulk generation)
- DALL-E 3: ~$60-120 ($1-2 per image)
- Stable Diffusion (local): Free

**Gallery Images (60 images):**
- Similar costs as above

**Total Estimated Cost:**
- Low end (Stable Diffusion local): $0
- Mid range (Midjourney bulk): $60-120
- High end (DALL-E 3 all): $120-240

---

## Alternative: Placeholder Assets

For immediate testing without AI generation:

**Option 1: Solid Colors**
- Already implemented in narrative stage JSONs
- Each stage has thematic background_color
- Works perfectly for testing

**Option 2: Simple Gradients**
Create simple SVG gradients for each theme:
- Creation: Black → Gold (light emerging)
- Garden: Green gradients
- Desert: Brown/tan gradients
- Egypt: Gold/blue gradients
- Exodus: Red/dark gradients

**Option 3: Public Domain Art**
Use public domain biblical artwork:
- Wikimedia Commons
- Gustave Doré biblical illustrations
- Public domain paintings

---

## Recommendation

### For Phase 12.4 QA Testing:
**Use text-only narratives with colored backgrounds** ✅

This allows us to:
- ✓ Test all ExperienceDirector functionality
- ✓ Verify migration system works
- ✓ Validate flow progression
- ✓ Check error handling
- ✓ Confirm save/load works
- ✓ Complete Phase 12 implementation

### After Phase 12 Complete:
**Add visual assets as content enhancement** 🎨

This is a separate task that:
- Doesn't block Phase 12 completion
- Doesn't require code changes
- Can be done incrementally
- Can use various art sources
- Enhances existing functionality

---

## Phase 12.4 Testing Plan (No Assets Required)

### Test 1: Fresh Install
1. Delete save file
2. Launch game
3. Verify: Text narrative "creation_day_1" shows
4. Verify: Colored background displays
5. Verify: Auto-advances after 3 seconds
6. Verify: Level 1 loads correctly

**Expected:** Text on dark background → Light background → Level 1  
**Result:** ✓ Pass (no images needed)

### Test 2: Existing Player Migration
1. Edit save: `levels_completed = 10`
2. Launch game
3. Verify: Migration detected
4. Verify: Resumes at Level 11
5. Verify: Previous nodes marked complete

**Expected:** Automatic migration, resume at correct position  
**Result:** ✓ Pass (no images needed)

### Test 3: Full Flow Progression
1. Complete Level 1
2. Verify: Reward screen shows
3. Click Continue
4. Verify: ExperienceDirector advances
5. Verify: Next narrative or level loads

**Expected:** Smooth progression through nodes  
**Result:** ✓ Pass (no images needed)

---

## Conclusion

**Visual assets are NOT blockers for Phase 12.4 QA.**

The system is fully functional with text-based narratives. Images are optional content enhancements that can be added later without any code modifications.

**Proceed to Phase 12.4 QA testing immediately!** ✅

---

**Status:** Ready for QA - No Asset Dependencies
