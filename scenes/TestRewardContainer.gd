extends Node2D

## Test scene for Phase 4 reward containers
## Creates placeholder textures and tests the container system

func _ready():
	print("=== Reward Container Test Scene ===")

	# Generate placeholder textures
	_generate_textures()

	await get_tree().create_timer(0.5).timeout

	# Test container
	_test_container()

func _generate_textures():
	"""Generate simple colored rectangle textures"""
	print("[Test] Generating placeholder textures...")

	# Create box base (brown rectangle)
	var base_img = Image.create(200, 150, false, Image.FORMAT_RGBA8)
	base_img.fill(Color(0.6, 0.4, 0.2, 1.0))  # Brown

	# Add border
	for x in range(200):
		for y in [0, 1, 2, 147, 148, 149]:
			base_img.set_pixel(x, y, Color(0.3, 0.2, 0.1, 1.0))
	for y in range(150):
		for x in [0, 1, 2, 197, 198, 199]:
			base_img.set_pixel(x, y, Color(0.3, 0.2, 0.1, 1.0))

	base_img.save_png("res://textures/reward_containers/box_base.png")
	print("[Test] Created box_base.png")

	# Create box lid (darker brown rectangle)
	var lid_img = Image.create(220, 80, false, Image.FORMAT_RGBA8)
	lid_img.fill(Color(0.5, 0.3, 0.15, 1.0))  # Darker brown

	# Add border
	for x in range(220):
		for y in [0, 1, 2, 77, 78, 79]:
			lid_img.set_pixel(x, y, Color(0.25, 0.15, 0.08, 1.0))
	for y in range(80):
		for x in [0, 1, 2, 217, 218, 219]:
			lid_img.set_pixel(x, y, Color(0.25, 0.15, 0.08, 1.0))

	lid_img.save_png("res://textures/reward_containers/box_lid.png")
	print("[Test] Created box_lid.png")

	print("[Test] Textures generated successfully!")

func _test_container():
	"""Test the reward container system"""
	print("[Test] Testing reward container...")

	# Load container config
	var config = ContainerConfigLoader.load_container("fade_chest_example")

	if config.is_empty():
		print("[Test] ERROR: Could not load container config!")
		return

	print("[Test] Loaded container config: ", config.get("container_id"))

	# Create container
	var container = RewardContainer.new()
	container.name = "TestContainer"
	add_child(container)

	# Center on screen
	var viewport_size = get_viewport_rect().size
	container.position = viewport_size / 2

	# Setup container
	container.setup(config)

	# Set test rewards
	container.set_rewards(1550, 5, [])

	print("[Test] Container created and positioned")

	# Play opening animation
	await get_tree().create_timer(1.0).timeout
	print("[Test] Playing opening animation...")
	container.play_opening_animation()

	# Wait for opening to complete
	await container.opening_complete
	print("[Test] Opening complete!")

	# Play reveal animation
	await get_tree().create_timer(0.5).timeout
	print("[Test] Playing reveal animation...")
	container.play_reveal_animation()

	# Wait for revealing
	await container.revealing_complete
	print("[Test] Revealing complete!")

	# Wait a bit then close
	await get_tree().create_timer(2.0).timeout
	print("[Test] Playing closing animation...")
	container.play_closing_animation()

	# Wait for completion
	await container.all_complete
	print("[Test] Container test complete!")

	# Cleanup
	await get_tree().create_timer(1.0).timeout
	print("[Test] Test finished - press ESC to exit")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
