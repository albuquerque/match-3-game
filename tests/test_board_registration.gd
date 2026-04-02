extends Node

func _ready():
	print("[TEST] test_board_registration starting")
	# Create a fake GameBoard stub
	var board_stub = Node.new()
	board_stub.name = "BoardStub"

	# PR 6.5c: GameManager no longer used — tests verify via GameRunState
	var gm = null

	var result = {"passed": false, "reason": "unknown"}
	if gm == null:
		result["passed"] = false
		result["reason"] = "GameManager not available"
		_write_result(result)
		get_tree().quit()
		return

	# Instantiate a local GameManager instance if necessary
	var gm_inst = null
	if typeof(gm) == TYPE_OBJECT and gm != null and gm is Node:
		# If gm is a node instance (autoload), use it
		gm_inst = gm
	else:
		# Try to instantiate a local GameManager from script for testing
		var gm_script_local = load("res://scripts/GameManager.gd")
		if gm_script_local:
			gm_inst = gm_script_local.new()
			# Add to scene tree so any internals relying on tree won't fail
			add_child(gm_inst)

	if gm_inst == null:
		result["passed"] = false
		result["reason"] = "Could not obtain GameManager instance"
		_write_result(result)
		get_tree().quit()
		return

	# Ensure no board registered (safe to call even if different object)
	gm_inst.unregister_board(board_stub)
	# Register the stub
	gm_inst.register_board(board_stub)
	# Verify get_board() returns the same stub
	var got = gm_inst.get_board()
	if got == board_stub:
		result["passed"] = true
		result["reason"] = "ok"
	else:
		result["passed"] = false
		result["reason"] = "get_board did not return registered stub"

	# Clean up
	if gm_inst and gm_inst.get_parent():
		remove_child(gm_inst)
	gm_inst = null
	_write_result(result)
	get_tree().quit()

func _write_result(dict_res: Dictionary):
	# Write JSON results to an absolute /tmp path for reliable host access
	var path = "/tmp/match3_test_results_board_registration.json"
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dict_res))
		f.close()
		print("[TEST] Wrote results to ", path)
	else:
		print("[TEST] Failed to open ", path)
