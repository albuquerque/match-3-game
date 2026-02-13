extends Node
class_name EffectExecutorNarrativeDialogue

var active_dialogue: Control = null
var typewriter_active: bool = false

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var anchor_id = context.get("anchor", "board")
	var viewport = context.get("viewport", null)
	if not viewport:
		push_warning("[NarrativeDialogueExecutor] No viewport in context")
		return

	# Support both 'message' and 'text' parameters (message takes priority)
	var text_content = params.get("message", params.get("text", ""))
	print("[NarrativeDialogueExecutor] Showing dialogue: ", text_content)

	if active_dialogue and is_instance_valid(active_dialogue):
		active_dialogue.queue_free()

	active_dialogue = _create_dialogue_panel(params, viewport)
	viewport.add_child(active_dialogue)
	active_dialogue.z_index = 999
	active_dialogue.modulate = Color(1,1,1,0)

	var final_position = active_dialogue.position
	var position_str = params.get("position", "bottom")

	match position_str:
		"top":
			active_dialogue.position = Vector2(final_position.x, final_position.y - 100)
		"center":
			active_dialogue.scale = Vector2(0.8, 0.8)
		_:
			active_dialogue.position = Vector2(final_position.x, final_position.y + 100)

	var tween = viewport.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(active_dialogue, "modulate", Color.WHITE, 0.5)

	if position_str == "center":
		tween.tween_property(active_dialogue, "scale", Vector2.ONE, 0.5)
	else:
		tween.tween_property(active_dialogue, "position", final_position, 0.5)

	var duration = params.get("duration", 0.0)
	if duration > 0:
		var timer = viewport.get_tree().create_timer(duration)
		timer.timeout.connect(Callable(self, "_dismiss_dialogue"))

func _create_dialogue_panel(params: Dictionary, viewport: Node) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.name = "NarrativeDialogue"
	var viewport_size = viewport.size
	var position_str = params.get("position", "bottom")
	var panel_height = 200 if params.has("image") else 180

	# Calculate safe panel width
	# The panel will add content_margin (20+20=40) + borders (3+3=6) = 46px extra
	# So we need to account for this in our calculation
	var screen_margin = 20  # Minimal screen margin on each side (40px total)
	var style_overhead = 46  # content_margin (40) + borders (6)
	var max_panel_width = viewport_size.x - (screen_margin * 2) - style_overhead
	var panel_width = min(max_panel_width, 640)  # Cap at 640px for readability
	var has_image = params.has("image")

	# Calculate actual rendered width for positioning
	var actual_panel_width = panel_width + style_overhead

	match position_str:
		"top":
			panel.position = Vector2((viewport_size.x - actual_panel_width) / 2, 60)
		"center":
			panel.position = Vector2((viewport_size.x - actual_panel_width) / 2, (viewport_size.y - panel_height) / 2)
		_:
			panel.position = Vector2((viewport_size.x - actual_panel_width) / 2, viewport_size.y - panel_height - 60)

	# Set both minimum and maximum size to prevent overflow
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.size = Vector2(panel_width, panel_height)

	# Ensure panel doesn't expand beyond set size
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var style_box = StyleBoxFlat.new()
	var style = params.get("style", "gospel")
	match style:
		"gospel":
			style_box.bg_color = Color(0.1, 0.1, 0.2, 0.95)
			style_box.border_color = Color(0.8, 0.7, 0.3, 1.0)
		"miracle":
			style_box.bg_color = Color(0.2, 0.1, 0.2, 0.95)
			style_box.border_color = Color(0.9, 0.8, 0.9, 1.0)
		"teaching":
			style_box.bg_color = Color(0.15, 0.1, 0.05, 0.95)
			style_box.border_color = Color(0.7, 0.6, 0.4, 1.0)
		_:
			style_box.bg_color = Color(0.1, 0.1, 0.1, 0.95)
			style_box.border_color = Color(0.5, 0.5, 0.5, 1.0)

	style_box.border_width_left = 3
	style_box.border_width_right = 3
	style_box.border_width_top = 3
	style_box.border_width_bottom = 3
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.corner_radius_bottom_right = 12
	style_box.content_margin_left = 20
	style_box.content_margin_right = 20
	style_box.content_margin_top = 15
	style_box.content_margin_bottom = 15
	panel.add_theme_stylebox_override("panel", style_box)

	# Main container - horizontal if image present
	var main_container: BoxContainer
	if params.has("image"):
		main_container = HBoxContainer.new()
		main_container.add_theme_constant_override("separation", 15)
	else:
		main_container = VBoxContainer.new()
		main_container.add_theme_constant_override("separation", 8)

	panel.add_child(main_container)

	# Add image if provided
	if params.has("image"):
		var image_path = params.get("image")
		var image_texture = _load_image(image_path)
		if image_texture:
			var texture_rect = TextureRect.new()
			texture_rect.texture = image_texture
			texture_rect.custom_minimum_size = Vector2(120, 120)
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			main_container.add_child(texture_rect)

	# Text container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	# Ensure vbox doesn't expand beyond available space
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(vbox)

	# Support both 'title' and 'character' parameters (title takes priority)
	var header_text = params.get("title", params.get("character", ""))
	if header_text != "":
		var name_label = Label.new()
		name_label.text = header_text
		name_label.add_theme_font_size_override("font_size", 22)
		name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		if ThemeManager and ThemeManager.has_method("apply_bangers_font"):
			ThemeManager.apply_bangers_font(name_label, 22)
		vbox.add_child(name_label)

	# Create appropriate label type based on whether we need BBCode
	var full_text = params.get("message", params.get("text", ""))
	var reveal_mode = params.get("reveal_mode", "instant")
	var emphasis_list = params.get("emphasis", [])

	var text_label: Control
	var use_bbcode = emphasis_list.size() > 0

	if use_bbcode:
		# Use RichTextLabel for BBCode support
		var rich_label = RichTextLabel.new()
		rich_label.bbcode_enabled = true
		rich_label.fit_content = true
		rich_label.scroll_active = false
		text_label = rich_label
		full_text = _apply_text_emphasis(full_text, emphasis_list)
	else:
		# Use regular Label for simple text
		text_label = Label.new()

	# Set initial text based on reveal mode
	if reveal_mode == "typewriter":
		if use_bbcode:
			text_label.text = ""
			text_label.visible_ratio = 0.0
		else:
			text_label.text = ""
			text_label.visible_ratio = 0.0
	else:
		text_label.text = full_text

	# Configure text wrapping and size
	if use_bbcode:
		# RichTextLabel uses autowrap property differently
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Set custom minimum width to match panel width (accounting for image if present)
		var text_width = panel_width - 40  # Account for panel margins (20 + 20)
		if params.has("image"):
			text_width -= 135  # Account for image (120) + separator (15)
		text_label.custom_minimum_size = Vector2(text_width, 60)
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		# Regular Label
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.custom_minimum_size = Vector2(0, 60)
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	text_label.add_theme_font_size_override("font_size", 18)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	if ThemeManager and ThemeManager.has_method("apply_bangers_font"):
		ThemeManager.apply_bangers_font(text_label, 18)
	vbox.add_child(text_label)

	# Start typewriter effect if enabled
	if reveal_mode == "typewriter":
		_start_typewriter_effect(text_label, full_text, params, panel)

	if params.get("duration", 0.0) == 0:
		var hint_label = Label.new()
		hint_label.text = "Tap to continue..."
		hint_label.add_theme_font_size_override("font_size", 14)
		hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
		hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		vbox.add_child(hint_label)

		hint_label.modulate = Color(1, 1, 1, 0.5)
		var hint_tween = panel.create_tween()
		hint_tween.set_loops(-1)  # -1 means infinite in Godot 4
		hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.8)
		hint_tween.tween_property(hint_label, "modulate:a", 0.5, 0.8)

		# Store tween in panel metadata so we can kill it when dismissing
		panel.set_meta("hint_tween", hint_tween)

		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_dialogue_clicked)
	else:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return panel

func _on_dialogue_clicked(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_dismiss_dialogue()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_dismiss_dialogue()

func _dismiss_dialogue() -> void:
	if not active_dialogue or not is_instance_valid(active_dialogue):
		return

	print("[NarrativeDialogueExecutor] Dismissing dialogue with animation")

	# Kill any running hint tween to prevent infinite loop errors
	if active_dialogue.has_meta("hint_tween"):
		var hint_tween = active_dialogue.get_meta("hint_tween")
		if hint_tween and hint_tween.is_valid():
			hint_tween.kill()
		active_dialogue.remove_meta("hint_tween")

	var viewport = active_dialogue.get_viewport()
	if not viewport:
		if is_instance_valid(active_dialogue):
			active_dialogue.queue_free()
			active_dialogue = null
		return

	var tween = viewport.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(active_dialogue, "modulate", Color(1, 1, 1, 0), 0.3)

	var current_pos = active_dialogue.position
	var viewport_size = viewport.size
	var screen_height = viewport_size.y

	if current_pos.y < screen_height * 0.3:
		tween.tween_property(active_dialogue, "position:y", current_pos.y - 80, 0.3)
	elif current_pos.y > screen_height * 0.6:
		tween.tween_property(active_dialogue, "position:y", current_pos.y + 80, 0.3)
	else:
		tween.tween_property(active_dialogue, "scale", Vector2(0.8, 0.8), 0.3)

	active_dialogue = null
	print("[NarrativeDialogueExecutor] Dialogue dismissed - animation playing")

func _load_image(image_path: String) -> Texture2D:
	"""Load image texture from various possible paths"""
	if ResourceLoader.exists(image_path):
		var resource = load(image_path)
		if resource is Texture2D:
			return resource

	# Try common image paths
	var paths_to_try = [
		image_path,
		"res://data/images/dialogue/%s" % image_path,
		"res://data/images/%s" % image_path,
		"res://assets/textures/dialogue/%s" % image_path,
		"res://textures/dialogue/%s" % image_path,
		"res://textures/%s" % image_path
	]

	for path in paths_to_try:
		if ResourceLoader.exists(path):
			var resource = load(path)
			if resource is Texture2D:
				return resource

	push_warning("[NarrativeDialogueExecutor] Could not load image: %s" % image_path)
	return null

func _apply_text_emphasis(text: String, emphasis_list: Array) -> String:
	"""Apply BBCode formatting to emphasized words"""
	var result = text

	for emphasis in emphasis_list:
		if not emphasis is Dictionary:
			continue

		var word = emphasis.get("word", "")
		var style = emphasis.get("style", "glow")

		if word == "":
			continue

		# Build BBCode for the style
		var bbcode_start = ""
		var bbcode_end = ""

		match style:
			"glow":
				bbcode_start = "[color=#FFD700][wave amp=25 freq=2]"
				bbcode_end = "[/wave][/color]"
			"bold":
				bbcode_start = "[b]"
				bbcode_end = "[/b]"
			"shake":
				bbcode_start = "[shake rate=10 level=5]"
				bbcode_end = "[/shake]"
			"rainbow":
				bbcode_start = "[rainbow freq=0.5 sat=0.8 val=1.0]"
				bbcode_end = "[/rainbow]"
			"emphasis":
				bbcode_start = "[color=#FFD700][b]"
				bbcode_end = "[/b][/color]"

		# Replace word with emphasized version (case-sensitive)
		result = result.replace(word, bbcode_start + word + bbcode_end)

	return result

func _start_typewriter_effect(label: Control, full_text: String, params: Dictionary, panel: Control) -> void:
	"""Animate text reveal character by character"""
	typewriter_active = true
	label.text = full_text
	label.visible_ratio = 0.0

	var chars_per_second = params.get("typewriter_speed", 30.0)
	var total_chars = full_text.length()
	var duration = total_chars / chars_per_second

	if panel and panel.has_method("create_tween"):
		var tween = panel.create_tween()
		tween.tween_property(label, "visible_ratio", 1.0, duration)
		tween.finished.connect(func(): typewriter_active = false)
