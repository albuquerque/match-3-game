extends Node

## TranslationBootstrap
## Manually loads PO files and adds them to TranslationServer
## This is a workaround until Godot Editor imports the PO files

func _ready():
	print("[TranslationBootstrap] Loading translations...")

	# Load core translations
	_load_po_file("res://data/translations/core/strings_en.po", "en")
	_load_po_file("res://data/translations/core/strings_es.po", "es")
	_load_po_file("res://data/translations/core/strings_pt.po", "pt")
	_load_po_file("res://data/translations/core/strings_fr.po", "fr")

	# Load all content pack translations (scan content_packs/*/translations/*.po)
	_load_po_files_in_dir("res://data/content_packs")

	print("[TranslationBootstrap] Translations loaded!")

func _load_po_file(path: String, locale: String):
	if not FileAccess.file_exists(path):
		print("[TranslationBootstrap] File not found: %s" % path)
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("[TranslationBootstrap] Failed to open: %s" % path)
		return

	var translation = Translation.new()
	translation.locale = locale

	var current_msgid = ""
	var current_msgstr = ""
	var in_msgid = false
	var in_msgstr = false

	while not file.eof_reached():
		var line = file.get_line().strip_edges()

		# Skip comments and empty lines
		if line.begins_with("#") or line == "":
			continue

		# Start of msgid
		if line.begins_with("msgid "):
			if current_msgid != "" and current_msgstr != "":
				# Add previous message
				translation.add_message(current_msgid, current_msgstr)

			current_msgid = _extract_string(line.substr(6))
			current_msgstr = ""
			in_msgid = true
			in_msgstr = false

		# Start of msgstr
		elif line.begins_with("msgstr "):
			current_msgstr = _extract_string(line.substr(7))
			in_msgid = false
			in_msgstr = true

		# Continuation line
		elif line.begins_with('"') and (in_msgid or in_msgstr):
			var continuation = _extract_string(line)
			if in_msgid:
				current_msgid += continuation
			elif in_msgstr:
				current_msgstr += continuation

	# Add final message
	if current_msgid != "" and current_msgstr != "":
		translation.add_message(current_msgid, current_msgstr)

	file.close()

	TranslationServer.add_translation(translation)
	print("[TranslationBootstrap] Loaded %s (%s)" % [path.get_file(), locale])

func _extract_string(line: String) -> String:
	"""Extract string content from a PO file line"""
	# Remove surrounding quotes
	if line.begins_with('"') and line.ends_with('"'):
		line = line.substr(1, line.length() - 2)

	# Unescape special characters
	line = line.replace('\\n', '\n')
	line = line.replace('\\t', '\t')
	line = line.replace('\\"', '"')
	line = line.replace('\\\\', '\\')

	return line

func _load_po_files_in_dir(root_path: String) -> void:
	# Recursively scan content packs for .po files and load them, inferring locale from filename suffix (e.g. narrative_fr.po -> fr)
	var dir = DirAccess.open(root_path)
	if not dir:
		print("[TranslationBootstrap] Content packs dir not found: %s" % root_path)
		return

	_scan_and_load(dir, root_path)

func _scan_and_load(dir: DirAccess, current_path: String) -> void:
	dir.list_dir_begin()
	while true:
		var fname = dir.get_next()
		if fname == "":
			break
		if fname == "." or fname == "..":
			continue

		var fullpath = "%s/%s" % [current_path, fname]
		if dir.current_is_dir():
			var sub = DirAccess.open(fullpath)
			if sub:
				_scan_and_load(sub, fullpath)
			continue

		# If file ends with .po, attempt to infer locale from filename and load
		if fname.to_lower().ends_with(".po"):
			var parts = fname.split("_")
			var locale = ""
			if parts.size() > 1:
				locale = parts[parts.size() - 1].replace(".po", "")
			else:
				# fallback: try filename without extension
				locale = fname.replace(".po", "")

			# Only load if we have a plausible 2-letter locale
			if locale.length() >= 2:
				_load_po_file(fullpath, locale)
			else:
				print("[TranslationBootstrap] Skipping PO with unknown locale: %s" % fname)
