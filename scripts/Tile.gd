extends Area2D
class_name Tile

signal tile_clicked(tile)
signal tile_swiped(tile, direction)
signal collectible_collected(tile, collectible_type)
signal unmovable_destroyed(tile)

var tile_type: int = 0
var grid_position: Vector2 = Vector2.ZERO
var is_selected: bool = false
var is_falling: bool = false
var tile_scale: float = 1.0  # Dynamic scale factor

# New mechanics properties (do NOT create new classes; keep on Tile)
var is_collectible: bool = false
var collectible_type: String = ""
var collectible_collected_flag: bool = false

var is_unmovable: bool = false
var unmovable_hits: int = 0  # number of hits required to destroy
var unmovable_max_hits: int = 0  # saved for visuals
var unmovable_type: String = ""  # Type of unmovable (snow, glass, wood, etc.)

# Unmovable Hard (multi-hit) properties
var is_unmovable_hard: bool = false
var hard_hits: int = 0
var hard_max_hits: int = 0
var hard_type: String = ""               # e.g., rock, metal, ice
var hard_textures: Array = []             # optional list of texture names/paths for each hit state (index 0 = full health)
var hard_reveals_on_destroy: Dictionary = {}  # e.g., {"type":"collectible","value":"coin"} or {"type":"tile","value":3}

# Spreader tile properties
var is_spreader: bool = false
var spreader_grace_moves: int = 0        # Remaining grace moves before spreading begins
var spreader_type: String = "virus"      # Type of spreader (for future expansion)
var spreader_textures: Array = []        # Optional list of texture paths for spreader visuals

# Rope/chain anchor (optional) - if set, this tile will move toward anchor when released
var rope_anchor: Vector2 = Vector2(-1, -1)
var rope_attached: bool = false

# Swipe detection variables
var swipe_start_pos: Vector2 = Vector2.ZERO
var is_swiping: bool = false
var swipe_threshold: float = 30.0  # Minimum distance to register as swipe
var touch_started_on_this_tile: bool = false

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

# Helper: robustly resolve the active theme name from ThemeManager (supports multiple method names)
func _resolve_theme_name() -> String:
	var tm = get_node_or_null("/root/ThemeManager")
	if not tm:
		return "legacy"
	# try several possible method/property names used across versions
	var candidates = ["get_theme_name", "get_current_theme_name", "get_current_theme", "current_theme", "theme_name"]
	# Try calling with call method safely
	for m in candidates:
		if tm.has_method(m):
			var res = tm.call(m)
			if typeof(res) == TYPE_STRING and res != "":
				return res
	# Try as property
	for p in candidates:
		if tm.has_variable(p):
			var v = tm.get(p)
			if typeof(v) == TYPE_STRING and v != "":
				return v
	# Fallback
	return "legacy"

# Helper: try candidate paths and return first existing path or empty string
func _find_existing_texture(candidates: Array) -> String:
	for c in candidates:
		if ResourceLoader.exists(c):
			return c
	# nothing found
	return ""

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

func setup(type: int, pos: Vector2, scale_factor: float = 1.0, skip_visual: bool = false):
	tile_type = type
	grid_position = pos
	tile_scale = scale_factor

	# Update collision shape size based on scale
	if collision_shape:
		if collision_shape.shape is CircleShape2D:
			# Replace with RectangleShape2D for better match with rounded corners
			var rect_shape = RectangleShape2D.new()
			rect_shape.size = Vector2(BASE_TILE_SIZE * tile_scale, BASE_TILE_SIZE * tile_scale)
			collision_shape.shape = rect_shape
		elif collision_shape.shape is RectangleShape2D:
			var rect_shape = collision_shape.shape as RectangleShape2D
			rect_shape.size = Vector2(BASE_TILE_SIZE * tile_scale, BASE_TILE_SIZE * tile_scale)


	# Call update_visual to set the correct sprite scale based on texture size unless skipped
	if not skip_visual:
		update_visual()

func update_visual():
	if is_queued_for_deletion():
		return

	# If sprite is not ready yet (called before _ready), wait one frame
	if not sprite:
		call_deferred("update_visual")
		return

	if tile_type <= 0 and not is_collectible and not is_unmovable and not is_unmovable_hard:
		visible = false
		return

	visible = true

	# Get texture path from ThemeManager (autoload singleton)
	var texture_path = "res://textures/tile_%d.png" % tile_type
	var theme_manager = get_node_or_null("/root/ThemeManager")
	var theme_name = _resolve_theme_name()
	if theme_manager:
		# keep debug friendly
		print("[Tile] Resolved theme_name:", theme_name)
		# allow ThemeManager to override a tile texture path if available
		if theme_manager.has_method("get_tile_texture_path"):
			# Use try/call to avoid crashing if method signature differs
			var ok_path = theme_manager.call("get_tile_texture_path", tile_type) if theme_manager.has_method("get_tile_texture_path") else null
			if ok_path and ok_path != "":
				texture_path = ok_path

	# If this tile is marked as a collectible, prefer collectible texture
	if is_collectible:
		# Prefer resolved theme_name
		# Try SVG then PNG in theme folder, then root
		var coll_candidates = [
			"res://textures/%s/%s.svg" % [theme_name, collectible_type],
			"res://textures/%s/%s.png" % [theme_name, collectible_type],
			"res://textures/%s.svg" % collectible_type,
			"res://textures/%s.png" % collectible_type
		]
		var found_coll = _find_existing_texture(coll_candidates)
		if found_coll != "":
			texture_path = found_coll
			print("[Tile] Using collectible texture: ", texture_path)

	# If this tile is marked as a spreader, prefer spreader texture
	if is_spreader:
		var found_spreader_texture = false
		# If explicit spreader_textures provided, use them (allows per-level custom textures)
		if spreader_textures and spreader_textures.size() > 0:
			# For now, use first texture (could later vary by grace state)
			var st = spreader_textures[0]
			if typeof(st) == TYPE_STRING:
				if st.begins_with("res://"):
					# Absolute path
					if ResourceLoader.exists(st):
						texture_path = st
						found_spreader_texture = true
				else:
					# Theme relative - try multiple candidates
					var candidates = []
					# If filename already has extension, use as-is
					if st.ends_with(".svg") or st.ends_with(".png"):
						candidates.append("res://textures/%s/%s" % [theme_name, st])
						candidates.append("res://textures/%s" % st)
					else:
						# No extension, try both svg and png
						candidates.append("res://textures/%s/%s.svg" % [theme_name, st])
						candidates.append("res://textures/%s/%s.png" % [theme_name, st])
						candidates.append("res://textures/%s.svg" % st)
						candidates.append("res://textures/%s.png" % st)

					var cand_found = _find_existing_texture(candidates)
					if cand_found != "":
						texture_path = cand_found
						found_spreader_texture = true
						print("[Tile] Using custom spreader texture: ", texture_path)

		# If no custom textures or not found, try convention-based texture names
		if not found_spreader_texture:
			var spreader_candidates = [
				"res://textures/%s/spreader_%s.svg" % [theme_name, spreader_type],
				"res://textures/%s/spreader_%s.png" % [theme_name, spreader_type],
				"res://textures/spreader_%s.svg" % spreader_type,
				"res://textures/spreader_%s.png" % spreader_type
			]
			var found_spreader = _find_existing_texture(spreader_candidates)
			if found_spreader != "":
				texture_path = found_spreader
				found_spreader_texture = true
				print("[Tile] Using spreader texture: ", texture_path)

	# For hard unmovable tiles, choose correct texture based on remaining hits
	if is_unmovable_hard and hard_type != "":
		var found_hard_texture = false
		# If explicit hard_textures provided, use them (index by remaining hits)
		if hard_textures and hard_textures.size() > 0:
			var idx = clamp(hard_max_hits - hard_hits, 0, hard_textures.size() - 1)
			var ht = hard_textures[idx]
			if typeof(ht) == TYPE_STRING:
				if ht.begins_with("res://"):
					if ResourceLoader.exists(ht):
						texture_path = ht
						found_hard_texture = true
				else:
					# theme relative
					var cand = "res://textures/%s/%s" % [theme_name, ht]
					var cand_found = _find_existing_texture([cand, cand + ".svg", cand + ".png"])
					if cand_found != "":
						texture_path = cand_found
						found_hard_texture = true

		# otherwise try convention-based texture names: unmovable_hard_{type}_{stage}
		if not found_hard_texture:
			# Stage ordering: prefer current damage stage then others
			var preferred_stage = max(0, hard_max_hits - hard_hits)
			var tried = []
			# try preferred stage first, then remaining stages
			tried.append(preferred_stage)
			for i in range(hard_max_hits):
				if i != preferred_stage:
					tried.append(i)
			# Also try stage indices that might be used in assets (0..max-1)
			var candidates = []
			for s in tried:
				candidates.append("res://textures/%s/unmovable_hard_%s_%d.svg" % [theme_name, hard_type, s])
				candidates.append("res://textures/%s/unmovable_hard_%s_%d.png" % [theme_name, hard_type, s])
				candidates.append("res://textures/unmovable_hard_%s_%d.svg" % [hard_type, s])
				candidates.append("res://textures/unmovable_hard_%s_%d.png" % [hard_type, s])
			# Also try without explicit stage (single-texture variants)
			candidates.append("res://textures/%s/unmovable_hard_%s.svg" % [theme_name, hard_type])
			candidates.append("res://textures/%s/unmovable_hard_%s.png" % [theme_name, hard_type])
			candidates.append("res://textures/unmovable_hard_%s.svg" % hard_type)
			candidates.append("res://textures/unmovable_hard_%s.png" % hard_type)
			var found = _find_existing_texture(candidates)
			if found != "":
				texture_path = found
				found_hard_texture = true

		# FALLBACK: try unmovable_soft_{type} in theme or root if hard texture isn't available
		if not found_hard_texture:
			var soft_candidates = [
				"res://textures/%s/unmovable_soft_%s.svg" % [theme_name, hard_type],
				"res://textures/%s/unmovable_soft_%s.png" % [theme_name, hard_type],
				"res://textures/unmovable_soft_%s.svg" % hard_type,
				"res://textures/unmovable_soft_%s.png" % hard_type
			]
			var soft_found = _find_existing_texture(soft_candidates)
			if soft_found != "":
				texture_path = soft_found
				found_hard_texture = true

		# Debug log showing final chosen texture path for hard tile
		if found_hard_texture:
			print("[Tile] Hard texture chosen:", texture_path)
		else:
			print("[Tile] No hard-specific texture found for type=", hard_type, " tried theme=", theme_name)

	# For unmovable tiles (soft), load texture based on type
	if is_unmovable and unmovable_type != "":
		var um_candidates = [
			"res://textures/%s/unmovable_soft_%s.svg" % [theme_name, unmovable_type],
			"res://textures/%s/unmovable_soft_%s.png" % [theme_name, unmovable_type],
			"res://textures/unmovable_soft_%s.svg" % unmovable_type,
			"res://textures/unmovable_soft_%s.png" % unmovable_type
		]
		var um_found = _find_existing_texture(um_candidates)
		if um_found != "":
			texture_path = um_found
			print("[Tile] Using unmovable texture: ", texture_path)
	elif is_unmovable and unmovable_max_hits > 0:
		# Legacy fallback for old unmovable system
		var um_path = "res://textures/unmovable_hits_%d.png" % unmovable_hits
		if ResourceLoader.exists(um_path):
			texture_path = um_path

	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		sprite.texture = texture
		sprite.centered = true
		sprite.region_enabled = false
		sprite.scale = Vector2(64.0 / float(texture.get_width()), 64.0 / float(texture.get_height())) * tile_scale
		sprite.modulate = Color.WHITE
		print("[Tile.update_visual] Applied scale to sprite:", sprite.scale, "Texture size:", texture.get_width(), texture.get_height())

		# Apply rounded corner shader
		apply_rounded_corner_shader()
	else:
		# Fallback to solid color or procedural texture for missing textures
		if tile_type > COLORS.size():
			sprite.modulate = Color.WHITE
		else:
			sprite.modulate = COLORS[tile_type - 1]

		var texture = ImageTexture.new()
		var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
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
		sprite.centered = true
		sprite.region_enabled = false
		sprite.scale = Vector2(64.0 / float(texture.get_width()), 64.0 / float(texture.get_height())) * tile_scale
		print("[Tile.update_visual] Fallback scale:", sprite.scale, "Texture size:", texture.get_width(), texture.get_height())

		# Apply rounded corner shader
		apply_rounded_corner_shader()

	# Visual hint for selection ring
	if selection_ring and not selection_ring.texture:
		var ring_texture = create_ring_texture()
		selection_ring.texture = ring_texture
		selection_ring.scale = Vector2(tile_scale, tile_scale)

	# Additional visual indicators for collectible or unmovable
	if is_spreader:
		# Green tint for spreader tiles, brighter when grace period expired
		if spreader_grace_moves <= 0:
			# Active spreader - bright green glow
			sprite.modulate = Color(0.5, 1.0, 0.5)  # Bright green
		else:
			# Grace period - yellowish tint
			sprite.modulate = Color(0.9, 1.0, 0.7)  # Yellow-green
	elif is_collectible:
		# Slight tint to indicate collectible
		sprite.modulate = Color(1, 0.95, 0.7)
	elif is_unmovable_hard:
		# Show a tougher visual tint based on remaining hits
		var strength_hard = clamp(float(hard_hits) / max(float(hard_max_hits), 1.0), 0.0, 1.0)
		sprite.modulate = Color(0.9 - 0.3 * (1.0 - strength_hard), 0.9 - 0.3 * (1.0 - strength_hard), 1.0 - 0.4 * (1.0 - strength_hard))
		# Ensure any legacy label is removed to avoid visual clutter
		var old_label = get_node_or_null("HardHitsLabel")
		if old_label:
			old_label.queue_free()
	elif is_unmovable:
		# Show a greyed/tough look depending on remaining hits
		var strength_soft = clamp(float(unmovable_hits) / max(float(unmovable_max_hits), 1.0), 0.0, 1.0)
		sprite.modulate = Color(0.9 - 0.3 * (1.0 - strength_soft), 0.9 - 0.3 * (1.0 - strength_soft), 1.0 - 0.4 * (1.0 - strength_soft))
		# Remove any hard hits label if present
		var old_label2 = get_node_or_null("HardHitsLabel")
		if old_label2:
			old_label2.queue_free()

# New helper methods for mechanics (no new classes)
func configure_collectible(c_type: String) -> void:
	is_collectible = true
	collectible_type = c_type
	collectible_collected_flag = false
	# update visual immediately
	update_visual()

func configure_unmovable(hits: int, u_type: String = "snow") -> void:
	is_unmovable = true
	unmovable_hits = hits
	unmovable_max_hits = hits
	unmovable_type = u_type
	print("[Tile] configure_unmovable called for pos=", grid_position, " type=", u_type, " hits=", hits)
	# Make sure sprite is visible and update visual immediately
	if sprite:
		sprite.visible = true
	update_visual()

# New configuration function for hard unmovable tiles
func configure_unmovable_hard(hits: int, h_type: String = "rock", textures: Array = [], reveals: Dictionary = {}) -> void:
	is_unmovable_hard = true
	hard_hits = hits
	hard_max_hits = hits
	hard_type = h_type
	hard_textures = textures
	hard_reveals_on_destroy = reveals
	print("[Tile] configure_unmovable_hard called for pos=", grid_position, " type=", h_type, " hits=", hits)
	if sprite:
		sprite.visible = true
	update_visual()

# Configuration function for spreader tiles
func configure_spreader(grace_moves: int = 2, s_type: String = "virus", textures: Array = []) -> void:
	is_spreader = true
	spreader_grace_moves = grace_moves
	spreader_type = s_type
	spreader_textures = textures
	print("[Tile] configure_spreader called for pos=", grid_position, " type=", s_type, " grace=", grace_moves, " textures=", textures.size())
	if sprite:
		sprite.visible = true
	update_visual()

func take_hit(amount: int = 1) -> bool:
	"""Apply a hit to unmovable tile. Returns true if destroyed."""
	print("[Tile] take_hit called at ", grid_position, " amount=", amount, " is_unmovable_hard=", is_unmovable_hard, " hard_hits=", hard_hits, " is_unmovable=", is_unmovable, " unmovable_hits=", unmovable_hits)
	# Handle hard unmovable first
	if is_unmovable_hard:
		hard_hits = max(0, hard_hits - amount)
		print("[Tile] take_hit after decrement hard_hits=", hard_hits)
		update_visual()
		if hard_hits <= 0:
			# transform or destroy
			is_unmovable_hard = false
			hard_max_hits = 0
			_create_unmovable_destruction_particles()
			# If reveals defined, transform tile accordingly
			if hard_reveals_on_destroy and hard_reveals_on_destroy.has("type"):
				_transform_on_hard_destroy(hard_reveals_on_destroy)
			else:
				# fallback: emit destroyed signal
				emit_signal("unmovable_destroyed", self)
			print("[Tile] take_hit returning true (hard destroyed) at ", grid_position)
			return true
		print("[Tile] take_hit returning false (hard still alive) at ", grid_position)
		return false

	# existing soft unmovable behavior
	if not is_unmovable:
		print("[Tile] take_hit: not unmovable, returning false at ", grid_position)
		return false
	unmovable_hits = max(0, unmovable_hits - amount)
	update_visual()
	if unmovable_hits <= 0:
		is_unmovable = false
		unmovable_max_hits = 0
		# Create smoke/dust effect when destroyed
		_create_unmovable_destruction_particles()
		emit_signal("unmovable_destroyed", self)
		print("[Tile] take_hit returning true (soft destroyed) at ", grid_position)
		return true
	print("[Tile] take_hit returning false (soft still alive) at ", grid_position)
	return false

# New helper to transform tile when hard unmovable is destroyed
func _transform_on_hard_destroy(reveal: Dictionary) -> void:
	# reveal example: {"type":"collectible","value":"coin"} or {"type":"tile","value":3}
	if not reveal.has("type"):
		return

	var rtype = reveal["type"]

	var gm = get_node_or_null("/root/GameManager")
	var gx = int(grid_position.x)
	var gy = int(grid_position.y)

	if rtype == "collectible":
		var collectible_value = reveal.get("value", "coin")
		configure_collectible(collectible_value)

		# update model so gravity/refill won't overwrite the revealed collectible
		if gm and gm.grid.size() > gx and gm.grid[gx].size() > gy:
			gm.grid[gx][gy] = gm.COLLECTIBLE

		# play reveal animation
		_create_collection_particles()

		# Ensure the GameBoard tiles array contains this tile instance so it isn't replaced
		var board = get_node_or_null("/root/MainGame/GameBoard")
		if board and board.tiles and gx < board.tiles.size():
			if gy >= board.tiles[gx].size():
				# Grow inner array if needed
				while board.tiles[gx].size() <= gy:
					board.tiles[gx].append(null)
			board.tiles[gx][gy] = self

			# Snap visual position to grid
			if board.has_method("grid_to_world_position"):
				position = board.grid_to_world_position(Vector2(gx, gy))

	elif rtype == "tile":
		var new_type = reveal.get("value", 1)
		update_type(int(new_type))

		# update model to the revealed tile type to keep consistency
		if gm and gm.grid.size() > gx and gm.grid[gx].size() > gy:
			gm.grid[gx][gy] = int(new_type)
		# Ensure GameBoard tiles array contains this tile instance
		var board2 = get_node_or_null("/root/MainGame/GameBoard")
		if board2 and board2.tiles and gx < board2.tiles.size():
			if gy >= board2.tiles[gx].size():
				while board2.tiles[gx].size() <= gy:
					board2.tiles[gx].append(null)
			board2.tiles[gx][gy] = self
		if board2 and board2.has_method("grid_to_world_position"):
			position = board2.grid_to_world_position(Vector2(gx, gy))
		print("[Tile] transform to tile complete at ", grid_position)
	elif rtype == "none":
		# just mark visual but do not call report_unmovable_destroyed here
		print("[Tile] transform type 'none' encountered - emitting unmovable_destroyed signal")
		emit_signal("unmovable_destroyed", self)

func _create_collection_particles():
	# small visual feedback for collectible collection
	var p = CPUParticles2D.new()
	p.amount = 12
	p.one_shot = true
	p.lifetime = 0.8
	p.speed_scale = 1.4
	p.gravity = Vector2(0, 200)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.color = Color(1, 0.9, 0.5)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func _create_unmovable_destruction_particles():
	"""Create smoke/dust particle effect when unmovable tile is destroyed"""
	print("[Tile] _create_unmovable_destruction_particles called for ", unmovable_type, " at ", grid_position)

	if not is_inside_tree():
		print("[Tile] Not in tree, returning")
		return

	# Get the parent node to add particles to (use GameBoard or scene root)
	var particle_parent = get_parent()
	if not particle_parent:
		print("[Tile] No parent found, cannot create particles")
		return

	print("[Tile] Creating smoke particles...")

	# Create smoke/dust cloud effect
	var smoke = CPUParticles2D.new()
	smoke.name = "UnmovableSmokeParticles"
	smoke.position = global_position  # Use global position so it stays when tile is removed
	smoke.emitting = true
	smoke.one_shot = true
	smoke.explosiveness = 0.7
	smoke.amount = 40  # Dense smoke cloud
	smoke.lifetime = 1.2  # Linger a bit
	smoke.speed_scale = 1.5
	smoke.z_index = 100  # Make sure it's visible on top

	# Smoke properties - billowing cloud effect
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 20.0  # Wider emission area
	smoke.direction = Vector2(0, -1)  # Upward drift
	smoke.spread = 45  # Less spread for more upward motion
	smoke.gravity = Vector2(0, -20)  # Gentle upward float
	smoke.initial_velocity_min = 15.0  # Much slower, more billowy
	smoke.initial_velocity_max = 40.0
	smoke.angular_velocity_min = -30  # Slow gentle rotation
	smoke.angular_velocity_max = 30
	smoke.scale_amount_min = 8.0  # Much larger smoke particles
	smoke.scale_amount_max = 15.0  # Huge billowing clouds
	smoke.damping_min = 1.0  # Slow down quickly
	smoke.damping_max = 2.5

	# Smoke color - opaque clouds based on unmovable type
	var smoke_color = Color(0.7, 0.7, 0.7, 1.0)  # Default grey, fully opaque
	if unmovable_type == "snow":
		smoke_color = Color(0.9, 0.9, 0.95, 1.0)  # White/very light grey
	elif unmovable_type == "glass":
		smoke_color = Color(0.8, 0.85, 0.9, 1.0)  # Very light blue-grey
	elif unmovable_type == "wood":
		smoke_color = Color(0.5, 0.45, 0.4, 1.0)  # Brown/tan dust

	# Gradient for smoke fade - much softer, longer fade
	var gradient = Gradient.new()
	gradient.add_point(0.0, smoke_color)  # Start fully opaque
	gradient.add_point(0.3, Color(smoke_color.r, smoke_color.g, smoke_color.b, 0.8))
	gradient.add_point(0.6, Color(smoke_color.r, smoke_color.g, smoke_color.b, 0.4))
	gradient.add_point(1.0, Color(smoke_color.r, smoke_color.g, smoke_color.b, 0))  # Fade to transparent
	smoke.color_ramp = gradient

	# Scale curve - billowing smoke effect
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 0.2))  # Start very small
	scale_curve.add_point(Vector2(0.15, 0.6))  # Quick initial expansion
	scale_curve.add_point(Vector2(0.4, 1.0))  # Continue expanding
	scale_curve.add_point(Vector2(0.7, 1.1))  # Reach maximum size
	scale_curve.add_point(Vector2(1, 0.9))  # Slight shrink as it fades
	smoke.scale_amount_curve = scale_curve

	particle_parent.add_child(smoke)
	print("[Tile] Smoke particles added to parent")

	# Add some debris/chunks for extra effect
	var debris = CPUParticles2D.new()
	debris.name = "UnmovableDebrisParticles"
	debris.position = global_position  # Use global position
	debris.emitting = true
	debris.one_shot = true
	debris.explosiveness = 0.8  # Less explosive, more dusty
	debris.amount = 15  # Fewer particles
	debris.lifetime = 1.0  # Longer lifetime
	debris.speed_scale = 1.5  # Slower
	debris.z_index = 100  # Make sure it's visible on top

	debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	debris.emission_sphere_radius = 12.0
	debris.direction = Vector2(0, 1)  # Downward bias
	debris.spread = 120  # Wide spread
	debris.gravity = Vector2(0, 250)  # Less heavy
	debris.initial_velocity_min = 50.0  # Slower burst
	debris.initial_velocity_max = 120.0
	debris.angular_velocity_min = -360  # Moderate rotation
	debris.angular_velocity_max = 360
	debris.scale_amount_min = 1.5  # Larger chunks
	debris.scale_amount_max = 4.0  # Bigger debris

	# Debris color - muted, dusty chunks (not bright/sparkly)
	var debris_color = Color(0.6, 0.6, 0.6, 0.9)  # Muted grey
	if unmovable_type == "snow":
		debris_color = Color(0.8, 0.8, 0.85, 0.9)  # Light grey/white chunks
	elif unmovable_type == "glass":
		debris_color = Color(0.7, 0.75, 0.8, 0.8)  # Pale blue-grey
	elif unmovable_type == "wood":
		debris_color = Color(0.45, 0.35, 0.25, 0.9)  # Dark brown chunks

	var debris_gradient = Gradient.new()
	debris_gradient.add_point(0.0, debris_color)
	debris_gradient.add_point(0.4, Color(debris_color.r * 0.9, debris_color.g * 0.9, debris_color.b * 0.9, debris_color.a))
	debris_gradient.add_point(0.8, Color(debris_color.r * 0.7, debris_color.g * 0.7, debris_color.b * 0.7, debris_color.a * 0.5))
	debris_gradient.add_point(1.0, Color(debris_color.r, debris_color.g, debris_color.b, 0))
	debris.color_ramp = debris_gradient

	particle_parent.add_child(debris)
	print("[Tile] Debris particles added to parent")

	# Play destruction sound
	if AudioManager and AudioManager.has_method("play_sfx"):
		print("[Tile] Playing destruction sound")
		# Different sounds for different materials
		if unmovable_type == "glass":
			AudioManager.play_sfx("tile_break")  # Glass breaking sound
		elif unmovable_type == "wood":
			AudioManager.play_sfx("tile_break")  # Wood cracking sound
		else:
			AudioManager.play_sfx("tile_break")  # Generic break sound

	# Auto-cleanup
	get_tree().create_timer(1.5).timeout.connect(smoke.queue_free)
	get_tree().create_timer(1.0).timeout.connect(debris.queue_free)
	print("[Tile] Particle effect complete")

func update_type(new_type: int):
	"""Update the tile to a new type and refresh its visual appearance"""
	print("Updating tile at ", grid_position, " from type ", tile_type, " to type ", new_type)
	tile_type = new_type
	update_visual()
	# Safely build debug strings without using inline ternary
	var sprite_visible_str = "no sprite"
	var texture_str = "no sprite"
	var scale_str = "no sprite"
	if sprite != null:
		sprite_visible_str = str(sprite.visible)
		if sprite.texture != null:
			texture_str = str(sprite.texture)
		scale_str = str(sprite.scale)
	print("Tile updated. Sprite visible: ", sprite_visible_str, " Texture: ", texture_str, " Scale: ", scale_str)

func apply_rounded_corner_shader():
	"""Apply the rounded corner shader to the sprite"""
	if not sprite:
		print("[Tile] Cannot apply shader - sprite not ready")
		return

	var shader_path = "res://shaders/rounded_tile.gdshader"
	if not ResourceLoader.exists(shader_path):
		print("[Tile] Shader not found at: ", shader_path)
		return

	var shader = load(shader_path)
	if not shader:
		print("[Tile] Failed to load shader")
		return

	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("corner_radius", 0.25)  # Larger radius for more visible rounded corners
	sprite.material = material
	print("[Tile] Applied rounded corner shader to tile at ", grid_position)

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
	# Handle touch/mouse press - check if it started on this tile
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		var global_pos = Vector2.ZERO
		if event is InputEventScreenTouch:
			global_pos = event.position
		else:
			global_pos = get_global_mouse_position()
		var local_pos = to_local(global_pos)

		if get_rect().has_point(local_pos):
			print("Touch started on tile at ", grid_position)
			swipe_start_pos = global_pos
			touch_started_on_this_tile = true
			is_swiping = true

	# Handle touch/mouse release - check if it's a swipe or tap
	elif (event is InputEventScreenTouch and not event.pressed) or \
		 (event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT):

		if touch_started_on_this_tile:
			print("Touch released, checking swipe on tile at ", grid_position)
			var global_pos = Vector2.ZERO
			if event is InputEventScreenTouch:
				global_pos = event.position
			else:
				global_pos = get_global_mouse_position()
			var swipe_vector = global_pos - swipe_start_pos
			var swipe_distance = swipe_vector.length()

			print("Swipe distance: ", swipe_distance, " Start: ", swipe_start_pos, " End: ", global_pos)

			if swipe_distance >= swipe_threshold:
				# It's a swipe - determine direction
				var swipe_direction = get_swipe_direction(swipe_vector)
				print("Swipe detected in direction: ", swipe_direction)
				emit_signal("tile_swiped", self, swipe_direction)
			else:
				# It's a tap - use normal click behavior
				print("Tap detected (swipe too short)")
				handle_click()

			touch_started_on_this_tile = false
			is_swiping = false

func _on_input_event(viewport, event, shape_idx):
	# Keep for compatibility but main input is handled in _input now
	pass

func get_swipe_direction(swipe_vector: Vector2) -> Vector2:
	"""Determine the primary swipe direction (up, down, left, right)"""
	var abs_x = abs(swipe_vector.x)
	var abs_y = abs(swipe_vector.y)

	if abs_x > abs_y:
		# Horizontal swipe
		if swipe_vector.x > 0:
			return Vector2(1, 0)
		else:
			return Vector2(-1, 0)
	else:
		# Vertical swipe
		if swipe_vector.y > 0:
			return Vector2(0, 1)
		else:
			return Vector2(0, -1)

func _on_mouse_entered():
	print("Mouse entered tile at ", grid_position)
	if not is_falling and not GameManager.processing_moves and sprite and sprite.texture:
		# Store the base scale (calculated by update_visual based on texture size)
		var base_scale = Vector2(64.0 / float(sprite.texture.get_width()), 64.0 / float(sprite.texture.get_height())) * tile_scale
		var tween = create_tween()
		# Scale 10% larger for hover effect
		tween.tween_property(sprite, "scale", base_scale * 1.1, 0.1)
		# Add visual feedback
		sprite.modulate = sprite.modulate.lightened(0.3)

func _on_mouse_exited():
	print("Mouse exited tile at ", grid_position)
	if not is_falling and sprite and sprite.texture:
		# Restore the correct base scale (calculated by update_visual based on texture size)
		var base_scale = Vector2(64.0 / float(sprite.texture.get_width()), 64.0 / float(sprite.texture.get_height())) * tile_scale
		var tween = create_tween()
		tween.tween_property(sprite, "scale", base_scale, 0.1)
		# Restore original color (only for loaded textures we don't modulate)
		sprite.modulate = Color.WHITE

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
	if is_queued_for_deletion() or not is_inside_tree():
		return null

	is_falling = true
	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	tween.tween_callback(func(): is_falling = false)
	return tween

func animate_swap_to(target_pos: Vector2, duration: float = 0.2) -> Tween:
	if is_queued_for_deletion() or not is_inside_tree():
		return null

	var tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration)
	return tween

func animate_destroy() -> Tween:
	if is_queued_for_deletion() or not is_inside_tree():
		return null

	# Create particle effect for tile destruction
	_create_destruction_particles()

	# Play destruction sound effect
	AudioManager.play_sfx("tile_match")

	var tween = create_tween()
	if sprite:
		# Get the current scale as base
		var current_scale = sprite.scale

		# Pop and shrink effect - scale relative to current scale
		tween.parallel().tween_property(sprite, "scale", current_scale * 1.3, 0.1)
		tween.parallel().tween_property(sprite, "scale", Vector2.ZERO, 0.2).set_delay(0.1)
		tween.parallel().tween_property(sprite, "rotation", PI * 1.5, 0.3)

	# Fade out with color shift
	tween.parallel().tween_property(self, "modulate", Color(2, 2, 2, 0), 0.3)

	# Don't call queue_free here - let GameBoard handle it after the animation completes
	return tween

func _create_destruction_particles():
	"""Create particle effect when tile is destroyed"""
	if not is_inside_tree():
		return

	# Create CPUParticles2D for the explosion effect
	var particles = CPUParticles2D.new()
	particles.name = "DestructionParticles"
	particles.position = Vector2.ZERO
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9  # More explosive
	particles.amount = 25  # Increased from 12
	particles.lifetime = 0.8  # Longer lifetime
	particles.speed_scale = 2.5  # Faster movement

	# Particle properties
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 300)  # More gravity for dramatic arc
	particles.initial_velocity_min = 120.0  # Faster
	particles.initial_velocity_max = 250.0  # Much faster
	particles.angular_velocity_min = -540  # More rotation
	particles.angular_velocity_max = 540
	particles.scale_amount_min = 1.0  # Much larger particles
	particles.scale_amount_max = 2.5

	# Color based on tile type - brighter
	var particle_color = Color.WHITE
	if tile_type > 0 and tile_type <= COLORS.size():
		particle_color = COLORS[tile_type - 1]
	# Make colors brighter for more impact
	particle_color = particle_color * 1.3
	particles.color = particle_color

	# Create gradient for fade out with glow effect
	var gradient = Gradient.new()
	gradient.add_point(0.0, particle_color * 1.5)  # Start bright
	gradient.add_point(0.3, particle_color * 1.2)  # Stay bright
	gradient.add_point(0.7, particle_color * 0.8)
	gradient.add_point(1.0, Color(particle_color.r, particle_color.g, particle_color.b, 0))
	particles.color_ramp = gradient

	# Scale gradient - start bigger, end smaller
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1.2))  # Start big
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(0.7, 0.6))
	scale_curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = scale_curve

	add_child(particles)

	# Auto-cleanup after particles finish - connect directly to queue_free
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)

func animate_spawn() -> Tween:
	if is_queued_for_deletion() or not is_inside_tree():
		return null

	if sprite:
		sprite.scale = Vector2.ZERO
	modulate = Color.WHITE

	var tween = create_tween()
	if sprite and sprite.texture:
		# Calculate the correct target scale based on texture size
		var target_scale = Vector2(64.0 / float(sprite.texture.get_width()), 64.0 / float(sprite.texture.get_height())) * tile_scale

		# Bouncy spawn with overshoot effect
		tween.tween_property(sprite, "scale", target_scale * 1.3, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "scale", target_scale, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

		# Add slight rotation wiggle
		tween.parallel().tween_property(sprite, "rotation", 0.1, 0.1)
		tween.tween_property(sprite, "rotation", -0.1, 0.1)
		tween.tween_property(sprite, "rotation", 0.0, 0.1)

	tween.tween_callback(func(): is_falling = false)
	return tween

func animate_match_highlight() -> Tween:
	if is_queued_for_deletion() or not is_inside_tree():
		return null

	if not sprite:
		return create_tween()  # Return empty tween if sprite not ready

	var tween = create_tween()
	# Check bounds before accessing COLORS array
	if tile_type >= 1 and tile_type <= COLORS.size():
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", COLORS[tile_type - 1], 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", COLORS[tile_type - 1], 0.1)
	else:
		# For special tiles, just flash white
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	return tween

# Use the property 'is_unmovable' directly instead of a method to avoid name collision
