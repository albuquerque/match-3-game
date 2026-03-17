extends PanelContainer

## GalleryItemCard — three-state display per the gallery reward architecture spec.
##
##   UNKNOWN    — no shards yet: shows "???" and a dark placeholder, no silhouette
##   DISCOVERED — at least 1 shard: shows silhouette + shard progress bar
##   UNLOCKED   — all shards collected: shows full art + "Unlocked!" label
##
## Subscribes directly to GalleryManager signals so it refreshes itself with no
## external orchestration. Disconnects cleanly in _exit_tree.

signal card_pressed(item_id: String)

enum State { UNKNOWN, DISCOVERED, UNLOCKED }

@onready var _art: TextureRect        = $ArtContainer/Art
@onready var _silhouette: TextureRect = $ArtContainer/Silhouette
@onready var _title_label: Label      = $InfoRow/Title
@onready var _progress_label: Label   = $InfoRow/Progress
@onready var _rarity_label: Label     = $InfoRow/Rarity
@onready var _click_area: Button      = $ClickArea

var _item_id: String = ""
var _item_data: Dictionary = {}
var _loaded_art_texture: Texture2D = null  # cache for art once loaded

func _ready() -> void:
	if _click_area:
		_click_area.pressed.connect(_on_pressed)
	if GalleryManager:
		GalleryManager.shard_added.connect(_on_shard_added)
		GalleryManager.item_unlocked.connect(_on_item_unlocked)

func setup(item_data: Dictionary) -> void:
	_item_data = item_data
	_item_id = str(item_data.get("id", ""))
	_refresh()

# ── State logic ────────────────────────────────────────────────────────────

func _current_state() -> State:
	var prog := GalleryManager.get_progress(_item_id)
	if prog.get("unlocked", false):
		return State.UNLOCKED
	if prog.get("discovered", false):
		return State.DISCOVERED
	return State.UNKNOWN

func _refresh() -> void:
	if _item_id.is_empty():
		return
	var prog := GalleryManager.get_progress(_item_id)
	var state := _current_state()
	var shards: int   = prog.get("shards", 0)
	var required: int = prog.get("required", int(_item_data.get("shards_required", 9)))

	match state:
		State.UNKNOWN:
			_apply_unknown()
		State.DISCOVERED:
			_apply_discovered(shards, required)
		State.UNLOCKED:
			_apply_unlocked()

func _apply_unknown() -> void:
	if _title_label:
		_title_label.text = tr("GALLERY_ITEM_UNKNOWN_TITLE")
	if _rarity_label:
		_rarity_label.text = ""
	if _progress_label:
		_progress_label.text = tr("GALLERY_NOT_DISCOVERED")
	# Show a silhouette (dark placeholder) for locked items so the card isn't blank
	if _silhouette:
		_silhouette.visible = true
		_silhouette.modulate = Color(0.15, 0.15, 0.15, 1.0)
		# Prefer item-specific silhouette if present, otherwise use the global locked placeholder
		var sil_path: String = str(_item_data.get("silhouette_asset", ""))
		if sil_path.begins_with("res://") and ResourceLoader.exists(sil_path):
			var tex = load(sil_path)
			print("[GalleryItemCard] _apply_unknown: loading silhouette for %s -> %s (type=%s)" % [_item_id, str(sil_path), typeof(tex)])
			_silhouette.texture = tex
		else:
			var placeholder_path = "res://assets/gallery/locked_placeholder.svg"
			if ResourceLoader.exists(placeholder_path):
				var p = load(placeholder_path)
				print("[GalleryItemCard] _apply_unknown: using placeholder for %s -> %s (type=%s)" % [_item_id, placeholder_path, typeof(p)])
				if p:
					_silhouette.texture = p
	# Ensure main art is hidden for UNKNOWN
	if _art:
		_art.visible = false

func _apply_discovered(shards: int, required: int) -> void:
	if _title_label:
		_title_label.text = str(_item_data.get("name", "Unknown"))
	if _rarity_label:
		_rarity_label.text = str(_item_data.get("rarity", "")).capitalize()
	if _progress_label:
		# Use tr() with formatting where possible
		_progress_label.text = tr("GALLERY_PROGRESS") % [shards, required]
	if _art:
		_art.visible = false
	# Show darkened silhouette
	if _silhouette:
		_silhouette.visible = true
		_silhouette.modulate = Color(0.3, 0.3, 0.35, 1.0)
		var sil_path: String = str(_item_data.get("silhouette_asset", ""))
		if sil_path.begins_with("res://") and ResourceLoader.exists(sil_path):
			var tex2 = load(sil_path)
			print("[GalleryItemCard] _apply_discovered: loading silhouette for %s -> %s (type=%s)" % [_item_id, str(sil_path), typeof(tex2)])
			_silhouette.texture = tex2
		else:
			var placeholder_path = "res://assets/gallery/locked_placeholder.svg"
			if ResourceLoader.exists(placeholder_path):
				var p2 = load(placeholder_path)
				print("[GalleryItemCard] _apply_discovered: using placeholder for %s -> %s (type=%s)" % [_item_id, placeholder_path, typeof(p2)])
				if p2:
					_silhouette.texture = p2

func _apply_unlocked() -> void:
	if _title_label:
		_title_label.text = str(_item_data.get("name", "Unknown"))
	if _rarity_label:
		_rarity_label.text = str(_item_data.get("rarity", "")).capitalize()
	if _progress_label:
		_progress_label.text = tr("GALLERY_UNLOCKED")
		_progress_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))

	var art_path: String = str(_item_data.get("art_asset", ""))
	var art_is_local := art_path.begins_with("res://")
	var art_available := false
	var cache_path := ""

	# Quick sync check: local res:// or cached disk image
	if art_is_local and ResourceLoader.exists(art_path):
		art_available = true
	elif art_is_local and not FileAccess.file_exists(art_path):
		art_available = false  # File missing — stay on silhouette
	elif not art_path.is_empty():
		# Remote URL — check disk cache first
		cache_path = "user://gallery_cache/" + art_path.md5_text() + ".png"
		if FileAccess.file_exists(cache_path):
			art_available = true
		else:
			art_available = false

	if art_available:
		# Synchronously use local resource or cached raster so preview/card shows immediately
		if art_is_local:
			var tex_local = load(art_path)
			if tex_local:
				_loaded_art_texture = tex_local
				if _art:
					_art.texture = tex_local
					_art.visible = true
					_art.modulate = Color.WHITE
				if _silhouette:
					_silhouette.visible = false
				# done
				return
		else:
			# Use cached file if present
			var img := Image.new()
			if img.load(ProjectSettings.globalize_path(cache_path)) == OK and not img.is_empty():
				var tcache = ImageTexture.create_from_image(img)
				_loaded_art_texture = tcache
				if _art:
					_art.texture = tcache
					_art.visible = true
					_art.modulate = Color.WHITE
				if _silhouette:
					_silhouette.visible = false
				return
	# If we reach here art is not immediately available — keep/show silhouette and start async load
	if _silhouette:
		_silhouette.visible = true
		_silhouette.modulate = Color(0.7, 0.7, 0.75, 1.0)
	# Begin async fetch which will update textures when ready
	if not art_path.is_empty():
		_load_art_async(art_path)

func _load_art_async(url: String) -> void:
	var tex: Texture2D = await GalleryImageLoader.load_image(url)
	if not is_instance_valid(self):
		return
	if tex and _art and is_instance_valid(_art):
		# Set art texture, cache locally in this card and hide silhouette
		_art.texture = tex
		_art.visible = true
		_art.modulate = Color.WHITE
		_loaded_art_texture = tex
		if _silhouette:
			_silhouette.visible = false
	else:
		# Art failed to load — fall back to brightened silhouette
		if _art:
			_art.visible = false
		if _silhouette and is_instance_valid(_silhouette):
			_silhouette.visible = true
			_silhouette.modulate = Color(0.7, 0.7, 0.75, 1.0)

# ── Signal handlers ───────────────────────────────────────────────────────

func _on_shard_added(item_id: String, _current: int, _required: int) -> void:
	if item_id == _item_id:
		_refresh()

func _on_item_unlocked(item_id: String) -> void:
	if item_id == _item_id:
		_refresh()

func _on_pressed() -> void:
	card_pressed.emit(_item_id)
	# Only open preview for fully unlocked items
	if _current_state() != State.UNLOCKED:
		return
	# If art already loaded in this card, pass it to the preview so it appears immediately
	var preloaded_tex: Texture2D = null
	if _loaded_art_texture and _loaded_art_texture is Texture2D:
		preloaded_tex = _loaded_art_texture
	elif _art and _art.visible and _art.texture:
		preloaded_tex = _art.texture
	# Debug: log whether we have a preloaded texture and its info
	if preloaded_tex:
		var rp = "<no-path>"
		if preloaded_tex is Resource and preloaded_tex.resource_path != "":
			rp = preloaded_tex.resource_path
		print("[GalleryItemCard] Opening preview for %s - preloaded texture present type=%s path=%s" % [_item_id, typeof(preloaded_tex), rp])
	else:
		print("[GalleryItemCard] Opening preview for %s - NO preloaded texture" % _item_id)
	var preview := preload("res://scripts/ui/gallery/GalleryPreview.gd").new()
	get_tree().root.add_child(preview)
	# Pass preloaded texture as second argument (optional)
	preview.open(_item_data, preloaded_tex)

func _exit_tree() -> void:
	if GalleryManager:
		if GalleryManager.shard_added.is_connected(_on_shard_added):
			GalleryManager.shard_added.disconnect(_on_shard_added)
		if GalleryManager.item_unlocked.is_connected(_on_item_unlocked):
			GalleryManager.item_unlocked.disconnect(_on_item_unlocked)
