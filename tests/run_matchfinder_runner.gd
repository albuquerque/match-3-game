extends Node

var test_script = load("res://tests/test_matchfinder_unit.gd")
var test_inst = null

func _ready():
	# instantiate and add to scene tree so its _ready() will be called with a valid tree
	test_inst = test_script.new()
	if test_inst:
		print("[RUNNER] Adding test node to scene tree")
		add_child(test_inst)
	else:
		print("[RUNNER] Failed to instantiate test script")
		# Ensure we still quit
		if Engine.get_main_loop() and Engine.get_main_loop().has_method("quit"):
			Engine.get_main_loop().quit()
		else:
			if get_tree():
				get_tree().quit()
			else:
				# Last resort: nothing we can do
				pass
