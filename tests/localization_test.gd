extends SceneTree

const PRODUCTION_SOURCES := [
	"res://scripts/main.gd",
	"res://scripts/ui/hud_command_button.gd",
	"res://scripts/ui/leaderboard_dialog.gd",
	"res://scripts/view/battlefield.gd",
	"res://scripts/view/battlefield_minimap.gd",
]

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var localization := root.get_node_or_null("Localization")
	_expect(localization != null, "localization autoload is unavailable", failures)
	if localization == null:
		quit(1)
		return
	_expect(I18n.reload_catalogs(), "localization catalogs failed parity validation", failures)
	var english_keys := I18n.catalog_keys(&"en-US")
	var chinese_keys := I18n.catalog_keys(&"zh-CN")
	_expect(not english_keys.is_empty(), "English catalog is empty", failures)
	_expect(english_keys == chinese_keys, "English and Chinese catalogs do not have matching keys", failures)

	_expect(I18n.set_locale(&"en-US"), "English locale could not be activated", failures)
	_expect(I18n.t(&"ui.hud.score", {"score": 7}) == "SCORE: 7", "English placeholder interpolation failed", failures)
	_expect(I18n.set_locale(&"zh-CN"), "Chinese locale could not be activated", failures)
	var chinese_score := I18n.t(&"ui.hud.score", {"score": 7})
	_expect(chinese_score.contains("分数") and chinese_score.contains("7"), "Chinese lookup or placeholder interpolation failed", failures)
	_expect(I18n.t(&"ui.title.start") == "开始游戏", "Chinese title action did not resolve", failures)

	var chinese_entries_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://localization/zh-CN.json")
	)
	_expect(chinese_entries_value is Dictionary, "Chinese catalog could not be parsed for font coverage", failures)
	if chinese_entries_value is Dictionary:
		var entries := (chinese_entries_value as Dictionary).get("entries", {}) as Dictionary
		var font := ThemeFactory.CJK_FONT
		_expect(font != null, "bundled Chinese font is unavailable", failures)
		if font != null:
			for codepoint: int in _required_codepoints(entries):
				if codepoint >= 0x2E80:
					_expect(
						font.has_char(codepoint),
						"bundled Chinese font lacks U+%04X '%s'" % [codepoint, String.chr(codepoint)],
						failures,
					)
	var theme := ThemeFactory.create()
	_expect(theme.default_font != null and theme.default_font.has_char("中".unicode_at(0)), "runtime UI theme lacks Chinese glyph coverage", failures)
	if chinese_entries_value is Dictionary and theme.default_font != null:
		var entries := (chinese_entries_value as Dictionary).get("entries", {}) as Dictionary
		for codepoint: int in _required_codepoints(entries):
			_expect(theme.default_font.has_char(codepoint), "runtime font chain lacks U+%04X" % codepoint, failures)

	var catalog_lookup := {}
	for key: String in english_keys:
		catalog_lookup[StringName(key)] = true
	var literal_key_regex := RegEx.create_from_string(r'I18n\.t\(&"([^"]+)"')
	for path: String in PRODUCTION_SOURCES:
		var source := FileAccess.get_file_as_string(path)
		for key_match: RegExMatch in literal_key_regex.search_all(source):
			var used_key := StringName(key_match.get_string(1))
			_expect(catalog_lookup.has(used_key), "localized source key is missing: %s in %s" % [used_key, path], failures)
	for faction_id: StringName in FactionCatalog.ORDER:
		var definition := FactionCatalog.definition(faction_id)
		for field: StringName in [&"name", &"epithet", &"identity", &"passive"]:
			var key := FactionCatalog.faction_text_key(faction_id, field)
			_expect(catalog_lookup.has(key), "faction display key is missing: %s" % key, failures)
			_expect(not definition.has(String(field)), "faction catalog retained localized prose in '%s'" % field, failures)
	for kind: StringName in FactionCatalog.BASE_STATS:
		var stats := FactionCatalog.BASE_STATS[kind] as Dictionary
		for field: StringName in [&"name", &"role"]:
			var key := FactionCatalog.entity_text_key(kind, field)
			_expect(catalog_lookup.has(key), "entity display key is missing: %s" % key, failures)
			_expect(not stats.has(String(field)), "entity catalog retained localized prose in '%s'" % field, failures)

	_audit_player_copy_literals(failures)
	await _verify_title_toggle(failures)
	I18n.set_locale(&"en-US")
	if failures.is_empty():
		print("PASS localization_test: catalog parity, placeholders, display-key audit, title toggle, and Chinese font coverage")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _required_codepoints(entries: Dictionary) -> Array[int]:
	var unique := {}
	for raw_value: Variant in entries.values():
		var value := String(raw_value)
		for index: int in value.length():
			var codepoint := value.unicode_at(index)
			if codepoint >= 32 and codepoint != 127:
				unique[codepoint] = true
	var result: Array[int] = []
	for raw_codepoint: Variant in unique:
		result.append(int(raw_codepoint))
	result.sort()
	return result


func _audit_player_copy_literals(failures: Array[String]) -> void:
	var creation_regex := RegEx.create_from_string(
		'(?:ThemeFactory\\.(?:label|button|icon_button)|feedback\\.emit|_show_feedback)\\("[A-Za-z]'
	)
	var assignment_regex := RegEx.create_from_string(
		'\\.(?:text|tooltip_text|placeholder_text)\\s*=\\s*"[A-Za-z]'
	)
	for path: String in PRODUCTION_SOURCES:
		var source := FileAccess.get_file_as_string(path)
		_expect(creation_regex.search(source) == null, "raw player-facing constructor copy remains in %s" % path, failures)
		_expect(assignment_regex.search(source) == null, "raw player-facing assignment copy remains in %s" % path, failures)
	var simulation_source := FileAccess.get_file_as_string("res://scripts/sim/rts_simulation.gd")
	var notice_regex := RegEx.create_from_string('battle_notice\\.emit\\(\\s*"')
	_expect(notice_regex.search(simulation_source) == null, "simulation still emits localized prose instead of semantic notice keys", failures)


func _verify_title_toggle(failures: Array[String]) -> void:
	I18n.set_locale(&"en-US")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	var save_path := "user://localization_test_%d.json" % Time.get_ticks_usec()
	game.leaderboard_save_path = save_path
	root.add_child(game)
	await process_frame
	var chinese_button := game._locale_buttons.get(&"zh-CN") as Button
	_expect(chinese_button != null and chinese_button.text == "中文", "title screen lacks the Chinese locale toggle", failures)
	if chinese_button != null:
		chinese_button.pressed.emit()
		await process_frame
		await process_frame
		_expect(I18n.locale() == &"zh-CN", "Chinese title toggle did not activate zh-CN", failures)
		var found_start := false
		for button: Node in game._screen.find_children("*", "Button", true, false):
			if (button as Button).text == "开始游戏":
				found_start = true
				break
		_expect(found_start, "title screen did not rebuild with Chinese copy", failures)
	var director := game.audio_director as AudioDirector
	director._music_player.stop()
	for player: AudioStreamPlayer in director._players:
		player.stop()
	await create_timer(0.15).timeout
	for player: AudioStreamPlayer in director._players:
		player.stream = null
	director._music_player.stream = null
	game.queue_free()
	await process_frame
	_cleanup(save_path)


func _cleanup(save_path: String) -> void:
	for path: String in [save_path, "%s.bak" % save_path, "%s.tmp" % save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
