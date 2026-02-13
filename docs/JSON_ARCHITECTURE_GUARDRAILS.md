# JSON Ownership Rules
## Experience Flow JSON

Defines:
- order of execution
- type of node
- references to content

Must NOT:
- contain gameplay logic
- contain visual definitions
- contain effect definitions
- contain reward mechanics
---
## Narrative Stage JSON

Defines:
- visual states
- asset references
- visual transitions
- anchor positioning

Must NOT:
- define level flow
- grant rewards
- change gameplay rules
- control progression
---
## Chapter JSON

Defines:
- content grouping
- thematic effects
- chapter metadata

Must NOT:
- define unlock conditions
- control experience flow
- grant rewards
- contain branching logic
---
## Level JSON

Defines:
- gameplay configuration
- board mechanics
- targets
- layout

Must NOT:
- reference narrative flow
- trigger rewards
- manage progression
---
## Collection/Reward JSON

Defines:
- items
- rarity
- presentation data

Must NOT:
- define reward timing
- define progression logic
- contain unlock conditions
---
## Runtime Rule

JSON describes **data**, not **behaviour**.

Execution lives in:
* Pipeline Steps
* Runtime Systems
* Managers

Never inside JSON interpretation logic.

---
## 🚨 JSON GOD OBJECT EARLY WARNING SIGNS

If you see ANY of these… stop expansion:

### Structure Smells
- JSON file exceeds 400–500 lines
- JSON contains multiple unrelated domains
- JSON includes conditional logic fields
- JSON references more than 3 other systems
---
### Parser Smells

- Parser has more than 3 nested switch/case blocks
- Parser modifies runtime state
- Parser calls managers directly
- Parser becomes >250 lines

---
### Content Smells
- Narrative JSON starts controlling gameplay
- Chapters define rewards or unlocks
- Experience flow contains UI fields
- Levels contain narrative info
