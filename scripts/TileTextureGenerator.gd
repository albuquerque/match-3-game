extends Node

# This script generates simple colored circle textures for the match-3 tiles
# Run this in the editor to create tile textures

const TILE_SIZE = 64
const COLORS = [
	Color.RED,
	Color.BLUE,
	Color.GREEN,
	Color.YELLOW,
	Color.PURPLE,
	Color.ORANGE
]

func generate_tile_textures():
	# Generate regular colored tiles (1-6)
	for i in range(COLORS.size()):
		var texture = create_circle_texture(COLORS[i], TILE_SIZE)
		var path = "res://textures/tile_%d.png" % (i + 1)
		save_texture_as_png(texture, path)
		print("Generated texture: ", path)

	# Generate horizontal arrow tile (7)
	var horizontal_arrow = create_horizontal_arrow_texture(TILE_SIZE)
	save_texture_as_png(horizontal_arrow, "res://textures/tile_7.png")
	print("Generated texture: res://textures/tile_7.png (Horizontal Arrow)")

	# Generate vertical arrow tile (8)
	var vertical_arrow = create_vertical_arrow_texture(TILE_SIZE)
	save_texture_as_png(vertical_arrow, "res://textures/tile_8.png")
	print("Generated texture: res://textures/tile_8.png (Vertical Arrow)")

	# Generate 4-way arrow tile (9)
	var four_way_arrow = create_four_way_arrow_texture(TILE_SIZE)
	save_texture_as_png(four_way_arrow, "res://textures/tile_9.png")
	print("Generated texture: res://textures/tile_9.png (4-Way Arrow)")

func create_circle_texture(color: Color, size: int) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)
	var radius = size / 2 - 2

	# Fill with transparent
	image.fill(Color.TRANSPARENT)

	# Draw circle with gradient
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)

			if distance <= radius:
				var alpha = 1.0 - (distance / radius) * 0.3
				var final_color = Color(color.r, color.g, color.b, alpha)

				# Add some shine effect
				if distance < radius * 0.6:
					final_color = final_color.lightened(0.3)

				image.set_pixel(x, y, final_color)

	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func save_texture_as_png(texture: ImageTexture, path: String):
	var image = texture.get_image()
	image.save_png(path)

func create_horizontal_arrow_texture(size: int) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)

	# Fill with transparent
	image.fill(Color.TRANSPARENT)

	# Draw a glowing circle background
	var radius = size / 2 - 2
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)

			if distance <= radius:
				var alpha = 1.0 - (distance / radius) * 0.5
				var glow_color = Color(1.0, 0.8, 0.0, alpha)  # Golden glow
				image.set_pixel(x, y, glow_color)

	# Draw horizontal arrow
	var arrow_color = Color.WHITE
	var arrow_thickness = 6
	var arrow_length = int(size * 0.6)
	var arrow_start_x = int(center.x - arrow_length / 2)
	var arrow_end_x = int(center.x + arrow_length / 2)
	var center_y = int(center.y)

	# Draw arrow shaft (horizontal line)
	for x in range(arrow_start_x, arrow_end_x):
		for thickness in range(-arrow_thickness / 2, arrow_thickness / 2):
			var y = center_y + thickness
			if x >= 0 and x < size and y >= 0 and y < size:
				image.set_pixel(x, y, arrow_color)

	# Draw arrow head (pointing right)
	var arrow_head_size = 12
	for i in range(arrow_head_size):
		for thickness in range(-1, 2):
			var x = arrow_end_x - arrow_head_size + i
			var y_top = center_y - i + thickness
			var y_bottom = center_y + i + thickness

			if x >= 0 and x < size:
				if y_top >= 0 and y_top < size:
					image.set_pixel(x, y_top, arrow_color)
				if y_bottom >= 0 and y_bottom < size:
					image.set_pixel(x, y_bottom, arrow_color)

	# Draw arrow tail (pointing left)
	for i in range(arrow_head_size):
		for thickness in range(-1, 2):
			var x = arrow_start_x + arrow_head_size - i
			var y_top = center_y - i + thickness
			var y_bottom = center_y + i + thickness

			if x >= 0 and x < size:
				if y_top >= 0 and y_top < size:
					image.set_pixel(x, y_top, arrow_color)
				if y_bottom >= 0 and y_bottom < size:
					image.set_pixel(x, y_bottom, arrow_color)

	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func create_vertical_arrow_texture(size: int) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)

	# Fill with transparent
	image.fill(Color.TRANSPARENT)

	# Draw a glowing circle background
	var radius = size / 2 - 2
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)

			if distance <= radius:
				var alpha = 1.0 - (distance / radius) * 0.5
				var glow_color = Color(0.0, 0.8, 1.0, alpha)  # Cyan glow
				image.set_pixel(x, y, glow_color)

	# Draw vertical arrow
	var arrow_color = Color.WHITE
	var arrow_thickness = 6
	var arrow_length = int(size * 0.6)
	var arrow_start_y = int(center.y - arrow_length / 2)
	var arrow_end_y = int(center.y + arrow_length / 2)
	var center_x = int(center.x)

	# Draw arrow shaft (vertical line)
	for y in range(arrow_start_y, arrow_end_y):
		for thickness in range(-arrow_thickness / 2, arrow_thickness / 2):
			var x = center_x + thickness
			if x >= 0 and x < size and y >= 0 and y < size:
				image.set_pixel(x, y, arrow_color)

	# Draw arrow head (pointing down)
	var arrow_head_size = 12
	for i in range(arrow_head_size):
		for thickness in range(-1, 2):
			var y = arrow_end_y - arrow_head_size + i
			var x_left = center_x - i + thickness
			var x_right = center_x + i + thickness

			if y >= 0 and y < size:
				if x_left >= 0 and x_left < size:
					image.set_pixel(x_left, y, arrow_color)
				if x_right >= 0 and x_right < size:
					image.set_pixel(x_right, y, arrow_color)

	# Draw arrow tail (pointing up)
	for i in range(arrow_head_size):
		for thickness in range(-1, 2):
			var y = arrow_start_y + arrow_head_size - i
			var x_left = center_x - i + thickness
			var x_right = center_x + i + thickness

			if y >= 0 and y < size:
				if x_left >= 0 and x_left < size:
					image.set_pixel(x_left, y, arrow_color)
				if x_right >= 0 and x_right < size:
					image.set_pixel(x_right, y, arrow_color)

	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func create_four_way_arrow_texture(size: int) -> ImageTexture:
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)

	# Fill with transparent
	image.fill(Color.TRANSPARENT)

	# Draw a glowing circle background
	var radius = size / 2 - 2
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var distance = pos.distance_to(center)

			if distance <= radius:
				var alpha = 1.0 - (distance / radius) * 0.5
				var glow_color = Color(1.0, 0.0, 1.0, alpha)  # Magenta glow
				image.set_pixel(x, y, glow_color)

	# Draw 4-way arrow
	var arrow_color = Color.WHITE
	var arrow_thickness = 6
	var arrow_length = int(size * 0.6)
	var center_x = int(center.x)
	var center_y = int(center.y)

	# Draw arrow shafts (cross shape)
	for i in range(-arrow_thickness / 2, arrow_thickness / 2):
		var x_offset = i
		var y_offset = arrow_length / 2
		# Vertical shaft
		if center_y + y_offset < size:
			image.set_pixel(center_x + x_offset, center_y + y_offset, arrow_color)
		# Horizontal shaft
		if center_x - y_offset >= 0:
			image.set_pixel(center_x - y_offset, center_y + x_offset, arrow_color)

	# Draw arrow heads (triangles)
	var arrow_head_size = 12
	for i in range(arrow_head_size):
		for thickness in range(-1, 2):
			var x = center_x - arrow_head_size + i
			var y_top = center_y - i + thickness
			var y_bottom = center_y + i + thickness

			if x >= 0 and x < size:
				if y_top >= 0 and y_top < size:
					image.set_pixel(x, y_top, arrow_color)
				if y_bottom >= 0 and y_bottom < size:
					image.set_pixel(x, y_bottom, arrow_color)

	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture
