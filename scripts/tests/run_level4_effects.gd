extends Node

func _ready():
	print("=== RUN LEVEL 4 EFFECTS TEST ===")
	var er = get_node_or_null('/root/EffectResolver')
	var eb = get_node_or_null('/root/EventBus')
	if not er:
		print("EffectResolver not available")
		get_tree().quit()
		return
	if not eb:
		print("EventBus not available")
		get_tree().quit()
		return

	var path = 'res://data/chapters/chapter_level_4.json'
	print("Loading chapter file: %s -> exists=%s" % [path, ResourceLoader.exists(path)])
	if er.load_effects_from_file(path):
		print("Loaded effects for Level 4 into EffectResolver")
	else:
		print("Failed to load effects for Level 4")

	# Emit level_loaded event exactly like GameUI does
	eb.emit_level_loaded('level_4', {"level":4, "target":4960})
	print("Emitted EventBus.level_loaded for level_4")

	# Wait a short while so any timers/tweens run (Godot 4 await)
	var t = get_tree().create_timer(1.5)
	await t.timeout
	print("=== TEST COMPLETE ===")
	get_tree().quit()
