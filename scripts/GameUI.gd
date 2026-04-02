extends Control
class_name GameUI


# ── Component references ──────────────────────────────────────────────────────
@onready var hud                = get_node_or_null("HUDComponent")
@onready var booster_bar        = get_node_or_null("BoosterPanel")
@onready var floating_menu_comp = get_node_or_null("FloatingMenu")

var floating_menu = null
var reward_notification = null
var level_transition = null

var booster_mode_active: bool = false
var active_booster_type: String = ""
var swap_first_tile = null
var line_blast_direction: String = ""
var _narrative_fullscreen_active: bool = false
var _narrative_hud_hidden: bool = false  ## true while a narrative stage has hidden the HUD

# ── Component accessors ───────────────────────────────────────────────────────
func _hud():
	return hud if (hud and hud.has_method("set_score")) else null

func _bbar():
	return booster_bar if (booster_bar and booster_bar.has_method("refresh_counts")) else null

func _fmc():
	return floating_menu_comp if (floating_menu_comp and floating_menu_comp.has_method("collapse")) else null

# ── Resolver helpers ──────────────────────────────────────────────────────────

func _get_rm():
	return NodeResolvers._get_rm()

func _get_tm():
	return NodeResolvers._get_tm()

func _get_pm():
	return NodeResolvers._get_pm()

func _get_am():
	return NodeResolvers._get_am()

func _get_ed():
	var rt = get_tree().root if has_node("/root") else null
	if rt:
		var ed = rt.get_node_or_null("ExperienceDirector")
		if ed:
			return ed
	return null

func _ready():
	self.z_index = 200

	floating_menu       = get_node_or_null("FloatingMenu")
	reward_notification = get_node_or_null("RewardNotification")
	level_transition    = get_node_or_null("LevelTransition")


	# Wire FloatingMenuComponent signals
	if _fmc():
		_fmc().connect("map_pressed",      func(): _on_floating_map_pressed())
		_fmc().connect("shop_pressed",     func(): _on_floating_shop_pressed())
		_fmc().connect("gallery_pressed",  func(): _on_floating_gallery_pressed())
		_fmc().connect("settings_pressed", func(): _on_floating_settings_pressed())

	# Wire BoosterPanelComponent booster_pressed → GameUI (GameUI still handles activation)
	if _bbar():
		booster_bar.connect("booster_pressed", Callable(self, "_on_booster_button_pressed"))

	# Register with VisualAnchorManager
	var vam = NodeResolvers._get_vam()
	if vam and vam.has_method("register_anchor"):
		vam.register_anchor("ui", self)

	# Connect PageManager
	var pm = NodeResolvers._get_pm()
	if pm == null:
		pm = get_tree().root.get_node_or_null("PageManager")
	if pm and pm.has_signal("page_opened"):
		if not pm.is_connected("page_opened", Callable(self, "_on_page_opened")):
			pm.connect("page_opened", Callable(self, "_on_page_opened"))
	if pm:
		pm.call_deferred("open", "StartPage", {})
	else:
		print("[GameUI] WARNING: PageManager not available; StartPage will not be opened automatically")

	# Connect NarrativeStageManager HUD visibility signal
	var nsm = get_tree().root.get_node_or_null("NarrativeStageManager")
	if nsm and nsm.has_signal("hud_visibility_changed"):
		if not nsm.is_connected("hud_visibility_changed", Callable(self, "_on_narrative_hud_visibility_changed")):
			nsm.connect("hud_visibility_changed", Callable(self, "_on_narrative_hud_visibility_changed"))
			print("[GameUI] Connected to NarrativeStageManager.hud_visibility_changed")
	if nsm and nsm.has_signal("stage_cleared"):
		if not nsm.is_connected("stage_cleared", Callable(self, "_on_narrative_stage_cleared")):
			nsm.connect("stage_cleared", Callable(self, "_on_narrative_stage_cleared"))
			print("[GameUI] Connected to NarrativeStageManager.stage_cleared")

	call_deferred("hide_gameplay_ui")


# ── Level loading (called by ExperiencePipeline) ──────────────────────────────
func _load_level_by_number(level_num: int) -> void:
	print("[GameUI] _load_level_by_number(%d) called by pipeline" % level_num)
	var lm = NodeResolvers._get_lm()
	if lm == null:
		lm = get_tree().root.get_node_or_null("LevelManager")
	if lm and lm.has_method("get_level_index"):
		var idx = lm.get_level_index(level_num)
		if idx >= 0:
			lm.set_current_level(idx)
			print("[GameUI] LevelManager set to index %d (level %d)" % [idx, level_num])
	# Prefer GameStateBridge.initialize_game — GameManager fallback removed (PR 6.5c).
	var bridge = load("res://games/match3/services/GameStateBridge.gd")
	if bridge != null and bridge.has_method("initialize_game"):
		print("[GameUI] Calling GameStateBridge.initialize_game() for level %d" % level_num)
		bridge.initialize_game()
		# Ensure GameBoard creates visuals even if it missed the level_loaded callback (race guard)
		var nrb = load("res://scripts/helpers/node_resolvers.gd")
		if nrb != null:
			var b = nrb._get_board()
			if b != null:
				print("[GameUI] Scheduling create_visual_grid on board: ", b)
				if b.has_method("create_visual_grid"):
					b.call_deferred("create_visual_grid")
				if b.has_method("_on_level_loaded"):
					b.call_deferred("_on_level_loaded")

# ── Gameplay UI visibility ────────────────────────────────────────────────────
func show_gameplay_ui() -> void:
	print("[GameUI] Showing gameplay UI elements")
	if _narrative_fullscreen_active:
		return
	# Show HUD unless a narrative stage explicitly suppressed it for this level
	if hud and not _narrative_hud_hidden:
		hud.visible = true
	if booster_bar: booster_bar.visible = true
	if floating_menu: floating_menu.visible = true
	if reward_notification: reward_notification.visible = true
	print("[GameUI] ✓ Gameplay UI elements shown")

func show_hud() -> void:
	"""Explicitly show the HUD. Called by the narrative system when a level
	that does NOT suppress the HUD starts. Never call from transition screens."""
	if hud:
		hud.visible = true
		print("[GameUI] HUD shown")

func hide_gameplay_ui() -> void:
	print("[GameUI] Hiding gameplay UI elements")
	# NOTE: HUD visibility is managed exclusively by _on_narrative_hud_visibility_changed.
	# Do NOT touch hud.visible here — it races with the narrative system on level load.
	if booster_bar: booster_bar.visible = false; print("[GameUI]   - BoosterPanel hidden")
	if floating_menu: floating_menu.visible = false
	if reward_notification: reward_notification.visible = false
	if level_transition: level_transition.visible = false
	print("[GameUI] ✓ Non-HUD gameplay UI elements hidden")

func _on_narrative_hud_visibility_changed(hud_visible: bool) -> void:
	"""Called when a stage with hide_hud:true loads."""
	print("[GameUI] Narrative HUD visibility → ", hud_visible)
	_narrative_hud_hidden = not hud_visible
	if hud:
		hud.visible = hud_visible
		print("[GameUI] HUD visibility set to: ", hud_visible)

func _on_narrative_stage_cleared() -> void:
	"""Stage cleared (level ended). Reset flag silently — do NOT show the HUD.
	The HUD will become visible only when the next level's narrative stage
	is loaded and it does not suppress the HUD."""
	print("[GameUI] Narrative stage cleared — HUD stays hidden until next level narrative loads")
	_narrative_hud_hidden = false

# ── Booster activation (GameUI still owns the activation state) ───────────────
func activate_booster(booster_type: String) -> void:
	booster_mode_active = true
	active_booster_type = booster_type
	if _bbar():
		_bbar().highlight_active(booster_type)
	print("[GameUI] Booster activated: %s" % booster_type)

func deactivate_booster() -> void:
	booster_mode_active = false
	active_booster_type = ""
	swap_first_tile = null
	if _bbar():
		_bbar().clear_highlight()
	print("[GameUI] Booster deactivated")

func update_booster_ui() -> void:
	## Compatibility shim kept for GameBoard callers — delegates to BoosterPanelComponent.
	if _bbar():
		_bbar()._refresh_counts()

# ── StartPage signal handlers ─────────────────────────────────────────────────
func _on_startpage_start_pressed():
	print("[GameUI] StartPage start_pressed received — routing through ExperienceDirector")
	var pm = _get_pm()
	if pm and pm.has_method("close"): pm.close("StartPage")
	var ed = _get_ed()
	if ed and ed.has_method("load_flow") and ed.has_method("start_flow"):
		if ed.load_flow("main_story"):
			ed.start_flow()
			return
	# If ExperienceDirector path wasn't used, fall back to initializing via GameStateBridge
	var bridge = load("res://games/match3/services/GameStateBridge.gd")
	if bridge != null and bridge.has_method("initialize_game"):
		print("[GameUI] Calling GameStateBridge.initialize_game() (fallback)")
		bridge.initialize_game()

func _on_startpage_settings_pressed():
	var pm = _get_pm()
	if pm: pm.open("SettingsDialog", {})

func _on_startpage_map_pressed():
	var pm = _get_pm()
	if pm: pm.open("WorldMap", {})

func _on_startpage_achievements_pressed():
	var pm = _get_pm()
	if pm: pm.open("AchievementsPage", {})

# ── FloatingMenu dispatch ─────────────────────────────────────────────────────
func _on_floating_map_pressed() -> void:
	if _fmc(): _fmc().collapse()
	_get_pm().open("WorldMap", {})

func _on_floating_shop_pressed() -> void:
	if _fmc(): _fmc().collapse()
	_get_pm().open("ShopUI", {})

func _on_floating_gallery_pressed() -> void:
	if _fmc(): _fmc().collapse()
	_get_pm().open("GalleryPage", {})

func _on_floating_settings_pressed() -> void:
	if _fmc(): _fmc().collapse()
	_get_pm().open("SettingsDialog", {})

# ── Booster button press handler (from BoosterPanelComponent signal) ──────────
func _on_booster_button_pressed(booster_id: String) -> void:
	print("[GameUI] Booster button pressed: %s" % booster_id)
	var rm = _get_rm()
	var am = _get_am()
	if am: am.play_sfx("ui_click")
	if not rm or not rm.has_method("get_booster_count"):
		return
	if rm.get_booster_count(booster_id) <= 0:
		return
	if booster_id == "shuffle":
		var board = get_node_or_null("../GameBoard")
		if board and board.has_method("activate_shuffle_booster"):
			board.activate_shuffle_booster()
	elif booster_id == "extra_moves":
		if rm.has_method("use_booster") and rm.use_booster("extra_moves"):
			# PR 6.5c: use GameStateBridge exclusively — GameManager fallback removed.
			var bridge2 = load("res://games/match3/services/GameStateBridge.gd")
			if bridge2 != null and bridge2.has_method("add_moves"):
				bridge2.add_moves(10)
	else:
		activate_booster(booster_id)
		if booster_id == "line_blast":
			line_blast_direction = "horizontal"
		elif booster_id == "swap":
			swap_first_tile = null

# ── PageManager event wiring ──────────────────────────────────────────────────
func _on_page_opened(page_name: String, node: Node) -> void:
	if page_name == "StartPage" and node:
		var sp = node
		if sp.has_method("show_screen"):
			sp.call_deferred("show_screen")
			sp.visible = true
			sp.modulate = Color(1, 1, 1, 1)
		if not sp.is_connected("start_pressed",        Callable(self, "_on_startpage_start_pressed")):
			sp.connect("start_pressed",        Callable(self, "_on_startpage_start_pressed"))
		if not sp.is_connected("settings_pressed",     Callable(self, "_on_startpage_settings_pressed")):
			sp.connect("settings_pressed",     Callable(self, "_on_startpage_settings_pressed"))
		if not sp.is_connected("map_pressed",          Callable(self, "_on_startpage_map_pressed")):
			sp.connect("map_pressed",          Callable(self, "_on_startpage_map_pressed"))
		if not sp.is_connected("achievements_pressed", Callable(self, "_on_startpage_achievements_pressed")):
			sp.connect("achievements_pressed", Callable(self, "_on_startpage_achievements_pressed"))
		if sp.has_method("set_level_info"):
			var level_num = _get_next_level_number()
			var desc = _get_level_description(level_num)
			# Also tell LevelManager to point at this level so it's ready when play is pressed
			var lm = NodeResolvers._get_lm()
			if lm and lm.has_method("get_level_index"):
				var idx = lm.get_level_index(level_num)
				if idx >= 0:
					lm.set_current_level(idx)
			sp.call_deferred("set_level_info", level_num, desc)
			print("[GameUI] Set StartPage level info: level=%d, desc=%s" % [level_num, desc])

	if page_name == "WorldMap" and node:
		if not node.is_connected("level_selected", Callable(self, "_on_worldmap_level_selected")):
			node.connect("level_selected", Callable(self, "_on_worldmap_level_selected"))
			print("[GameUI] Connected to WorldMap.level_selected")

func _on_worldmap_level_selected(level_num: int) -> void:
	print("[GameUI] WorldMap level_selected received: %d — routing through ExperienceDirector" % level_num)
	var am = _get_am()
	if am: am.play_sfx("ui_click")
	var ed = _get_ed()
	if ed and ed.has_method("load_flow") and ed.has_method("start_flow_at_level"):
		if ed.load_flow("main_story"):
			var pm = _get_pm()
			# Hide StartPage before closing WorldMap so it doesn't flash through.
			# It remains on the PageManager stack but invisible while the flow runs.
			if pm and pm.has_method("get_open_page"):
				var sp_node = pm.get_open_page("StartPage")
				if sp_node and is_instance_valid(sp_node):
					sp_node.visible = false
					print("[GameUI] Hid StartPage before WorldMap flow start")
			# Close WorldMap with flow_starting=true — suppresses PageManager
			# from revealing the StartPage underneath.
			if pm: pm.close("WorldMap", {"flow_starting": true})
			ed.start_flow_at_level(level_num)
			return
	# Fallback — close normally then load directly via GameStateBridge
	var pm2 = _get_pm()
	if pm2: pm2.close("WorldMap")
	var lm = NodeResolvers._get_lm()
	if lm and lm.has_method("get_level_index"):
		var idx = lm.get_level_index(level_num)
		if idx >= 0: lm.set_current_level(idx)
	# PR 6.5c: use GameStateBridge — GameManager.initialize_game removed.
	var bridge3 = load("res://games/match3/services/GameStateBridge.gd")
	if bridge3 != null and bridge3.has_method("initialize_game"):
		bridge3.initialize_game()

# ── Progress helpers ──────────────────────────────────────────────────────────
func _get_next_level_number() -> int:
	## Returns the next level the player should play: levels_completed + 1,
	## clamped to the total number of levels available.
	var rm = _get_rm()
	var completed = rm.levels_completed if (rm and "levels_completed" in rm) else 0
	var next_level = completed + 1
	# Clamp to available levels
	var lm = NodeResolvers._get_lm()
	if lm and "levels" in lm and lm.levels.size() > 0:
		next_level = clamp(next_level, 1, lm.levels.size())
	else:
		next_level = max(1, next_level)
	return next_level

func _get_level_description(level_num: int) -> String:
	## Returns the description string for the given level number.
	var lm = NodeResolvers._get_lm()
	if lm and lm.has_method("get_level_index"):
		var idx = lm.get_level_index(level_num)
		if idx >= 0 and lm.has_method("get_level_by_index"):
			var ld = lm.get_level_by_index(idx)
			if ld and "description" in ld:
				return str(ld.description)
		# Fallback: try get_current_level after setting index
		if idx >= 0:
			lm.set_current_level(idx)
			var ld2 = lm.get_current_level()
			if ld2 and "description" in ld2:
				return str(ld2.description)
	return ""
