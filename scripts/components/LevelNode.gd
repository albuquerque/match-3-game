extends Control
class_name LevelNode

# Small LevelNode component for WorldMap tiles

var level_id: String = ""
var unlocked: bool = false

func setup(data: Dictionary) -> void:
	# Data: {level_id: String, unlocked: bool, name: String}
	level_id = data.get("level_id", "")
	unlocked = data.get("unlocked", false)
	# Visual representation
	var lbl = Label.new()
	lbl.text = data.get("name", level_id)
	add_child(lbl)

func set_unlocked(val: bool) -> void:
	unlocked = val
	# update visuals accordingly
	modulate = Color(1,1,1,1) if unlocked else Color(0.6,0.6,0.6,1)

func is_unlocked() -> bool:
	return unlocked
