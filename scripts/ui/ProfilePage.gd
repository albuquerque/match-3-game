extends "res://scripts/ui/ScreenBase.gd"

# ProfilePage - display player stats stub

func _ready():
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	var lbl = Label.new()
	lbl.name = "ProfileLabel"
	lbl.text = "Player Profile\n(Placeholder)"
	lbl.horizontal_alignment = Label.ALIGN_CENTER
	lbl.valign = Label.VALIGN_CENTER
	add_child(lbl)
	ensure_fullscreen()
	visible = false

func setup(params: Dictionary = {}) -> void:
	# optionally display player id
	if params.has("player_id"):
		get_node("ProfileLabel").text = "Player Profile: %s" % str(params.player_id)

func initialize(data: Dictionary = {}) -> void:
	setup(data)
