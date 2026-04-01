# shim intentionally does not declare a class_name to avoid hiding a real NodeResolvers autoload
# Keep this file as a plain script providing static helper functions via preload when needed.

static func _get_root_instance(name: String) -> Object:
    var ml = Engine.get_main_loop()
    if ml != null and ml is SceneTree:
        var rt = ml.root
        if rt:
            var inst = rt.get_node_or_null(name)
            if inst:
                return inst
    return null

# Generic pattern: if a full NodeResolvers autoload exists under scene root, prefer calling its helper methods.
# Otherwise, fall back to resolving common autoload names directly from the scene root.

static func _get_gm():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_gm"):
        return inst.call("_get_gm")
    return _get_root_instance("GameManager")

static func _get_pm():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_pm"):
        return inst.call("_get_pm")
    return _get_root_instance("PageManager")

static func _get_board():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_board"):
        return inst.call("_get_board")
    # Prefer GameRunState.board_ref when available instead of calling legacy GameManager.get_board
    if typeof(GameRunState) != TYPE_NIL and GameRunState.board_ref != null:
        return GameRunState.board_ref
    # fallback: try scene tree search
    return _get_root_instance("GameBoard")

static func _get_rm():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_rm"):
        return inst.call("_get_rm")
    return _get_root_instance("RewardManager")

static func _get_xd():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_xd"):
        return inst.call("_get_xd")
    return _get_root_instance("ExperienceDirector")


static func _get_am():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_am"):
        return inst.call("_get_am")
    return _get_root_instance("AudioManager")

static func _get_tm():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_tm"):
        return inst.call("_get_tm")
    return _get_root_instance("ThemeManager")

static func _get_ar():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_ar"):
        return inst.call("_get_ar")
    return _get_root_instance("AssetRegistry")

static func _get_cm():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_cm"):
        return inst.call("_get_cm")
    return _get_root_instance("CollectionManager")

static func _get_srm():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_srm"):
        return inst.call("_get_srm")
    return _get_root_instance("StarRatingManager")

static func _get_lm():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_lm"):
        return inst.call("_get_lm")
    return _get_root_instance("LevelManager")

static func _get_vam():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_vam"):
        return inst.call("_get_vam")
    return _get_root_instance("VisualAnchorManager")

static func _get_adm():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_adm"):
        return inst.call("_get_adm")
    return _get_root_instance("AdMobManager")

static func _get_vm():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_vm"):
        return inst.call("_get_vm")
    return _get_root_instance("VibrationManager")

static func _get_dlc():
    var inst = _get_root_instance("NodeResolvers")
    if inst and inst.has_method("_get_dlc"):
        return inst.call("_get_dlc")
    return _get_root_instance("DLCManager")

static func _ar_fallback(name: String) -> Object:
    # helper alias - keep backward compatibility with older code expecting _fallback_autoload
    return _get_root_instance(name)

static func _fallback_autoload(name: String) -> Object:
    # Expose simple fallback autoload resolver
    var inst = _get_root_instance(name)
    return inst
