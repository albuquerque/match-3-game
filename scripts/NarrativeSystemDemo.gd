extends Node
## NarrativeSystemDemo - Example usage of the narrative animation system

func _ready():
	print("\n" + "=".repeat(60))
	print("Narrative Animation System - Demo")
	print("=".repeat(60) + "\n")

	# Wait a frame for autoloads to initialize
	await get_tree().process_frame

	# Load sample chapter
	_load_sample_chapter()

	# Simulate some gameplay events
	await get_tree().create_timer(1.0).timeout
	_simulate_gameplay()

## Load the sample chapter
func _load_sample_chapter():
	print("[Demo] Loading sample chapter...")

	var chapter_path = "res://data/chapters/sample_chapter_01.json"

	if EffectResolver.load_effects_from_file(chapter_path):
		print("[Demo] ✓ Sample chapter loaded successfully")

		# Load assets for the chapter
		var file = FileAccess.open(chapter_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			json.parse(file.get_as_text())
			file.close()

			if json.data:
				AssetRegistry.load_chapter_assets(json.data)
				print("[Demo] ✓ Chapter assets registered")
	else:
		print("[Demo] ✗ Failed to load sample chapter")

## Simulate gameplay events to trigger effects
func _simulate_gameplay():
	print("\n[Demo] Simulating gameplay events...\n")

	# Simulate level start
	print("--- Simulating: Level Start ---")
	EventBus.emit_level_start("level_01", {"chapter": "sample_chapter_01"})
	await get_tree().create_timer(0.5).timeout

	# Simulate tile spawning
	print("\n--- Simulating: Tile Spawned ---")
	EventBus.emit_tile_spawned("tile_001", {"type": 1, "pos": Vector2(3, 4)})
	await get_tree().create_timer(0.5).timeout

	# Simulate tile destruction
	print("\n--- Simulating: Tile Destroyed ---")
	EventBus.emit_tile_destroyed("tile_001", {"type": 1, "pos": Vector2(3, 4)})
	await get_tree().create_timer(0.5).timeout

	# Simulate special tile activation
	print("\n--- Simulating: Special Tile Activated ---")
	EventBus.emit_special_tile_activated("special_001", {"special_type": "bomb"})
	await get_tree().create_timer(0.5).timeout

	# Simulate level complete
	print("\n--- Simulating: Level Complete ---")
	EventBus.emit_level_complete("level_01", {"score": 5000, "stars": 3})
	await get_tree().create_timer(2.0).timeout

	# Simulate level failed
	print("\n--- Simulating: Level Failed ---")
	EventBus.emit_level_failed("level_02", {"score": 1200, "target": 5000})
	await get_tree().create_timer(1.0).timeout

	print("\n" + "=".repeat(60))
	print("Demo Complete - Check console output above")
	print("=".repeat(60) + "\n")

	print("[Demo] All events triggered successfully!")
	print("[Demo] Effect executors are currently stubbed (no-op)")
	print("[Demo] Next step: Implement actual visual effects in executors")
