extends Control
class_name HUDComponent

## HUDComponent: owns and updates all in-game HUD elements.
## E1: Self-wiring — connects directly to GameManager + RewardManager signals.
## GameUI no longer needs to call set_score/set_moves/etc. on every signal.

signal hud_ready

@onready var score_label: Label        = get_node_or_null("TopPanel/ScoreContainer/ScoreLabel")
@onready var level_label: Label        = get_node_or_null("TopPanel/LevelContainer/LevelLabel")
@onready var moves_label: Label        = get_node_or_null("TopPanel/MovesContainer/MovesLabel")
@onready var target_label: Label       = get_node_or_null("TopPanel/TargetContainer/TargetLabel")
@onready var target_progress: ProgressBar = get_node_or_null("TopPanel/TargetContainer/TargetProgress")
@onready var coins_label: Label = get_node_or_null("CurrencyPanel/HBox/CoinsLabel")
@onready var gems_label: Label  = get_node_or_null("CurrencyPanel/HBox/GemsLabel")
@onready var lives_label: Label = get_node_or_null("CurrencyPanel/HBox/LivesLabel")

func _ready() -> void:
	_connect_signals()
	emit_signal("hud_ready")

func _connect_signals() -> void:
	# Connect to GameManager autoload signals directly
	var gm = _gm()
	if gm:
		if not gm.is_connected("score_changed", _on_score_changed):
			gm.connect("score_changed", _on_score_changed)
		if not gm.is_connected("moves_changed", _on_moves_changed):
			gm.connect("moves_changed", _on_moves_changed)
		if not gm.is_connected("level_changed", _on_level_changed):
			gm.connect("level_changed", _on_level_changed)
		if not gm.is_connected("collectibles_changed", _on_collectibles_changed):
			gm.connect("collectibles_changed", _on_collectibles_changed)
		if gm.has_signal("unmovables_changed") and not gm.is_connected("unmovables_changed", _on_unmovables_changed):
			gm.connect("unmovables_changed", _on_unmovables_changed)
		if gm.has_signal("level_loaded") and not gm.is_connected("level_loaded", _on_level_loaded):
			gm.connect("level_loaded", _on_level_loaded)
	# Connect to RewardManager for currency display
	var rm = _rm()
	if rm and rm.has_signal("coins_changed") and not rm.is_connected("coins_changed", _on_currency_changed):
		rm.connect("coins_changed", _on_currency_changed)

func _gm():
	return Engine.get_singleton("GameManager") if Engine.has_singleton("GameManager") else get_node_or_null("/root/GameManager")

func _rm():
	return get_node_or_null("/root/RewardManager")

# ── Self-wired signal handlers ───────────────────────────────────────────────

func _on_level_loaded() -> void:
	_refresh_from_gm()

func _on_score_changed(new_score: int) -> void:
	var gm = _gm()
	var unmov = gm.unmovable_target if gm else 0
	var coll  = gm.collectible_target if gm else 0
	set_score(new_score)
	if unmov == 0 and coll == 0:
		set_target_score(new_score, gm.target_score if gm else 1)

func _on_moves_changed(moves: int) -> void:
	set_moves(moves)

func _on_level_changed(new_level: int) -> void:
	set_level(new_level)
	_refresh_from_gm()

func _on_collectibles_changed(collected: int, target: int) -> void:
	set_objective_collectibles(collected, target)

func _on_unmovables_changed(cleared: int, target: int) -> void:
	set_objective_unmovables(cleared, target)

func _on_currency_changed(_amount: int) -> void:
	_refresh_currency()

func _refresh_from_gm() -> void:
	var gm = _gm()
	if not gm:
		return
	set_score(gm.score)
	set_level(gm.level)
	set_moves(gm.moves_left)
	if gm.unmovable_target > 0:
		set_objective_unmovables(gm.unmovables_cleared, gm.unmovable_target)
	elif gm.collectible_target > 0:
		set_objective_collectibles(gm.collectibles_collected, gm.collectible_target)
	else:
		set_target_score(gm.score, gm.target_score)
	_refresh_currency()

func _refresh_currency() -> void:
	var rm = _rm()
	if not rm:
		return
	set_coins(rm.get_coins() if rm.has_method("get_coins") else 0)
	set_gems(rm.get_gems()   if rm.has_method("get_gems")  else 0)
	set_lives(rm.get_lives() if rm.has_method("get_lives") else 0, 5)

# ── Public API (still callable by GameUI for explicit refresh) ───────────────

func set_score(score: int) -> void:
	if score_label:
		score_label.text = "%d" % score
		_flash(score_label, Color.YELLOW)

func set_level(level: int) -> void:
	if level_label:
		level_label.text = "Lv %d" % level
		_pulse(level_label)

func set_moves(moves: int) -> void:
	if moves_label:
		moves_label.text = "%d" % moves
		moves_label.modulate = Color.RED if moves <= 5 else Color.WHITE
		if moves <= 5:
			_pulse_warning(moves_label)

func set_target_score(score: int, target: int) -> void:
	if target_label:
		target_label.text = tr("UI_GOAL_SCORE") + ": %d" % target
	if target_progress:
		target_progress.value = min(float(score) / float(max(target, 1)) * 100.0, 100)

func set_objective_collectibles(collected: int, target: int) -> void:
	if target_label:
		target_label.text = tr("UI_COINS") + ": %d/%d" % [collected, target]
	if target_progress:
		target_progress.value = min(float(collected) / float(max(target, 1)) * 100.0, 100)
	if target_label:
		_flash(target_label, Color(1.0, 0.9, 0.2))

func set_objective_unmovables(cleared: int, target: int) -> void:
	if target_label:
		target_label.text = tr("UI_OBSTACLES") + ": %d/%d" % [cleared, target]
	if target_progress:
		target_progress.value = min(float(cleared) / float(max(target, 1)) * 100.0, 100)
	if target_label:
		_flash(target_label, Color(1.0, 0.5, 0.3))

func set_coins(amount: int) -> void:
	if coins_label: coins_label.text = "💰 %d" % amount

func set_gems(amount: int) -> void:
	if gems_label: gems_label.text = "💎 %d" % amount

func set_lives(current: int, max_lives: int) -> void:
	if lives_label: lives_label.text = "❤️ %d/%d" % [current, max_lives]

# ── Animations ───────────────────────────────────────────────────────────────

func _flash(node: Control, color: Color) -> void:
	var tw = create_tween()
	tw.tween_property(node, "modulate", color, 0.08)
	tw.tween_property(node, "modulate", Color.WHITE, 0.15)

func _pulse(node: Control) -> void:
	var tw = create_tween()
	tw.tween_property(node, "scale", Vector2(1.25, 1.25), 0.15)
	tw.tween_property(node, "scale", Vector2.ONE, 0.15)

func _pulse_warning(node: Control) -> void:
	var tw = create_tween().set_loops(3)
	tw.tween_property(node, "scale", Vector2(1.2, 1.2), 0.15)
	tw.tween_property(node, "scale", Vector2.ONE, 0.15)
