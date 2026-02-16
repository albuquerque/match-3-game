# Animation Sequences: Sequential vs Parallel

## Current Implementation: Sequential Only

### How Sequences Work Now

All animation steps in a `"sequence"` run **one after another**, not simultaneously.

**Example:**
```json
"steps": [
  {"action": "shake", "duration": 0.2},
  {"action": "fade_layer", "layer": 0, "from": 1.0, "to": 0.0, "duration": 0.5},
  {"action": "fade_layer", "layer": 1, "from": 0.0, "to": 1.0, "duration": 0.5}
]
```

**Timeline:**
```
0.0s - 0.2s:  Shake (0.2s)
0.2s - 0.7s:  Fade out layer 0 (0.5s)
0.7s - 1.2s:  Fade in layer 1 (0.5s)
Total: 1.2 seconds
```

Each step waits for the previous step to complete before starting.

---

## What "Parallel" Would Mean (Not Implemented Yet)

If parallel tweens were implemented, multiple animations could run **at the same time**.

**Hypothetical Example:**
```json
"steps": [
  {"action": "shake", "duration": 0.2},
  {
    "parallel": true,  // ← Hypothetical future feature
    "actions": [
      {"action": "fade_layer", "layer": 0, "from": 1.0, "to": 0.0, "duration": 0.5},
      {"action": "fade_layer", "layer": 1, "from": 0.0, "to": 1.0, "duration": 0.5}
    ]
  }
]
```

**Hypothetical Timeline:**
```
0.0s - 0.2s:  Shake (0.2s)
0.2s - 0.7s:  BOTH fades happen simultaneously (0.5s)
Total: 0.7 seconds
```

**This is NOT currently implemented.**

---

## Current Workarounds

### Workaround 1: Fast Sequential Fades
Use shorter durations to make the transition feel smoother:

```json
"steps": [
  {"action": "shake", "duration": 0.2},
  {"action": "fade_layer", "layer": 0, "from": 1.0, "to": 0.0, "duration": 0.3},
  {"action": "fade_layer", "layer": 1, "from": 0.0, "to": 1.0, "duration": 0.3}
]
// Total: 0.8s (fast enough to feel almost simultaneous)
```

### Workaround 2: Overlapping Alpha Values
Start the second fade while first is still partially visible:

```json
"steps": [
  {"action": "shake", "duration": 0.2},
  {"action": "fade_layer", "layer": 0, "from": 1.0, "to": 0.3, "duration": 0.4},
  {"action": "fade_layer", "layer": 1, "from": 0.0, "to": 0.7, "duration": 0.3},
  {"action": "fade_layer", "layer": 0, "from": 0.3, "to": 0.0, "duration": 0.2},
  {"action": "fade_layer", "layer": 1, "from": 0.7, "to": 1.0, "duration": 0.2}
]
// Creates a smoother crossfade effect
```

### Workaround 3: Use Scale Instead
Use scale swap which can feel more dynamic:

```json
"steps": [
  {"action": "shake", "duration": 0.2},
  {"action": "scale_layer", "layer": 0, "scale": 0.0, "duration": 0.3},
  {"action": "scale_layer", "layer": 1, "scale": 1.0, "duration": 0.3}
]
```

---

## Why Sequences are Sequential

The current implementation uses `await` for each step:

```gdscript
func _animate_sequence(steps: Array):
    for step in steps:
        var action = step.get("action", "")
        match action:
            "shake":
                await _animate_shake(step)  // ← Waits here
            "fade_layer":
                await _animate_fade_layer(step)  // ← Waits here
```

Each `await` pauses execution until the animation completes, then moves to the next step.

---

## Future Enhancement: Parallel Support

To implement parallel animations, the code would need to:

1. **Detect parallel blocks:**
```json
{
  "parallel": true,
  "actions": [...]
}
```

2. **Start all tweens without awaiting:**
```gdscript
var tweens = []
for action in parallel_actions:
    var tween = _start_animation(action)  // Don't await
    tweens.append(tween)

// Wait for all to finish
for tween in tweens:
    await tween.finished
```

3. **Handle synchronization:**
- All parallel animations start at the same time
- Sequence continues when **all** parallel animations complete
- Proper cleanup if one fails

**This is a future enhancement** that could be added if needed.

---

## Summary

**Current State:**
- ✅ Sequential sequences work perfectly
- ✅ All steps run one-after-another
- ✅ Predictable, easy to understand
- ❌ No simultaneous animations

**Workarounds:**
- ✅ Use fast durations (0.3s each)
- ✅ Use scale swap instead of fade
- ✅ Overlapping alpha values for smoother transition

**Future:**
- ⏳ Parallel tween support could be added
- ⏳ Would require code changes to RewardContainer
- ⏳ Not currently needed for most use cases

---

## Recommendation

**For two-image crossfade:**

Use **fast sequential fades** (Method 1):
```json
"steps": [
  {"action": "shake", "duration": 0.2},
  {"action": "fade_layer", "layer": 0, "from": 1.0, "to": 0.0, "duration": 0.3},
  {"action": "fade_layer", "layer": 1, "from": 0.0, "to": 1.0, "duration": 0.3}
]
```

This is:
- ✅ Simple and clean
- ✅ Fast enough to feel smooth (0.8s total)
- ✅ No code changes needed
- ✅ Works with current system

**Don't worry about true simultaneous fades** - sequential is perfectly fine and most players won't notice the difference if you keep it fast!
