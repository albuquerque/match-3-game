extends Node

func _ready():
	# Instantiate the test node and add to scene so _ready executes
	var t = load("res://tests/test_board_registration.gd").new()
	add_child(t)
