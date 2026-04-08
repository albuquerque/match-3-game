#!/usr/bin/env python3
"""PR 12 — Final Cleanup: remove dead scripts, orphan .uid files, stale game_debug.log."""
import os, subprocess

ROOT = "/Users/sal76/src/match-3-game"
os.chdir(ROOT)

# ── Files to git rm (tracked dead code) ──────────────────────────────────────
DEAD_TRACKED = [
    # Unreferenced by any .gd or .tscn
    "scripts/LevelTransition.gd",
    "scripts/GalleryUI.gd",
    "scripts/RewardNotification.gd",
    "scripts/DLCDownloadTest.gd",
    "scripts/DLCSystemTest.gd",
    # Old root-level duplicates — live versions are in scripts/ui/
    "scripts/AchievementsPage.gd",
    "scripts/ShopUI.gd",
    # Stale log committed by mistake
    "scripts/game_debug.log",
]

print("Removing tracked dead files with git rm:")
for f in DEAD_TRACKED:
    if os.path.exists(f):
        r = subprocess.run(["git", "rm", "-f", f], capture_output=True, text=True, cwd=ROOT)
        if r.returncode == 0:
            print(f"  git rm  {f}")
        else:
            print(f"  WARN: {r.stderr.strip()}")
    else:
        print(f"  SKIP (already gone): {f}")

# ── Orphan .uid files (untracked — just delete) ───────────────────────────────
ORPHAN_UIDS = [
    "scripts/SettingsDialog.gd.uid",
    "scripts/WorldMap.gd.uid",
    "scripts/TextureCache.gd.uid",
    "scripts/GameManager.gd.uid",
    "scripts/ui/BoosterPanel.gd.uid",
    "scripts/ui/gallery_adapter.gd.uid",
    "scripts/ui/FloatingMenu.gd.uid",
    "scripts/ui/UIBootstrap.gd.uid",
    "scripts/ui/GalleryUI.gd.uid",
    "scripts/ui/AchievementsPanel.gd.uid",
    "scripts/ui/WorldMapAdapter.gd.uid",
    # uid sidecars of dead scripts removed above
    "scripts/LevelTransition.gd.uid",
    "scripts/GalleryUI.gd.uid",
    "scripts/RewardNotification.gd.uid",
    "scripts/DLCDownloadTest.gd.uid",
    "scripts/DLCSystemTest.gd.uid",
    "scripts/AchievementsPage.gd.uid",
    "scripts/ShopUI.gd.uid",
]

print("\nRemoving orphan .uid files:")
for f in ORPHAN_UIDS:
    fp = os.path.join(ROOT, f)
    if os.path.exists(fp):
        # try git rm first (if tracked), else just delete
        r = subprocess.run(["git", "rm", "-f", f], capture_output=True, text=True, cwd=ROOT)
        if r.returncode == 0:
            print(f"  git rm  {f}")
        else:
            os.remove(fp)
            print(f"  rm      {f}")
    else:
        print(f"  SKIP (already gone): {f}")

# ── Clear Godot cache ─────────────────────────────────────────────────────────
for cache in [".godot/editor/filesystem_cache10", ".godot/uid_cache.bin"]:
    cp = os.path.join(ROOT, cache)
    if os.path.exists(cp):
        os.remove(cp)
        print(f"\n  cleared  {cache}")

print("\nDone.")
