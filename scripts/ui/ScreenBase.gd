extends Control
class_name ScreenBase

signal screen_shown
signal screen_hidden

var _open_tween_duration: float = 0.25
var _background_color: Color = Color(0.03, 0.03, 0.03, 1.0)
var bg: ColorRect = null

func _ready():
	# Make fullscreen anchors by default for screens
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Ensure an opaque background exists (child named 'Background')
	bg = get_node_or_null("Background")
	if not bg:
		bg = ColorRect.new()
		bg.name = "Background"
		bg.color = _background_color
		bg.anchor_left = 0
		bg.anchor_top = 0
		bg.anchor_right = 1
		bg.anchor_bottom = 1
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(bg)

	# Default hidden state
	if not visible:
		self.modulate = Color(1,1,1,0)

func show_screen(duration: float = -1.0):
	if duration <= 0.0:
		duration = _open_tween_duration
	visible = true
	self.modulate = Color(1,1,1,0)
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1,1,1,1), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.connect("finished", Callable(self, "_emit_shown"))

func _emit_shown():
	emit_signal("screen_shown")

func hide_screen(duration: float = -1.0):
	if duration <= 0.0:
		duration = _open_tween_duration
	var tw = create_tween()
	tw.tween_property(self, "modulate", Color(1,1,1,0), duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.connect("finished", Callable(self, "_on_hide_complete"))

func _on_hide_complete():
	visible = false
	emit_signal("screen_hidden")

func set_background_color(col: Color):
	_background_color = col
	if bg:
		bg.color = col

func ensure_fullscreen():
	# Utility to adjust size/anchors when needed
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	if get_viewport():
		self.size = get_viewport().get_visible_rect().size

# Provide a default close hook that subclasses can call
func close_screen():
	hide_screen()
