extends Node2D
class_name RewardRevealSystem

## Reward Reveal System
## Spawns reward icons and animates them flying to HUD positions

signal reward_revealed(reward_type: String, amount: int)
signal all_rewards_revealed
signal waiting_for_claim  # New signal for interactive mode

# Reward icon scenes/textures
var coin_texture: Texture2D = null
var gem_texture: Texture2D = null

# HUD target positions (set from outside)
var coin_target_position: Vector2 = Vector2.ZERO
var gem_target_position: Vector2 = Vector2.ZERO

# Active reward icons being animated
var active_icons: Array = []

# Interactive mode
var claim_button: Button = null
var waiting_for_user_claim: bool = false

func _ready():
	# Try to load reward textures
	_load_reward_textures()

## Load reward icon textures
func _load_reward_textures():
	"""Load or create reward icon textures"""
	# Get current theme
	var theme_name = "modern"  # Default theme
	if ThemeManager:
		theme_name = ThemeManager.current_theme

	# Try to load coin icon from theme folder
	var coin_paths = [
		"res://textures/%s/coin.svg" % theme_name,
		"res://textures/%s/coin.png" % theme_name,
		"res://textures/coin.svg",
		"res://textures/coin.png",
		"res://textures/ui/coin_icon.png"
	]

	coin_texture = null
	for path in coin_paths:
		if ResourceLoader.exists(path):
			coin_texture = load(path)
			print("[RewardRevealSystem] Loaded coin texture from: ", path)
			break

	if not coin_texture:
		print("[RewardRevealSystem] No coin texture found, creating placeholder")
		coin_texture = _create_coin_texture()

	# Try to load gem icon from theme folder
	var gem_paths = [
		"res://textures/%s/gem.svg" % theme_name,
		"res://textures/%s/gem.png" % theme_name,
		"res://textures/gem.svg",
		"res://textures/gem.png",
		"res://textures/ui/gem_icon.png"
	]

	gem_texture = null
	for path in gem_paths:
		if ResourceLoader.exists(path):
			gem_texture = load(path)
			print("[RewardRevealSystem] Loaded gem texture from: ", path)
			break

	if not gem_texture:
		print("[RewardRevealSystem] No gem texture found, creating placeholder")
		gem_texture = _create_gem_texture()

## Set target position for coin rewards
func set_coin_target(pos: Vector2):
	"""Set where coin rewards should fly to (HUD coin counter position)"""
	coin_target_position = pos
	print("[RewardRevealSystem] Coin target set to: ", pos)

## Set target position for gem rewards
func set_gem_target(pos: Vector2):
	"""Set where gem rewards should fly to (HUD gem counter position)"""
	gem_target_position = pos
	print("[RewardRevealSystem] Gem target set to: ", pos)

## Reveal rewards with animation
func reveal_rewards(rewards_data: Dictionary, spawn_position: Vector2, pattern: String = "burst"):
	"""
	Spawn and animate reward icons
	Args:
		rewards_data: {"coins": 100, "gems": 5}
		spawn_position: Where rewards spawn from
		pattern: Animation pattern (burst, arc, cascade, sequential)
	"""
	print("[RewardRevealSystem] Revealing rewards: ", rewards_data, " pattern: ", pattern)

	var coins = rewards_data.get("coins", 0)
	var gems = rewards_data.get("gems", 0)

	match pattern:
		"burst":
			await _reveal_burst(coins, gems, spawn_position)
		"arc":
			await _reveal_arc(coins, gems, spawn_position)
		"cascade":
			await _reveal_cascade(coins, gems, spawn_position)
		"sequential":
			await _reveal_sequential(coins, gems, spawn_position)
		"interactive":
			await _reveal_interactive(coins, gems, spawn_position, rewards_data)
		_:
			await _reveal_burst(coins, gems, spawn_position)

	all_rewards_revealed.emit()
	print("[RewardRevealSystem] All rewards revealed")

## Burst pattern - all rewards explode outward then fly to HUD
func _reveal_burst(coins: int, gems: int, spawn_pos: Vector2):
	"""All rewards burst out then fly to HUD"""
	var total_rewards = (1 if coins > 0 else 0) + (1 if gems > 0 else 0)
	var angle_step = TAU / max(total_rewards, 1)
	var current_angle = 0.0

	# Spawn coins
	if coins > 0:
		var icon = _create_reward_icon("coin", coins, spawn_pos)
		var burst_offset = Vector2(cos(current_angle), sin(current_angle)) * 80
		_animate_reward_burst(icon, spawn_pos, burst_offset, coin_target_position)
		current_angle += angle_step

	# Spawn gems
	if gems > 0:
		await get_tree().create_timer(0.1).timeout
		var icon = _create_reward_icon("gem", gems, spawn_pos)
		var burst_offset = Vector2(cos(current_angle), sin(current_angle)) * 80
		_animate_reward_burst(icon, spawn_pos, burst_offset, gem_target_position)

	# Wait for animations to complete
	await get_tree().create_timer(1.5).timeout

## Arc pattern - rewards fly in nice arc to HUD
func _reveal_arc(coins: int, gems: int, spawn_pos: Vector2):
	"""Rewards fly in arc to HUD"""
	if coins > 0:
		var icon = _create_reward_icon("coin", coins, spawn_pos)
		_animate_reward_arc(icon, spawn_pos, coin_target_position)

	if gems > 0:
		await get_tree().create_timer(0.2).timeout
		var icon = _create_reward_icon("gem", gems, spawn_pos)
		_animate_reward_arc(icon, spawn_pos, gem_target_position)

	await get_tree().create_timer(1.2).timeout

## Cascade pattern - rewards fly one after another
func _reveal_cascade(coins: int, gems: int, spawn_pos: Vector2):
	"""Rewards cascade to HUD"""
	if coins > 0:
		var icon = _create_reward_icon("coin", coins, spawn_pos)
		_animate_reward_arc(icon, spawn_pos, coin_target_position)
		await get_tree().create_timer(0.3).timeout

	if gems > 0:
		var icon = _create_reward_icon("gem", gems, spawn_pos)
		_animate_reward_arc(icon, spawn_pos, gem_target_position)
		await get_tree().create_timer(0.3).timeout

	await get_tree().create_timer(0.9).timeout

## Sequential pattern - one completes before next starts
func _reveal_sequential(coins: int, gems: int, spawn_pos: Vector2):
	"""One reward completes before next"""
	if coins > 0:
		var icon = _create_reward_icon("coin", coins, spawn_pos)
		_animate_reward_arc(icon, spawn_pos, coin_target_position)
		await get_tree().create_timer(1.0).timeout

	if gems > 0:
		var icon = _create_reward_icon("gem", gems, spawn_pos)
		_animate_reward_arc(icon, spawn_pos, gem_target_position)
		await get_tree().create_timer(1.0).timeout

## Interactive pattern - one reward at a time, wait for CLAIM tap
func _reveal_interactive(coins: int, gems: int, spawn_pos: Vector2, rewards_data: Dictionary):
	"""Show one reward, wait for user to claim, then show next"""
	print("[RewardRevealSystem] Interactive reveal mode - user must claim each reward")

	# Build list of all rewards to reveal
	var reward_queue: Array = []

	if coins > 0:
		reward_queue.append({"type": "coin", "amount": coins, "target": coin_target_position})

	if gems > 0:
		reward_queue.append({"type": "gem", "amount": gems, "target": gem_target_position})

	# Include boosters if present
	var boosters = rewards_data.get("boosters", [])
	if typeof(boosters) == TYPE_DICTIONARY:
		# Dictionary format: {"hammer": 2, "bomb": 1}
		for booster_type in boosters.keys():
			var booster_count = boosters[booster_type]
			if booster_count > 0:
				reward_queue.append({"type": "booster", "booster_type": booster_type, "amount": booster_count, "target": Vector2(300, -200)})
	elif typeof(boosters) == TYPE_ARRAY:
		# Array format: [{"type": "hammer", "count": 2}, ...]
		for booster in boosters:
			if typeof(booster) == TYPE_DICTIONARY:
				var booster_type = booster.get("type", "unknown")
				var booster_count = booster.get("count", 1)
				if booster_count > 0:
					reward_queue.append({"type": "booster", "booster_type": booster_type, "amount": booster_count, "target": Vector2(300, -200)})


	# Include gallery images
	var gallery_images = rewards_data.get("gallery_images", [])
	for image_name in gallery_images:
		reward_queue.append({"type": "gallery", "name": image_name, "target": Vector2(400, -200)})

	# Include collection cards
	var cards = rewards_data.get("cards", [])
	for card in cards:
		var card_name = card.get("card_name", card.get("card_id", "Card"))
		reward_queue.append({"type": "card", "name": card_name, "target": Vector2(500, -200)})

	# Reveal each reward one by one
	for reward in reward_queue:
		await _reveal_single_reward_interactive(reward, spawn_pos)

	print("[RewardRevealSystem] All interactive rewards claimed")

## Reveal single reward and wait for user to claim it
func _reveal_single_reward_interactive(reward: Dictionary, spawn_pos: Vector2):
	"""Show one reward, pause, wait for CLAIM button tap"""
	var reward_type = reward.get("type")
	var amount = reward.get("amount", 1)
	var target = reward.get("target", Vector2.ZERO)

	# Create reward icon
	var icon: Node2D
	if reward_type == "booster":
		var booster_type = reward.get("booster_type", "hammer")
		icon = _create_booster_icon(booster_type, amount, spawn_pos)
	elif reward_type == "gallery":
		var image_name = reward.get("name", "Image")
		icon = _create_gallery_icon(image_name, spawn_pos)
	elif reward_type == "card":
		var card_name = reward.get("name", "Card")
		icon = _create_card_icon(card_name, spawn_pos)
	else:
		icon = _create_reward_icon(reward_type, amount, spawn_pos)

	# Animate icon to center of screen (paused position)
	# Convert screen center to local coordinates
	var screen_center = get_viewport_rect().size / 2
	var pause_position_global = screen_center + Vector2(0, -200)  # Higher - 200px above center
	var pause_position = to_local(pause_position_global)

	print("[RewardRevealSystem] Moving reward from spawn to center - Local: ", pause_position, " Global: ", pause_position_global)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(icon, "position", pause_position, 0.5)
	# Scale container: sprite is 0.1, so 2.5x makes final size = 0.1 × 2.5 = 0.25 (32px final)
	tween.tween_property(icon, "scale", Vector2(2.5, 2.5), 0.5)
	await tween.finished

	# Create CLAIM button (use global screen center for button positioning)
	_create_claim_button(pause_position_global)

	# Emit signal so other systems know we're waiting
	waiting_for_claim.emit()
	waiting_for_user_claim = true

	# Wait for user to click CLAIM
	while waiting_for_user_claim:
		await get_tree().create_timer(0.1).timeout

	# Remove CLAIM button
	_remove_claim_button()

	# Since this is a reward screen with no HUD, just fade out the reward in place
	# instead of flying it to a non-existent HUD position
	var collect_tween = create_tween()
	collect_tween.set_ease(Tween.EASE_IN)
	collect_tween.set_trans(Tween.TRANS_CUBIC)

	# Shrink and fade out at current position
	collect_tween.parallel().tween_property(icon, "scale", Vector2(0.2, 0.2), 0.6)
	collect_tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.6)

	# Play claim sound
	if AudioManager:
		AudioManager.play_sfx("combo")

	await collect_tween.finished

	# Cleanup
	_on_reward_arrived(icon)

	# Small delay before next reward
	await get_tree().create_timer(0.3).timeout



## Create CLAIM button
func _create_claim_button(screen_center: Vector2):
	"""Create the CLAIM button for interactive mode"""
	if claim_button:
		return  # Already exists

	claim_button = Button.new()
	claim_button.text = "CLAIM"
	claim_button.custom_minimum_size = Vector2(200, 70)
	claim_button.position = screen_center + Vector2(-100, 200)  # Lower - 200px below center
	claim_button.z_index = 300

	# Style the button
	claim_button.add_theme_font_size_override("font_size", 32)

	# Create StyleBoxFlat for button
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.8, 0.3, 0.9)  # Green
	style_normal.border_width_left = 3
	style_normal.border_width_right = 3
	style_normal.border_width_top = 3
	style_normal.border_width_bottom = 3
	style_normal.border_color = Color(1.0, 1.0, 1.0, 1.0)
	style_normal.corner_radius_top_left = 10
	style_normal.corner_radius_top_right = 10
	style_normal.corner_radius_bottom_left = 10
	style_normal.corner_radius_bottom_right = 10
	claim_button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.3, 1.0, 0.4, 1.0)  # Brighter green
	style_hover.border_width_left = 3
	style_hover.border_width_right = 3
	style_hover.border_width_top = 3
	style_hover.border_width_bottom = 3
	style_hover.border_color = Color(1.0, 1.0, 0.0, 1.0)  # Gold border on hover
	style_hover.corner_radius_top_left = 10
	style_hover.corner_radius_top_right = 10
	style_hover.corner_radius_bottom_left = 10
	style_hover.corner_radius_bottom_right = 10
	claim_button.add_theme_stylebox_override("hover", style_hover)

	# Connect button
	claim_button.pressed.connect(_on_claim_pressed)

	# Add to scene tree (needs to be in a CanvasLayer or Control node)
	var root = get_tree().root
	if root:
		root.add_child(claim_button)

	# Pulse animation - create a looping tween without triggering infinite loop detection
	_start_button_pulse()

	print("[RewardRevealSystem] CLAIM button created")

## Start pulsing animation for CLAIM button
func _start_button_pulse():
	"""Create a self-repeating pulse animation for the claim button"""
	if not claim_button or not is_instance_valid(claim_button):
		return

	var pulse_tween = create_tween()
	pulse_tween.tween_property(claim_button, "scale", Vector2(1.1, 1.1), 0.5)
	pulse_tween.tween_property(claim_button, "scale", Vector2(1.0, 1.0), 0.5)

	# When finished, start again (manual loop to avoid infinite loop detection)
	pulse_tween.finished.connect(_start_button_pulse)


## Remove CLAIM button
func _remove_claim_button():
	"""Remove the CLAIM button and stop pulse animation"""
	if claim_button and is_instance_valid(claim_button):
		# Disconnect any connected signals to stop the pulse loop
		var connections = claim_button.get_signal_connection_list("tree_exiting")
		for connection in connections:
			if connection.get("callable"):
				claim_button.disconnect("tree_exiting", connection.callable)

		claim_button.queue_free()
		claim_button = null

## Handle CLAIM button press
func _on_claim_pressed():
	"""User clicked CLAIM button"""
	print("[RewardRevealSystem] User claimed reward!")
	waiting_for_user_claim = false

## Create booster icon
func _create_booster_icon(booster_type: String, amount: int, pos: Vector2) -> Node2D:
	"""Create a booster reward icon"""
	var icon_container = Node2D.new()
	icon_container.position = pos
	icon_container.z_index = 200
	add_child(icon_container)

	# Create colored circle for booster
	var circle = Sprite2D.new()
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.9, 0.5, 1.0, 1.0))  # Purple for boosters
	var texture = ImageTexture.create_from_image(image)
	circle.texture = texture
	circle.scale = Vector2(0.5, 0.5)
	icon_container.add_child(circle)

	# Icon label
	var icon_label = Label.new()
	var booster_icon = _get_booster_icon(booster_type)
	icon_label.text = booster_icon
	icon_label.position = Vector2(-15, -20)
	icon_label.add_theme_font_size_override("font_size", 40)
	icon_container.add_child(icon_label)

	# Amount label
	var label = Label.new()
	label.text = "+%d" % amount
	label.position = Vector2(-20, 30)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	icon_container.add_child(label)

	active_icons.append(icon_container)

	# Pop in
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(circle, "scale", Vector2.ONE, 0.3)

	return icon_container

## Create gallery icon
func _create_gallery_icon(image_name: String, pos: Vector2) -> Node2D:
	"""Create a gallery image unlock icon"""
	var icon_container = Node2D.new()
	icon_container.position = pos
	icon_container.z_index = 200
	add_child(icon_container)

	# Create colored square for gallery
	var square = Sprite2D.new()
	var image = Image.create(80, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 0.7, 0.4, 1.0))  # Orange for gallery
	var texture = ImageTexture.create_from_image(image)
	square.texture = texture
	square.scale = Vector2(0.5, 0.5)
	icon_container.add_child(square)

	# Gallery icon
	var icon_label = Label.new()
	icon_label.text = "🖼️"
	icon_label.position = Vector2(-15, -25)
	icon_label.add_theme_font_size_override("font_size", 40)
	icon_container.add_child(icon_label)

	# Name label
	var label = Label.new()
	label.text = image_name
	label.position = Vector2(-60, 35)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	icon_container.add_child(label)

	active_icons.append(icon_container)

	# Pop in
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(square, "scale", Vector2.ONE, 0.3)

	return icon_container

## Create card icon
func _create_card_icon(card_name: String, pos: Vector2) -> Node2D:
	"""Create a collection card unlock icon"""
	var icon_container = Node2D.new()
	icon_container.position = pos
	icon_container.z_index = 200
	add_child(icon_container)

	# Create colored square for card
	var square = Sprite2D.new()
	var image = Image.create(80, 80, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.4, 0.9, 0.7, 1.0))  # Teal for cards
	var texture = ImageTexture.create_from_image(image)
	square.texture = texture
	square.scale = Vector2(0.5, 0.5)
	icon_container.add_child(square)

	# Card icon
	var icon_label = Label.new()
	icon_label.text = "🃏"
	icon_label.position = Vector2(-15, -25)
	icon_label.add_theme_font_size_override("font_size", 40)
	icon_container.add_child(icon_label)

	# Name label
	var label = Label.new()
	label.text = card_name
	label.position = Vector2(-60, 35)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color.WHITE)
	icon_container.add_child(label)

	active_icons.append(icon_container)

	# Pop in
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(square, "scale", Vector2.ONE, 0.3)

	return icon_container

func _get_booster_icon(booster_type: String) -> String:
	"""Get emoji icon for booster type"""
	match booster_type:
		"hammer":
			return "🔨"
		"swap":
			return "🔄"
		"shuffle":
			return "🔀"
		"bomb":
			return "💣"
		"rainbow":
			return "🌈"
		"lightning":
			return "⚡"
		_:
			return "🎁"

## Create standard reward icon (coins/gems)
func _create_reward_icon(reward_type: String, amount: int, pos: Vector2) -> Node2D:
	"""Create a reward icon with label"""
	var icon_container = Node2D.new()
	icon_container.position = pos
	icon_container.z_index = 200  # Above everything
	add_child(icon_container)

	# Create sprite with fixed size
	var sprite = Sprite2D.new()
	sprite.texture = coin_texture if reward_type == "coin" else gem_texture

	# Set sprite to fixed size (texture will auto-scale to fit)
	# This gives us consistent sizing regardless of image dimensions
	sprite.centered = true  # Center the texture in the sprite

	# Scale sprite to desired display size
	# Using 128x128 PNG images - very small scale for compact icons
	sprite.scale = Vector2(0.1, 0.1)  # 10% of 128px = 13px starting size

	icon_container.add_child(sprite)

	# Create amount label
	var label = Label.new()
	label.text = "+%d" % amount

	# Font and rendering settings for smooth text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.GOLD)

	# Enable antialiasing for smooth text rendering
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING

	# Add outline for better visibility and smoothness
	label.add_theme_constant_override("outline_size", 3)  # Increased from 2 to 3 for more smoothness
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))  # Solid black outline

	# Add shadow for depth and additional smoothness
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_outline_size", 0)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))  # Semi-transparent shadow

	# Center the text horizontally for better appearance
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.custom_minimum_size = Vector2(60, 20)
	label.position = Vector2(-30, 20)

	# Set texture filter to linear for smoother rendering (especially when scaled)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	icon_container.add_child(label)

	active_icons.append(icon_container)

	# Pop in animation - animate sprite from smaller to target size
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	# Keep sprite small - animate from 0.05 to 0.1 (target size)
	sprite.scale = Vector2(0.05, 0.05)  # Start even smaller
	tween.tween_property(sprite, "scale", Vector2(0.1, 0.1), 0.3)  # Pop to 0.1, not 1.0!

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("match")

	return icon_container

## Create coin texture
func _create_coin_texture() -> Texture2D:
	"""Create circular coin placeholder texture"""
	var size = 64
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Draw circular coin
	var center = Vector2(size / 2, size / 2)
	var radius = size / 2 - 2

	for y in range(size):
		for x in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)

			if dist < radius:
				# Gold gradient - darker at edges
				var brightness = 1.0 - (dist / radius) * 0.3
				image.set_pixel(x, y, Color(1.0 * brightness, 0.84 * brightness, 0.0, 1.0))
			elif dist < radius + 2:
				# Gold border
				image.set_pixel(x, y, Color(0.8, 0.6, 0.0, 1.0))

	return ImageTexture.create_from_image(image)

## Create gem texture
func _create_gem_texture() -> Texture2D:
	"""Create diamond-shaped gem placeholder texture"""
	var size = 64
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Draw diamond shape (gem)
	var center = Vector2(size / 2, size / 2)
	var half_size = size / 2 - 4

	for y in range(size):
		for x in range(size):
			var dx = abs(x - center.x)
			var dy = abs(y - center.y)

			# Diamond shape: |x - cx| + |y - cy| < size
			if dx + dy < half_size:
				# Blue gradient - brighter at center
				var dist_from_center = (dx + dy) / float(half_size)
				var brightness = 1.0 - dist_from_center * 0.5
				image.set_pixel(x, y, Color(0.3 * brightness, 0.7 * brightness, 1.0 * brightness, 1.0))
			elif dx + dy < half_size + 2:
				# Dark blue border
				image.set_pixel(x, y, Color(0.1, 0.3, 0.6, 1.0))

	return ImageTexture.create_from_image(image)

## Animate reward with burst pattern
func _animate_reward_burst(icon: Node2D, start_pos: Vector2, burst_offset: Vector2, target_pos: Vector2):
	"""Burst out then fly to target"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Burst out
	tween.tween_property(icon, "position", start_pos + burst_offset, 0.3)
	tween.tween_interval(0.1)

	# Fly to target with curve
	var control_point = (icon.position + target_pos) / 2 + Vector2(0, -100)
	tween.tween_method(_move_along_curve.bind(icon, icon.position, control_point, target_pos), 0.0, 1.0, 0.8)

	# Shrink on arrival
	tween.parallel().tween_property(icon.get_child(0), "scale", Vector2(0.3, 0.3), 0.8)

	# Cleanup
	tween.tween_callback(_on_reward_arrived.bind(icon))

## Animate reward with arc pattern
func _animate_reward_arc(icon: Node2D, start_pos: Vector2, target_pos: Vector2):
	"""Fly to target in arc"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Create arc control point
	var mid = (start_pos + target_pos) / 2
	var control_point = mid + Vector2(0, -150)  # Arc upward

	tween.tween_method(_move_along_curve.bind(icon, start_pos, control_point, target_pos), 0.0, 1.0, 1.0)

	# Shrink on arrival
	tween.parallel().tween_property(icon.get_child(0), "scale", Vector2(0.3, 0.3), 1.0)

	# Cleanup
	tween.tween_callback(_on_reward_arrived.bind(icon))

## Move along quadratic bezier curve
func _move_along_curve(t: float, icon: Node2D, start: Vector2, control: Vector2, end: Vector2):
	"""Move icon along bezier curve"""
	var q0 = start.lerp(control, t)
	var q1 = control.lerp(end, t)
	icon.position = q0.lerp(q1, t)

## Handle reward arrival at target
func _on_reward_arrived(icon: Node2D):
	"""Cleanup when reward reaches target"""
	if icon and is_instance_valid(icon):
		icon.queue_free()
		active_icons.erase(icon)

## Cleanup
func cleanup():
	"""Clean up all active icons"""
	for icon in active_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	active_icons.clear()

	_remove_claim_button()
