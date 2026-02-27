extends "res://scripts/ui/ScreenBase.gd"

# Placeholder Game page used during refactor. Replace with full scene later.

func _ready():
	ensure_fullscreen()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	print("[Game] placeholder ready")

func setup(params: Dictionary = {}):
	print("[Game] setup called with params:", params)
