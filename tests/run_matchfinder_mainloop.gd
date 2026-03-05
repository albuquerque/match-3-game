class_name MatchFinderMainLoop
extends SceneTree

func _init():
	print("[MAINLOOP] Initializing SceneTree mainloop runner for MatchFinder tests")
	var test_script = load("res://tests/test_matchfinder_unit.gd")
	if not test_script:
		print("[MAINLOOP] ERROR: Could not load test script")
		quit()
	var test_inst = test_script.new()
	if test_inst:
		add_child(test_inst)
		print("[MAINLOOP] Test node added to tree")
	else:
		print("[MAINLOOP] ERROR: Failed to instantiate test script")
		quit()
