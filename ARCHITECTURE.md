# 🚨 God Object Early Warning Checklist

#### Purpose:
Detect architectural drift early and prevent any class from becoming a monolithic controller that owns too many responsibilities.

#### When to Use:

- During PR reviews

- Before merging new systems

- During refactors

- When adding new game features or pipelines
---
## 🧠 Responsibility & Ownership
### ❗ Single Responsibility Violations

-[ ] Class manages more than one domain (e.g., flow + UI + rewards + persistence)

-[ ] Class executes logic and renders UI

-[ ] Class parses data and executes behavior

-[ ]  Class manages lifecycle and business rules

- [ ] Class coordinates systems and performs work itself

🚩 Early Warning Sign:

> “This class is the only place that knows how everything works.”
---
### ❗ Decision Authority Creep

-[ ] Class decides execution order for multiple unrelated systems

-[ ] Class contains large match / switch / if type == routing blocks

-[ ] Class owns branching logic across multiple subsystems

-[ ] New features require editing the same central class

🚩 Smell:

>Adding a new feature always requires modifying this file.
---
## 🧱 Structural Indicators
### ❗ Size & Complexity

 -[ ] File exceeds ~300–400 lines

-[ ]  Functions exceed ~50–70 lines

-[ ]  Functions contain nested logic > 3 levels deep

-[ ]  File has multiple unrelated regions or sections

🚩 Smell:

>You need comments like # --- rewards ---, # --- narrative ---, # --- effects ---.
---
### ❗ Dependency Explosion

-[ ]  Imports or references more than 5–7 systems

-[ ]  Performs multiple get_node() or scene tree searches

-[ ]  Requires references to unrelated managers

-[ ]  Needs extensive setup to test

🚩 Smell:

>Constructor requires half the game to exist.
---
## 🔄 Change Pattern Warnings
### ❗ Change Frequency Clustering

-[ ]  This file appears in most commits

-[ ]  Unrelated features modify the same class

-[ ]  Bug fixes in one area break another area

-[ ]  Merge conflicts frequently occur in this file

🚩 Smell:

>“We touched this file again… for something unrelated.”
---
### ❗ Extension Pain

-[ ]  Adding a new feature requires modifying existing logic instead of adding a new module

-[ ]  New behaviors require editing core flow code

-[ ]  New content types require editing the same executor/controller

🚩 Smell:

>“Just add another case to this switch.”
---
## 🧪 Testing Indicators

-[ ]  Cannot test behavior without running full game loop

-[ ]  Requires scene tree to exist for logic tests

-[ ]  Hard to mock dependencies

-[ ]  Tests fail due to unrelated system changes

🚩 Smell:

>Small changes cause cascading failures.
---
## 🎮 Game Architecture Specific Warnings

-[ ]  Director classes execute gameplay logic directly

-[ ]  Managers contain UI logic

-[ ]  Executors contain flow control

-[ ]  Systems both trigger events and handle them

-[ ]  Runtime systems parse JSON themselves

-[ ]  Context/state is passed via global lookups

🚩 Critical Smell:

>Director → Manager → Executor → Director loop.
---
##🔥 Critical Red Flags (Immediate Refactor Recommended)

-[ ]  Class name contains: Manager, Controller, Director, Orchestrator AND exceeds 300 lines

- [ ]  Class owns:
-
  - flow

  - state

  - execution
    
  - UI

  - rewards

  - effects

-[ ]  More than 5 public methods unrelated to one domain

-[ ]  Class is described as:
- 
  - “central”

  - “core”

  - “main logic”

  - “brain”
---
## ✅ Healthy Architecture Signals (What Good Looks Like)

-[ ]  Directors only coordinate — never execute work

-[ ]  Steps/modules execute one clear responsibility

-[ ]  Pipeline controls execution order

-[ ]  Context objects hold shared references

-[ ]  Executors are stateless or narrowly scoped

-[ ]  Systems communicate via events or contracts

-[ ]  Adding a feature = adding a new module, not editing core
---
## 🛠️ If 3+ Warnings Trigger — Do This Immediately

1. Extract execution into Step / Executor classes

2. Move shared references into a Context object

3. Replace conditional routing with polymorphism or pipeline

4. Split domains into:

    - Flow

   - Execution

   - Rendering

   - Data parsing

5. Reduce scene tree access to one boundary layer

6. Introduce event ownership rules
---
## 📌 PR Review Quick Scan (30 Second Version)

-[ ]  Did this PR increase a Director/Manager size significantly?

-[ ]  Did it add new responsibilities to an existing class?

-[ ]  Did it introduce a new if type == block?

-[ ]  Did it add more dependencies to a central class?

-[ ]  Did it require editing a core system for a feature?

If YES to any two → pause and review architecture.
