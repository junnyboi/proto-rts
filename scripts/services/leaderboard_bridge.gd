class_name LeaderboardBridge
extends Node

signal state_changed(state: StringName, entries: Array, personal_rank: Dictionary)
signal callsign_sync_changed(state: StringName)

const CHANNEL := "mandate-of-myth-leaderboard"
const PROTOCOL_VERSION := 1
const REQUEST_TIMEOUT_SECONDS := 4.0
const LIST_LIMIT := 10
const MAX_RESPONSE_ROWS := 20
const MAX_SCORE := LeaderboardStore.MAX_SCORE
const RESPONSE_QUEUE := "__mandateOfMythLeaderboardResponses"

var state: StringName = &"native_local"
var entries: Array[Dictionary] = []
var personal_rank: Dictionary = {}
var _store: LeaderboardStore
var _pending: Dictionary = {}
var _request_sequence := 0
var _web_ready := false


func setup(store: LeaderboardStore) -> void:
	_store = store
	if not OS.has_feature("web"):
		_set_state(&"native_local", [], {})
		set_process(false)
		return
	_web_ready = _install_web_receiver()
	_set_state(&"offline" if _web_ready else &"error", [], {})
	set_process(_web_ready)


func request_list() -> void:
	if not _web_ready:
		_set_state(&"native_local", [], {})
		return
	_send_request(&"list", {"limit": LIST_LIMIT})


func submit_current() -> void:
	if _store == null:
		return
	if not _web_ready:
		_set_state(&"native_local", [], {})
		return
	_send_request(&"submit", _store.public_profile(_source_revision()))


func update_callsign() -> void:
	if _store == null:
		return
	if not _web_ready:
		callsign_sync_changed.emit(&"native_local")
		return
	callsign_sync_changed.emit(&"syncing")
	_send_request(&"update_callsign", {
		"anonymousProfileId": String(_store.snapshot().get("anonymous_profile_id", "")),
		"callsign": _store.callsign(),
	})


func _process(_delta: float) -> void:
	_poll_web_responses()
	var now := Time.get_ticks_msec() / 1000.0
	var timed_out: Array[String] = []
	for request_id in _pending:
		var request := _pending[request_id] as Dictionary
		if now >= float(request.get("deadline", 0.0)):
			timed_out.append(String(request_id))
	for request_id in timed_out:
		var request_type := StringName((_pending[request_id] as Dictionary).get("type", ""))
		_pending.erase(request_id)
		if request_type == &"update_callsign":
			callsign_sync_changed.emit(&"offline")
		else:
			_set_state(&"offline", [], {})


func _send_request(request_type: StringName, payload: Dictionary) -> void:
	_request_sequence += 1
	var request_id := "%d-%d" % [Time.get_ticks_msec(), _request_sequence]
	_pending[request_id] = {
		"type": request_type,
		"deadline": Time.get_ticks_msec() / 1000.0 + REQUEST_TIMEOUT_SECONDS,
	}
	if request_type != &"update_callsign":
		_set_state(&"syncing", entries, personal_rank)
	var message := {
		"channel": CHANNEL,
		"version": PROTOCOL_VERSION,
		"type": String(request_type),
		"requestId": request_id,
		"payload": payload,
	}
	var script := "window.parent.postMessage(%s, window.location.origin);" % JSON.stringify(message)
	JavaScriptBridge.eval(script)


func _install_web_receiver() -> bool:
	var script := """
(function () {
  const queueName = '%s';
  window[queueName] = window[queueName] || [];
  if (!window.__mandateOfMythLeaderboardListener) {
    window.addEventListener('message', function (event) {
      const data = event.data;
      if (event.source !== window.parent || event.origin !== window.location.origin) return;
      if (!data || data.channel !== '%s' || data.version !== %d) return;
      if (typeof data.requestId !== 'string' || typeof data.ok !== 'boolean') return;
      window[queueName].push(JSON.stringify(data));
    });
    window.__mandateOfMythLeaderboardListener = true;
  }
  return true;
})();
""" % [RESPONSE_QUEUE, CHANNEL, PROTOCOL_VERSION]
	return bool(JavaScriptBridge.eval(script))


func _poll_web_responses() -> void:
	var raw: Variant = JavaScriptBridge.eval("window.%s.shift() || '';" % RESPONSE_QUEUE)
	while raw is String and not String(raw).is_empty():
		var parsed: Variant = JSON.parse_string(String(raw))
		if parsed is Dictionary:
			_handle_response(parsed as Dictionary)
		raw = JavaScriptBridge.eval("window.%s.shift() || '';" % RESPONSE_QUEUE)


func _handle_response(response: Dictionary) -> void:
	if String(response.get("channel", "")) != CHANNEL:
		return
	if int(response.get("version", -1)) != PROTOCOL_VERSION:
		return
	var request_id := String(response.get("requestId", ""))
	if not _pending.has(request_id):
		return
	var request := _pending[request_id] as Dictionary
	var request_type := StringName(request.get("type", ""))
	_pending.erase(request_id)
	if not bool(response.get("ok", false)):
		if request_type == &"update_callsign":
			callsign_sync_changed.emit(&"error")
		else:
			_set_state(&"error", [], {})
		return
	if request_type == &"update_callsign":
		callsign_sync_changed.emit(&"online")
		return
	var payload: Variant = response.get("payload", {})
	if not (payload is Dictionary):
		_set_state(&"error", [], {})
		return
	var clean_rows := _sanitize_rows((payload as Dictionary).get("entries", []))
	var clean_personal_rank := _sanitize_personal_rank((payload as Dictionary).get("personalRank", {}))
	_set_state(&"online", clean_rows, clean_personal_rank)


func _sanitize_rows(raw_rows: Variant) -> Array[Dictionary]:
	var clean_rows: Array[Dictionary] = []
	if not (raw_rows is Array):
		return clean_rows
	for raw_row in raw_rows as Array:
		if not (raw_row is Dictionary):
			continue
		var row := raw_row as Dictionary
		var clean_callsign := String(row.get("callsign", "UNKNOWN")).strip_edges().left(LeaderboardStore.MAX_CALLSIGN_LENGTH)
		if clean_callsign.is_empty() or (_store != null and not _store.validate_callsign(clean_callsign).is_empty()):
			clean_callsign = "UNKNOWN"
		clean_rows.append({
			"rank": clampi(int(row.get("rank", clean_rows.size() + 1)), 1, 1_000_000),
			"callsign": clean_callsign,
			"score": clampi(int(row.get("score", 0)), 0, MAX_SCORE),
			"victories": clampi(int(row.get("victories", 0)), 0, MAX_SCORE),
			"faction": _sanitize_faction(String(row.get("faction", "unknown"))),
		})
		if clean_rows.size() >= MAX_RESPONSE_ROWS:
			break
	return clean_rows


func _sanitize_personal_rank(raw_rank: Variant) -> Dictionary:
	if not (raw_rank is Dictionary):
		return {}
	var rank := raw_rank as Dictionary
	var position := int(rank.get("rank", 0))
	if position <= 0:
		return {}
	return {
		"rank": clampi(position, 1, 1_000_000),
		"score": clampi(int(rank.get("score", 0)), 0, MAX_SCORE),
	}


func _sanitize_faction(value: String) -> String:
	return value if StringName(value) in FactionCatalog.ORDER else "unknown"


func _set_state(next_state: StringName, next_entries: Array, next_personal_rank: Dictionary) -> void:
	state = next_state
	entries.clear()
	for raw_entry in next_entries:
		if raw_entry is Dictionary:
			entries.append((raw_entry as Dictionary).duplicate(true))
	personal_rank = next_personal_rank.duplicate(true)
	state_changed.emit(state, entries.duplicate(true), personal_rank.duplicate(true))


func _source_revision() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "development"))
