class_name I18n
extends Node

## Presentation-only localization service. Gameplay state stores stable identifiers;
## player-facing copy is resolved only when the presentation layer renders it.

const DEFAULT_LOCALE := &"en-US"
const SUPPORTED_LOCALES: Array[StringName] = [&"en-US", &"zh-CN"]
const CATALOG_DIRECTORY := "res://localization"

static var _locale := DEFAULT_LOCALE
static var _catalogs: Dictionary = {}


func _ready() -> void:
	if not reload_catalogs():
		push_error("I18n: localization catalogs failed validation")
		return
	_activate_locale(DEFAULT_LOCALE)


static func t(key: StringName, placeholder_values: Dictionary = {}) -> String:
	var locale_entries := _catalogs.get(_locale, {}) as Dictionary
	var english_entries := _catalogs.get(DEFAULT_LOCALE, {}) as Dictionary
	var template := String(locale_entries.get(String(key), english_entries.get(String(key), "")))
	if template.is_empty():
		push_error("I18n: missing localization key %s" % key)
		return "[%s]" % key
	var required := _placeholder_names(template)
	var provided: Array[String] = []
	for raw_name: Variant in placeholder_values:
		provided.append(String(raw_name))
	provided.sort()
	if provided != required:
		push_error(
			"I18n: placeholder mismatch for %s; expected %s, received %s"
			% [key, required, provided]
		)
		return template
	for name: String in required:
		var value: Variant = placeholder_values.get(name, placeholder_values.get(StringName(name)))
		template = template.replace("{%s}" % name, str(value))
	return template


static func locale() -> StringName:
	return _locale


static func supported_locales() -> PackedStringArray:
	var result := PackedStringArray()
	for locale_id: StringName in SUPPORTED_LOCALES:
		result.append(String(locale_id))
	return result


static func set_locale(locale_id: StringName) -> bool:
	if locale_id not in SUPPORTED_LOCALES or not _catalogs.has(locale_id):
		return false
	if _locale == locale_id:
		return true
	_activate_locale(locale_id)
	return true


static func reload_catalogs() -> bool:
	var next_catalogs: Dictionary = {}
	var english_keys := PackedStringArray()
	var english_placeholders: Dictionary = {}
	for locale_id: StringName in SUPPORTED_LOCALES:
		var path := "%s/%s.json" % [CATALOG_DIRECTORY, locale_id]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("I18n: cannot open catalog %s" % path)
			return false
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary:
			push_error("I18n: invalid JSON catalog %s" % path)
			return false
		var root := parsed as Dictionary
		if String(root.get("locale", "")) != String(locale_id):
			push_error("I18n: locale metadata mismatch in %s" % path)
			return false
		var entries_value: Variant = root.get("entries")
		if not entries_value is Dictionary:
			push_error("I18n: missing entries object in %s" % path)
			return false
		var entries := entries_value as Dictionary
		var keys := PackedStringArray()
		for raw_key: Variant in entries:
			var key := String(raw_key)
			var value: Variant = entries[raw_key]
			if not value is String or String(value).is_empty():
				push_error("I18n: invalid value for %s in %s" % [key, path])
				return false
			keys.append(key)
		keys.sort()
		if locale_id == DEFAULT_LOCALE:
			english_keys = keys
			for key: String in keys:
				english_placeholders[key] = _placeholder_names(String(entries[key]))
		elif keys != english_keys:
			push_error("I18n: catalog key parity failed for %s" % locale_id)
			return false
		else:
			for key: String in keys:
				if _placeholder_names(String(entries[key])) != english_placeholders[key]:
					push_error("I18n: placeholder parity failed for %s.%s" % [locale_id, key])
					return false
		next_catalogs[locale_id] = entries.duplicate(true)
	_catalogs = next_catalogs
	if not _catalogs.has(_locale):
		_locale = DEFAULT_LOCALE
	return true


static func catalog_keys(locale_id: StringName = &"") -> PackedStringArray:
	var requested := _locale if locale_id.is_empty() else locale_id
	var entries := _catalogs.get(requested, {}) as Dictionary
	var keys := PackedStringArray()
	for raw_key: Variant in entries:
		keys.append(String(raw_key))
	keys.sort()
	return keys


static func _placeholder_names(template: String) -> Array[String]:
	var regex := RegEx.create_from_string("\\{([A-Za-z][A-Za-z0-9_]*)\\}")
	var result: Array[String] = []
	for match_result: RegExMatch in regex.search_all(template):
		var name := match_result.get_string(1)
		if name not in result:
			result.append(name)
	result.sort()
	return result


static func _activate_locale(locale_id: StringName) -> void:
	_locale = locale_id
	TranslationServer.set_locale(String(locale_id))
	DisplayServer.window_set_title(t(&"ui.game_title"))
