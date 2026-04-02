#!/usr/bin/env python3
"""PR 8 — move experience/pipeline/narrative files to experience/ layer."""
import os, shutil, re, subprocess

ROOT = "/Users/sal76/src/match-3-game"
os.chdir(ROOT)

# ── 1. Create destination directories ────────────────────────────────────────
for d in ["experience", "experience/pipeline", "experience/pipeline/steps", "experience/narrative"]:
    os.makedirs(d, exist_ok=True)
    print(f"  mkdir  {d}/")

# ── 2. Move map: old_path -> new_path (relative to ROOT) ─────────────────────
MOVES = [
    # Experience orchestration
    ("scripts/ExperienceDirector.gd",    "experience/ExperienceDirector.gd"),
    ("scripts/FlowCoordinator.gd",       "experience/FlowCoordinator.gd"),
    ("scripts/ExperienceFlowParser.gd",  "experience/ExperienceFlowParser.gd"),
    ("scripts/ExperienceState.gd",       "experience/ExperienceState.gd"),
    # Narrative
    ("scripts/NarrativeStageController.gd", "experience/narrative/NarrativeStageController.gd"),
    ("scripts/NarrativeStageManager.gd",    "experience/narrative/NarrativeStageManager.gd"),
    ("scripts/NarrativeStageRenderer.gd",   "experience/narrative/NarrativeStageRenderer.gd"),
    # Pipeline core
    ("scripts/runtime_pipeline/PipelineStep.gd",             "experience/pipeline/PipelineStep.gd"),
    ("scripts/runtime_pipeline/PipelineContext.gd",          "experience/pipeline/PipelineContext.gd"),
    ("scripts/runtime_pipeline/ExperiencePipeline.gd",       "experience/pipeline/ExperiencePipeline.gd"),
    ("scripts/runtime_pipeline/ContextBuilder.gd",           "experience/pipeline/ContextBuilder.gd"),
    ("scripts/runtime_pipeline/NodeTypeStepFactory.gd",      "experience/pipeline/NodeTypeStepFactory.gd"),
    ("scripts/runtime_pipeline/FlowStepDefinitionLoader.gd", "experience/pipeline/FlowStepDefinitionLoader.gd"),
    # Pipeline steps
    ("scripts/runtime_pipeline/steps/AdRewardStep.gd",         "experience/pipeline/steps/AdRewardStep.gd"),
    ("scripts/runtime_pipeline/steps/ConditionalStep.gd",      "experience/pipeline/steps/ConditionalStep.gd"),
    ("scripts/runtime_pipeline/steps/CutsceneStep.gd",         "experience/pipeline/steps/CutsceneStep.gd"),
    ("scripts/runtime_pipeline/steps/DLCFlowStep.gd",          "experience/pipeline/steps/DLCFlowStep.gd"),
    ("scripts/runtime_pipeline/steps/GrantRewardsStep.gd",     "experience/pipeline/steps/GrantRewardsStep.gd"),
    ("scripts/runtime_pipeline/steps/LoadLevelStep.gd",        "experience/pipeline/steps/LoadLevelStep.gd"),
    ("scripts/runtime_pipeline/steps/PremiumGateStep.gd",      "experience/pipeline/steps/PremiumGateStep.gd"),
    ("scripts/runtime_pipeline/steps/ShowLevelFailureStep.gd", "experience/pipeline/steps/ShowLevelFailureStep.gd"),
    ("scripts/runtime_pipeline/steps/ShowNarrativeStep.gd",    "experience/pipeline/steps/ShowNarrativeStep.gd"),
    ("scripts/runtime_pipeline/steps/ShowRewardsStep.gd",      "experience/pipeline/steps/ShowRewardsStep.gd"),
    ("scripts/runtime_pipeline/steps/UnlockStep.gd",           "experience/pipeline/steps/UnlockStep.gd"),
]

# ── 3. Build path-replacement map ────────────────────────────────────────────
# Maps old res:// path -> new res:// path
PATH_MAP = {}
for src, dst in MOVES:
    old_res = "res://" + src.replace("\\", "/")
    new_res = "res://" + dst.replace("\\", "/")
    PATH_MAP[old_res] = new_res

print("\nPath map:")
for o, n in PATH_MAP.items():
    print(f"  {o}")
    print(f"    -> {n}")

# ── 4. git mv each file ───────────────────────────────────────────────────────
print("\nMoving files with git mv:")
for src, dst in MOVES:
    if not os.path.exists(src):
        print(f"  SKIP (missing): {src}")
        continue
    result = subprocess.run(["git", "mv", src, dst], capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  git mv {src} -> {dst}")
    else:
        print(f"  WARN git mv failed ({result.stderr.strip()}), falling back to copy+delete")
        shutil.copy2(src, dst)
        os.remove(src)

# ── 5. Update all res:// paths in .gd and .tscn files ────────────────────────
print("\nUpdating res:// paths in source files:")
changed = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    # Skip hidden dirs, android build, .venv, tools
    dirnames[:] = [d for d in dirnames if not d.startswith(".") and d not in ("android", ".venv", "tools", "builds")]
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
            print(f"  updated {rel}")
            changed.append(rel)

print(f"\nUpdated {len(changed)} files.")

# ── 6. Update project.godot autoload paths ───────────────────────────────────
print("\nUpdating project.godot autoloads:")
gp = os.path.join(ROOT, "project.godot")
text = open(gp, "r", encoding="utf-8").read()
new_text = text
autoload_updates = [
    ('NarrativeStageManager="*res://scripts/NarrativeStageManager.gd"',
     'NarrativeStageManager="*res://experience/narrative/NarrativeStageManager.gd"'),
    ('ExperienceDirector="*res://scripts/ExperienceDirector.gd"',
     'ExperienceDirector="*res://experience/ExperienceDirector.gd"'),
]
for old, new in autoload_updates:
    if old in new_text:
        new_text = new_text.replace(old, new)
        print(f"  {old.split('=')[0]}: scripts/ -> experience/")
    else:
        print(f"  WARN: could not find autoload entry for {old.split('=')[0]}")
if new_text != text:
    open(gp, "w", encoding="utf-8").write(new_text)
    print("  project.godot saved.")

print("\nDone. Run `git status` to review.")
