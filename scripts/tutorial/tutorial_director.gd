class_name TutorialDirector
extends Node

signal callout_changed(callout: Dictionary)
signal tutorial_completed

const SCHEMA_VERSION := 1
const TUTORIAL_VERSION := 1
const SAVE_PATH := "user://mandate_of_myth_tutorial.json"

const STEPS: Array[Dictionary] = [
	{
		"id": &"select",
		"title_key": &"tutorial.select.title",
		"body_key": &"tutorial.select.body",
		"fallback_key": &"tutorial.select.fallback",
		"completion_event": &"select_player",
		"timeout_seconds": 30.0,
	},
	{
		"id": &"command",
		"title_key": &"tutorial.command.title",
		"body_key": &"tutorial.command.body",
		"fallback_key": &"tutorial.command.fallback",
		"completion_event": &"command_issued",
		"timeout_seconds": 45.0,
	},
	{
		"id": &"production",
		"title_key": &"tutorial.production.title",
		"body_key": &"tutorial.production.body",
		"fallback_key": &"tutorial.production.fallback",
		"completion_event": &"production_ordered",
		"timeout_seconds": 60.0,
	},
	{
		"id": &"objective",
		"title_key": &"tutorial.objective.title",
		"body_key": &"tutorial.objective.body",
		"fallback_key": &"tutorial.objective.fallback",
		"completion_event": &"objective_progressed",
		"timeout_seconds": 120.0,
	},
	{
		"id": &"pause",
		"title_key": &"tutorial.pause.title",
		"body_key": &"tutorial.pause.body",
		"fallback_key": &"tutorial.pause.fallback",
		"completion_event": &"pause_opened",
		"timeout_seconds": 45.0,
	},
]

var _save_path := SAVE_PATH
var _completed := false
var _active := false
var _step_index := 0
var _elapsed := 0.0
var _fallback_active := false
var _input_method: StringName = InputRouter.KEYBOARD_MOUSE
var _force_next_run := false


func setup(custom_save_path: String = SAVE_PATH) -> void:
	_save_path = custom_save_path
	_load()


func start_run() -> bool:
	_active = _force_next_run or not _completed
	_force_next_run = false
	_step_index = 0
	_elapsed = 0.0
	_fallback_active = false
	_emit_callout()
	return _active


func end_run() -> void:
	_active = false
	_emit_callout()


func advance(delta: float, paused: bool = false) -> void:
	if not _active or paused or delta <= 0.0 or _step_index >= STEPS.size():
		return
	_elapsed += delta
	var timeout := float(STEPS[_step_index].get("timeout_seconds", 0.0))
	if timeout > 0.0 and _elapsed >= timeout and not _fallback_active:
		_fallback_active = true
		_emit_callout()


func notify_event(event_name: StringName) -> bool:
	if not _active or _step_index >= STEPS.size():
		return false
	if STEPS[_step_index].get("completion_event", &"") != event_name:
		return false
	_step_index += 1
	_elapsed = 0.0
	_fallback_active = false
	if _step_index >= STEPS.size():
		_complete()
	else:
		_emit_callout()
	return true


func set_input_method(next_method: StringName) -> void:
	if next_method not in InputRouter.METHODS or _input_method == next_method:
		return
	_input_method = next_method
	_emit_callout()


func replay_next_run() -> void:
	_completed = false
	_force_next_run = true
	_save()


func skip() -> void:
	if _active:
		_complete()


func is_active() -> bool:
	return _active


func is_completed() -> bool:
	return _completed


func current_step_id() -> StringName:
	return STEPS[_step_index].get("id", &"") as StringName if _active and _step_index < STEPS.size() else &""


func snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"tutorial_version": TUTORIAL_VERSION,
		"completed": _completed,
		"active": _active,
		"step_index": _step_index,
		"step_id": current_step_id(),
		"fallback_active": _fallback_active,
		"input_method": _input_method,
	}


func _complete() -> void:
	_active = false
	_completed = true
	_save()
	_emit_callout()
	tutorial_completed.emit()


func _emit_callout() -> void:
	if not _active or _step_index >= STEPS.size():
		callout_changed.emit({})
		return
	var callout := STEPS[_step_index].duplicate(true)
	callout["step"] = _step_index + 1
	callout["total"] = STEPS.size()
	callout["fallback_active"] = _fallback_active
	callout["input_method"] = _input_method
	callout["input_key"] = StringName("tutorial.%s.input.%s" % [
		String(callout["id"]),
		String(_input_method),
	])
	callout_changed.emit(callout)


func _load() -> void:
	_completed = false
	if not FileAccess.file_exists(_save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	if not (parsed is Dictionary):
		return
	var data := parsed as Dictionary
	if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
		return
	if int(data.get("tutorial_version", -1)) != TUTORIAL_VERSION:
		return
	_completed = bool(data.get("completed", false))


func _save() -> void:
	var temp_path := "%s.tmp" % _save_path
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("Tutorial progress could not be saved: %s" % _save_path)
		return
	file.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"tutorial_version": TUTORIAL_VERSION,
		"completed": _completed,
		"updated_unix_time": int(Time.get_unix_time_from_system()),
	}, "\t"))
	file.close()
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path))
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path),
		ProjectSettings.globalize_path(_save_path),
	)
