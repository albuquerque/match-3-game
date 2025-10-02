extends Area2D
class_name Tile

signal tile_clicked(tile)

var tile_type: int = 0
var grid_position: Vector2 = Vector2.ZERO
var is_selected: bool = false
var is_falling: bool = false
var tile_scale: float = 1.0  # Dynamic scale factor

@onready var sprite: Sprite2D = $Sprite2D
@onready var selection_ring: Sprite2D = $SelectionRing
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

const BASE_TILE_SIZE = 64
const COLORS = [
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW,
	Color.PURPLE,
	Color.ORANGE
]

func _ready():
	# Enable input processing
	set_process_input(true)

	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	# Add null check for selection_ring
	if selection_ring:
		selection_ring.visible = false
	# Defer update_visual to ensure all @onready nodes are ready
	call_deferred("update_visual")

func setup(type: int, pos: Vector2, scale_factor: float = 1.0):
	tile_type = type
	grid_position = pos
	tile_scale = scale_factor

	# Update collision shape size based on scale
	if collision_shape and collision_shape.shape is CircleShape2D:
		var circle_shape = collision_shape.shape as CircleShape2D
		circle_shape.radius = (BASE_TILE_SIZE / 2) * tile_scale

	update_visual()

func update_visual():
	# Add null check for sprite to prevent nil assignment error
	if not sprite:
		# If sprite isn't ready yet, defer the visual update
		call_deferred("update_visual")
		return

	if tile_type <= 0 or tile_type > COLORS.size():
		visible = false
		return

	visible = true
	sprite.modulate = COLORS[tile_type - 1]

	# Create a simple colored circle
	var texture = ImageTexture.new()
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)

	# Draw a circle
	for x in range(64):
		for y in range(64):
			var center = Vector2(32, 32)
			var distance = Vector2(x, y).distance_to(center)
			if distance <= 28:
				image.set_pixel(x, y, Color.WHITE)
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)

	texture.set_image(image)
	sprite.texture = texture

	# Create selection ring texture if it doesn't exist
	if selection_ring and not selection_ring.texture:
		var ring_texture = create_ring_texture()
		selection_ring.texture = ring_texture

func create_ring_texture() -> ImageTexture:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	var center = Vector2(32, 32)
	var outer_radius = 30
	var inner_radius = 25

	# Draw ring
	for x in range(64):
		for y in range(64):
			var distance = Vector2(x, y).distance_to(center)
			if distance >= inner_radius and distance <= outer_radius:
				image.set_pixel(x, y, Color.YELLOW)

	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func set_selected(selected: bool):
	# Add null check for selection_ring
	if not selection_ring:
		return

	is_selected = selected
	selection_ring.visible = selected

	if selected:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(selection_ring, "scale", Vector2(1.2, 1.2), 0.5)
		tween.tween_property(selection_ring, "scale", Vector2(1.0, 1.0), 0.5)
	else:
		var tweens = get_tree().get_nodes_in_group("tile_tweens")
		for tween in tweens:
			if tween.is_valid():
				tween.kill()

func _input(event):
	# Global input handling as backup
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos = to_local(get_global_mouse_position())
		if get_rect().has_point(local_pos):
			print("Global click detected on tile at ", grid_position)
			handle_click()

func _on_input_event(viewport, event, shape_idx):
	print("Input event detected: ", event.get_class(), " on tile at ", grid_position)
	if event is InputEventScreenTouch and event.pressed:
		print("Touch detected on tile at ", grid_position)
		handle_click()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Mouse click detected on tile at ", grid_position)
		handle_click()

func _on_mouse_entered():
	print("Mouse entered tile at ", grid_position)
	if not is_falling and not GameManager.processing_moves and sprite:
		var tween = create_tween()
		# Scale from 1.25 to 1.375 (1.25 * 1.1) for hover effect
		tween.tween_property(sprite, "scale", Vector2(1.375, 1.375), 0.1)
		# Add visual feedback
		sprite.modulate = sprite.modulate.lightened(0.3)

func _on_mouse_exited():
	print("Mouse exited tile at ", grid_position)
	if not is_falling and sprite:
		var tween = create_tween()
		# Return to original scale of 1.25
		tween.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.1)
		# Restore original color
		if tile_type > 0 and tile_type <= COLORS.size():
			sprite.modulate = COLORS[tile_type - 1]

func handle_click():
	print("Handle click called on tile at ", grid_position, " type: ", tile_type)

	# Add immediate visual feedback
	show_click_feedback()

	if is_falling or GameManager.processing_moves:
		print("Click blocked - falling: ", is_falling, " processing: ", GameManager.processing_moves)
		return

	print("Emitting tile_clicked signal for tile at ", grid_position)
	emit_signal("tile_clicked", self)

func show_click_feedback():
	# Immediate visual feedback for clicks
	if sprite:
		var original_scale = sprite.scale
		var tween = create_tween()
		tween.tween_property(sprite, "scale", original_scale * 0.9, 0.05)
		tween.tween_property(sprite, "scale", original_scale, 0.05)

		# Flash effect
		var original_modulate = sprite.modulate
		var flash_tween = create_tween()
		flash_tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		flash_tween.tween_property(sprite, "modulate", original_modulate, 0.1)

func get_rect() -> Rect2:
	# Get the clickable area of the tile
	return Rect2(-32, -32, 64, 64)

func animate_to_position(target_pos: Vector2, duration: float = 0.3) -> Tween:
	is_falling = true
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.tween_callback(func(): is_falling = false)
	return tween

func animate_swap_to(target_pos: Vector2, duration: float = 0.2) -> Tween:
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	return tween

func animate_destroy() -> Tween:
	var tween = create_tween()
	if sprite:
		tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.3)
		tween.parallel().tween_property(sprite, "rotation", PI * 2, 0.3)
	tween.parallel().tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(queue_free)
	return tween

func animate_spawn() -> Tween:
	if sprite:
		sprite.scale = Vector2.ZERO
	modulate = Color.WHITE

	var tween = create_tween()
	if sprite:
		# Use the proper target scale (1.25, 1.25) to match existing tiles from the scene
		tween.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.4)
	tween.tween_callback(func(): is_falling = false)
	return tween

func animate_match_highlight() -> Tween:
	if not sprite:
		return create_tween()  # Return empty tween if sprite not ready

	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", COLORS[tile_type - 1], 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", COLORS[tile_type - 1], 0.1)
	return tween
