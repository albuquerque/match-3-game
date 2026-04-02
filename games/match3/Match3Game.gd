## Match3Game — Thin wrapper that surfaces win/loss through the BaseGame interface.
##
## Responsibilities (and ONLY these):
##   1. Bridge GameBoard.level_complete → BaseGame.game_won signal.
##   2. Bridge GameBoard.game_over    → BaseGame.game_lost signal.
##   3. Implement start() / stop() as required by BaseGame.
class_name Match3Game
extends "res://games/base/BaseGame.gd"

## Emitted after game_won to pass along final score and stars (convenience).
signal match3_level_won(level: int, score: int, stars: int)

## Emitted after game_lost to pass along the final score (convenience).
signal match3_level_lost(level: int, score: int)

# ── Private ───────────────────────────────────────────────────────────────────

var _board_connected: bool = false

# ── BaseGame overrides ────────────────────────────────────────────────────────

## Called by ExperienceDirector (PR 3+) with level data.
## For now this is a no-op stub — the old system still loads levels.
func start(_level_data: Dictionary) -> void:
	print("[Match3Game] start() — level_data keys: ", _level_data.keys())
	_connect_board()

## Called when leaving this game (win, loss, or abort).
func stop() -> void:
	print("[Match3Game] stop()")
	_disconnect_board()

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Auto-connect on scene entry so the signals fire even before ExperienceDirector
	# calls start() (old-system compatibility for PR 2).
	_connect_board()

func _exit_tree() -> void:
	_disconnect_board()

# ── Internal helpers ──────────────────────────────────────────────────────────

func _connect_board() -> void:
	if _board_connected:
		return
	var board = GameRunState.board_ref
	if board == null:
		push_warning("[Match3Game] board_ref not yet set — signals not wired.")
		return
	if board.has_signal("level_complete") and not board.is_connected("level_complete", _on_level_complete):
		board.connect("level_complete", _on_level_complete)
	if board.has_signal("game_over") and not board.is_connected("game_over", _on_game_over):
		board.connect("game_over", _on_game_over)
	_board_connected = true
	print("[Match3Game] Connected to board_ref signals")

func _disconnect_board() -> void:
	var board = GameRunState.board_ref
	if board and is_instance_valid(board):
		if board.is_connected("level_complete", _on_level_complete):
			board.disconnect("level_complete", _on_level_complete)
		if board.is_connected("game_over", _on_game_over):
			board.disconnect("game_over", _on_game_over)
	_board_connected = false

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_level_complete() -> void:
	var lvl   = GameRunState.level
	var score = GameRunState.score
	var stars = GameRunState.last_level_moves_left
	print("[Match3Game] → game_won (level=%d score=%d)" % [lvl, score])
	match3_level_won.emit(lvl, score, stars)
	game_won.emit()

func _on_game_over() -> void:
	var lvl   = GameRunState.level
	var score = GameRunState.score
	print("[Match3Game] → game_lost (level=%d score=%d)" % [lvl, score])
	match3_level_lost.emit(lvl, score)
	game_lost.emit()
