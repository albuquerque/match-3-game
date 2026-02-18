extends Node
class_name ContentPackTranslationLoader

## Manages loading/unloading of content pack translations
## Keeps core translations always loaded, switches pack translations dynamically
##
## Architecture:
## - Core translations (UI, system messages) → Always loaded
## - Pack translations (narrative, characters) → Loaded per content pack

var _loaded_core: bool = false
var _current_pack: String = ""
var _pack_translations: Dictionary = {}  # locale -> Translation

const CORE_TRANSLATIONS_PATH = "res://data/translations/core/"
const CONTENT_PACKS_PATH = "res://data/content_packs/"

func _ready():
	load_core_translations()

## Load core app translations (UI, system messages, game mechanics)
## These are universal across all content packs
func load_core_translations():
	if _loaded_core:
		print("[TranslationLoader] Core translations already loaded")
		return

	print("[TranslationLoader] Loading core translations...")

	var core_locales = ["en", "es", "pt", "fr"]
	var loaded_count = 0

	for locale in core_locales:
		# Try both .po and .translation files
		var trans_path = CORE_TRANSLATIONS_PATH + "strings_%s.translation" % locale
		var po_path = CORE_TRANSLATIONS_PATH + "strings_%s.po" % locale

		var translation = null

		# Godot auto-converts .po to .translation on import
		if ResourceLoader.exists(trans_path):
			translation = load(trans_path)
		elif ResourceLoader.exists(po_path):
			translation = load(po_path)

		if translation:
			TranslationServer.add_translation(translation)
			loaded_count += 1
			print("[TranslationLoader]   ✓ Loaded core/%s" % locale)
		else:
			print("[TranslationLoader]   ⚠️  Missing core/%s" % locale)

	_loaded_core = true
	print("[TranslationLoader] Core translations loaded (%d locales)" % loaded_count)

## Load content pack translations (narrative, characters, locations, levels)
## Pack-specific content that varies between apps
func load_pack_translations(pack_id: String):
	if _current_pack == pack_id:
		print("[TranslationLoader] Pack '%s' already loaded" % pack_id)
		return

	# Unload previous pack if exists
	if _current_pack != "":
		unload_pack_translations()

	print("[TranslationLoader] Loading pack translations: %s" % pack_id)

	var pack_trans_path = CONTENT_PACKS_PATH + pack_id + "/translations/"

	# Check if pack has translations folder
	if not DirAccess.dir_exists_absolute(pack_trans_path):
		print("[TranslationLoader] ⚠️  Pack has no translations folder: %s" % pack_id)
		print("[TranslationLoader]   Skipping pack translation loading")
		_current_pack = pack_id  # Still mark as current pack
		return

	var dir = DirAccess.open(pack_trans_path)
	if not dir:
		print("[TranslationLoader] ERROR: Cannot open pack translations: %s" % pack_trans_path)
		return

	var loaded_count = 0

	# Scan for all translation files in pack
	var files = dir.get_files()
	for file_name in files:
		# Look for both .po and .translation files
		if file_name.ends_with(".translation") or file_name.ends_with(".po"):
			var locale = _extract_locale_from_filename(file_name)
			var file_path = pack_trans_path + file_name

			var translation = load(file_path)
			if translation and translation is Translation:
				TranslationServer.add_translation(translation)
				_pack_translations[locale] = translation
				loaded_count += 1
				print("[TranslationLoader]   ✓ Loaded pack/%s/%s" % [pack_id, locale])

	_current_pack = pack_id
	print("[TranslationLoader] Pack translations loaded: %s (%d locales)" % [pack_id, loaded_count])

## Unload current pack translations
## Used when switching between content packs
func unload_pack_translations():
	if _current_pack == "":
		return

	print("[TranslationLoader] Unloading pack: %s" % _current_pack)

	for locale in _pack_translations:
		var translation = _pack_translations[locale]
		TranslationServer.remove_translation(translation)
		print("[TranslationLoader]   ✓ Removed %s" % locale)

	_pack_translations.clear()
	_current_pack = ""

## Extract locale code from filename
## Examples:
##   "strings_en.po" -> "en"
##   "narrative_es.po" -> "es"
##   "strings_en.translation" -> "en"
func _extract_locale_from_filename(filename: String) -> String:
	# Remove extension
	var name_only = filename.replace(".po", "").replace(".translation", "")

	# Split by underscore
	var parts = name_only.split("_")

	# Last part should be locale code
	if parts.size() >= 2:
		return parts[-1]

	# Fallback to English
	return "en"

## Get currently loaded pack ID
func get_current_pack() -> String:
	return _current_pack

## Check if a specific pack is loaded
func is_pack_loaded(pack_id: String) -> bool:
	return _current_pack == pack_id

## Get list of available locales for current pack
func get_pack_locales() -> Array:
	return _pack_translations.keys()

## Reload current pack (useful after translation updates)
func reload_current_pack():
	if _current_pack != "":
		var pack_to_reload = _current_pack
		unload_pack_translations()
		load_pack_translations(pack_to_reload)
