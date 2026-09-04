class_name TweakService
extends Node

signal values_changed
signal status_changed(status: StringName)
signal run_integrity_changed(eligible: bool, marker: String)

const CATALOG := preload("res://config/tweaks/catalog.gd")
const SCHEMA_VERSION := 1
const SAVE_PATH := "user://mandate_of_myth_tweaks.json"

var _save_path := SAVE_PATH
var _requested: Dictionary = {}
var _active: Dictionary = {}
var _run_active := false
var _run_tainted := false
var _run_tainted_ids: Dictionary = {}


func setup(custom_save_path: String = SAVE_PATH) -> void:
	_save_path = custom_save_path
	var catalog_errors := CATALOG.validation_errors()
	assert(catalog_errors.is_empty(), "Invalid tweak catalog: %s" % "; ".join(catalog_errors))
	_requested = CATALOG.defaults()
	_active = CATALOG.defaults()
	_load_persisted_values()
	_activate_boundary(CATALOG.LIVE, false)
	_emit_state()


func requested_values() -> Dictionary:
	return _requested.duplicate(true)


func active_values() -> Dictionary:
	return _active.duplicate(true)


func requested_value(id: StringName) -> Variant:
	var descriptor := CATALOG.descriptor(id)
	return _requested.get(id, descriptor.get("default"))


func active_value(id: StringName) -> Variant:
	var descriptor := CATALOG.descriptor(id)
	return _active.get(id, descriptor.get("default"))


func set_requested(id: StringName, value: Variant) -> bool:
	var descriptor := CATALOG.descriptor(id)
	if descriptor.is_empty():
		return false
	var validation := _validated_value(descriptor, value)
	if not bool(validation.get("ok", false)):
		status_changed.emit(&"invalid")
		return false
	var normalized: Variant = validation["value"]
	if _same_value(_requested.get(id), normalized):
		return true
	_requested[id] = normalized
	if descriptor["apply_mode"] == CATALOG.LIVE:
		_activate_descriptor(descriptor, true)
	_save_persisted_values()
	_emit_state()
	return true


func reset_control(id: StringName) -> bool:
	var descriptor := CATALOG.descriptor(id)
	if descriptor.is_empty():
		return false
	return set_requested(id, descriptor["default"])


func reset_all() -> void:
	var changed := false
	for descriptor: Dictionary in CATALOG.DESCRIPTORS:
		var id := descriptor["id"] as StringName
		if not _same_value(_requested.get(id), descriptor["default"]):
			_requested[id] = descriptor["default"]
			changed = true
		if descriptor["apply_mode"] == CATALOG.LIVE:
			_activate_descriptor(descriptor, true)
	if not changed:
		return
	_save_persisted_values()
	_emit_state()


func apply_boundary(mode: StringName) -> Array[StringName]:
	if mode not in CATALOG.APPLY_MODES:
		return []
	return _activate_boundary(mode, true)


func begin_run() -> void:
	_run_active = true
	_run_tainted = false
	_run_tainted_ids.clear()
	_activate_boundary(CATALOG.NEXT_RUN, true)
	for descriptor: Dictionary in CATALOG.DESCRIPTORS:
		var id := descriptor["id"] as StringName
		if (
			descriptor["integrity"] != CATALOG.COSMETIC
			and not _same_value(_active.get(id), descriptor["default"])
		):
			_taint(id)
	_emit_integrity()


func end_run() -> void:
	_run_active = false
	_run_tainted = false
	_run_tainted_ids.clear()
	_emit_integrity()


func run_is_rank_eligible() -> bool:
	return not _run_tainted


func is_run_active() -> bool:
	return _run_active


func run_configuration_marker() -> String:
	if not _run_tainted:
		return "baseline"
	var ids := PackedStringArray()
	for raw_id: Variant in _run_tainted_ids:
		ids.append(String(raw_id))
	ids.sort()
	return "tweaked:%s" % ",".join(ids)


func pending_count() -> int:
	var result := 0
	for descriptor: Dictionary in CATALOG.DESCRIPTORS:
		var id := descriptor["id"] as StringName
		if not _same_value(_requested.get(id), _active.get(id)):
			result += 1
	return result


func pending_for(mode: StringName) -> int:
	var result := 0
	for descriptor: Dictionary in CATALOG.DESCRIPTORS:
		if descriptor["apply_mode"] != mode:
			continue
		var id := descriptor["id"] as StringName
		if not _same_value(_requested.get(id), _active.get(id)):
			result += 1
	return result


func validated_persisted_deltas() -> Dictionary:
	var result := {}
	for descriptor: Dictionary in CATALOG.DESCRIPTORS:
		var id := descriptor["id"] as StringName
		var requested: Variant = _requested.get(id, descriptor["default"])
		if not _same_value(requested, descriptor["default"]):
			result[id] = requested
	return result


func _activate_boundary(mode: StringName, may_taint: bool) -> Array[StringName]:
	var applied: Array[StringName] = []
	for descriptor: Dictionary in CATALOG.DESCRIPTORS:
		if descriptor["apply_mode"] != mode:
			continue
		var id := descriptor["id"] as StringName
		if _same_value(_active.get(id), _requested.get(id)):
			continue
		_activate_descriptor(descriptor, may_taint)
		applied.append(id)
	if not applied.is_empty():
		_emit_state()
	return applied


func _activate_descriptor(descriptor: Dictionary, may_taint: bool) -> void:
	var id := descriptor["id"] as StringName
	_active[id] = _requested.get(id, descriptor["default"])
	if (
		may_taint
		and _run_active
		and descriptor["integrity"] != CATALOG.COSMETIC
		and not _same_value(_active[id], descriptor["default"])
	):
		_taint(id)


func _taint(id: StringName) -> void:
	if _run_tainted_ids.has(id):
		return
	_run_tainted = true
	_run_tainted_ids[id] = true
	_emit_integrity()


func _emit_integrity() -> void:
	run_integrity_changed.emit(run_is_rank_eligible(), run_configuration_marker())


func _emit_state() -> void:
	values_changed.emit()
	status_changed.emit(&"pending" if pending_count() > 0 else &"saved")


func _validated_value(descriptor: Dictionary, raw_value: Variant) -> Dictionary:
	match descriptor["type"]:
		&"bool":
			if raw_value is bool:
				return {"ok": true, "value": raw_value}
		&"int":
			if raw_value is int or raw_value is float:
				var value := int(round(float(raw_value)))
				if value >= int(descriptor["min"]) and value <= int(descriptor["max"]):
					return {"ok": true, "value": value}
		&"float":
			if raw_value is int or raw_value is float:
				var value := float(raw_value)
				if not is_finite(value) or value < float(descriptor["min"]) or value > float(descriptor["max"]):
					return {"ok": false}
				var step := float(descriptor.get("step", 0.0))
				if step > 0.0:
					value = snappedf(value, step)
				value = clampf(value, float(descriptor["min"]), float(descriptor["max"]))
				return {"ok": true, "value": value}
		&"enum":
			var value := StringName(raw_value)
			if value in descriptor.get("options", []):
				return {"ok": true, "value": value}
	return {"ok": false}


func _same_value(left: Variant, right: Variant) -> bool:
	if (left is float or left is int) and (right is float or right is int):
		return is_equal_approx(float(left), float(right))
	return left == right


func _load_persisted_values() -> void:
	if not FileAccess.file_exists(_save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_save_path))
	if not (parsed is Dictionary):
		return
	var root := parsed as Dictionary
	if int(root.get("schema_version", -1)) != SCHEMA_VERSION:
		return
	var values: Variant = root.get("values", {})
	if not (values is Dictionary):
		return
	for raw_id: Variant in values:
		var id := StringName(raw_id)
		var descriptor := CATALOG.descriptor(id)
		if descriptor.is_empty():
			continue
		var validation := _validated_value(descriptor, (values as Dictionary)[raw_id])
		if bool(validation.get("ok", false)):
			_requested[id] = validation["value"]


func _save_persisted_values() -> bool:
	var temp_path := "%s.tmp" % _save_path
	var temp := FileAccess.open(temp_path, FileAccess.WRITE)
	if temp == null:
		push_warning("Tweak settings could not be opened for writing: %s" % temp_path)
		return false
	temp.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"values": validated_persisted_deltas(),
	}, "\t"))
	temp.flush()
	temp.close()
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_save := ProjectSettings.globalize_path(_save_path)
	if FileAccess.file_exists(_save_path):
		DirAccess.remove_absolute(absolute_save)
	var replace_error := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if replace_error != OK:
		push_warning("Tweak settings replacement failed: %s" % error_string(replace_error))
		return false
	return true
