extends Node

func _ready():
	print("[test_runner] starting")
	var wm_script = load("res://scripts/WorldMap.gd")
	if not wm_script:
		print("[test_runner] Failed to load WorldMap.gd")
		get_tree().quit()
		return
	var wm = wm_script.new()
	add_child(wm)
	# Give a tiny delay for async _ready/_populate to run
	await get_tree().create_timer(0.2).timeout
	print("[test_runner] done - quitting")
	get_tree().quit()
