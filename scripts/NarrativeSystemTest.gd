extends Node2D
## NarrativeSystemTest - Visual test scene for the narrative animation system

@onready var status_label = $UI/StatusLabel
@onready var test_button_container = $UI/TestButtons

var test_count = 0

func _ready():
	print("\n" + "=".repeat(60))
	print("Narrative Animation System - Visual Test")
	print("=".repeat(60) + "\n")

	# Wait for autoloads
	await get_tree().process_frame

	# Update status
	_update_status("Loading sample chapter...")

	# Load sample chapter
	var success = await _load_sample_chapter()

	if success:
		_update_status("✓ Chapter loaded - Click buttons to test effects")
		_setup_test_buttons()
	else:
		_update_status("✗ Failed to load chapter")

func _load_sample_chapter() -> bool:
	var chapter_path = "res://data/chapters/sample_chapter_01.json"

	if not ResourceLoader.exists(chapter_path):
		push_error("[NarrativeTest] Sample chapter not found: " + chapter_path)
		return false

	if EffectResolver.load_effects_from_file(chapter_path):
		print("[NarrativeTest] ✓ Sample chapter loaded")

		# Load assets
		var file = FileAccess.open(chapter_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			json.parse(file.get_as_text())
			file.close()

			if json.data:
				AssetRegistry.load_chapter_assets(json.data)
				print("[NarrativeTest] ✓ Chapter assets loaded")

		return true
	else:
		push_error("[NarrativeTest] ✗ Failed to load chapter")
		return false

func _setup_test_buttons():
	# Create test buttons for each event type
	_create_test_button("Level Start", func(): _test_level_start())
	_create_test_button("Tile Destroyed", func(): _test_tile_destroyed())
	_create_test_button("Special Activated", func(): _test_special_activated())
	_create_test_button("Level Complete", func(): _test_level_complete())
	_create_test_button("Level Failed", func(): _test_level_failed())
	_create_test_button("Spawn Many Particles", func(): _test_particle_burst())

func _create_test_button(label_text: String, callback: Callable):
	var button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(200, 40)
	button.pressed.connect(callback)
	test_button_container.add_child(button)

func _test_level_start():
	_update_status("Testing: Level Start Animation")
	EventBus.emit_level_start("test_level", {"chapter": "sample_chapter_01"})
	test_count += 1

func _test_tile_destroyed():
	_update_status("Testing: Tile Destroyed (Particles)")
	# Emit at random position
	var pos = Vector2(randf_range(100, 600), randf_range(200, 800))
	EventBus.emit_tile_destroyed("tile_%d" % test_count, {
		"type": randi() % 6 + 1,
		"pos": pos
	})
	test_count += 1

func _test_special_activated():
	_update_status("Testing: Special Tile (Camera Shake)")
	EventBus.emit_special_tile_activated("special_%d" % test_count, {
		"type": "bomb",
		"pos": Vector2(360, 500)
	})
	test_count += 1

func _test_level_complete():
	_update_status("Testing: Level Complete (Timeline Sequence)")
	EventBus.emit_level_complete("test_level", {
		"score": 5000,
		"stars": 3
	})
	test_count += 1

func _test_level_failed():
	_update_status("Testing: Level Failed (Shader Effect)")
	EventBus.emit_level_failed("test_level", {
		"score": 1200,
		"target": 5000
	})
	test_count += 1

func _test_particle_burst():
	_update_status("Testing: Particle Burst at Multiple Positions")
	# Spawn particles at multiple positions
	for i in range(5):
		var pos = Vector2(
			randf_range(100, 600),
			randf_range(200, 800)
		)
		EventBus.emit_tile_destroyed("burst_%d_%d" % [test_count, i], {
			"pos": pos,
			"type": randi() % 6 + 1
		})
	test_count += 1

func _update_status(message: String):
	if status_label:
		status_label.text = message
	print("[NarrativeTest] %s" % message)

func _input(event):
	# Press SPACE to run automated test sequence
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_run_automated_test()

func _run_automated_test():
	_update_status("Running automated test sequence...")

	await get_tree().create_timer(0.5).timeout
	_test_level_start()

	await get_tree().create_timer(1.0).timeout
	_test_tile_destroyed()

	await get_tree().create_timer(0.5).timeout
	_test_tile_destroyed()

	await get_tree().create_timer(0.5).timeout
	_test_special_activated()

	await get_tree().create_timer(1.5).timeout
	_test_level_complete()

	await get_tree().create_timer(2.0).timeout
	_test_particle_burst()

	await get_tree().create_timer(1.0).timeout
	_update_status("✓ Automated test complete")
