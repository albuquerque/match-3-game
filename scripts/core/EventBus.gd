extends Node

# Central EventBus autoload for lightweight, signal-only communication.
# Register this script as an Autoload (singleton) named `EventBus` in the project settings.

signal open_page(page_name: String, params: Dictionary)
signal close_page(page_name: String)
signal progress_request_save(reason: String)
signal progress_loaded(progress)
signal gallery_opened()
signal gallery_closed()
signal achievement_unlocked(id: String)
signal language_changed(locale: String)
signal level_loaded(name: String, info: Dictionary)

# Convenience emit helpers (optional)
func emit_open_page(page_name: String, params: Dictionary = {}) -> void:
	emit_signal("open_page", page_name, params)

func emit_close_page(page_name: String) -> void:
	emit_signal("close_page", page_name)

func emit_progress_loaded(progress) -> void:
	emit_signal("progress_loaded", progress)

func emit_gallery_opened() -> void:
	emit_signal("gallery_opened")

func emit_gallery_closed() -> void:
	emit_signal("gallery_closed")

func emit_language_changed(locale: String) -> void:
	emit_signal("language_changed", locale)

func emit_level_loaded(name: String, info: Dictionary) -> void:
	emit_signal("level_loaded", name, info)
