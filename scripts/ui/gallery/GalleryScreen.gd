extends ScreenBase

## GalleryScreen — fullscreen gallery page.
## Tabs: one per gallery category (artifacts/relics/heroes) + a "Story" tab.
## Story tab shows narrative stages the player has seen, populated from StoryManager.

const CARD_SCENE_PATH := "res://scenes/ui/gallery/GalleryItemCard.tscn"

@onready var _tab_container: TabContainer = $Background/VBox/TabContainer
@onready var _close_btn: Button = $Background/VBox/TopBar/CloseButton
@onready var _title_label: Label = $Background/VBox/TopBar/TitleLabel

var _card_scene: PackedScene = null
var _story_tab_index: int = -1

# StoryManager is a newly registered autoload — access via root to avoid
# static analyser errors until the editor re-indexes project.godot
var _story_mgr: Node = null

func _ready() -> void:
	super._ready()
	_card_scene = load(CARD_SCENE_PATH)
	_story_mgr = get_node_or_null("/root/StoryManager")
	# Localise static UI labels
	if _title_label:
		_title_label.text = tr("GALLERY_TITLE")
	if _close_btn:
		_close_btn.text = tr("UI_BUTTON_CLOSE")
		_close_btn.pressed.connect(_on_close_pressed)
	if _story_mgr:
		_story_mgr.story_stage_seen.connect(_on_story_stage_seen)
	call_deferred("_populate_all_tabs")

func _populate_all_tabs() -> void:
	if not _tab_container:
		push_error("[GalleryScreen] TabContainer not found")
		return
	if not _card_scene:
		push_error("[GalleryScreen] GalleryItemCard scene not found at %s" % CARD_SCENE_PATH)
		return

	for child in _tab_container.get_children():
		child.queue_free()

	_story_tab_index = -1

	# ── Gallery category tabs ──────────────────────────────────────────────
	var all_items: Array = GalleryManager.get_all_items()
	var by_category: Dictionary = {}
	for item in all_items:
		var cat: String = str(item.get("category", "artifacts"))
		if not by_category.has(cat):
			by_category[cat] = []
		by_category[cat].append(item)

	var categories: Array = by_category.keys()
	categories.sort()

	for i in range(categories.size()):
		var cat: String = categories[i]
		var scroll := ScrollContainer.new()
		scroll.name = cat
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var grid := GridContainer.new()
		grid.name = "Grid"
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)
		_tab_container.add_child(scroll)
		# Category names come from data; keep display capitalised but ensure common UI label keys elsewhere use tr().
		_tab_container.set_tab_title(i, cat.capitalize())

		for item_data in by_category[cat]:
			var card: Node = _card_scene.instantiate()
			grid.add_child(card)
			if card.has_method("setup"):
				card.setup(item_data)

	# ── Story tab ──────────────────────────────────────────────────────────
	_story_tab_index = _tab_container.get_child_count()
	_tab_container.add_child(_build_story_tab())
	_tab_container.set_tab_title(_story_tab_index, tr("GALLERY_TAB_STORY"))

	print("[GalleryScreen] populated %d category tabs + Story tab, %d gallery items" \
		% [categories.size(), all_items.size()])

func _build_story_tab() -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = "Story"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.name = "StoryList"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var seen: Array = _story_mgr.get_seen_stages() if _story_mgr else []

	if seen.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.name = "EmptyLabel"
		empty_lbl.text = tr("GALLERY_STORY_EMPTY")
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty_lbl.add_theme_font_size_override("font_size", 16)
		vbox.add_child(empty_lbl)
	else:
		for stage_data in seen:
			_add_story_card(vbox, stage_data)

	return scroll

func _add_story_card(vbox: VBoxContainer, stage_data: Dictionary) -> void:
	var card := PanelContainer.new()
	card.set_script(load("res://scripts/ui/gallery/StoryCard.gd"))
	vbox.add_child(card)
	# Collect current full list from the vbox children that are already StoryCards
	# We pass the live seen list from StoryManager so the index is always accurate.
	var seen: Array = _story_mgr.get_seen_stages() if _story_mgr else []
	var idx := 0
	for i in range(seen.size()):
		if seen[i].get("id", "") == stage_data.get("id", ""):
			idx = i
			break
	card.setup(stage_data, seen, idx)

# ── Live update when a new stage is seen while gallery is open ─────────────

func _on_story_stage_seen(stage_id: String) -> void:
	if not _tab_container or _story_tab_index < 0:
		return
	var story_scroll := _tab_container.get_child(_story_tab_index) as ScrollContainer
	if not story_scroll:
		return
	var vbox := story_scroll.get_node_or_null("StoryList") as VBoxContainer
	if not vbox:
		return
	# Remove empty label if present
	var empty := vbox.get_node_or_null("EmptyLabel")
	if empty:
		empty.queue_free()
	var meta: Dictionary = _story_mgr.get_stage_meta(stage_id) if _story_mgr else {}
	if not meta.is_empty():
		_add_story_card(vbox, meta)

func _on_close_pressed() -> void:
	close_screen()
