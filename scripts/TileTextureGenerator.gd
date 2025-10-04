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
	for i in range(COLORS.size()):
		var texture = create_circle_texture(COLORS[i], TILE_SIZE)
		var path = "res://textures/tile_%d.png" % (i + 1)
		save_texture_as_png(texture, path)
		print("Generated texture: ", path)

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
