extends Node

## TranslationBootstrap
## Loads and registers all PO-based translations at runtime by parsing
## .po files directly. This avoids dependency on Godot's editor-compiled
## .translation binary files, ensuring translations work on Android and
## other platforms without requiring a re-import step in the editor.

const SUPPORTED_LOCALES := ["en", "es", "pt", "fr"]

## PO files to load: [path, locale]
const PO_FILES := [
	["res://data/translations/core/strings_en.po", "en"],
	["res://data/translations/core/strings_es.po", "es"],
	["res://data/translations/core/strings_pt.po", "pt"],
	["res://data/translations/core/strings_fr.po", "fr"],
	["res://data/content_packs/genesis/translations/narrative_en.po", "en"],
	["res://data/content_packs/genesis/translations/narrative_es.po", "es"],
	["res://data/content_packs/genesis/translations/narrative_pt.po", "pt"],
	["res://data/content_packs/genesis/translations/narrative_fr.po", "fr"],
]

func _ready():
	# Load all PO-based translations first
	_load_all_po_translations()
	# Sync locale — saved preference takes priority over OS locale
	_sync_locale()
	print("[TranslationBootstrap] Done. Active locale: %s" % TranslationServer.get_locale())


func _load_all_po_translations() -> void:
	for entry in PO_FILES:
		var path: String = entry[0]
		var locale: String = entry[1]
		var count := _load_po_file(path, locale)
		if count > 0:
			print("[TranslationBootstrap] Loaded %d keys from %s (%s)" % [count, path.get_file(), locale])
		else:
			push_warning("[TranslationBootstrap] No keys loaded from: %s" % path)


## Parse a .po file and register its translations with TranslationServer.
## Returns the number of translation keys loaded.
func _load_po_file(path: String, locale: String) -> int:
	if not FileAccess.file_exists(path):
		push_warning("[TranslationBootstrap] PO file not found: %s" % path)
		return 0

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[TranslationBootstrap] Cannot open PO file: %s" % path)
		return 0

	var translation := Translation.new()
	translation.locale = locale

	var current_msgid := ""
	var current_msgstr := ""
	var in_msgstr := false
	var count := 0

	while not file.eof_reached():
		var line := file.get_line().strip_edges()

		if line.begins_with("msgid "):
			# Save previous pair
			if current_msgid != "" and current_msgstr != "":
				translation.add_message(current_msgid, current_msgstr)
				count += 1
			current_msgid = _extract_po_string(line.substr(6))
			current_msgstr = ""
			in_msgstr = false

		elif line.begins_with("msgstr "):
			current_msgstr = _extract_po_string(line.substr(7))
			in_msgstr = true

		elif line.begins_with('"') and in_msgstr:
			# Continuation line for msgstr
			current_msgstr += _extract_po_string(line)

		elif line.begins_with('"') and not in_msgstr and current_msgid != "":
			# Continuation line for msgid
			current_msgid += _extract_po_string(line)

		elif line == "" and current_msgid != "":
			# Blank line — flush current pair
			if current_msgstr != "":
				translation.add_message(current_msgid, current_msgstr)
				count += 1
			current_msgid = ""
			current_msgstr = ""
			in_msgstr = false

	# Flush last entry if file doesn't end with blank line
	if current_msgid != "" and current_msgstr != "":
		translation.add_message(current_msgid, current_msgstr)
		count += 1

	file.close()

	if count > 0:
		TranslationServer.add_translation(translation)

	return count


## Extract the string value from a PO quoted string token.
func _extract_po_string(s: String) -> String:
	s = s.strip_edges()
	if s.begins_with('"') and s.ends_with('"'):
		s = s.substr(1, s.length() - 2)
	# Unescape common PO escape sequences
	# Process double-backslash first before other escapes
	s = s.replace("\\n", "\n")
	s = s.replace("\\t", "\t")
	s = s.replace("\\\"", "\"")
	return s


func _sync_locale() -> void:
	# 1. Try saved preference from RewardManager
	var rm = get_node_or_null("/root/RewardManager")
	if rm and "language" in rm and rm.language != "":
		var saved = rm.language.substr(0, 2).to_lower()
		print("[TranslationBootstrap] Applying saved locale preference: %s" % saved)
		TranslationServer.set_locale(saved)
		return

	# 2. Fall back to OS locale, normalised to 2-letter code
	var os_locale = OS.get_locale().substr(0, 2).to_lower()
	if os_locale in SUPPORTED_LOCALES:
		print("[TranslationBootstrap] Applying OS locale: %s" % os_locale)
		TranslationServer.set_locale(os_locale)
	else:
		print("[TranslationBootstrap] OS locale '%s' not supported, keeping 'en'" % os_locale)
		TranslationServer.set_locale("en")


## Load a compiled .translation resource file at runtime (e.g. from a DLC pack).
## Pass the full res:// or user:// path to the .translation file.
func load_translation_resource(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_warning("[TranslationBootstrap] Translation resource not found: %s" % path)
		return false
	var translation = load(path) as Translation
	if not translation:
		push_warning("[TranslationBootstrap] Failed to load translation resource: %s" % path)
		return false
	TranslationServer.add_translation(translation)
	print("[TranslationBootstrap] Loaded translation: %s (%s)" % [path.get_file(), translation.locale])
	return true


## Load a PO file at runtime (e.g. from a downloaded DLC pack).
func load_po_translation(path: String, locale: String) -> bool:
	var count := _load_po_file(path, locale)
	return count > 0

