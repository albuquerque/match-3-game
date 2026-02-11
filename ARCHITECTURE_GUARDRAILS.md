# 🧬 ARCHITECTURE GUARDRAILS — Experience System
## Purpose

These rules prevent architectural drift after the Experience Pipeline refactor.
They define strict ownership boundaries between orchestration, narrative, effects, rewards, and gameplay.

*Goal*: prevent re-emergence of God Orchestrator patterns and maintain long-term system clarity.
---
## 🎯 CORE PRINCIPLES
### 1. Pipeline Owns Execution

The ExperiencePipeline is the only system allowed to:

- advance flow steps

- sequence runtime events

- control execution order

- handle progression between steps

No other system may trigger flow advancement.
---
### 2. Director Is Startup Only

ExperienceDirector responsibilities:

- load experience flow

- initialise pipeline

- start execution

Director must never:

- run effects

- manage narrative state

- grant rewards

- inspect gameplay outcomes

- coordinate UI
---
### 3. Steps Are Atomic

Pipeline Steps must:

- perform one task

- emit completion event

- never trigger other steps directly

- never advance flow manually

Example:
```
LoadLevelStep
ShowNarrativeStep
GrantRewardStep
```
---
### 4. EffectResolver Must Stay Thin

Allowed:

- executor lookup

- executor dispatch

Forbidden:

- scene tree searches
- JSON parsing
- flow branching
- DLC orchestration
- narrative progression
- pipeline control

Executors perform logic — resolver routes only.
---
### 5. Execution Context Is Centralized

Scene tree lookup is allowed only in:
``
ExecutionContextBuilder
``

Forbidden everywhere else:

- find_node

- get_tree searches

- viewport discovery

- board lookup

Steps and executors receive context via injection.
---
### 6. Narrative System Is Passive

Narrative must:

- respond to pipeline commands

- render state

- emit completion signals

Narrative must not:

- advance experience flow

- trigger pipeline steps

- change global experience state

- dispatch effects independently
---
### 7. Reward System Is Isolated

RewardOrchestrator must:

- grant rewards

- emit reward completion

Reward system must not:

- control flow

- inspect narrative

- execute effects

- mutate pipeline state
---
### 8. EventBus Rules

Allowed:

- broadcast events

- signal completion

Forbidden:

- orchestrating logic

- triggering flow advancement

- replacing pipeline sequencing

EventBus is communication — not control.
---
## 🚫 ANTI-PATTERN WATCHLIST

If any class starts doing more than 3 of these, stop and refactor:

- sequencing steps

- managing state transitions

- resolving scene nodes

- executing effects

- handling narrative progression

- granting rewards

- parsing JSON

- loading resources

- branching flow logic

That is a God Object forming.
---
## 🧱 FUTURE FEATURE RULES
### Adding New Effects

- Create new executor

- Register via ExecutorRegistry

- Do not modify resolver logic

### Adding Narrative Mechanics

- Implement new PipelineStep

- Narrative remains rendering layer

### Adding Game Modes

- Create new ExperienceFlow JSON

- Extend Steps, not Director

### Adding DLC

- Extend asset loading layer

- Do not embed DLC logic in pipeline or resolver
---
## 🔒 HARD LIMITS

These are enforceable architectural rules:

- ExperienceDirector < 300 lines

- EffectResolver < 200 lines

- PipelineStep classes < 150 lines

- NarrativeRenderer contains zero game logic

- Steps never call other steps
---
## 🧪 BEFORE MERGING NEW FEATURES

Ask:

1. Does this introduce new orchestration logic?

2. Is flow advancement controlled only by pipeline?

3. Is scene lookup centralized?

4. Is this responsibility already owned elsewhere?

5. Is a new Step better than modifying Director?

If unsure — create a Step.
---
## 🧭 ARCHITECTURE NORTH STAR

Target runtime structure:
````
ExperienceDirector
  → ExperiencePipeline
      → PipelineSteps
          → EffectResolver
              → Executors
          → NarrativeRenderer
          → RewardOrchestrator
````

One direction only.

No upward control.
---
## 🧬 FINAL RULE

If a class starts:

- knowing too much

- coordinating too many systems

- sequencing unrelated operations

…it is becoming an orchestrator.

Refactor immediately.
