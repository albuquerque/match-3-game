extends Control
class_name GameUI

var NodeResolverAPI = null

func _init_resolvers():
	if NodeResolverAPI == null:
		var s = load("res://scripts/helpers/node_resolvers_api.gd")
		if s != null and typeof(s) != TYPE_NIL and s.has_method("_get_gm"):
			NodeResolverAPI = s
		else:
			NodeResolverAPI = load("res://scripts/helpers/node_resolvers_shim.gd")

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

# ── Component accessors ───────────────────────────────────────────────────────
func _hud():
	return hud if (hud and hud.has_method("set_score")) else null

func _bbar():
	return booster_bar if (booster_bar and booster_bar.has_method("refresh_counts")) else null

func _fmc():
	return floating_menu_comp if (floating_menu_comp and floating_menu_comp.has_method("collapse")) else null

# ── Resolver helpers ──────────────────────────────────────────────────────────
func _get_gm():
	return NodeResolverAPI._get_gm()

func _get_rm():
	return NodeResolverAPI._get_rm()

func _get_tm():
	return NodeResolverAPI._get_tm()

func _get_pm():
	return NodeResolverAPI._get_pm()

func _get_am():
	return NodeResolverAPI._get_am()

func _get_ed():
	var rt = get_tree().root if has_node("/root") else null
	if rt:
		var ed = rt.get_node_or_null("ExperienceDirector")
		if ed:
			return ed
	return null

func _ready():
	_init_resolvers()
	self.z_index = 200

	floating_menu       = get_node_or_null("FloatingMenu")
	reward_notification = get_node_or_null("RewardNotification")
	level_transition    = get_node_or_null("LevelTransition")

	# Wire HUD signals (HUDComponent.tscn not instanced — wire directly to scene labels)
	call_deferred("_connect_hud_signals")

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
	var vam = NodeResolverAPI._get_vam() if typeof(NodeResolverAPI) != TYPE_NIL else null
	if vam and vam.has_method("register_anchor"):
		vam.register_anchor("ui", self)

	# Connect PageManager
	var pm = NodeResolverAPI._get_pm() if typeof(NodeResolverAPI) != TYPE_NIL else null
	if pm == null:
		pm = get_tree().root.get_node_or_null("PageManager")
	if pm and pm.has_signal("page_opened"):
		if not pm.is_connected("page_opened", Callable(self, "_on_page_opened")):
			pm.connect("page_opened", Callable(self, "_on_page_opened"))
	if pm:
		pm.call_deferred("open", "StartPage", {})
	else:
		print("[GameUI] WARNING: PageManager not available; StartPage will not be opened automatically")

	call_deferred("hide_gameplay_ui")

# ── HUD wiring — connects GameManager signals to the labels already in the scene ──
func _connect_hud_signals() -> void:
	# If a HUDComponent node exists (future), let it handle its own wiring.
	if hud != null:
		return
	var gm = _get_gm()
	if gm == null:
		push_warning("[GameUI] _connect_hud_signals: GameManager not found")
		return
	if not gm.is_connected("score_changed", _on_score_changed):
		gm.connect("score_changed", _on_score_changed)
	if not gm.is_connected("moves_changed", _on_moves_changed):
		gm.connect("moves_changed", _on_moves_changed)
	if not gm.is_connected("level_changed", _on_level_changed):
		gm.connect("level_changed", _on_level_changed)
	if not gm.is_connected("level_loaded", _on_hud_level_loaded):
		gm.connect("level_loaded", _on_hud_level_loaded)
	if gm.has_signal("collectibles_changed") and not gm.is_connected("collectibles_changed", _on_collectibles_changed):
		gm.connect("collectibles_changed", _on_collectibles_changed)
	if gm.has_signal("unmovables_changed") and not gm.is_connected("unmovables_changed", _on_unmovables_changed):
		gm.connect("unmovables_changed", _on_unmovables_changed)
	var rm = _get_rm()
	if rm and rm.has_signal("coins_changed") and not rm.is_connected("coins_changed", _on_currency_changed):
		rm.connect("coins_changed", _on_currency_changed)
	print("[GameUI] HUD signals wired directly to scene labels")

# ── HUD label helpers ─────────────────────────────────────────────────────────
func _score_label() -> Label:
	return get_node_or_null("VBoxContainer/TopPanel/HBoxContainer/ScoreContainer/ScoreLabel")

func _moves_label() -> Label:
	return get_node_or_null("VBoxContainer/TopPanel/HBoxContainer/MovesContainer/MovesLabel")

func _level_label() -> Label:
	return get_node_or_null("VBoxContainer/TopPanel/HBoxContainer/LevelContainer/LevelLabel")

func _target_label() -> Label:
	return get_node_or_null("VBoxContainer/TopPanel/HBoxContainer/TargetContainer/TargetLabel")

func _target_progress() -> ProgressBar:
	return get_node_or_null("VBoxContainer/TopPanel/HBoxContainer/TargetContainer/TargetProgress")

func _coins_label() -> Label:
	return get_node_or_null("VBoxContainer/CurrencyPanel/HBoxContainer/CoinsLabel")

func _gems_label() -> Label:
	return get_node_or_null("VBoxContainer/CurrencyPanel/HBoxContainer/GemsLabel")

func _lives_label() -> Label:
	return get_node_or_null("VBoxContainer/CurrencyPanel/HBoxContainer/LivesLabel")

# ── HUD signal handlers ───────────────────────────────────────────────────────
func _on_hud_level_loaded() -> void:
	var gm = _get_gm()
	if not gm:
		return
	var sl = _score_label()
	if sl: sl.text = "%d" % gm.score
	var ll = _level_label()
	if ll: ll.text = "Lv %d" % gm.level
	var ml = _moves_label()
	if ml: ml.text = "%d" % gm.moves_left
	_refresh_target_display(gm)
	_refresh_currency_display()

func _on_score_changed(new_score: int) -> void:
	var sl = _score_label()
	if sl: sl.text = "%d" % new_score
	var gm = _get_gm()
	if gm and gm.unmovable_target == 0 and gm.collectible_target == 0:
		_refresh_target_display(gm)

func _on_moves_changed(moves: int) -> void:
	var ml = _moves_label()
	if ml:
		ml.text = "%d" % moves
		ml.modulate = Color.RED if moves <= 5 else Color.WHITE

func _on_level_changed(new_level: int) -> void:
	var ll = _level_label()
	if ll: ll.text = "Lv %d" % new_level

func _on_collectibles_changed(collected: int, target: int) -> void:
	var tl = _target_label()
	if tl: tl.text = "%d / %d" % [collected, target]
	var tp = _target_progress()
	if tp:
		tp.max_value = target
		tp.value = collected

func _on_unmovables_changed(cleared: int, target: int) -> void:
	var tl = _target_label()
	if tl: tl.text = "%d / %d" % [cleared, target]
	var tp = _target_progress()
	if tp:
		tp.max_value = target
		tp.value = cleared

func _on_currency_changed(_amount: int) -> void:
	_refresh_currency_display()

func _refresh_target_display(gm: Node) -> void:
	var tl = _target_label()
	var tp = _target_progress()
	if gm.unmovable_target > 0:
		if tl: tl.text = "%d / %d" % [gm.unmovables_cleared, gm.unmovable_target]
		if tp: tp.max_value = gm.unmovable_target; tp.value = gm.unmovables_cleared
	elif gm.collectible_target > 0:
		if tl: tl.text = "%d / %d" % [gm.collectibles_collected, gm.collectible_target]
		if tp: tp.max_value = gm.collectible_target; tp.value = gm.collectibles_collected
	else:
		if tl: tl.text = "%d / %d" % [gm.score, gm.target_score]
		if tp:
			tp.max_value = gm.target_score
			tp.value = gm.score

func _refresh_currency_display() -> void:
	var rm = _get_rm()
	if not rm:
		return
	var cl = _coins_label()
	if cl: cl.text = "💰 %d" % (rm.get_coins() if rm.has_method("get_coins") else 0)
	var gl = _gems_label()
	if gl: gl.text = "💎 %d" % (rm.get_gems() if rm.has_method("get_gems") else 0)
	var ll = _lives_label()
	if ll: ll.text = "❤️ %d/5" % (rm.get_lives() if rm.has_method("get_lives") else 5)

# ── Level loading (called by ExperiencePipeline) ──────────────────────────────
func _load_level_by_number(level_num: int) -> void:
	print("[GameUI] _load_level_by_number(%d) called by pipeline" % level_num)
	var lm = NodeResolverAPI._get_lm() if typeof(NodeResolverAPI) != TYPE_NIL else null
	if lm == null:
		lm = get_tree().root.get_node_or_null("LevelManager")
	if lm and lm.has_method("get_level_index"):
		var idx = lm.get_level_index(level_num)
		if idx >= 0:
			lm.set_current_level(idx)
			print("[GameUI] LevelManager set to index %d (level %d)" % [idx, level_num])
	var gm = _get_gm()
	if gm and gm.has_method("initialize_game"):
		print("[GameUI] Calling GameManager.initialize_game() for level %d" % level_num)
		gm.initialize_game()

# ── Gameplay UI visibility ────────────────────────────────────────────────────
func show_gameplay_ui() -> void:
	print("[GameUI] Showing gameplay UI elements")
	if _narrative_fullscreen_active:
		return
	var top_panel = get_node_or_null("VBoxContainer/TopPanel")
	if top_panel: top_panel.visible = true
	if booster_bar: booster_bar.visible = true
	var currency_panel = get_node_or_null("VBoxContainer/CurrencyPanel")
	if currency_panel: currency_panel.visible = true
	if floating_menu: floating_menu.visible = true
	if reward_notification: reward_notification.visible = true
	print("[GameUI] ✓ All gameplay UI elements shown")

func hide_gameplay_ui() -> void:
	print("[GameUI] Hiding gameplay UI elements")
	var top_panel = get_node_or_null("VBoxContainer/TopPanel")
	if top_panel: top_panel.visible = false; print("[GameUI]   - TopPanel hidden")
	if booster_bar: booster_bar.visible = false; print("[GameUI]   - BoosterPanel hidden")
	var currency_panel = get_node_or_null("VBoxContainer/CurrencyPanel")
	if currency_panel: currency_panel.visible = false
	if floating_menu: floating_menu.visible = false
	if reward_notification: reward_notification.visible = false
	if level_transition: level_transition.visible = false
	print("[GameUI] ✓ All gameplay UI elements hidden")

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
	var gm = _get_gm()
	if gm and gm.has_method("initialize_game"):
		gm.initialize_game()

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
			var gm = _get_gm()
			if gm and gm.has_method("add_moves"):
				gm.add_moves(10)
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
			var lm = NodeResolverAPI._get_lm() if typeof(NodeResolverAPI) != TYPE_NIL else null
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
	var pm = _get_pm()
	if pm: pm.close("WorldMap")
	var ed = _get_ed()
	if ed and ed.has_method("load_flow") and ed.has_method("start_flow_at_level"):
		if ed.load_flow("main_story"):
			ed.start_flow_at_level(level_num)
			return
	# Fallback
	var lm = NodeResolverAPI._get_lm() if typeof(NodeResolverAPI) != TYPE_NIL else null
	if lm and lm.has_method("get_level_index"):
		var idx = lm.get_level_index(level_num)
		if idx >= 0: lm.set_current_level(idx)
	var gm = _get_gm()
	if gm and gm.has_method("initialize_game"):
		gm.initialize_game()

# ── Progress helpers ──────────────────────────────────────────────────────────
func _get_next_level_number() -> int:
	## Returns the next level the player should play: levels_completed + 1,
	## clamped to the total number of levels available.
	var rm = _get_rm()
	var completed = rm.levels_completed if (rm and "levels_completed" in rm) else 0
	var next_level = completed + 1
	# Clamp to available levels
	var lm = NodeResolverAPI._get_lm() if typeof(NodeResolverAPI) != TYPE_NIL else null
	if lm and "levels" in lm and lm.levels.size() > 0:
		next_level = clamp(next_level, 1, lm.levels.size())
	else:
		next_level = max(1, next_level)
	return next_level

func _get_level_description(level_num: int) -> String:
	## Returns the description string for the given level number.
	var lm = NodeResolverAPI._get_lm() if typeof(NodeResolverAPI) != TYPE_NIL else null
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
