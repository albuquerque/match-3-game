## BaseGame — Base interface for all swappable game modes.
##
## Every game mode (Match3, Mahjong, Sudoku, etc.) must extend this class
## and implement start() / stop(). ExperienceDirector will talk only to
## this interface — never to a concrete game mode directly.
##
## See: docs/specs/godot_refactor_plan.md — Base Game Interface section.
class_name BaseGame
extends Node

## Emitted when the player successfully completes the game.
signal game_won

## Emitted when the player fails (e.g. runs out of moves/lives).
signal game_lost

## Start the game with the provided level data dictionary.
## Concrete subclasses must override this and call super.start(level_data)
## only if they need shared bootstrap behaviour added here in the future.
func start(_level_data: Dictionary) -> void:
	push_warning("BaseGame.start() not overridden in: " + get_script().resource_path)

## Stop / clean up the game. Called by ExperienceDirector when leaving
## the game scene (win, loss, or abort).
## Concrete subclasses must override this.
func stop() -> void:
	push_warning("BaseGame.stop() not overridden in: " + get_script().resource_path)
