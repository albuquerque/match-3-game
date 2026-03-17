extends Control

# Lightweight bridge so legacy callers that open "GalleryPage" will show the
# new GalleryScreen scene located at res://scenes/ui/gallery/gallery_screen.tscn

var gallery_scene = null
var gallery_script = null
var instantiated: Node = null

func _load_resources():
	# Try to load the packed scene first (preferred). Use load() to avoid parse-time script failures.
	var sc = load("res://scenes/ui/gallery/gallery_screen.tscn")
	if sc and typeof(sc) != TYPE_NIL:
		gallery_scene = sc
		return
	# Fallback: attempt to load the script resource at runtime (use load, not preload)
	var s = load("res://scripts/ui/gallery_screen.gd")
	if s and typeof(s) != TYPE_NIL:
		gallery_script = s

func _ready():
	_load_resources()
	# If the scene was instanced in the tscn, prefer that instance to avoid parent path warnings
	var existing = get_node_or_null("GalleryScreenInstance")
	if existing:
		instantiated = existing
		return
	existing = get_node_or_null("GalleryScreen")
	if existing:
		instantiated = existing
		return
	# If we have a packed scene, instance it; otherwise, if we have a script, attach it to a Control
	if gallery_scene:
		var inst = gallery_scene.instantiate()
		inst.name = "GalleryScreenInstance"
		call_deferred("add_child", inst)
		instantiated = inst
		return
	elif gallery_script:
		instantiated = Control.new()
		instantiated.set_script(gallery_script)
		instantiated.name = "GalleryScreen"
		call_deferred("add_child", instantiated)

func show_screen():
	if instantiated and instantiated.has_method("show_screen"):
		instantiated.call_deferred("show_screen")
	elif instantiated and instantiated is CanvasItem:
		instantiated.call_deferred("show")

func hide_screen():
	if instantiated and instantiated.has_method("hide_screen"):
		instantiated.call_deferred("hide_screen")
	elif instantiated and instantiated is CanvasItem:
		instantiated.call_deferred("hide")

func will_close():
	# forward to child if it needs to clean up
	if instantiated and instantiated.has_method("will_close"):
		instantiated.call_deferred("will_close")
	# Ensure child is queued for free to avoid lingering resources
	if instantiated and is_instance_valid(instantiated):
		instantiated.queue_free()
		instantiated = null
