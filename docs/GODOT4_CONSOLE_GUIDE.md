# Godot 4 Console/Remote Tab - Quick Guide

## Where is the "Console" in Godot 4?

In Godot 4, there's no traditional console where you can type commands. Instead, you use the **Remote** tab.

---

## Finding the Remote Tab

### Step-by-Step:

1. **Run your game** (Press F5 or click Play ▶️ button)

2. **Look at the bottom panel** of Godot editor

3. **You'll see tabs:**
   ```
   [ Debugger ] [ Errors ] [ Search Results ] [ Audio ] [ Animation ] [ Remote ] [ Output ]
   ```

4. **Click "Remote" tab**

5. **Look for input field** at the bottom of the Remote panel

6. **Type commands** there and press Enter

---

## Visual Guide

```
┌─────────────────────────────────────────────────────┐
│  Godot Editor                                       │
│                                                     │
│  [Scene Panel]        [Inspector Panel]            │
│                                                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│  [Game Running Here]                               │
│                                                     │
├─────────────────────────────────────────────────────┤
│ [Debugger][Errors][Remote][Output] ← Click Remote  │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Remote Tab Content:                               │
│  - Scene Tree (Remote)                             │
│  - Node inspector                                  │
│                                                     │
│  ┌───────────────────────────────────────────────┐ │
│  │ Type your command here and press Enter ↵     │ │
│  └───────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

---

## What to Type

In the Remote tab input field at the bottom:

```gdscript
ExperienceDirector.load_flow("main_story")
```
*Press Enter*

```gdscript
ExperienceDirector.reset_flow()
```
*Press Enter*

```gdscript
ExperienceDirector.start_flow()
```
*Press Enter*

Then watch the **Output** tab for logs!

---

## If Remote Tab is Grayed Out

**Problem:** Remote tab only works when game is running

**Solution:**
1. Press F5 to run the game
2. While game is running, go to Remote tab
3. Now you can type commands

---

## Alternative: Use Test Button (No Remote Tab Needed!)

If you can't find or use the Remote tab, use the test button instead:

1. **Create the button:**
   - Open `MainGame.tscn`
   - Add a Button node
   - Attach script: `res://scripts/TestNarrativeButton.gd`

2. **Run the game** (F5)

3. **Click "TEST NARRATIVE" button**

4. **Watch Output tab** for results

Much easier! 🎉

---

## Output Tab vs Remote Tab

**Output Tab:**
- Shows print statements and logs
- Read-only (can't type commands)
- Always visible
- ✅ Use this to SEE results

**Remote Tab:**
- Execute commands while game runs
- Input field at bottom to type
- Only active when game running
- ✅ Use this to RUN commands

---

## Quick Reference

| Want to... | Use this... |
|------------|-------------|
| See logs/output | Output tab |
| Run commands | Remote tab (while game running) |
| Easiest test | Test button (click and done!) |

---

## Status

✅ Remote tab is the Godot 4 equivalent of a console  
✅ Test button is even easier - just click it!  
✅ Output tab shows all the results

**Recommendation:** Use the test button - it's the easiest way!
