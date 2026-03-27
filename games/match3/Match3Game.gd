## Match3Game — Thin wrapper that owns the Match3 board and surfaces win/loss
## through the BaseGame interface.
##
## Responsibilities (and ONLY these):
##   1. Hold a reference to GameBoard (its direct child in Match3Game.tscn).
##   2. Bridge GameManager.level_complete → BaseGame.game_won signal.
##   3. Bridge GameManager.game_over    → BaseGame.game_lost signal.
##   4. Implement start() / stop() as required by BaseGame.
##
## ✅ PR 2 — old system still drives gameplay; this node is wired in parallel.
## ❌ Does NOT touch MatchOrchestrator, EventBus, or any other subsystem.
class_name Match3Game
extends BaseGame

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
	_game_manager = get_node_or_null("/root/GameManager")
	if _game_manager == null:
		push_warning("[Match3Game] GameManager autoload not found — signals not wired.")
		return

	if not _game_manager.is_connected("level_complete", _on_level_complete):
		_game_manager.connect("level_complete", _on_level_complete)

	if not _game_manager.is_connected("game_over", _on_game_over):
		_game_manager.connect("game_over", _on_game_over)

	print("[Match3Game] Connected to GameManager signals.")

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
	var lvl   = _game_manager.level         if _game_manager else 0
	var score = _game_manager.score         if _game_manager else 0
	var stars = _game_manager.last_level_moves_left if _game_manager else 0
	print("[Match3Game] → game_won (level=%d score=%d)" % [lvl, score])
	match3_level_won.emit(lvl, score, stars)
	game_won.emit()

func _on_game_over() -> void:
	var lvl   = _game_manager.level if _game_manager else 0
	var score = _game_manager.score if _game_manager else 0
	print("[Match3Game] → game_lost (level=%d score=%d)" % [lvl, score])
	match3_level_lost.emit(lvl, score)
	game_lost.emit()
