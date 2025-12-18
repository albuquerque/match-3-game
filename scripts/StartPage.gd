extends Control

signal start_pressed
signal booster_selected(booster_id: String)
signal exchange_pressed

func _ready():
	# Fullscreen anchors
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	visible = true

	# Create a simple layout programmatically so the scene file isn't required here
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_left = 0.1
	vbox.anchor_top = 0.1
	vbox.anchor_right = 0.9
	vbox.anchor_bottom = 0.9
	# don't set margins/offsets here; anchors are sufficient
	add_child(vbox)

	var level_label = Button.new()
	level_label.name = "LevelButton"
	level_label.text = "Level: --"
	level_label.add_theme_font_size_override("font_size", 36)
	# Clicking the level button starts the level
	level_label.pressed.connect(Callable(self, "_on_start_pressed"))
	vbox.add_child(level_label)

	# Description label below level button
	var desc_label = Label.new()
	desc_label.name = "LevelDescription"
	desc_label.text = ""
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(desc_label)

	var actions_h = HBoxContainer.new()
	actions_h.name = "ActionsH"
	vbox.add_child(actions_h)

	var start_btn = Button.new()
	start_btn.name = "StartButton"
	start_btn.text = "Start Level"
	start_btn.custom_minimum_size = Vector2(200, 64)
	start_btn.pressed.connect(Callable(self, "_on_start_pressed"))
	actions_h.add_child(start_btn)

	var exchange_btn = Button.new()
	exchange_btn.name = "ExchangeButton"
	exchange_btn.text = "Exchange Gems"
	exchange_btn.custom_minimum_size = Vector2(200, 64)
	exchange_btn.pressed.connect(Callable(self, "_on_exchange_pressed"))
	actions_h.add_child(exchange_btn)

	# Booster sample options
	var boosters_v = VBoxContainer.new()
	boosters_v.name = "BoostersV"
	vbox.add_child(boosters_v)

	var boost_label = Label.new()
	boost_label.text = "Free boosters:"
	boosters_v.add_child(boost_label)

	for b in ["hammer", "shuffle", "swap"]:
		var bbtn = Button.new()
		bbtn.text = b.capitalize()
		# connect to a bound callable to avoid anonymous lambda issues
		bbtn.pressed.connect(Callable(self, "_on_booster_button_pressed").bind(b))
		boosters_v.add_child(bbtn)

func set_level_info(level_number: int, description: String):
	var btn = get_node_or_null("VBox/LevelButton")
	if btn and btn is Button:
		btn.text = "Level %d" % level_number
	var dl = get_node_or_null("VBox/LevelDescription")
	if dl and dl is Label:
		dl.text = description

func close():
	visible = false
	queue_free()

func _on_start_pressed():
	emit_signal("start_pressed")

func _on_booster_button_pressed(bid: String):
	emit_signal("booster_selected", bid)

func _on_exchange_pressed():
	emit_signal("exchange_pressed")
