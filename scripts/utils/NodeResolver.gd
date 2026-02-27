class_name NodeResolver
extends Node

# Node-resolver-first utility (minimal implementation)
# This helper prefers returning autoload singleton instances when available.
# For scene-tree lookups (e.g., MainGame/GameBoard) files should still fallback to get_node_or_null where needed.

static func resolve(name: String, path_hint: String = "") -> Node:
	# Graceful runtime-only fallback: attempt to resolve common autoloads via the SceneTree root
	var main_loop = Engine.get_main_loop()
	if main_loop != null and main_loop is SceneTree:
		var root = main_loop.root
		if root != null:
			# try direct child under root
			var candidate = root.get_node_or_null(name)
			if candidate != null:
				return candidate
			# (no '/root/<name>' literal lookups - prefer plain name)

	# Last resort: return null
	return null
