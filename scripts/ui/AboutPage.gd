extends "res://scripts/ui/ScreenBase.gd"

# AboutPage - simple static content page

func _ready():
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	# Minimal visual: a label
	var lbl = Label.new()
	lbl.name = "AboutLabel"
	lbl.text = "About: Match-3 Game\nVersion: 1.0"
	lbl.horizontal_alignment = Label.ALIGN_CENTER
	lbl.valign = Label.VALIGN_CENTER
	add_child(lbl)
	ensure_fullscreen()
	visible = false

func setup(params: Dictionary = {}) -> void:
	# no params required
	pass

func initialize(data: Dictionary = {}) -> void:
	# alias for the refactor template
	setup(data)
