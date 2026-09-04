class_name LeaderboardStore
extends Node

signal profile_changed(profile: Dictionary)

const SCHEMA_VERSION := 1
const SAVE_PATH := "user://mandate_of_myth_leaderboard.json"
const MAX_HISTORY := 30
const DEFAULT_LIMIT := 10
const MAX_SCORE := 9_000_000_000
const MIN_CALLSIGN_LENGTH := 3
const MAX_CALLSIGN_LENGTH := 20
const PLACEHOLDER_NAME_PREFIX := "Forgotten One - "
const LEGACY_PLACEHOLDER_NAME_PREFIX := "MERIDIAN-"

var _save_path := SAVE_PATH
var _profile: Dictionary = {}
var _callsign_pattern := RegEx.new()
var _legacy_placeholder_pattern := RegEx.new()
var _profile_id_pattern := RegEx.new()


func setup(custom_save_path: String = SAVE_PATH) -> void:
	_save_path = custom_save_path
	_callsign_pattern.compile("^[A-Za-z0-9 _-]{%d,%d}$" % [MIN_CALLSIGN_LENGTH, MAX_CALLSIGN_LENGTH])
	_legacy_placeholder_pattern.compile("^%s[A-F0-9]{4}$" % LEGACY_PLACEHOLDER_NAME_PREFIX)
	_profile_id_pattern.compile("^[a-f0-9]{32}$")
	var loaded := _load_profile(_save_path)
	if loaded.is_empty():
		loaded = _load_profile(_backup_path())
		if not loaded.is_empty():
			_remove_file(_save_path)
	_profile = loaded if not loaded.is_empty() else _fresh_profile()
	_save_profile()
	profile_changed.emit(snapshot())


func snapshot() -> Dictionary:
	return _profile.duplicate(true)


func callsign() -> String:
	return String(_profile.get("callsign", ""))


func validate_callsign(value: String) -> String:
	var candidate := value.strip_edges()
	if candidate.length() < MIN_CALLSIGN_LENGTH:
		return "leaderboard.validation_too_short"
	if candidate.length() > MAX_CALLSIGN_LENGTH:
		return "leaderboard.validation_too_long"
	if _callsign_pattern.search(candidate) == null:
		return "leaderboard.validation_charset"
	return ""


func set_callsign(value: String) -> String:
	var candidate := value.strip_edges()
	var validation_error := validate_callsign(candidate)
	if not validation_error.is_empty():
		return validation_error
	if candidate == callsign():
		return ""
	_profile["callsign"] = candidate
	_profile["updated_unix_time"] = int(Time.get_unix_time_from_system())
	_save_profile()
	profile_changed.emit(snapshot())
	return ""


func record_match(
	score: int,
	result: StringName,
	faction: StringName,
	elapsed_seconds: int,
	rank_eligible: bool = true,
	run_configuration_marker: String = "baseline",
) -> Dictionary:
	var clean_score := clampi(score, 0, MAX_SCORE)
	var clean_result := result if result in [&"victory", &"defeat"] else &"defeat"
	var clean_faction := faction if faction in FactionCatalog.ORDER else &"unknown"
	var now := int(Time.get_unix_time_from_system())
	var next_match_number := maxi(0, int(_profile.get("total_matches", 0))) + 1
	var entry := {
		"run_id": _random_hex(12),
		"match_number": next_match_number,
		"score": clean_score,
		"result": String(clean_result),
		"faction": String(clean_faction),
		"elapsed_seconds": maxi(0, elapsed_seconds),
		"finished_unix_time": now,
		"rank_eligible": rank_eligible,
		"run_configuration_marker": run_configuration_marker.left(512),
	}
	var history := _profile.get("run_history", []) as Array
	history.append(entry)
	while history.size() > MAX_HISTORY:
		history.pop_front()
	_profile["run_history"] = history
	_profile["total_matches"] = next_match_number
	if clean_result == &"victory":
		_profile["victories"] = maxi(0, int(_profile.get("victories", 0))) + 1
	_profile["best_score"] = maxi(int(_profile.get("best_score", 0)), clean_score)
	if rank_eligible:
		_profile["best_ranked_score"] = maxi(int(_profile.get("best_ranked_score", 0)), clean_score)
	_profile["last_faction"] = String(clean_faction)
	_profile["updated_unix_time"] = now
	_save_profile()
	profile_changed.emit(snapshot())
	return entry.duplicate(true)


func local_leaderboard(limit: int = DEFAULT_LIMIT) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for raw_entry in _profile.get("run_history", []) as Array:
		var entry := (raw_entry as Dictionary).duplicate(true)
		entry["callsign"] = callsign()
		rows.append(entry)
	rows.sort_custom(_rank_before)
	if rows.size() > maxi(0, limit):
		rows.resize(maxi(0, limit))
	for index in range(rows.size()):
		rows[index]["rank"] = index + 1
	return rows


func public_profile(source_revision: String = "") -> Dictionary:
	return {
		"anonymousProfileId": String(_profile.get("anonymous_profile_id", "")),
		"callsign": callsign(),
		"bestScore": maxi(0, int(_profile.get("best_ranked_score", 0))),
		"totalMatches": maxi(0, int(_profile.get("total_matches", 0))),
		"victories": maxi(0, int(_profile.get("victories", 0))),
		"lastFaction": String(_profile.get("last_faction", "unknown")),
		"sourceRevision": source_revision.left(80),
		"updatedUnixTime": maxi(0, int(_profile.get("updated_unix_time", 0))),
	}


func _fresh_profile() -> Dictionary:
	var suffix := _random_hex(2).left(3).to_upper()
	return {
		"schema_version": SCHEMA_VERSION,
		"anonymous_profile_id": _random_hex(16),
		"callsign": "%s%s" % [PLACEHOLDER_NAME_PREFIX, suffix],
		"total_matches": 0,
		"victories": 0,
		"best_score": 0,
		"best_ranked_score": 0,
		"last_faction": "unknown",
		"run_history": [],
		"updated_unix_time": int(Time.get_unix_time_from_system()),
	}


func _load_profile(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return {}
	return _sanitize_profile(parsed as Dictionary)


func _sanitize_profile(raw: Dictionary) -> Dictionary:
	if int(raw.get("schema_version", -1)) != SCHEMA_VERSION:
		return {}
	var anonymous_profile_id := String(raw.get("anonymous_profile_id", "")).to_lower()
	if _profile_id_pattern.search(anonymous_profile_id) == null:
		return {}
	var saved_callsign := String(raw.get("callsign", "")).strip_edges()
	if not validate_callsign(saved_callsign).is_empty():
		return {}
	if _legacy_placeholder_pattern.search(saved_callsign) != null:
		saved_callsign = "%s%s" % [
			PLACEHOLDER_NAME_PREFIX,
			saved_callsign.trim_prefix(LEGACY_PLACEHOLDER_NAME_PREFIX).left(3),
		]
	var history: Array[Dictionary] = []
	var raw_history: Variant = raw.get("run_history", [])
	if raw_history is Array:
		for raw_entry in raw_history as Array:
			if raw_entry is Dictionary:
				var clean_entry := _sanitize_entry(raw_entry as Dictionary)
				if not clean_entry.is_empty():
					history.append(clean_entry)
	while history.size() > MAX_HISTORY:
		history.pop_front()
	var history_best := 0
	var history_ranked_best := 0
	var history_victories := 0
	for entry in history:
		history_best = maxi(history_best, int(entry["score"]))
		if bool(entry["rank_eligible"]):
			history_ranked_best = maxi(history_ranked_best, int(entry["score"]))
		if entry["result"] == "victory":
			history_victories += 1
	var total_matches := maxi(history.size(), clampi(int(raw.get("total_matches", history.size())), 0, MAX_SCORE))
	var legacy_ranked_best := int(raw.get("best_score", history_ranked_best))
	var saved_ranked_best := int(raw.get("best_ranked_score", legacy_ranked_best))
	return {
		"schema_version": SCHEMA_VERSION,
		"anonymous_profile_id": anonymous_profile_id,
		"callsign": saved_callsign,
		"total_matches": total_matches,
		"victories": clampi(maxi(history_victories, int(raw.get("victories", history_victories))), 0, total_matches),
		"best_score": maxi(history_best, clampi(int(raw.get("best_score", history_best)), 0, MAX_SCORE)),
		"best_ranked_score": maxi(history_ranked_best, clampi(saved_ranked_best, 0, MAX_SCORE)),
		"last_faction": _sanitize_faction(String(raw.get("last_faction", "unknown"))),
		"run_history": history,
		"updated_unix_time": maxi(0, int(raw.get("updated_unix_time", 0))),
	}


func _sanitize_entry(raw: Dictionary) -> Dictionary:
	var run_id := String(raw.get("run_id", "")).left(32)
	if run_id.is_empty():
		return {}
	var result := String(raw.get("result", "defeat"))
	if result not in ["victory", "defeat"]:
		result = "defeat"
	return {
		"run_id": run_id,
		"match_number": maxi(1, int(raw.get("match_number", 1))),
		"score": clampi(int(raw.get("score", 0)), 0, MAX_SCORE),
		"result": result,
		"faction": _sanitize_faction(String(raw.get("faction", "unknown"))),
		"elapsed_seconds": maxi(0, int(raw.get("elapsed_seconds", 0))),
		"finished_unix_time": maxi(0, int(raw.get("finished_unix_time", 0))),
		"rank_eligible": bool(raw.get("rank_eligible", true)),
		"run_configuration_marker": String(raw.get("run_configuration_marker", "baseline")).left(512),
	}


func _sanitize_faction(value: String) -> String:
	return value if StringName(value) in FactionCatalog.ORDER else "unknown"


func _save_profile() -> bool:
	var temp_path := "%s.tmp" % _save_path
	var temp := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp == null:
		push_warning("Leaderboard profile could not be opened for writing: %s" % temp_path)
		return false
	temp.store_string(JSON.stringify(_profile, "\t"))
	temp.flush()
	temp.close()
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_save := ProjectSettings.globalize_path(_save_path)
	var absolute_backup := ProjectSettings.globalize_path(_backup_path())
	if FileAccess.file_exists(_backup_path()):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(_save_path):
		var backup_error := DirAccess.rename_absolute(absolute_save, absolute_backup)
		if backup_error != OK:
			push_warning("Leaderboard profile backup failed: %s" % error_string(backup_error))
	var replace_error := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if replace_error != OK:
		push_warning("Leaderboard profile replacement failed: %s" % error_string(replace_error))
		return false
	return true


func _backup_path() -> String:
	return "%s.bak" % _save_path


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _random_hex(byte_count: int) -> String:
	var bytes := Crypto.new().generate_random_bytes(byte_count)
	var result := ""
	for byte in bytes:
		result += "%02x" % int(byte)
	return result


func _rank_before(left: Dictionary, right: Dictionary) -> bool:
	if int(left["score"]) != int(right["score"]):
		return int(left["score"]) > int(right["score"])
	if int(left["elapsed_seconds"]) != int(right["elapsed_seconds"]):
		return int(left["elapsed_seconds"]) < int(right["elapsed_seconds"])
	if int(left["finished_unix_time"]) != int(right["finished_unix_time"]):
		return int(left["finished_unix_time"]) < int(right["finished_unix_time"])
	return String(left["run_id"]) < String(right["run_id"])
