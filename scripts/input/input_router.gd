class_name InputRouter
extends Node

signal method_changed(method: StringName)

const KEYBOARD_MOUSE := &"keyboard_mouse"
const GAMEPAD := &"gamepad"
const TOUCH := &"touch"
const METHODS: Array[StringName] = [KEYBOARD_MOUSE, GAMEPAD, TOUCH]
const EMULATED_MOUSE_GUARD_MS := 900

var method: StringName = KEYBOARD_MOUSE
var _last_direct_input_ms := -EMULATED_MOUSE_GUARD_MS


func observe(event: InputEvent) -> void:
	var next_method := method
	var is_direct := false
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		next_method = TOUCH
		is_direct = true
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		next_method = GAMEPAD
		is_direct = true
	elif event is InputEventKey:
		next_method = KEYBOARD_MOUSE
		is_direct = true
	elif event is InputEventMouseButton:
		next_method = KEYBOARD_MOUSE
		is_direct = true
	elif event is InputEventMouseMotion:
		if Time.get_ticks_msec() - _last_direct_input_ms < EMULATED_MOUSE_GUARD_MS:
			return
		next_method = KEYBOARD_MOUSE
	if is_direct:
		_last_direct_input_ms = Time.get_ticks_msec()
	_set_method(next_method)


func force_method(next_method: StringName) -> bool:
	if next_method not in METHODS:
		return false
	_last_direct_input_ms = Time.get_ticks_msec()
	_set_method(next_method)
	return true


func _set_method(next_method: StringName) -> void:
	if method == next_method:
		return
	method = next_method
	method_changed.emit(method)
