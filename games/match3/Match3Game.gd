## Match3Game — Thin wrapper that surfaces win/loss through the BaseGame interface.
##
## Responsibilities (and ONLY these):
##   1. Bridge GameManager.level_complete → BaseGame.game_won signal.
##   2. Bridge GameManager.game_over    → BaseGame.game_lost signal.
##   3. Implement start() / stop() as required by BaseGame.
##
## ⚠️  GameBoard is NOT a child of Match3Game.tscn in shadow mode (PR 2–3).
##     The board lives in MainGame.tscn and is driven by GameManager.
##     In PR 6 the board will be moved here and the tscn updated.
##
## ✅ PR 2/3 — old system still drives gameplay; this node observes in parallel.
## ❌ Does NOT touch MatchOrchestrator, EventBus, or any other subsystem.
class_name Match3Game
extends "res://games/base/BaseGame.gd"

## Emitted after game_won to pass along final score and stars (convenience).
signal match3_level_won(level: int, score: int, stars: int)

## Emitted after game_lost to pass along the final score (convenience).
signal match3_level_lost(level: int, score: int)

# ── Private ───────────────────────────────────────────────────────────────────

var _game_manager: Node = null  # Resolved via autoload at start()

# ── BaseGame overrides ────────────────────────────────────────────────────────

## Called by ExperienceDirector (PR 3+) with level data.
## For now this is a no-op stub — the old system still loads levels.
func start(_level_data: Dictionary) -> void:
	print("[Match3Game] start() — level_data keys: ", _level_data.keys())
	_connect_game_manager()

## Called when leaving this game (win, loss, or abort).
func stop() -> void:
	print("[Match3Game] stop()")
	_disconnect_game_manager()

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Auto-connect on scene entry so the signals fire even before ExperienceDirector
	# calls start() (old-system compatibility for PR 2).
	_connect_game_manager()

func _exit_tree() -> void:
	_disconnect_game_manager()

# ── Internal helpers ──────────────────────────────────────────────────────────

func _connect_game_manager() -> void:
	if _game_manager != null:
		return  # Already connected.
	# Prefer board_ref signals (true owner) exposed via GameRunState
	var board = GameRunState.board_ref if typeof(GameRunState) != TYPE_NIL else null
	if board != null:
		if board.has_signal("level_complete") and not board.is_connected("level_complete", _on_level_complete):
			board.connect("level_complete", _on_level_complete)
		if board.has_signal("game_over") and not board.is_connected("game_over", _on_game_over):
			board.connect("game_over", _on_game_over)
		print("[Match3Game] Connected to board_ref signals (preferred)")
		return

	# Resolve legacy GameManager via node_resolvers helper only (no direct /root lookup)
	var nr = load("res://scripts/helpers/node_resolvers.gd")
	if nr != null:
		_game_manager = nr._get_gm()
	if _game_manager == null:
		push_warning("[Match3Game] GameManager autoload not found via node_resolvers — signals not wired.")
		return

	if not _game_manager.is_connected("level_complete", _on_level_complete):
		_game_manager.connect("level_complete", _on_level_complete)

	if not _game_manager.is_connected("game_over", _on_game_over):
		_game_manager.connect("game_over", _on_game_over)

	print("[Match3Game] Connected to GameManager signals (fallback).")

func _disconnect_game_manager() -> void:
	if _game_manager == null:
		return
	if _game_manager.is_connected("level_complete", _on_level_complete):
		_game_manager.disconnect("level_complete", _on_level_complete)
	if _game_manager.is_connected("game_over", _on_game_over):
		_game_manager.disconnect("game_over", _on_game_over)
	_game_manager = null

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_level_complete() -> void:
	var lvl   = GameRunState.level if typeof(GameRunState) != TYPE_NIL else (_game_manager.level if _game_manager else 0)
	var score = GameRunState.score if typeof(GameRunState) != TYPE_NIL else (_game_manager.score if _game_manager else 0)
	var stars = GameRunState.last_level_moves_left if typeof(GameRunState) != TYPE_NIL else 0
	print("[Match3Game] → game_won (level=%d score=%d)" % [lvl, score])
	match3_level_won.emit(lvl, score, stars)
	game_won.emit()

func _on_game_over() -> void:
	var lvl   = GameRunState.level if typeof(GameRunState) != TYPE_NIL else (_game_manager.level if _game_manager else 0)
	var score = GameRunState.score if typeof(GameRunState) != TYPE_NIL else (_game_manager.score if _game_manager else 0)
	print("[Match3Game] → game_lost (level=%d score=%d)" % [lvl, score])
	match3_level_lost.emit(lvl, score)
	game_lost.emit()
