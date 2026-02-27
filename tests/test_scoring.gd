extends Node

func _ready():
	print("[TEST] test_scoring _ready() starting")
	var pts = Scoring.points_for(5, 2)
	assert(pts > 0)
	print("[TEST] test_scoring passed: pts=", pts)
	get_tree().quit()
