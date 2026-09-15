extends SceneTree

var failures: Array[String] = []
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _initialize() -> void:
	call_deferred("run")

func finish() -> void:
	for failure: String in failures:
		push_error(failure)
	print("PLAYER_NAME_UNICODE ", JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func clean(path: String) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

const Store := preload("res://scripts/services/leaderboard_store.gd")
const Bridge := preload("res://scripts/services/leaderboard_bridge.gd")

func run() -> void:
	var path := "user://unicode_names_%d.json" % Time.get_ticks_usec()
	var store := Store.new()
	root.add_child(store)
	store.setup(path)
	for value: String in ["张伟", "李娜", "王昊", "王𠮷", "张A", "Juń", "ABC_123-4"]:
		check(store.set_callsign(value).is_empty(), "accept " + value)
		check(store.callsign() == value, "preserve " + value)
		var restored := Store.new()
		root.add_child(restored)
		restored.setup(path)
		check(restored.callsign() == value, "persist " + value)
		var wire: Dictionary = JSON.parse_string(JSON.stringify(restored.public_profile()))
		check(wire.callsign == value, "JSON submission " + value)
		var bridge := Bridge.new()
		root.add_child(bridge)
		bridge.setup(restored)
		bridge._pending["unicode"] = {"type": &"list", "deadline": 999999999.0}
		bridge._handle_response({"channel": Bridge.CHANNEL, "version": Bridge.PROTOCOL_VERSION, "requestId": "unicode", "ok": true, "payload": {"entries": [{"callsign": wire.callsign, "rank": 1, "score": 10, "faction": "human"}]}})
		check(bridge.entries.size() == 1 and bridge.entries[0].callsign == value, "retrieved row " + value)
		bridge.free()
		restored.free()
	for value: String in ["x", "ab", "昊", "<张伟>", "张\n伟", "张\u200b伟", "\u0301AB", "王".repeat(21)]:
		check(not store.validate_callsign(value).is_empty(), "reject " + value)
	check(store.validate_callsign("𠮷".repeat(20)).is_empty(), "astral length counts codepoints")
	store.free()
	clean(path)
	finish()
