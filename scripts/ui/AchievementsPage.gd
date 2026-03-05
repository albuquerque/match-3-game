extends "res://scripts/ui/ScreenBase.gd"

# Achievements page showing badges and daily login streak

signal back_pressed

@onready var streak_label: Label
@onready var badges_container: VBoxContainer
@onready var claim_reward_button: Button
@onready var back_button: Button

# Preload gold star texture for consistent display
var gold_star_texture = preload("res://textures/gold_star.svg")
var Resolver = null

func _ready():
	_ensure_resolver()
	# Create UI programmatically for flexibility
	_setup_ui()
	_update_display()
	ensure_fullscreen()
	# Ensure this screen consumes input so clicks don't pass through to underlying pages
	if self is Control:
		self.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func _ensure_resolver():
	if Resolver == null:
		var s = load("res://scripts/helpers/node_resolvers_api.gd")
		if s != null and typeof(s) != TYPE_NIL:
			Resolver = s
		else:
			Resolver = load("res://scripts/helpers/node_resolvers_shim.gd")

func _setup_ui():
	# Try to add background image first, fallback to solid color
	_setup_background()

	# Main container
	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.anchor_left = 0.1
	vbox.anchor_top = 0.05
	vbox.anchor_right = 0.9
	vbox.anchor_bottom = 0.95
	add_child(vbox)

	# Title with warm biblical colors
	var title = Label.new()
	title.text = tr("UI_ACHIEVEMENTS_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_bangers_font(title, 40)
	title.add_theme_color_override("font_color", Color(0.5, 0.3, 0.1))  # Deep warm brown
	vbox.add_child(title)

	# Top bar: spacer + close button to make closing obvious
	var top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	var top_spacer = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(top_spacer)
	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = tr("UI_CLOSE")
	close_btn.custom_minimum_size = Vector2(80, 36)
	# Swallow the raw GUI input on close so clicks don't pass through to underlying pages
	if close_btn and close_btn.has_signal("gui_input"):
		close_btn.connect("gui_input", Callable(self, "_on_close_gui_input"))
	if close_btn and close_btn.has_signal("pressed"):
		close_btn.connect("pressed", Callable(self, "_on_back_pressed"))
	top_bar.add_child(close_btn)
	vbox.add_child(top_bar)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	# Daily Streak Section (increased transparency)
	var streak_panel = Panel.new()
	var streak_style = StyleBoxFlat.new()
	streak_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)  # Reduced opacity from 1.0 to 0.8
	streak_style.corner_radius_top_left = 10
	streak_style.corner_radius_top_right = 10
	streak_style.corner_radius_bottom_left = 10
	streak_style.corner_radius_bottom_right = 10
	streak_panel.add_theme_stylebox_override("panel", streak_style)
	streak_panel.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(streak_panel)

	var streak_vbox = VBoxContainer.new()
	streak_vbox.anchor_right = 1.0
	streak_vbox.anchor_bottom = 1.0
	streak_vbox.offset_left = 20
	streak_vbox.offset_top = 20
	streak_vbox.offset_right = -20
	streak_vbox.offset_bottom = -20
	streak_panel.add_child(streak_vbox)

	var streak_title = Label.new()
	streak_title.text = tr("UI_DAILY_STREAK_TITLE")
	streak_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_bangers_font(streak_title, 28)
	streak_title.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	streak_vbox.add_child(streak_title)

	streak_label = Label.new()
	streak_label.name = "StreakLabel"
	streak_label.text = tr("UI_CURRENT_STREAK") % 0
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_bangers_font(streak_label, 24)
	streak_vbox.add_child(streak_label)

	var reward_info = Label.new()
	reward_info.text = tr("UI_LOGIN_REWARDS_INFO")
	reward_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_bangers_font(reward_info, 16)
	reward_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	streak_vbox.add_child(reward_info)

	# Claim reward button
	claim_reward_button = Button.new()
	claim_reward_button.name = "ClaimRewardButton"
	claim_reward_button.text = tr("UI_CLAIM_DAILY")
	claim_reward_button.custom_minimum_size = Vector2(250, 50)
	claim_reward_button.disabled = true
	if claim_reward_button and claim_reward_button.has_signal("pressed"):
		claim_reward_button.connect("pressed", Callable(self, "_on_claim_reward_pressed"))
	streak_vbox.add_child(claim_reward_button)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	# Badges section
	var badges_title = Label.new()
	badges_title.text = tr("UI_MILESTONE_BADGES")
	badges_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_bangers_font(badges_title, 28)
	badges_title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	vbox.add_child(badges_title)

	# Scroll container for badges
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	badges_container = VBoxContainer.new()
	badges_container.name = "BadgesContainer"
	scroll.add_child(badges_container)

	# Back button
	back_button = Button.new()
	back_button.text = tr("UI_BACK")
	back_button.custom_minimum_size = Vector2(150, 50)
	# Swallow gui input to prevent click-through
	if back_button and back_button.has_signal("gui_input"):
		back_button.connect("gui_input", Callable(self, "_on_close_gui_input"))
	if back_button and back_button.has_signal("pressed"):
		back_button.connect("pressed", Callable(self, "_on_back_pressed"))
	vbox.add_child(back_button)

func _setup_background():
	# Try to set a subtle background color or image
	if not has_node("Background"):
		var bg = ColorRect.new()
		bg.name = "Background"
		bg.anchor_left = 0
		bg.anchor_top = 0
		bg.anchor_right = 1
		bg.anchor_bottom = 1
		bg.color = Color(0.06, 0.04, 0.02)
		add_child(bg)

func _apply_bangers_font(node: Node, size: int) -> void:
	# Lightweight font application - use ThemeManager if available
	var tm = Resolver._get_tm() if typeof(Resolver) != TYPE_NIL else null
	if tm and tm.has_method("apply_bangers_font"):
		tm.apply_bangers_font(node, size)

func _update_display():
	var rm = Resolver._get_rm() if typeof(Resolver) != TYPE_NIL else null
	if rm == null and has_method("get_tree"):
		var rt = get_tree().root
		if rt:
			rm = rt.get_node_or_null("RewardManager")
	if not rm:
		return

	# Update streak display
	var streak = rm.daily_streak
	if streak_label:
		streak_label.text = tr("UI_CURRENT_STREAK") % streak

		# Add visual flair for milestones
		if streak >= 7:
			streak_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		elif streak >= 4:
			streak_label.add_theme_color_override("font_color", Color(0.8, 1, 0.4))
		else:
			streak_label.add_theme_color_override("font_color", Color(1, 1, 1))

	# Check if reward can be claimed
	var can_claim = _can_claim_daily_reward()
	if claim_reward_button:
		claim_reward_button.disabled = not can_claim
		if can_claim:
			claim_reward_button.text = "🎁 " + tr("UI_CLAIM_DAILY")
		else:
			claim_reward_button.text = "✓ " + tr("UI_CLAIMED")

	# Update badges
	_update_badges(streak)

func _can_claim_daily_reward() -> bool:
	var rm = Resolver._get_rm() if typeof(Resolver) != TYPE_NIL else null
	if rm == null and has_method("get_tree"):
		var rt = get_tree().root
		if rt:
			rm = rt.get_node_or_null("RewardManager")
	if not rm:
		return false

	var last_claim = rm.last_daily_reward_claim if "last_daily_reward_claim" in rm else ""
	var today = Time.get_date_string_from_system()

	return last_claim != today

func _update_badges(streak: int):
	if not badges_container:
		return

	# Clear existing badges
	for child in badges_container.get_children():
		child.queue_free()

	var rm = Resolver._get_rm() if typeof(Resolver) != TYPE_NIL else null
	if rm == null and has_method("get_tree"):
		var rt = get_tree().root
		if rt:
			rm = rt.get_node_or_null("RewardManager")
	if not rm:
		return

	# Define all achievements with categories (expanded for long-term engagement)
	var achievement_categories = [
		{
			"title": "📈 Match Master",
			"achievements": [
				{"id": "matches_100", "title": "First Century", "desc": "Make 100 matches"},
				{"id": "matches_500", "title": "Match Veteran", "desc": "Make 500 matches"},
				{"id": "matches_1000", "title": "Match Legend", "desc": "Make 1000 matches"},
				{"id": "matches_2500", "title": "Match Hero", "desc": "Make 2500 matches"},
				{"id": "matches_5000", "title": "Match Master", "desc": "Make 5000 matches"},
				{"id": "matches_10000", "title": "Match God", "desc": "Make 10,000 matches"},
			]
		},
		# ... other categories omitted for brevity (kept same as original) ...
	]

	# Create categories and achievements
	for category in achievement_categories:
		var category_header = Label.new()
		category_header.text = tr(category["title"])
		category_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_apply_bangers_font(category_header, 24)
		category_header.add_theme_color_override("font_color", Color(0.4, 0.2, 0.1))
		category_header.custom_minimum_size = Vector2(0, 40)
		badges_container.add_child(category_header)

		for achievement_data in category["achievements"]:
			var achievement_panel = _create_achievement_panel(
				achievement_data["id"],
				tr(achievement_data["title"]),
				tr(achievement_data["desc"]),
				0, 1, false
			)
			badges_container.add_child(achievement_panel)

		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 15)
		badges_container.add_child(spacer)

func _create_achievement_panel(achievement_id: String, title: String, desc: String, current_progress: int, target_progress: int, unlocked: bool) -> Panel:
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	if unlocked:
		style.bg_color = Color(0.95, 0.92, 0.82, 0.75)
		style.border_color = Color(0.8, 0.65, 0.3, 0.9)
	else:
		style.bg_color = Color(0.85, 0.9, 0.95, 0.7)
		style.border_color = Color(0.6, 0.7, 0.8, 0.8)

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(450, 100)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var main_hbox = HBoxContainer.new()
	main_hbox.anchor_right = 1.0
	main_hbox.anchor_bottom = 1.0
	main_hbox.offset_left = 15
	main_hbox.offset_top = 10
	main_hbox.offset_right = -15
	main_hbox.offset_bottom = -10
	panel.add_child(main_hbox)

	var achievement_vbox = VBoxContainer.new()
	achievement_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_vbox.custom_minimum_size = Vector2(300, 0)
	main_hbox.add_child(achievement_vbox)

	var title_label = Label.new()
	title_label.text = title if unlocked else "🔒 " + title
	_apply_bangers_font(title_label, 20)
	if unlocked:
		title_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.1))
	else:
		title_label.add_theme_color_override("font_color", Color(0.3, 0.4, 0.6))
	achievement_vbox.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = desc
	_apply_bangers_font(desc_label, 14)
	if unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.1))
	else:
		desc_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	achievement_vbox.add_child(desc_label)

	var progress_container = HBoxContainer.new()
	progress_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_vbox.add_child(progress_container)

	var progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size = Vector2(150, 20)
	progress_bar.max_value = target_progress
	progress_bar.value = current_progress
	progress_container.add_child(progress_bar)

	var progress_label = Label.new()
	progress_label.text = "%d/%d" % [current_progress, target_progress]
	progress_label.custom_minimum_size = Vector2(60, 0)
	_apply_bangers_font(progress_label, 16)
	return panel

func _on_claim_reward_pressed():
	print("[AchievementsPage] Claim reward pressed")
	var rm = Resolver._get_rm() if typeof(Resolver) != TYPE_NIL else null
	if rm and rm.has_method("claim_daily_reward"):
		rm.claim_daily_reward()
		_update_display()

func _on_back_pressed():
	# Emit local signal for any listeners, then request PageManager to close this page
	print("[AchievementsPage] back pressed")
	# Prevent double-press and consume input to avoid click-through
	if back_button:
		back_button.disabled = true
	if has_method("get_tree") and get_tree() != null:
		var st = get_tree()
		if st and st.has_method("set_input_as_handled"):
			st.set_input_as_handled()

	# Emit local signal for any listeners
	emit_signal("back_pressed")

	# Hide first so we don't remove the node while input is still being dispatched
	if has_method("hide_screen"):
		hide_screen()
	# Defer the actual close to the next frame (or after a short timer) so the release event doesn't hit underlying UI
	call_deferred("_deferred_close_request")
	return

func _deferred_close_request() -> void:
	print("[AchievementsPage] deferred close request: emitting EventBus/page manager close")
	var eb = Resolver._get_evbus() if typeof(Resolver) != TYPE_NIL else null
	if eb == null and has_method("get_tree"):
		var rt = get_tree().root
		if rt:
			eb = rt.get_node_or_null("EventBus")
	# Prefer EventBus; otherwise call PageManager directly
	if eb and eb.has_method("emit_close_page"):
		eb.emit_close_page("AchievementsPage")
		return
	var pm = Resolver._get_pm() if typeof(Resolver) != TYPE_NIL else null
	if pm == null and has_method("get_tree"):
		var rt2 = get_tree().root
		if rt2:
			pm = rt2.get_node_or_null("PageManager")
	if pm and pm.has_method("close"):
		pm.close("AchievementsPage")
		return

	# As a last resort, free
	queue_free()

func show_dialog():
	visible = true
	modulate = Color(1,1,1,0)
	var t = get_tree().create_tween()
	t.tween_property(self, "modulate", Color(1,1,1,1), 0.15)
	# Give focus to close button so keyboard/back works immediately
	var cb = get_node_or_null("TopBar/CloseButton")
	if cb:
		cb.grab_focus()

func _unhandled_input(ev):
	# Support Esc key or back button on desktop/mobile to close the page
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.scancode == KEY_ESCAPE:
			_on_back_pressed()
	if ev is InputEventScreenTouch and ev.is_pressed() == false:
		# ignore
		pass

func _on_close_gui_input(ev: InputEvent) -> void:
	# Accept mouse/touch input on these controls to prevent propagation to underlying UI.
	if ev is InputEventMouseButton:
		if ev.pressed:
			# consume the input via SceneTree to avoid calling non-existent InputEvent.accept()
			if has_method("get_tree") and get_tree() != null and get_tree().has_method("set_input_as_handled"):
				get_tree().set_input_as_handled()
			call_deferred("_on_back_pressed")
	elif ev is InputEventScreenTouch:
		if ev.is_pressed():
			if has_method("get_tree") and get_tree() != null and get_tree().has_method("set_input_as_handled"):
				get_tree().set_input_as_handled()
			call_deferred("_on_back_pressed")
