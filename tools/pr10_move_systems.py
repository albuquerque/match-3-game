#!/usr/bin/env python3
"""PR 10 — move audio/ads/assets/DLC/effects/services to systems/ and games/match3/"""
import os, shutil, subprocess

ROOT = "/Users/sal76/src/match-3-game"
os.chdir(ROOT)

# ── 1. Create destination directories ────────────────────────────────────────
for d in ["systems/effects"]:
    os.makedirs(d, exist_ok=True)
    print(f"  mkdir  {d}/")

# ── 2. Move map ───────────────────────────────────────────────────────────────
MOVES = [
    # Platform / infrastructure systems → systems/
    ("scripts/AudioManager.gd",          "systems/AudioManager.gd"),
    ("scripts/AdMobManager.gd",          "systems/AdMobManager.gd"),
    ("scripts/AssetRegistry.gd",         "systems/AssetRegistry.gd"),
    ("scripts/ThemeManager.gd",          "systems/ThemeManager.gd"),
    ("scripts/DLCConfig.gd",             "systems/DLCConfig.gd"),
    ("scripts/DLCManager.gd",            "systems/DLCManager.gd"),
    ("scripts/EffectResolver.gd",        "systems/EffectResolver.gd"),
    ("scripts/VibrationManager.gd",      "systems/VibrationManager.gd"),
    ("scripts/TileTextureGenerator.gd",  "systems/TileTextureGenerator.gd"),
    ("scripts/TranslationBootstrap.gd",  "systems/TranslationBootstrap.gd"),
    ("scripts/LevelManager.gd",          "systems/LevelManager.gd"),
    # Effect executors → systems/effects/
    ("scripts/effects/EffectExecutor.gd",                  "systems/effects/EffectExecutor.gd"),
    ("scripts/effects/effect_executor_base.gd",            "systems/effects/effect_executor_base.gd"),
    ("scripts/effects/background_dim_executor.gd",         "systems/effects/background_dim_executor.gd"),
    ("scripts/effects/background_tint_executor.gd",        "systems/effects/background_tint_executor.gd"),
    ("scripts/effects/camera_impulse_executor.gd",         "systems/effects/camera_impulse_executor.gd"),
    ("scripts/effects/camera_lerp_executor.gd",            "systems/effects/camera_lerp_executor.gd"),
    ("scripts/effects/cutscene_executor.gd",               "systems/effects/cutscene_executor.gd"),
    ("scripts/effects/foreground_dim_executor.gd",         "systems/effects/foreground_dim_executor.gd"),
    ("scripts/effects/gameplay_pause_executor.gd",         "systems/effects/gameplay_pause_executor.gd"),
    ("scripts/effects/narrative_dialogue_executor.gd",     "systems/effects/narrative_dialogue_executor.gd"),
    ("scripts/effects/play_animation_executor.gd",         "systems/effects/play_animation_executor.gd"),
    ("scripts/effects/progressive_brightness_executor.gd", "systems/effects/progressive_brightness_executor.gd"),
    ("scripts/effects/screen_flash_executor.gd",           "systems/effects/screen_flash_executor.gd"),
    ("scripts/effects/screen_overlay_executor.gd",         "systems/effects/screen_overlay_executor.gd"),
    ("scripts/effects/shader_param_lerp_executor.gd",      "systems/effects/shader_param_lerp_executor.gd"),
    ("scripts/effects/spawn_particles_executor.gd",        "systems/effects/spawn_particles_executor.gd"),
    ("scripts/effects/state_swap_executor.gd",             "systems/effects/state_swap_executor.gd"),
    ("scripts/effects/symbolic_overlay_executor.gd",       "systems/effects/symbolic_overlay_executor.gd"),
    ("scripts/effects/timeline_sequence_executor.gd",      "systems/effects/timeline_sequence_executor.gd"),
    ("scripts/effects/vignette_executor.gd",               "systems/effects/vignette_executor.gd"),
    # Match3 board services → games/match3/board/services/
    ("scripts/services/MatchFinder.gd",  "games/match3/board/services/MatchFinder.gd"),
    ("scripts/services/Scoring.gd",      "games/match3/board/services/Scoring.gd"),
]

# ── 3. Build path-replacement map ─────────────────────────────────────────────
PATH_MAP = {}
for src, dst in MOVES:
    PATH_MAP["res://" + src] = "res://" + dst

print(f"\n{len(MOVES)} files to move.")

# ── 4. git mv each file ────────────────────────────────────────────────────────
print("\nMoving files with git mv:")
for src, dst in MOVES:
    if not os.path.exists(src):
        print(f"  SKIP (missing): {src}")
        continue
    result = subprocess.run(["git", "mv", src, dst], capture_output=True, text=True, cwd=ROOT)
    if result.returncode == 0:
        print(f"  git mv  {src}  ->  {dst}")
    else:
        print(f"  WARN: {result.stderr.strip()} — fallback copy")
        os.makedirs(os.path.dirname(dst), exist_ok=True)
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
        os.makedirs(os.path.dirname(uid_dst), exist_ok=True)
        shutil.move(uid_src, uid_dst)
        print(f"  uid  {uid_src}")

# ── 7. Remove now-empty old directories ───────────────────────────────────────
for d in ["scripts/effects", "scripts/services"]:
    dp = os.path.join(ROOT, d)
    if os.path.isdir(dp):
        remaining = [f for f in os.listdir(dp) if not f.endswith(".uid")]
        if not remaining:
            # remove any leftover .uid files then rmdir
            for f in os.listdir(dp):
                os.remove(os.path.join(dp, f))
            os.rmdir(dp)
            print(f"  rmdir  {d}/")
        else:
            print(f"  NOTE   {d}/ not empty: {remaining}")

# ── 8. Clear Godot filesystem cache ───────────────────────────────────────────
for cache in [".godot/editor/filesystem_cache10", ".godot/uid_cache.bin"]:
    cp = os.path.join(ROOT, cache)
    if os.path.exists(cp):
        os.remove(cp)
        print(f"  cleared  {cache}")

print("\nDone. Open project in Godot editor before running.")
