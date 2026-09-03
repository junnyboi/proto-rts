extends SceneTree

const STORE_SCRIPT := preload("res://scripts/services/leaderboard_store.gd")
const BRIDGE_SCRIPT := preload("res://scripts/services/leaderboard_bridge.gd")


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var failures: Array[String] = []
	var save_path := "user://leaderboard_test_%d.json" % Time.get_ticks_usec()
	_cleanup(save_path)
	var store := STORE_SCRIPT.new() as LeaderboardStore
	root.add_child(store)
	store.setup(save_path)
	_verify_profile_and_callsign(store, failures)
	_verify_legacy_placeholder_migration(failures)
	_verify_ranking(store, failures)
	_verify_history_bound(store, failures)
	_verify_persistence_and_recovery(store, save_path, failures)
	_verify_bridge_sanitization(store, failures)
	root.remove_child(store)
	store.free()
	_cleanup(save_path)

	if failures.is_empty():
		print("PASS leaderboard_test: profile persistence, callsigns, ranking, bounded history, recovery, privacy, and bridge sanitization")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_profile_and_callsign(store: LeaderboardStore, failures: Array[String]) -> void:
	var profile := store.snapshot()
	_expect(String(profile.get("anonymous_profile_id", "")).length() == 32, "fresh profile did not create a 128-bit anonymous ID", failures)
	var placeholder_name := store.callsign()
	var placeholder_pattern := RegEx.create_from_string("^Forgotten One - [A-F0-9]{3}$")
	_expect(placeholder_pattern.search(placeholder_name) != null, "fresh profile did not create a Forgotten One placeholder name", failures)
	var original := store.callsign()
	_expect(not store.set_callsign("x").is_empty(), "short callsign was accepted", failures)
	_expect(store.callsign() == original, "invalid callsign mutated the profile", failures)
	_expect(not store.set_callsign("INVALID!CALLSIGN").is_empty(), "punctuated callsign was accepted", failures)
	_expect(store.set_callsign("JADE GENERAL") == "", "valid callsign was rejected", failures)
	_expect(store.callsign() == "JADE GENERAL", "valid callsign was not persisted in memory", failures)


func _verify_legacy_placeholder_migration(failures: Array[String]) -> void:
	var migration_path := "user://leaderboard_migration_test_%d.json" % Time.get_ticks_usec()
	_cleanup(migration_path)
	var legacy_store := STORE_SCRIPT.new() as LeaderboardStore
	root.add_child(legacy_store)
	legacy_store.setup(migration_path)
	legacy_store.set_callsign("MERIDIAN-E828")
	root.remove_child(legacy_store)
	legacy_store.free()

	var migrated_store := STORE_SCRIPT.new() as LeaderboardStore
	root.add_child(migrated_store)
	migrated_store.setup(migration_path)
	_expect(migrated_store.callsign() == "Forgotten One - E82", "legacy placeholder name was not migrated", failures)
	root.remove_child(migrated_store)
	migrated_store.free()
	_cleanup(migration_path)


func _verify_ranking(store: LeaderboardStore, failures: Array[String]) -> void:
	store.record_match(1000, &"victory", &"human", 300)
	store.record_match(400, &"defeat", &"beast", 100)
	store.record_match(1000, &"defeat", &"celestial", 180)
	var rows := store.local_leaderboard(10)
	_expect(rows.size() == 3, "local leaderboard omitted completed matches", failures)
	if rows.size() == 3:
		_expect(int(rows[0]["score"]) == 1000 and int(rows[0]["elapsed_seconds"]) == 180, "equal scores were not ranked by faster completion", failures)
		_expect(int(rows[1]["score"]) == 1000 and int(rows[1]["elapsed_seconds"]) == 300, "slower tied score did not rank second", failures)
		_expect(int(rows[2]["score"]) == 400, "lower score did not rank last", failures)
		_expect(int(rows[0]["rank"]) == 1 and int(rows[2]["rank"]) == 3, "local rank numbers were not assigned", failures)
		_expect(String(rows[0]["callsign"]) == "JADE GENERAL", "local rows did not use the current callsign", failures)
	var public_profile := store.public_profile("test-revision")
	_expect(not public_profile.has("run_history"), "public profile leaked local match history", failures)
	_expect(not public_profile.has("runHistory"), "public profile leaked local match history", failures)
	_expect(int(public_profile.get("bestScore", 0)) == 1000, "public profile did not expose the lifetime best score", failures)


func _verify_history_bound(store: LeaderboardStore, failures: Array[String]) -> void:
	for index in range(LeaderboardStore.MAX_HISTORY + 5):
		store.record_match(index, &"defeat", &"demon", index + 1)
	var profile := store.snapshot()
	var history := profile.get("run_history", []) as Array
	_expect(history.size() == LeaderboardStore.MAX_HISTORY, "local run history exceeded its retention limit", failures)
	_expect(int(profile.get("total_matches", 0)) == LeaderboardStore.MAX_HISTORY + 8, "lifetime match count was truncated with run history", failures)
	_expect(int(profile.get("best_score", 0)) == 1000, "history trimming changed the lifetime best score", failures)


func _verify_persistence_and_recovery(store: LeaderboardStore, save_path: String, failures: Array[String]) -> void:
	var expected := store.snapshot()
	var restored := STORE_SCRIPT.new() as LeaderboardStore
	root.add_child(restored)
	restored.setup(save_path)
	_expect(restored.callsign() == "JADE GENERAL", "callsign did not survive a store reload", failures)
	_expect(int(restored.snapshot().get("total_matches", 0)) == int(expected.get("total_matches", -1)), "lifetime totals did not survive a store reload", failures)
	var corrupt := FileAccess.open(save_path, FileAccess.WRITE)
	if corrupt == null:
		failures.append("test could not corrupt the primary save to verify backup recovery")
	else:
		corrupt.store_string("not-json")
		corrupt.close()
		var recovered := STORE_SCRIPT.new() as LeaderboardStore
		root.add_child(recovered)
		recovered.setup(save_path)
		_expect(recovered.callsign() == "JADE GENERAL", "store did not recover a corrupt primary save from backup", failures)
		root.remove_child(recovered)
		recovered.free()
	root.remove_child(restored)
	restored.free()


func _verify_bridge_sanitization(store: LeaderboardStore, failures: Array[String]) -> void:
	var bridge := BRIDGE_SCRIPT.new() as LeaderboardBridge
	root.add_child(bridge)
	bridge.setup(store)
	_expect(bridge.state == &"native_local", "native bridge did not enter explicit local mode", failures)
	bridge._pending["valid"] = {"type": &"list", "deadline": 99_999_999.0}
	var raw_rows: Array = []
	for index in range(LeaderboardBridge.MAX_RESPONSE_ROWS + 5):
		raw_rows.append({
			"rank": index + 1,
			"callsign": "BAD\nNAME" if index == 1 else "PLAYER-%02d-LONG-LONG-LONG" % index,
			"score": -10 if index == 0 else index * 10,
			"victories": index,
			"faction": "human" if index % 2 == 0 else "invalid",
		})
	bridge._handle_response({
		"channel": LeaderboardBridge.CHANNEL,
		"version": LeaderboardBridge.PROTOCOL_VERSION,
		"requestId": "valid",
		"ok": true,
		"payload": {
			"entries": raw_rows,
			"personalRank": {"rank": 7, "score": 1234},
		},
	})
	_expect(bridge.state == &"online", "valid global response did not enter online state", failures)
	_expect(bridge.entries.size() == LeaderboardBridge.MAX_RESPONSE_ROWS, "global response row cap was not enforced", failures)
	if not bridge.entries.is_empty():
		_expect(int(bridge.entries[0]["score"]) == 0, "negative global score was not clamped", failures)
		_expect(String(bridge.entries[0]["callsign"]).length() <= LeaderboardStore.MAX_CALLSIGN_LENGTH, "global callsign was not length-limited", failures)
		_expect(String(bridge.entries[1]["callsign"]) == "UNKNOWN", "invalid global callsign characters were not sanitized", failures)
		_expect(String(bridge.entries[1]["faction"]) == "unknown", "unknown global faction was not sanitized", failures)
	_expect(int(bridge.personal_rank.get("rank", 0)) == 7, "personal global rank was not accepted", failures)
	var previous_entries := bridge.entries.duplicate(true)
	bridge._handle_response({
		"channel": LeaderboardBridge.CHANNEL,
		"version": LeaderboardBridge.PROTOCOL_VERSION,
		"requestId": "stale",
		"ok": true,
		"payload": {"entries": []},
	})
	_expect(bridge.entries == previous_entries, "uncorrelated global response changed visible rankings", failures)
	root.remove_child(bridge)
	bridge.free()


func _cleanup(save_path: String) -> void:
	for path in [save_path, "%s.bak" % save_path, "%s.tmp" % save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
