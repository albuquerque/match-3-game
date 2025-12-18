extends Panel

@onready var close_button = $VBoxContainer/CloseButton
@onready var volume_slider = $VBoxContainer/VolumeSlider

func _ready():
    visible = false
    close_button.pressed.connect(_on_close_pressed)

func show_dialog():
    visible = true
    modulate = Color.TRANSPARENT
    var t = create_tween()
    t.tween_property(self, "modulate", Color.WHITE, 0.15)

func _on_close_pressed():
    var t = create_tween()
    t.tween_property(self, "modulate", Color.TRANSPARENT, 0.15)
    t.tween_callback(func(): visible = false)

func get_volume() -> float:
    return volume_slider.value

