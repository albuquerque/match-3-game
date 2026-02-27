extends Control
class_name FloatingMenuComponent

# FloatingMenuComponent: the circular hamburger button + expandable panel.
# Scene: res://scenes/ui/components/FloatingMenu.tscn
# Emits signals so GameUI can open pages without this component knowing about them.

signal map_pressed
signal shop_pressed
signal gallery_pressed
signal settings_pressed

@onready var menu_button: TextureButton  = get_node_or_null("MenuButton")
@onready var expandable_panel: VBoxContainer = get_node_or_null("ExpandablePanel")
@onready var map_button: TextureButton   = get_node_or_null("ExpandablePanel/MapButton")
@onready var shop_button: TextureButton  = get_node_or_null("ExpandablePanel/ShopButton")
@onready var gallery_button: TextureButton = get_node_or_null("ExpandablePanel/GalleryButton")
@onready var settings_button: TextureButton = get_node_or_null("ExpandablePanel/SettingsButton")

var _expanded: bool = false

func _ready() -> void:
	if expandable_panel:
		expandable_panel.modulate = Color(1, 1, 1, 0)
		expandable_panel.visible = false
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	if map_button:
		map_button.pressed.connect(func(): emit_signal("map_pressed"))
	if shop_button:
		shop_button.pressed.connect(func(): emit_signal("shop_pressed"))
	if gallery_button:
		gallery_button.pressed.connect(func(): emit_signal("gallery_pressed"))
	if settings_button:
		settings_button.pressed.connect(func(): emit_signal("settings_pressed"))

# ── Private ───────────────────────────────────────────────────────────────────

func _on_menu_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("ui_click")
	_expanded = !_expanded
	_animate_toggle()


func _animate_toggle() -> void:
	if not expandable_panel:
		return
	var tw = create_tween().set_parallel(true)
	if _expanded:
		expandable_panel.visible = true
		tw.tween_property(expandable_panel, "modulate", Color(1, 1, 1, 1), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(expandable_panel, "modulate", Color(1, 1, 1, 0), 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.finished.connect(func(): expandable_panel.visible = false, CONNECT_ONE_SHOT)

func collapse() -> void:
	"""Force collapse — called by GameUI when a page is opened."""
	_expanded = false
	if expandable_panel:
		expandable_panel.modulate = Color(1, 1, 1, 0)
		expandable_panel.visible = false
