extends Node

# NodeResolvers — static autoload resolver helpers.
# Use GameRunState for state, GameStateBridge for signals/methods.
const STRICT: bool = false

static func _fallback_autoload(name: String) -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop != null and main_loop is SceneTree:
		var root = main_loop.root
		if root != null:
			var candidate = root.get_node_or_null(name)
			if candidate != null:
				return candidate
	return null

static func _get_autoload(name: String, strict_label: String = "") -> Node:
	var res = _fallback_autoload(name)
	if res == null and STRICT:
		var label = strict_label if strict_label != "" else name
		push_error("[NodeResolvers] STRICT: %s autoload missing" % label)
	return res

# _get_gm() permanently returns null.
static func _get_gm() -> Node:
	return null

static func _get_pm() -> Node:
	return _get_autoload("PageManager", "PageManager")

static func _get_board() -> Node:
	var direct = _get_autoload("GameBoard", "GameBoard")
	if direct:
		return direct
	if STRICT:
		push_error("[NodeResolvers] STRICT: GameBoard could not be resolved")
	return null

# Convenience helpers — read directly from GameRunState.
static func _gm_grid_width() -> int:
	return int(GameRunState.GRID_WIDTH)

static func _gm_grid_height() -> int:
	return int(GameRunState.GRID_HEIGHT)

static func _is_cell_blocked(x: int, y: int) -> bool:
	var gqs = load("res://games/match3/board/services/GridQueryService.gd")
	if gqs != null:
		return gqs.is_cell_blocked(null, x, y)
	return false

static func _play_sfx(name: String) -> void:
	var am = _get_am()
	if am and am.has_method("play_sfx"):
		am.play_sfx(name)
	else:
		print("[NodeResolvers] play_sfx fallback (no AudioManager): ", name)

static func _get_rm() -> Node:
	return _get_autoload("RewardManager", "RewardManager")

static func _get_xd() -> Node:
	return _get_autoload("ExperienceDirector", "ExperienceDirector")

static func _get_am() -> Node:
	return _get_autoload("AudioManager", "AudioManager")

static func _get_tm() -> Node:
	return _get_autoload("ThemeManager", "ThemeManager")

static func _get_ar() -> Node:
	return _get_autoload("AssetRegistry", "AssetRegistry")

static func _get_cm() -> Node:
	return _get_autoload("CollectionManager", "CollectionManager")

static func _get_srm() -> Node:
	return _get_autoload("StarRatingManager", "StarRatingManager")

static func _get_lm() -> Node:
	return _get_autoload("LevelManager", "LevelManager")

static func _get_vam() -> Node:
	return _get_autoload("VisualAnchorManager", "VisualAnchorManager")

static func _get_adm() -> Node:
	return _get_autoload("AdMobManager", "AdMobManager")

static func _get_vm() -> Node:
	return _get_autoload("VibrationManager", "VibrationManager")

static func _get_dlc() -> Node:
	return _get_autoload("DLCManager", "DLCManager")
