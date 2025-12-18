extends Panel

signal dialog_closed(dialog)

@onready var close_button = $VBoxContainer/CloseButton

var _is_closing: bool = false

func _ready():
    visible = false
    mouse_filter = Control.MOUSE_FILTER_STOP
    if close_button:
        print("[AboutDialog] close_button found, connecting signal to close_dialog")
        close_button.disabled = false
        close_button.focus_mode = Control.FOCUS_NONE
        # connect directly to close_dialog for a reliable close
        close_button.connect("pressed", Callable(self, "close_dialog"))

func close_dialog():
    if visible:
        print("[AboutDialog] close_dialog called - hiding and emitting signal")
        hide()
        emit_signal("dialog_closed", self)

# keep show_dialog for opening animation
func show_dialog():
    visible = true
    _is_closing = false
    modulate = Color.TRANSPARENT
    print("[AboutDialog] show_dialog called; visible=" + str(visible))
    var t = create_tween()
    t.tween_property(self, "modulate", Color.WHITE, 0.12)
