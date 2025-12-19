extends Control

@onready var play_button = $VBoxContainer/PlayButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var title_label = $VBoxContainer/TitleLabel

func _ready():
	play_button.connect("pressed", _on_play_pressed)
	settings_button.connect("pressed", _on_settings_pressed)
	quit_button.connect("pressed", _on_quit_pressed)

	# Animate title
	animate_title()

	# Play menu music
	AudioManager.play_music("menu", 1.0)

func _on_play_pressed():
	AudioManager.play_sfx("ui_click")
	get_tree().change_scene_to_file("res://scenes/MainGame.tscn")

func _on_settings_pressed():
	# Placeholder for settings menu
	print("Settings not implemented yet")

func _on_quit_pressed():
	get_tree().quit()

func animate_title():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(title_label, "modulate", Color.YELLOW, 2.0)
	tween.tween_property(title_label, "modulate", Color.WHITE, 2.0)
