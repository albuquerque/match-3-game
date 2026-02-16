@tool
extends EditorScript

## Generate placeholder textures for reward container testing
## Run this script from the Godot editor: File > Run

func _run():
	print("=== Generating Reward Container Placeholder Textures ===")

	# Create directory if it doesn't exist
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("textures/reward_containers"):
		dir.make_dir_recursive("textures/reward_containers")
		print("Created directory: textures/reward_containers/")

	# Generate box base
	_generate_box_base()

	# Generate box lid
	_generate_box_lid()

	print("=== Texture generation complete! ===")
	print("Generated files:")
	print("  - res://textures/reward_containers/box_base.png")
	print("  - res://textures/reward_containers/box_lid.png")

func _generate_box_base():
	"""Generate simple box base texture"""
	var size = Vector2i(200, 150)
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

	# Fill with gradient (brown box)
	for y in range(size.y):
		for x in range(size.x):
			var border = 10
			var is_border = (x < border or x >= size.x - border or
							y < border or y >= size.y - border)

			if is_border:
				# Border - darker brown
				img.set_pixel(x, y, Color(0.4, 0.25, 0.1, 1.0))
			else:
				# Interior - lighter brown with gradient
				var gradient_t = float(y) / size.y
				var brown = Color(0.6, 0.4, 0.2, 1.0).lerp(Color(0.5, 0.3, 0.15, 1.0), gradient_t)
				img.set_pixel(x, y, brown)

	# Save
	img.save_png("res://textures/reward_containers/box_base.png")
	print("Generated: box_base.png")

func _generate_box_lid():
	"""Generate simple box lid texture"""
	var size = Vector2i(220, 80)
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

	# Fill with gradient (slightly darker brown for lid)
	for y in range(size.y):
		for x in range(size.x):
			var border = 8
			var is_border = (x < border or x >= size.x - border or
							y < border or y >= size.y - border)

			if is_border:
				# Border - darkest brown
				img.set_pixel(x, y, Color(0.35, 0.2, 0.08, 1.0))
			else:
				# Interior - medium brown with gradient
				var gradient_t = float(y) / size.y
				var brown = Color(0.55, 0.35, 0.18, 1.0).lerp(Color(0.45, 0.28, 0.13, 1.0), gradient_t)
				img.set_pixel(x, y, brown)

	# Add a highlight on top
	for x in range(40, size.x - 40):
		for y in range(15, 25):
			var current = img.get_pixel(x, y)
			img.set_pixel(x, y, current.lightened(0.2))

	# Save
	img.save_png("res://textures/reward_containers/box_lid.png")
	print("Generated: box_lid.png")
