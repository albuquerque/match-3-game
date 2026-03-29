extends Node

# Lightweight NodeResolvers API used for static analysis and runtime fallback lookups.
# Provides resolver-first helpers used across the project during the refactor.

# Helper: return the main scene tree root or null
static func _get_tree_root():
	var ml = Engine.get_main_loop()
	if ml and ml is SceneTree:
		# Use the SceneTree.root property for Godot 4 compatibility
		return ml.root
	return null

static func _fallback_autoload(name: String) -> Node:
	# Try to find the autoload by name on the scene tree root
	var root = _get_tree_root()
	if root:
		var n = root.get_node_or_null(name)
		if n:
			return n
	# Not found
	return null

# Common resolver helpers
static func _get_gm():
	return _fallback_autoload("GameManager")

static func _get_rm():
	return _fallback_autoload("RewardManager")


# AudioManager resolver (missing previously)
static func _get_am():
	return _fallback_autoload("AudioManager")

static func _get_pm():
	return _fallback_autoload("PageManager")

static func _get_tm():
	return _fallback_autoload("ThemeManager")

static func _get_lm():
	return _fallback_autoload("LevelManager")

static func _get_vam():
	return _fallback_autoload("VisualAnchorManager")

static func _get_ar():
	return _fallback_autoload("AssetRegistry")

static func _get_adm():
	return _fallback_autoload("AdMobManager")

static func _get_xd():
	return _fallback_autoload("ExperienceDirector")

static func _get_main_game():
	# Attempt to return MainGame node or GameUI
	var root = _get_tree_root()
	if root:
		var mg = root.get_node_or_null("MainGame")
		if mg:
			return mg
		var gu = root.get_node_or_null("GameUI")
		if gu:
			return gu
	return null

# Generic getters for other autoloads (no-op safe defaults)
static func _get_cm():
	return _fallback_autoload("CollectionManager")

static func _get_vm():
	return _fallback_autoload("VibrationManager")

static func _get_dlc():
	return _fallback_autoload("DLCManager")

static func _get_board():
	# PR 5d: resolve GameBoard directly — GameManager no longer provides get_board()
	var root = _get_tree_root()
	if root:
		return root.get_node_or_null("GameBoard")
	return null

static func _get_srm():
	return _fallback_autoload("StarRatingManager")
# End of NodeResolvers API

static func _gm_grid_width() -> int:
	var gm = _get_gm()
	if gm == null:
		return 0
	# Prefer getter method when available
	if gm.has_method("get_grid_width"):
		return int(gm.get_grid_width())
	# Try property-style access
	if typeof(gm) == TYPE_OBJECT and "GRID_WIDTH" in gm:
		return int(gm.GRID_WIDTH)
	return 0

static func _gm_grid_height() -> int:
	var gm = _get_gm()
	if gm == null:
		return 0
	# Prefer getter method when available
	if gm.has_method("get_grid_height"):
		return int(gm.get_grid_height())
	# Try property-style access
	if typeof(gm) == TYPE_OBJECT and "GRID_HEIGHT" in gm:
		return int(gm.GRID_HEIGHT)
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
