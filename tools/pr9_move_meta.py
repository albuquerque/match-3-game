#!/usr/bin/env python3
"""PR 9 — move meta (progression, rewards, profile, systems) to meta/ layer."""
import os, shutil, subprocess

ROOT = "/Users/sal76/src/match-3-game"
os.chdir(ROOT)

# ── 1. Create destination directories ────────────────────────────────────────
for d in [
    "meta",
    "meta/progression",
    "meta/rewards",
    "meta/rewards/system",
    "meta/profile",
    "meta/systems",
]:
    os.makedirs(d, exist_ok=True)
    print(f"  mkdir  {d}/")

# ── 2. Move map ───────────────────────────────────────────────────────────────
MOVES = [
    # Progression
    ("scripts/progression/AchievementManager.gd",  "meta/progression/AchievementManager.gd"),
    ("scripts/progression/GalleryManager.gd",       "meta/progression/GalleryManager.gd"),
    ("scripts/progression/ProfileManager.gd",       "meta/progression/ProfileManager.gd"),
    ("scripts/progression/ProgressManager.gd",      "meta/progression/ProgressManager.gd"),
    # Rewards — top-level managers
    ("scripts/RewardManager.gd",                    "meta/rewards/RewardManager.gd"),
    ("scripts/StarRatingManager.gd",                "meta/rewards/StarRatingManager.gd"),
    ("scripts/RewardOrchestrator.gd",               "meta/rewards/RewardOrchestrator.gd"),
    # Rewards — reward_system subsystem
    ("scripts/reward_system/ContainerConfigLoader.gd",       "meta/rewards/system/ContainerConfigLoader.gd"),
    ("scripts/reward_system/ContainerParticleSpawner.gd",    "meta/rewards/system/ContainerParticleSpawner.gd"),
    ("scripts/reward_system/ContainerSelectionRules.gd",     "meta/rewards/system/ContainerSelectionRules.gd"),
    ("scripts/reward_system/RewardContainer.gd",             "meta/rewards/system/RewardContainer.gd"),
    ("scripts/reward_system/RewardPresentationProfile.gd",   "meta/rewards/system/RewardPresentationProfile.gd"),
    ("scripts/reward_system/RewardRevealSystem.gd",          "meta/rewards/system/RewardRevealSystem.gd"),
    ("scripts/reward_system/RewardSummaryPanel.gd",          "meta/rewards/system/RewardSummaryPanel.gd"),
    ("scripts/reward_system/RewardTransitionController.gd",  "meta/rewards/system/RewardTransitionController.gd"),
    ("scripts/reward_system/SimpleRewardUI.gd",              "meta/rewards/system/SimpleRewardUI.gd"),
    # Profile / game state model
    ("scripts/model/GameState.gd",                  "meta/profile/GameState.gd"),
    ("scripts/LevelProgress.gd",                    "meta/profile/LevelProgress.gd"),
    # Systems
    ("scripts/CollectionManager.gd",                "meta/systems/CollectionManager.gd"),
    ("scripts/systems/ContentPackTranslationLoader.gd", "meta/systems/ContentPackTranslationLoader.gd"),
    ("scripts/systems/GalleryImageLoader.gd",       "meta/systems/GalleryImageLoader.gd"),
    ("scripts/systems/ShardDropSystem.gd",          "meta/systems/ShardDropSystem.gd"),
    ("scripts/systems/StoryManager.gd",             "meta/systems/StoryManager.gd"),
]

# ── 3. Build path-replacement map ─────────────────────────────────────────────
PATH_MAP = {}
for src, dst in MOVES:
    old_res = "res://" + src
    new_res = "res://" + dst
    PATH_MAP[old_res] = new_res

print(f"\n{len(MOVES)} files to move.")

# ── 4. git mv each file ────────────────────────────────────────────────────────
print("\nMoving files with git mv:")
for src, dst in MOVES:
    if not os.path.exists(src):
        print(f"  SKIP (missing): {src}")
        continue
    result = subprocess.run(["git", "mv", src, dst], capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  git mv  {src}  ->  {dst}")
    else:
        print(f"  WARN git mv failed: {result.stderr.strip()} — falling back")
        shutil.copy2(src, dst)
        os.remove(src)

# ── 5. Update all res:// paths in source files ────────────────────────────────
print("\nUpdating res:// paths in source files:")
changed = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [d for d in dirnames
                   if not d.startswith(".")
                   and d not in ("android", ".venv", "tools", "builds")]
    for fname in filenames:
        if not fname.endswith((".gd", ".tscn", ".tres", ".godot")):
            continue
        fpath = os.path.join(dirpath, fname)
        try:
            text = open(fpath, "r", encoding="utf-8").read()
        except Exception:
            continue
        new_text = text
        for old, new in PATH_MAP.items():
            new_text = new_text.replace(old, new)
        if new_text != text:
            open(fpath, "w", encoding="utf-8").write(new_text)
            rel = os.path.relpath(fpath, ROOT)
            print(f"  updated  {rel}")
            changed.append(rel)

print(f"\nUpdated {len(changed)} files.")

# ── 6. Move .uid sidecars (untracked) ─────────────────────────────────────────
print("\nMoving .uid sidecars:")
for src, dst in MOVES:
    uid_src = src + ".uid"
    uid_dst = dst + ".uid"
    if os.path.exists(uid_src):
        shutil.move(uid_src, uid_dst)
        print(f"  uid  {uid_src}  ->  {uid_dst}")

# ── 7. Remove now-empty old directories ───────────────────────────────────────
for d in [
    "scripts/reward_system",
    "scripts/systems",
    "scripts/model",
    "scripts/progression",
    "scripts/managers",  # stale duplicates — unreferenced
]:
    dp = os.path.join(ROOT, d)
    if os.path.isdir(dp) and not os.listdir(dp):
        os.rmdir(dp)
        print(f"  rmdir  {d}/")
    elif os.path.isdir(dp):
        remaining = os.listdir(dp)
        print(f"  NOTE   {d}/ not empty, remaining: {remaining}")

# ── 8. Delete stale scripts/managers/ duplicates ─────────────────────────────
stale = [
    "scripts/managers/GalleryManager.gd",
    "scripts/managers/ProgressManager.gd",
]
for f in stale:
    fp = os.path.join(ROOT, f)
    if os.path.exists(fp):
        result = subprocess.run(["git", "rm", "-f", f], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"  git rm  {f}  (stale duplicate)")
        else:
            os.remove(fp)
            print(f"  rm  {f}  (stale duplicate)")

# ── 9. Clear Godot filesystem cache ───────────────────────────────────────────
for cache in [".godot/editor/filesystem_cache10", ".godot/uid_cache.bin"]:
    cp = os.path.join(ROOT, cache)
    if os.path.exists(cp):
        os.remove(cp)
        print(f"  cleared  {cache}")

print("\nDone. Open project in Godot editor before running.")
