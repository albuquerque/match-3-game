# Match-3 Experience System --- STRICT AI AGENT REFACTOR TASK LIST

## ROLE

You are an AI coding agent tasked with refactoring the runtime
experience orchestration system. Your goal is to eliminate orchestration
coupling ("God Orchestrator Syndrome") and introduce a clear execution
pipeline with separated responsibilities.

------------------------------------------------------------------------

## GLOBAL RULES

-   DO NOT change gameplay behaviour.
-   DO NOT modify JSON schema unless instructed.
-   DO NOT change executor behaviour.
-   DO maintain backwards compatibility with existing flows.
-   DO create new classes instead of expanding existing orchestration
    classes.

------------------------------------------------------------------------

## PHASE 1 --- ARCHITECTURE EXTRACTION

### Task 1.1 --- Create Runtime Pipeline Layer

Create new folder: scripts/runtime_pipeline/

Create: - ExperiencePipeline.gd - PipelineStep.gd - PipelineContext.gd

Responsibilities: - Central runtime flow execution - Step sequencing -
Context propagation

SUCCESS CRITERIA: - No gameplay logic inside pipeline - Pipeline only
coordinates execution order

------------------------------------------------------------------------

### Task 1.2 --- Extract Execution Context

Move from EffectResolver / ExperienceDirector: - board lookup - viewport
resolution - overlay references

Create: ExecutionContextBuilder.gd

SUCCESS CRITERIA: - Resolver no longer searches scene tree

------------------------------------------------------------------------

## PHASE 2 --- DIRECTOR SLIMMING

### Task 2.1 --- Reduce ExperienceDirector Responsibilities

Remove: - direct effect execution - scene node discovery - narrative
state mutation

Replace with: - pipeline.start(flow)

SUCCESS CRITERIA: - Director only loads flow + starts pipeline

------------------------------------------------------------------------

### Task 2.2 --- Convert Director Into Facade

Director must only: - load JSON - build runtime flow - initialise
pipeline

Remove: - branching logic - executor invocation

------------------------------------------------------------------------

## PHASE 3 --- EFFECT SYSTEM DECOUPLING

### Task 3.1 --- Refactor EffectResolver

New Responsibilities: - executor lookup only - effect dispatch only

Remove: - DLC loading - JSON parsing - debug flow control - runtime
entity discovery

------------------------------------------------------------------------

### Task 3.2 --- Introduce ExecutorRegistry

Create: ExecutorRegistry.gd

Responsibilities: - register executor classes - resolve executor
instances

SUCCESS CRITERIA: - Resolver no longer instantiates executors directly

------------------------------------------------------------------------

## PHASE 4 --- NARRATIVE SYSTEM SEPARATION

### Task 4.1 --- Narrative Runtime Layer

Create: NarrativeRuntime.gd

Move from: NarrativeStageController NarrativeStageManager

Responsibilities: - stage activation - progression tracking - narrative
state transitions

------------------------------------------------------------------------

### Task 4.2 --- Renderer Isolation

NarrativeStageRenderer must: - receive render commands only - contain
zero progression logic

SUCCESS CRITERIA: - Renderer does not reference flow or director

------------------------------------------------------------------------

## PHASE 5 --- REWARD PIPELINE

### Task 5.1 --- Implement RewardPipelineStep

Create: RewardPipelineStep.gd

Responsibilities: - trigger RewardOrchestrator - emit reward completion
event

------------------------------------------------------------------------

### Task 5.2 --- Remove Reward Logic From Director

Director must not: - grant rewards - inspect star ratings - modify
inventory

------------------------------------------------------------------------

## PHASE 6 --- EVENT OWNERSHIP RULES

### Task 6.1 --- EventBus Usage Refactor

Rules: - Pipeline emits lifecycle events - Executors emit completion
events - UI listens only

SUCCESS CRITERIA: - Director no longer subscribes to gameplay events

------------------------------------------------------------------------

## PHASE 7 --- VALIDATION & SAFETY

### Task 7.1 --- JSON Validation Layer

Create: FlowSchemaValidator.gd

Responsibilities: - validate flow structure - validate effect payloads

------------------------------------------------------------------------

### Task 7.2 --- Runtime Logging

Create: ExperienceLogger.gd

Must log: - pipeline start - step execution - effect dispatch - executor
completion

------------------------------------------------------------------------

## PHASE 8 --- FINAL STRUCTURE TARGET

scripts/ runtime_pipeline/ experience/ narrative/ effects/ rewards/
validation/ logging/

------------------------------------------------------------------------

## COMPLETION CHECKLIST

-   [ ] ExperienceDirector \< 300 lines
-   [ ] EffectResolver \< 200 lines
-   [ ] Zero scene tree lookup outside context builder
-   [ ] Executors fully decoupled
-   [ ] Narrative renderer stateless
-   [ ] Pipeline owns execution order
-   [ ] Director owns only startup

------------------------------------------------------------------------

## OUTPUT REQUIREMENTS

Agent must produce: - new classes listed above - updated dependency
diagram - migration commit sequence - unit test stubs for pipeline
