# Generating Experience Flows with an AI (Book of Genesis examples)

This document contains a validated JSON Schema set and an example prompt you can pass to an AI to generate experience flows tailored to the Book of Genesis. The schemas live in `docs/schemas/` and represent the canonical shapes used by the game.

Quick steps

1. Provide the AI with the `experience_flow.json` schema and the small example flow.
2. Ask the AI to produce a JSON instance that validates against the schema.
3. Validate with a JSON Schema validator (e.g., `jsonschema` in Python or `ajv` in Node).
4. Run `ExperienceFlowParser` or load the flow in the editor for manual inspection and in-game testing.

Prompt template (tuned for Book of Genesis)

You can paste the schema followed by this instruction. Replace items in ALL CAPS with your values.

---

You are a generator that must produce a game "experience flow" JSON that validates against the provided JSON Schema.

Theme: Book of Genesis (biblical narrative, family/creation arcs)
Target levels: 20
Chapter grouping: 5 levels per chapter
Tone: reverent, story-first, easy onboarding
Constraints:
- Must begin with a narrative_stage intro for Creation and an easy Level_01
- After each level node, include a reward node awarding coins or small collectibles
- Use `definition_id` references for recurring narrative nodes where appropriate
- Use level ids `level_01`..`level_20`
- Use narrative ids that match Book of Genesis events (e.g., creation_day_1, adam_eve, noah_called)
- Ensure flow length equals number of nodes implied by the structure

Output only the JSON instance (no commentary). Validate it against the schema before returning.

Example short snippet (not full flow):

{
  "experience_id": "genesis_story",
  "version": "1.0",
  "name": "Genesis - Chapter Entries",
  "flow": [
    { "definition_id": "narrative_stage_1", "type": "narrative_stage", "id": "creation_day_1" },
    { "type": "level", "id": "level_01" },
    { "type": "reward", "id": "level_01_complete", "rewards": [ { "type":"coins", "amount": 100 } ] }
  ]
}

Validation checklist for the AI/validator
- `experience_id`, `version`, and `flow` exist
- All nodes have a recognized `type`
- Level nodes have an `id`
- Narrative nodes have an `id`
- If `definition_id` is present, ensure a matching file exists in `data/flow_step_definitions/`

If the AI cannot guarantee file creation for `definition_id`, instruct it to avoid using `definition_id` and emit full node shapes instead.

Troubleshooting
- If the flow fails to load in-game, open the parser logs in Godot and validate the flow JSON against `docs/schemas/experience_flow.json`.
- Use `tools/report_definition_usage.py` to see `definition_id` references and resolve missing templates.

---

If you'd like, I can:
- (A) generate a full 20-level Book of Genesis flow using the schema and the prompt above, or
- (B) add a Python CLI `tools/validate_flow.py` that validates a JSON file against the schema and checks referenced definitions/levels/assets, or
- (C) both.

Pick A, B or C and I will implement it next.
