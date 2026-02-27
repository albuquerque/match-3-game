extends Node

# Non-strict NodeResolvers: prefer autoload singletons but do not spam errors during startup.
# Implemented as static helpers so existing callsites (NodeResolvers._get_gm()) keep working.
const STRICT: bool = false

static func _fallback_autoload(name: String) -> Node:
	var main_loop = Engine.get_main_loop()
	if main_loop != null and main_loop is SceneTree:
		var root = main_loop.root
		if root != null:
			var candidate = root.get_node_or_null(name)
			if candidate != null:
				return candidate
	# Last resort: return null
	return null

# Reusable generic autoload getter to remove repeated code.
static func _get_autoload(name: String, strict_label: String = "") -> Node:
	var res = _fallback_autoload(name)
	if res == null and STRICT:
		var label = strict_label if strict_label != "" else name
		push_error("[NodeResolvers] STRICT: %s autoload missing" % label)
	return res

# Public static helpers - keep specific getters used throughout the codebase
static func _get_gm() -> Node:
	return _get_autoload("GameManager", "GameManager")

# PageManager resolver
static func _get_pm() -> Node:
	return _get_autoload("PageManager", "PageManager")

static func _get_board() -> Node:
	# Prefer GameManager-provided board if autoload present
	var gm = _get_autoload("GameManager", "GameManager")
	if gm and gm.has_method("get_board"):
		return gm.get_board()
	# fallback to direct autoload name 'GameBoard'
	var direct = _get_autoload("GameBoard", "GameBoard")
	if direct:
		return direct
	if STRICT:
		push_error("[NodeResolvers] STRICT: GameBoard could not be resolved")
	return null

# Convenience helpers for common GameManager-derived properties
static func _gm_grid_width() -> int:
	var gm = _get_gm()
	if gm == null:
		return 0
	# Try preferred getter methods first
	if gm.has_method("get_grid_width"):
		return int(gm.get_grid_width())
	# Fall back to direct property access if available safely
	if typeof(gm) == TYPE_OBJECT:
		if "GRID_WIDTH" in gm:
			return int(gm.GRID_WIDTH)
		# Try property access via get if present
		if gm.has_method("get"):
			# Many autoload instances support get(varname)
			var ok = gm.get("GRID_WIDTH") if gm.has_method("get") else null
			if typeof(ok) == TYPE_INT or typeof(ok) == TYPE_FLOAT:
				return int(ok)
	return 0

static func _gm_grid_height() -> int:
	var gm = _get_gm()
	if gm == null:
		return 0
	if gm.has_method("get_grid_height"):
		return int(gm.get_grid_height())
	if typeof(gm) == TYPE_OBJECT:
		if "GRID_HEIGHT" in gm:
			return int(gm.GRID_HEIGHT)
		if gm.has_method("get"):
			var ok2 = gm.get("GRID_HEIGHT") if gm.has_method("get") else null
			if typeof(ok2) == TYPE_INT or typeof(ok2) == TYPE_FLOAT:
				return int(ok2)
	return 0

static func _is_cell_blocked(x: int, y: int) -> bool:
	var gm = _get_gm()
	if gm != null and gm.has_method("is_cell_blocked"):
		return gm.is_cell_blocked(x, y)
	# conservative default: not blocked
	return false

static func _play_sfx(name: String) -> void:
	var am = _get_am()
	if am and am.has_method("play_sfx"):
		am.play_sfx(name)
	else:
		# no AudioManager available - no-op
		print("[NodeResolvers] play_sfx fallback (no AudioManager): ", name)

static func _get_rm() -> Node:
	return _get_autoload("RewardManager", "RewardManager")

static func _get_xd() -> Node:
	return _get_autoload("ExperienceDirector", "ExperienceDirector")

static func _get_evbus() -> Node:
	return _get_autoload("EventBus", "EventBus")

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
