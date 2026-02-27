extends Node

func _ready():
	var sf = load("res://scripts/game/SpecialFactory.gd")
	print("Loaded SF type=", typeof(sf), " has_method=", sf.has_method("determine_special_type"))
	var cases = {
		"vertical4": [Vector2(2,3), Vector2(2,4), Vector2(2,5), Vector2(2,6)],
		"horizontal4": [Vector2(1,4), Vector2(2,4), Vector2(3,4), Vector2(4,4)],
		"tshape": [Vector2(2,3), Vector2(2,4), Vector2(2,5), Vector2(1,4), Vector2(3,4)]
	}
	for name in cases.keys():
		var matches = cases[name]
		var inst = null
		if sf.has_method("new"):
			inst = sf.new()
		else:
			inst = sf
		var res = -1
		if inst and inst.has_method("determine_special_type"):
			res = inst.determine_special_type(matches, Vector2(2,4), [], 8, 8, 3)
		print("case=", name, " -> ", res)
	get_tree().quit()
