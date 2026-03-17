extends Node
## Unit tests for GalleryManager shard logic.
## Run headless: godot --headless --path . --script tests/test_gallery_system.gd
var _passed := 0
var _failed := 0
func _ready() -> void:
	_run_all()
	print("[TestGallerySystem] Results: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)
func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  OK %s" % msg)
	else:
		_failed += 1
		print("  FAIL: %s" % msg)
func _run_all() -> void:
	print("[TestGallerySystem] Running tests...")
	_test_shard_accumulation()
	_test_unlock_trigger()
	_test_duplicate_shard_ignored_after_unlock()
	_test_weight_selection()
func _make_gallery_manager() -> Node:
	var s = load("res://scripts/progression/GalleryManager.gd")
	var gm = Node.new()
	gm.set_script(s)
	add_child(gm)
	gm._definitions = {
		"item_a": {"id": "item_a", "name": "A", "rarity": "rare", "category": "test", "shards_required": 3, "art_asset": "", "silhouette_asset": ""},
		"item_b": {"id": "item_b", "name": "B", "rarity": "common", "category": "test", "shards_required": 5, "art_asset": "", "silhouette_asset": ""		}
	gm._state = {
		"item_a": {"shards": 0, "unlocked": false},
		"item_b": {"shards": 0, "unlocked": false}
	}
	return gm
func _test_shard_accumulation() -> void:
	var gm = _make_gallery_manager()
	gm.add_shard("item_a")
	gm.add_shard("item_a")
	var prog = gm.get_progress("item_a")
	_assert(prog.shards == 2, "shard_accumulation: 2 shards after 2 adds")
	_assert(not prog.unlocked, "shard_accumulation: not unlocked at 2/3")
	gm.queue_free()
func _test_unlock_trigger() -> void:
	var gm = _make_gallery_manager()
	var unlocked_id := ""
	gm.item_unlocked.connect(func(id): unlocked_id = id)
	gm.add_shard("item_a")
	gm.add_shard("item_a")
	var result = gm.add_shard("item_a")
	_assert(result == true, "unlock_trigger: add_shard returns true on unlock")
	_assert(unlocked_id == "item_a", "unlock_trigger: item_unlocked signal fires with correct id")
	var prog = gm.get_progress("item_a")
	_assert(prog.unlocked == true, "unlock_trigger: state shows unlocked")
	gm.queue_free()
func _test_duplicate_shard_ignored_after_unlock() -> void:
	var gm = _make_gallery_manager()
	gm._state["item_a"]["shards"] = 3
	gm._state["item_a"]["unlocked"] = true
	var result = gm.add_shard("item_a")
	_assert(result == false, "duplicate_shard: returns false when already unlocked")
	_assert(gm._state["item_a"]["shards"] == 3, "duplicate_shard: shard count unchanged")
	gm.queue_free()
func _test_weight_selection() -> void:
	var s = load("res://scripts/systems/ShardDropSystem.gd")
	var sds = Node.new()
	sds.set_script(s)
	add_child(sds)
	_assert(sds._weight_for_ratio(0.95) == 10.0, "weight: >=90% gives 10")
	_assert(sds._weight_for_ratio(0.75) == 5.0, "weight: >=70% gives 5")
	_assert(sds._weight_for_ratio(0.5) == 2.0, "weight: >=30% gives 2")
	_assert(sds._weight_for_ratio(0.1) == 1.0, "weight: <30% gives 1")
	sds.queue_free()
