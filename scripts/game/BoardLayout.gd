extends Node
class_name BoardLayout

# BoardLayout: visual layout and border helpers extracted from GameBoard
# Public API (static functions) so callers can delegate to these utilities.

static func calculate_responsive_layout(gameboard: Node) -> void:
    var viewport = gameboard.get_viewport()
    if not viewport:
        return
    var screen_size = viewport.get_visible_rect().size

    # Use gameboard values (GameBoard exposes these properties)
    var board_margin = gameboard.board_margin if typeof(gameboard.board_margin) != TYPE_NIL else 20.0
    var ui_top_space = 180.0
    var ui_bottom_space = 100.0

    var available_width = screen_size.x - (board_margin * 2)
    var available_height = screen_size.y - ui_top_space - ui_bottom_space - (board_margin * 2)

    var grid_w = GameManager.GRID_WIDTH
    var grid_h = GameManager.GRID_HEIGHT
    var max_tile_size_width = available_width / max(1, grid_w)
    var max_tile_size_height = available_height / max(1, grid_h)
    var tile_size = min(max_tile_size_width, max_tile_size_height)
    tile_size = max(tile_size, 50.0)

    # write back to gameboard (GameBoard defines these properties)
    gameboard.tile_size = tile_size
    var total_grid_width = grid_w * tile_size
    var total_grid_height = grid_h * tile_size
    gameboard.grid_offset = Vector2(
        (screen_size.x - total_grid_width) / 2,
        ui_top_space + (available_height - total_grid_height) / 2
    )

    # No further delegation necessary; function writes computed values back to the provided gameboard

static func setup_background(gameboard: Node) -> void:
    # Hide legacy background control if present and ensure sizes are set
    if gameboard.has_node("Background"):
        var bg = gameboard.get_node("Background")
        if bg:
            bg.visible = false

    # compute board rect if tile_size / grid_offset exist
    if not (GameManager and typeof(gameboard.tile_size) != TYPE_NIL and typeof(gameboard.grid_offset) != TYPE_NIL):
        return

    var board_size = Vector2(
        GameManager.GRID_WIDTH * gameboard.tile_size + 20,
        GameManager.GRID_HEIGHT * gameboard.tile_size + 20
    )

    if gameboard.has_node("Background"):
        var bg = gameboard.get_node("Background")
        bg.color = Color(0.2, 0.2, 0.3, 0.7)
        bg.size = board_size
        bg.position = Vector2(gameboard.grid_offset.x - 10, gameboard.grid_offset.y - 10)

    # create or refresh tile area overlay
    setup_tile_area_overlay(gameboard)

static func setup_tile_area_overlay(gameboard: Node) -> void:
    # Remove existing overlay nodes found either on the gameboard or on its parent
    if gameboard.tile_area_overlay and is_instance_valid(gameboard.tile_area_overlay):
        var p = gameboard.tile_area_overlay.get_parent()
        if p:
            p.remove_child(gameboard.tile_area_overlay)
        gameboard.tile_area_overlay.queue_free()
        gameboard.tile_area_overlay = null

    var parent = gameboard.get_parent()
    # Clean orphan overlays on parent
    if parent:
        for child in parent.get_children():
            if child and is_instance_valid(child) and child.name == "TileAreaOverlay":
                parent.remove_child(child)
                child.queue_free()

    # Also remove local orphan overlays
    for child in gameboard.get_children():
        if child and is_instance_valid(child) and child.name == "TileAreaOverlay":
            gameboard.remove_child(child)
            child.queue_free()

    # Create overlay control
    var overlay = Control.new()
    overlay.name = "TileAreaOverlay"
    overlay.z_index = -50
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

    # Guard required values
    if not (typeof(gameboard.tile_size) != TYPE_NIL and typeof(gameboard.grid_offset) != TYPE_NIL):
        # attach empty overlay and return
        if parent:
            parent.call_deferred("add_child", overlay)
        else:
            gameboard.call_deferred("add_child", overlay)
        gameboard.tile_area_overlay = overlay
        return

    for x in range(GameManager.GRID_WIDTH):
        for y in range(GameManager.GRID_HEIGHT):
            if not GameManager.is_cell_blocked(x, y):
                var tile_overlay = ColorRect.new()
                tile_overlay.color = Color(0.1, 0.15, 0.25, 0.5)
                tile_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
                var left = x * gameboard.tile_size + gameboard.grid_offset.x
                var top = y * gameboard.tile_size + gameboard.grid_offset.y
                tile_overlay.position = Vector2(left, top)
                tile_overlay.size = Vector2(gameboard.tile_size, gameboard.tile_size)
                overlay.add_child(tile_overlay)

    # Attach deferred to avoid parent-busy
    if parent:
        parent.call_deferred("add_child", overlay)
    else:
        gameboard.call_deferred("add_child", overlay)

    gameboard.tile_area_overlay = overlay

static func setup_background_image(gameboard: Node, image_path: String) -> void:
    if image_path == "":
        return
    if not ResourceLoader.exists(image_path):
        print("[BoardLayout] ERROR: Background image not found: ", image_path)
        return
    var background_rect = TextureRect.new()
    background_rect.name = "BackgroundImage"
    var texture = load(image_path)
    if not texture:
        print("[BoardLayout] ERROR: Failed to load texture: ", image_path)
        return
    background_rect.texture = texture
    background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    var vp = gameboard.get_viewport()
    var screen_size = vp.get_visible_rect().size if vp else Vector2(720,1280)
    background_rect.size = screen_size
    background_rect.position = Vector2.ZERO
    background_rect.z_index = -100
    # deferred attach to parent
    var parent = gameboard.get_parent()
    if parent:
        parent.call_deferred("add_child", background_rect)
        parent.call_deferred("move_child", background_rect, 0)
    else:
        gameboard.call_deferred("add_child", background_rect)
        gameboard.call_deferred("move_child", background_rect, 0)
    gameboard.background_sprite = background_rect

static func deferred_attach_background(gameboard: Node, background_rect: Node, parent: Node) -> void:
    if not parent or not background_rect:
        return
    parent.add_child(background_rect)
    parent.move_child(background_rect, 0)
    var existing_bg = parent.get_node_or_null("Background")
    if existing_bg and existing_bg is ColorRect:
        existing_bg.visible = false

static func draw_borders(gameboard: Node, border_container: Node, color: Color, width: float = 3.0) -> void:
    # Delegate to BorderRenderer if available - avoid accessing module-level var from static context
    var br = null
    # Try loading the renderer script resource locally
    var br_local = load("res://scripts/game/BorderRenderer.gd")
    if br_local != null:
        br = br_local
    # If br is still null, we intentionally do not reference module-level BorderRenderer here
    if br != null and br.has_method("draw_board_borders"):
        br.draw_board_borders(gameboard, border_container, GameManager, gameboard.grid_offset, gameboard.tile_size, color, width)
        return
    # Fallback: do nothing
    return
