extends Node
## EffectResolver - Central dispatcher that maps events to visual effects
## Loads effect definitions from JSON and instantiates executors
## This class must NOT contain story-specific logic

# Reference to EventBus (autoload)
var event_bus: Node = null

# Active effect definitions loaded from chapter JSON
var active_effects: Array = []

# Effect executor instances (registered by type)
var executors: Dictionary = {}

# Current chapter metadata
var current_chapter: Dictionary = {}

# Cached viewport reference for executors
var cached_viewport: Window = null

# ============================================
# Effect Executor Classes - MUST BE DECLARED FIRST
# ============================================

## Base executor class
class EffectExecutor:
	func execute(context: Dictionary):
		push_warning("[EffectExecutor] Base executor called - override in subclass")

## Narrative dialogue executor - Shows story text overlays (DLC-only feature)
class NarrativeDialogueExecutor extends EffectExecutor:
	var active_dialogue: Control = null

	func execute(context: Dictionary):
		var params = context.get("params", {})
		var anchor_id = context.get("anchor", "board")

		print("[NarrativeDialogueExecutor] Showing dialogue: ", params.get("text", ""))
		print("[NarrativeDialogueExecutor] Context keys: ", context.keys())

		# Get viewport from context (passed by EffectResolver)
		var viewport = context.get("viewport", null)
		if not viewport:
			push_warning("[NarrativeDialogueExecutor] No viewport in context")
			return

		print("[NarrativeDialogueExecutor] ✓ Got viewport: ", viewport.name)

		# Dismiss any active dialogue first
		if active_dialogue and is_instance_valid(active_dialogue):
			print("[NarrativeDialogueExecutor] Dismissing previous dialogue")
			active_dialogue.queue_free()

		# Create and show new dialogue
		print("[NarrativeDialogueExecutor] Creating dialogue panel...")
		active_dialogue = _create_dialogue_panel(params)
		print("[NarrativeDialogueExecutor] Adding panel to viewport...")
		viewport.add_child(active_dialogue)
		active_dialogue.z_index = 999
		print("[NarrativeDialogueExecutor] Panel added! Position: ", active_dialogue.position, " Size: ", active_dialogue.size)

		# Enhanced animation based on position
		var final_position = active_dialogue.position
		var position_str = params.get("position", "bottom")

		# Set initial state for animation
		active_dialogue.modulate = Color(1, 1, 1, 0)

		# Set initial offset based on position
		match position_str:
			"top":
				active_dialogue.position = Vector2(final_position.x, final_position.y - 100)  # Slide from above
			"center":
				active_dialogue.scale = Vector2(0.8, 0.8)  # Zoom in for center
			_:  # bottom
				active_dialogue.position = Vector2(final_position.x, final_position.y + 100)  # Slide from below

		# Create animation tween
		var tween = viewport.create_tween()
		tween.set_parallel(true)  # Run animations in parallel
		tween.set_trans(Tween.TRANS_BACK)  # Bouncy/elastic effect
		tween.set_ease(Tween.EASE_OUT)

		# Fade in
		tween.tween_property(active_dialogue, "modulate", Color.WHITE, 0.5)

		# Slide/zoom to final position
		if position_str == "center":
			tween.tween_property(active_dialogue, "scale", Vector2.ONE, 0.5)
		else:
			tween.tween_property(active_dialogue, "position", final_position, 0.5)

		print("[NarrativeDialogueExecutor] ✓ Animation started")

		# Auto-dismiss if duration specified
		var duration = params.get("duration", 0.0)
		if duration > 0:
			await viewport.get_tree().create_timer(duration).timeout
			_dismiss_dialogue()

	func _create_dialogue_panel(params: Dictionary) -> PanelContainer:
		print("[NarrativeDialogueExecutor] _create_dialogue_panel called")
		print("[NarrativeDialogueExecutor] Params: ", params)

		var panel = PanelContainer.new()
		panel.name = "NarrativeDialogue"

		# Position
		var viewport_size = Vector2(720, 1280)
		var position_str = params.get("position", "bottom")
		var panel_height = 180

		match position_str:
			"top":
				panel.position = Vector2(40, 60)
			"center":
				panel.position = Vector2(40, (viewport_size.y - panel_height) / 2)
			_:
				panel.position = Vector2(40, viewport_size.y - panel_height - 60)

		panel.custom_minimum_size = Vector2(viewport_size.x - 80, panel_height)

		# Styling
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

		# Content
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		panel.add_child(vbox)

		# Character name
		var character_name = params.get("character", "")
		if character_name != "":
			var name_label = Label.new()
			name_label.text = character_name
			name_label.add_theme_font_size_override("font_size", 22)
			name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))

			if ThemeManager and ThemeManager.has_method("apply_bangers_font"):
				ThemeManager.apply_bangers_font(name_label, 22)

			vbox.add_child(name_label)

		# Dialogue text
		var text_label = Label.new()
		text_label.text = params.get("text", "")
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.add_theme_font_size_override("font_size", 18)
		text_label.add_theme_color_override("font_color", Color.WHITE)
		text_label.custom_minimum_size = Vector2(0, 60)

		if ThemeManager and ThemeManager.has_method("apply_bangers_font"):
			ThemeManager.apply_bangers_font(text_label, 18)

		vbox.add_child(text_label)

		# Tap hint for manual dismiss
		if params.get("duration", 0.0) == 0:
			var hint_label = Label.new()
			hint_label.text = "Tap to continue..."
			hint_label.add_theme_font_size_override("font_size", 14)
			hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))
			hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			vbox.add_child(hint_label)

			# Add pulsing animation to hint
			hint_label.modulate = Color(1, 1, 1, 0.5)
			var hint_tween = panel.create_tween()
			hint_tween.set_loops()  # Loop forever
			hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.8)
			hint_tween.tween_property(hint_label, "modulate:a", 0.5, 0.8)

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

		var viewport = active_dialogue.get_viewport()
		if viewport:
			var tween = viewport.create_tween()
			tween.set_parallel(true)
			tween.set_trans(Tween.TRANS_BACK)
			tween.set_ease(Tween.EASE_IN)

			# Fade out
			tween.tween_property(active_dialogue, "modulate", Color(1, 1, 1, 0), 0.3)

			# Slide/scale out based on current position
			var current_pos = active_dialogue.position
			var screen_height = viewport.size.y

			if current_pos.y < screen_height * 0.3:
				# Top - slide up
				tween.tween_property(active_dialogue, "position:y", current_pos.y - 80, 0.3)
			elif current_pos.y > screen_height * 0.6:
				# Bottom - slide down
				tween.tween_property(active_dialogue, "position:y", current_pos.y + 80, 0.3)
			else:
				# Center - scale down
				tween.tween_property(active_dialogue, "scale", Vector2(0.8, 0.8), 0.3)

			await tween.finished

		if is_instance_valid(active_dialogue):
			active_dialogue.queue_free()
		active_dialogue = null
		print("[NarrativeDialogueExecutor] Dialogue dismissed")

## Background dimming/brightening executor
class BackgroundDimExecutor extends EffectExecutor:
	func execute(context: Dictionary):
		var params = context.get("params", {})
		var viewport = context.get("viewport", null)
		if not viewport:
			return

		var amount = params.get("amount", 0.5)  # 0.0 = black, 1.0 = no change
		var duration = params.get("duration", 0.5)

		print("[BackgroundDimExecutor] Dimming to %d%% over %ss" % [int(amount * 100), duration])

		# Create or get dim overlay
		var dim_overlay = viewport.get_node_or_null("BackgroundDimOverlay")
		if not dim_overlay:
			dim_overlay = ColorRect.new()
			dim_overlay.name = "BackgroundDimOverlay"
			dim_overlay.color = Color.BLACK
			dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dim_overlay.anchor_left = 0
			dim_overlay.anchor_top = 0
			dim_overlay.anchor_right = 1
			dim_overlay.anchor_bottom = 1
			dim_overlay.z_index = 100  # Above game but below dialogue
			viewport.add_child(dim_overlay)

		# Animate opacity
		var target_alpha = 1.0 - amount  # amount=0.5 means 50% dim = 0.5 alpha
		var tween = viewport.create_tween()
		tween.tween_property(dim_overlay, "color:a", target_alpha, duration)

## Screen flash executor (for dramatic moments)
class ScreenFlashExecutor extends EffectExecutor:
	func execute(context: Dictionary):
		var params = context.get("params", {})
		var viewport = context.get("viewport", null)
		if not viewport:
			return

		var flash_color = params.get("color", "white")
		var duration = params.get("duration", 0.3)

		print("[ScreenFlashExecutor] Flashing %s for %ss" % [flash_color, duration])

		# Create flash overlay
		var flash = ColorRect.new()
		flash.name = "ScreenFlash"
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.anchor_left = 0
		flash.anchor_top = 0
		flash.anchor_right = 1
		flash.anchor_bottom = 1
		flash.z_index = 998  # Just below dialogue

		# Set color
		match flash_color:
			"white":
				flash.color = Color.WHITE
			"gold":
				flash.color = Color(1.0, 0.9, 0.3, 1.0)
			"blue":
				flash.color = Color(0.3, 0.5, 1.0, 1.0)
			"purple":
				flash.color = Color(0.8, 0.3, 1.0, 1.0)
			_:
				flash.color = Color.WHITE

		viewport.add_child(flash)

		# Animate: flash in quickly, fade out slowly
		var tween = viewport.create_tween()
		tween.tween_property(flash, "color:a", 0.0, duration)
		await tween.finished
		flash.queue_free()

## Vignette effect executor (darkens edges of screen)
class VignetteEffector extends EffectExecutor:
	func execute(context: Dictionary):
		var params = context.get("params", {})
		var viewport = context.get("viewport", null)
		if not viewport:
			return

		var intensity = params.get("intensity", 0.5)
		var duration = params.get("duration", 0.5)

		print("[VignetteEffector] Applying vignette at %d%% intensity" % int(intensity * 100))

		# Create or get vignette overlay
		var vignette = viewport.get_node_or_null("VignetteOverlay")
		if not vignette:
			vignette = ColorRect.new()
			vignette.name = "VignetteOverlay"
			vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vignette.anchor_left = 0
			vignette.anchor_top = 0
			vignette.anchor_right = 1
			vignette.anchor_bottom = 1
			vignette.z_index = 101

			# Create radial gradient shader for vignette effect
			var shader_code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float vignette = smoothstep(0.5, 1.5, dist);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * intensity);
}
"""
			var shader = Shader.new()
			shader.code = shader_code
			var shader_material = ShaderMaterial.new()
			shader_material.shader = shader
			shader_material.set_shader_parameter("intensity", 0.0)
			vignette.material = shader_material

			viewport.add_child(vignette)

		# Animate intensity
		if vignette.material and vignette.material is ShaderMaterial:
			var tween = viewport.create_tween()
			tween.tween_method(
				func(value): vignette.material.set_shader_parameter("intensity", value),
				vignette.material.get_shader_parameter("intensity"),
				intensity,
				duration
			)

## Background color overlay executor
class BackgroundTintExecutor extends EffectExecutor:
	func execute(context: Dictionary):
		var params = context.get("params", {})
		var viewport = context.get("viewport", null)
		if not viewport:
			return

		var tint_color = params.get("color", "blue")
		var intensity = params.get("intensity", 0.3)
		var duration = params.get("duration", 0.5)

		print("[BackgroundTintExecutor] Tinting background %s at %d%%" % [tint_color, int(intensity * 100)])

		# Create or get tint overlay
		var tint = viewport.get_node_or_null("BackgroundTintOverlay")
		if not tint:
			tint = ColorRect.new()
			tint.name = "BackgroundTintOverlay"
			tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tint.anchor_left = 0
			tint.anchor_top = 0
			tint.anchor_right = 1
			tint.anchor_bottom = 1
			tint.z_index = 99  # Below dim overlay
			viewport.add_child(tint)

		# Set tint color
		var color: Color
		match tint_color:
			"blue":
				color = Color(0.2, 0.3, 0.6, intensity)
			"gold":
				color = Color(0.9, 0.8, 0.3, intensity)
			"purple":
				color = Color(0.5, 0.2, 0.6, intensity)
			"red":
				color = Color(0.6, 0.2, 0.2, intensity)
			"green":
				color = Color(0.2, 0.6, 0.3, intensity)
			_:
				color = Color(0.2, 0.3, 0.6, intensity)

		# Animate color
		var tween = viewport.create_tween()
		tween.tween_property(tint, "color", color, duration)

## Progressive brightness executor - Brightens with each match
class ProgressiveBrightnessExecutor extends EffectExecutor:
	var match_count: int = 0
	var target_matches: int = 30
	var dim_overlay: ColorRect = null

	func execute(context: Dictionary):
		var params = context.get("params", {})
		var viewport = context.get("viewport", null)
		var event_name = context.get("binding", {}).get("on", "")

		print("[ProgressiveBrightnessExecutor] execute called - event_name: '%s'" % event_name)
		print("[ProgressiveBrightnessExecutor] Context keys: ", context.keys())

		if not viewport:
			print("[ProgressiveBrightnessExecutor] No viewport!")
			return

		# Initialize on level_loaded
		if event_name == "level_loaded":
			print("[ProgressiveBrightnessExecutor] LEVEL_LOADED branch")
			match_count = 0
			target_matches = params.get("target_matches", 30)

			# Create black overlay
			dim_overlay = viewport.get_node_or_null("ProgressiveBrightnessOverlay")
			if dim_overlay:
				dim_overlay.queue_free()

			dim_overlay = ColorRect.new()
			dim_overlay.name = "ProgressiveBrightnessOverlay"
			dim_overlay.color = Color.BLACK
			dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dim_overlay.anchor_left = 0
			dim_overlay.anchor_top = 0
			dim_overlay.anchor_right = 1
			dim_overlay.anchor_bottom = 1
			dim_overlay.z_index = -75  # Above background (-100) but below tile area (-50)
			viewport.add_child(dim_overlay)

			print("[ProgressiveBrightnessExecutor] Starting completely dark - will brighten over %d matches" % target_matches)

		# Brighten on match_cleared
		elif event_name == "match_cleared":
			print("[ProgressiveBrightnessExecutor] MATCH_CLEARED branch")
			if not dim_overlay or not is_instance_valid(dim_overlay):
				print("[ProgressiveBrightnessExecutor] Overlay invalid, trying to find it...")
				dim_overlay = viewport.get_node_or_null("ProgressiveBrightnessOverlay")
				if not dim_overlay:
					print("[ProgressiveBrightnessExecutor] Overlay not found in viewport!")
					return

			if dim_overlay:
				match_count += 1
				var progress = min(float(match_count) / float(target_matches), 1.0)
				var target_alpha = 1.0 - progress  # Start at 1.0 (black), end at 0.0 (transparent)

				print("[ProgressiveBrightnessExecutor] Match %d/%d - Brightness: %d%%" % [match_count, target_matches, int(progress * 100)])

				var tween = viewport.create_tween()
				tween.tween_property(dim_overlay, "color:a", target_alpha, 0.3)

				# Remove overlay when fully bright
				if progress >= 1.0:
					print("[ProgressiveBrightnessExecutor] ✓ Fully illuminated!")
					await tween.finished
					if is_instance_valid(dim_overlay):
						dim_overlay.queue_free()
						dim_overlay = null

## Camera shake executor
class CameraImpulseExecutor extends EffectExecutor:
	func execute(context: Dictionary):
		var params = context.get("params", {})
		var viewport = context.get("viewport", null)
		var strength = params.get("strength", 0.3)
		var duration = params.get("duration", 0.2)

		print("[CameraImpulseExecutor] Applying screen shake: strength=%s, duration=%s" % [strength, duration])

		if not viewport:
			print("[CameraImpulseExecutor] No viewport - skipping shake")
			return

		# Try to find GameBoard node from viewport
		var game_board = null
		for child in viewport.get_children():
			if child.name == "MainGame":
				game_board = child.get_node_or_null("GameBoard")
				break

		if game_board and game_board is Node2D:
			_shake_node(game_board, strength, duration)
		else:
			print("[CameraImpulseExecutor] GameBoard not found - skipping shake")

	func _shake_node(node: Node2D, strength: float, duration: float):
		var original_pos = node.position
		var shake_amount = strength * 15.0

		var tree = node.get_tree()
		if not tree:
			return

		var tween = tree.create_tween()
		var shake_count = int(duration / 0.05)

		for i in range(shake_count):
			var random_offset = Vector2(
				randf_range(-shake_amount, shake_amount),
				randf_range(-shake_amount, shake_amount)
			)
			tween.tween_property(node, "position", original_pos + random_offset, 0.05)

		tween.tween_property(node, "position", original_pos, 0.1)

## Play animation executor (stub)
class PlayAnimationExecutor extends EffectExecutor:
	func execute(context: Dictionary):
		print("[PlayAnimationExecutor] Stub - would play animation")

## State swap executor (stub)
class StateSwapExecutor extends EffectExecutor:
	func execute(context: Dictionary):
		print("[StateSwapExecutor] Stub - would swap state")

## Timeline sequence executor (stub)
class TimelineSequenceExecutor extends EffectExecutor:
	func execute(context: Dictionary):
		print("[TimelineSequenceExecutor] Stub - would execute timeline")

## Spawn particles executor (stub)
class SpawnParticlesExecutor extends EffectExecutor:
	func execute(context: Dictionary):
		print("[SpawnParticlesExecutor] Stub - would spawn particles")

## Shader parameter lerp executor (stub)
class ShaderParamLerpExecutor extends EffectExecutor:
	func execute(context: Dictionary):
		print("[ShaderParamLerpExecutor] Stub - would lerp shader param")


## Screen overlay executor (stub)
class ScreenOverlayExecutor extends EffectExecutor:
	func execute(context: Dictionary):
		print("[ScreenOverlayExecutor] Stub - would show overlay")

# ============================================
# Main EffectResolver Functions
# ============================================

func _ready():
	print("[EffectResolver] Initializing effect resolver...")

	# Get EventBus autoload
	event_bus = get_node_or_null("/root/EventBus")
	if not event_bus:
		push_warning("[EffectResolver] EventBus autoload not found - effects disabled")
		return

	# Cache viewport reference for executors
	cached_viewport = get_tree().root
	if cached_viewport:
		print("[EffectResolver] ✓ Cached viewport reference: ", cached_viewport.name)
	else:
		push_warning("[EffectResolver] Failed to cache viewport reference")

	# Register effect executors (stub implementations)
	_register_executors()

	# Connect to all gameplay events
	_connect_event_signals()

	print("[EffectResolver] Ready - listening for events")

## Register all available effect executors
func _register_executors():
	print("[EffectResolver] Registering effect executors...")

	# Create and register executor instances
	executors["play_animation"] = PlayAnimationExecutor.new()
	executors["state_swap"] = StateSwapExecutor.new()
	executors["timeline_sequence"] = TimelineSequenceExecutor.new()
	executors["spawn_particles"] = SpawnParticlesExecutor.new()
	executors["shader_param_lerp"] = ShaderParamLerpExecutor.new()
	executors["camera_impulse"] = CameraImpulseExecutor.new()
	executors["screen_overlay"] = ScreenOverlayExecutor.new()
	executors["narrative_dialogue"] = NarrativeDialogueExecutor.new()

	# Visual effect executors
	executors["background_dim"] = BackgroundDimExecutor.new()
	executors["screen_flash"] = ScreenFlashExecutor.new()
	executors["vignette"] = VignetteEffector.new()
	executors["background_tint"] = BackgroundTintExecutor.new()
	executors["progressive_brightness"] = ProgressiveBrightnessExecutor.new()

	print("[EffectResolver] Registered %d executors" % executors.size())

## Connect to all EventBus signals
func _connect_event_signals():
	if not event_bus:
		return

	event_bus.level_loaded.connect(_on_event.bind("level_loaded"))
	event_bus.level_start.connect(_on_event.bind("level_start"))
	event_bus.level_complete.connect(_on_event.bind("level_complete"))
	event_bus.level_failed.connect(_on_event.bind("level_failed"))
	event_bus.tile_spawned.connect(_on_event_with_entity.bind("tile_spawned"))
	event_bus.tile_matched.connect(_on_event_with_entity.bind("tile_matched"))
	event_bus.tile_destroyed.connect(_on_event_with_entity.bind("tile_destroyed"))
	event_bus.match_cleared.connect(_on_match_cleared.bind("match_cleared"))
	event_bus.special_tile_activated.connect(_on_event_with_entity.bind("special_tile_activated"))
	event_bus.spreader_tick.connect(_on_event_with_entity.bind("spreader_tick"))
	event_bus.spreader_destroyed.connect(_on_event_with_entity.bind("spreader_destroyed"))
	event_bus.custom_event.connect(_on_custom_event)

	print("[EffectResolver] Connected to EventBus signals")

## Load effect definitions from chapter JSON
func load_effects(chapter_data: Dictionary) -> bool:
	print("[EffectResolver] Loading effects for chapter: ", chapter_data.get("chapter_id", "unknown"))

	# Validate chapter version compatibility
	var required_version = chapter_data.get("requires_engine_version", "1.0.0")
	if not _is_version_compatible(required_version):
		push_warning("[EffectResolver] Chapter requires engine version %s - skipping" % required_version)
		return false

	current_chapter = chapter_data
	active_effects = chapter_data.get("effects", [])

	print("[EffectResolver] Loaded %d effect bindings" % active_effects.size())

	# Debug: Print all loaded effects
	for i in range(active_effects.size()):
		var effect = active_effects[i]
		print("[EffectResolver]   Effect %d: on='%s', effect='%s'" % [i, effect.get("on", ""), effect.get("effect", "")])

	return true

## Load effects from JSON file path (supports both res:// and user:// for DLC)
func load_effects_from_file(path: String) -> bool:
	print("[EffectResolver] Loading effects from: ", path)

	# Check if file exists (works for both res:// and user://)
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		push_warning("[EffectResolver] Effect file not found: %s" % path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[EffectResolver] Failed to open effect file: %s" % path)
		return false

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_warning("[EffectResolver] Failed to parse JSON: %s (Error: %s)" % [path, json.get_error_message()])
		return false

	return load_effects(json.data)

## Load DLC chapter from installed chapter ID
func load_dlc_chapter(chapter_id: String) -> bool:
	print("[EffectResolver] Loading DLC chapter: ", chapter_id)

	# Check if chapter is installed
	if not AssetRegistry.is_chapter_installed(chapter_id):
		push_warning("[EffectResolver] DLC chapter not installed: %s" % chapter_id)
		return false

	# Get chapter info
	var chapter_info = AssetRegistry.get_chapter_info(chapter_id)
	var chapter_path = AssetRegistry.DLC_BASE_DIR + chapter_id + "/manifest.json"

	# Load effects from manifest
	if load_effects_from_file(chapter_path):
		# Also load assets into AssetRegistry
		AssetRegistry.load_chapter_assets(current_chapter)
		print("[EffectResolver] Successfully loaded DLC chapter: ", chapter_id)
		return true

	return false

## Clear active effects
func clear_effects():
	active_effects.clear()
	current_chapter.clear()
	print("[EffectResolver] Cleared active effects")

## Clean up all visual overlays (call when switching levels)
func cleanup_visual_overlays():
	if not cached_viewport:
		return

	print("[EffectResolver] Cleaning up visual overlays...")

	# List of overlay names to remove
	var overlay_names = [
		"BackgroundDimOverlay",
		"BackgroundTintOverlay",
		"VignetteOverlay",
		"ProgressiveBrightnessOverlay",
		"ScreenFlash"
	]

	for overlay_name in overlay_names:
		var overlay = cached_viewport.get_node_or_null(overlay_name)
		if overlay and is_instance_valid(overlay):
			print("[EffectResolver] Removing overlay: %s" % overlay_name)
			overlay.queue_free()

	print("[EffectResolver] ✓ Visual overlays cleaned up")

## Generic event handler (level events)
func _on_event(level_id: String, context: Dictionary, event_name: String):
	print("[EffectResolver] _on_event called: event=%s, level_id=%s" % [event_name, level_id])
	print("[EffectResolver] Context: ", context)

	# Clean up visual overlays from previous level when new level loads
	if event_name == "level_loaded":
		cleanup_visual_overlays()

	_process_event(event_name, "", context)

## Event handler for match_cleared (special case - has match_size instead of entity_id)
func _on_match_cleared(match_size: int, context: Dictionary, event_name: String):
	context["match_size"] = match_size
	_process_event(event_name, "", context)

## Event handler with entity ID
func _on_event_with_entity(entity_id: String, context: Dictionary, event_name: String):
	_process_event(event_name, entity_id, context)

## Custom event handler
func _on_custom_event(event_name: String, entity_id: String, context: Dictionary):
	_process_event(event_name, entity_id, context)

## Process an event and trigger matching effects
func _process_event(event_name: String, entity_id: String, context: Dictionary):
	print("[EffectResolver] Processing event: %s (entity: %s)" % [event_name, entity_id])
	print("[EffectResolver] Active effects count: %d" % active_effects.size())

	# Find matching effect bindings
	var matched_count = 0
	for i in range(active_effects.size()):
		var binding = active_effects[i]
		var binding_event = binding.get("on", "")
		print("[EffectResolver] Checking effect %d: on='%s' vs event='%s'" % [i, binding_event, event_name])

		if binding_event == event_name:
			# Check level condition if specified
			var condition = binding.get("condition", {})
			if condition.has("level"):
				var required_level = condition.get("level")
				# Try to get level from event context first, then fall back to GameManager
				var current_level = context.get("level", 0)
				if current_level == 0 and GameManager:
					current_level = GameManager.level if "level" in GameManager else 0

				print("[EffectResolver] Level condition check: current=%d, required=%d" % [current_level, required_level])
				if current_level != required_level:
					print("[EffectResolver] ✗ Level mismatch - skipping")
					continue
				print("[EffectResolver] ✓ Level condition matched!")

			matched_count += 1
			print("[EffectResolver] ✓ MATCH! Calling _execute_effect for effect %d" % i)
			_execute_effect(binding, entity_id, context)
		else:
			print("[EffectResolver] ✗ No match (skipping)")

	print("[EffectResolver] Matched %d effects for event '%s'" % [matched_count, event_name])

## Execute a single effect binding
func _execute_effect(binding: Dictionary, entity_id: String, context: Dictionary):
	var effect_type = binding.get("effect", "")

	if effect_type.is_empty():
		push_warning("[EffectResolver] Effect binding missing 'effect' type")
		return

	# Get executor for this effect type
	var executor = executors.get(effect_type)
	if not executor:
		push_warning("[EffectResolver] No executor registered for effect: %s" % effect_type)
		return

	# Prepare execution context
	var exec_context = {
		"binding": binding,
		"entity_id": entity_id,
		"event_context": context,
		"anchor": binding.get("anchor", ""),
		"target": binding.get("target", ""),
		"params": binding.get("params", {}),
		"viewport": cached_viewport  # Use cached viewport
	}

	print("[EffectResolver] Executing effect: %s (anchor: %s, viewport: %s)" % [effect_type, exec_context.anchor, "present" if cached_viewport else "NULL"])

	# Execute effect (fail-safe)
	executor.execute(exec_context)

## Check if required version is compatible
func _is_version_compatible(required: String) -> bool:
	# Simple version check - for now accept all versions
	# In production: parse version strings and compare major.minor.patch
	return true
