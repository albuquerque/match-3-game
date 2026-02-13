# Match-3 Experience System Refactor Documentation

## Purpose

This document describes the architectural refactor for the Experience
Flow, Narrative, and Effects execution systems. It is intended for AI
agents and developers to understand system responsibilities and
boundaries.

## High-Level Architecture

-   ExperienceDirector: Orchestrates high-level flow execution
-   ExperienceFlowParser: Parses JSON experience flow definitions
-   NarrativeStageManager / Controller: Handles narrative stage
    lifecycle
-   RewardOrchestrator: Processes rewards
-   EffectResolver + Executors: Executes modular effects
-   LevelManager / GameManager: Core gameplay coordination

## Design Goals

-   Separation of concerns between orchestration, parsing, and execution
-   Data-driven flows via JSON
-   Modular effects through executor pattern
-   Maintainable narrative progression logic

## Flow Execution Lifecycle

1.  ExperienceDirector loads flow JSON
2.  Parser converts JSON into runtime structures
3.  Director dispatches steps
4.  NarrativeStageController manages narrative events
5.  EffectResolver executes gameplay or narrative effects
6.  RewardOrchestrator handles rewards
7.  GameManager advances gameplay state

## Effects System

-   Base executor defines execution interface
-   Timeline executor handles sequenced effects
-   Narrative dialogue executor handles dialogue sequences
-   Resolver maps effect types to executors

## Narrative System

-   NarrativeStageManager loads stage data
-   Controller handles activation and progression
-   Dialogue executor renders narrative content

## JSON Data Structure

### Experience Flow

Defines ordered steps: - narrative - level - reward - effects

### Narrative Stage

Defines dialogue, characters, and triggers.

### Level Data

Defines gameplay objectives and board setup.

## Refactor Recommendations

-   Move parsing logic fully into parser layer
-   Introduce dependency injection for executors
-   Separate UI triggers from gameplay logic
-   Add validation schemas for JSON files
-   Improve logging around effect execution

## Extension Guidelines

-   Add new executors by inheriting base executor
-   Register executor in resolver
-   Extend JSON schema safely
