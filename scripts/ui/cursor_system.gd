class_name CursorSystem
extends RefCounted

const SELECT := &"select"
const UI_ACTION := &"ui_action"
const BOX_SELECT := &"box_select"
const MOVE := &"move"
const ATTACK := &"attack"
const ATTACK_MOVE := &"attack_move"
const PATROL := &"patrol"
const RALLY := &"rally"
const GATHER_JADE := &"gather_jade"
const GATHER_LUMBER := &"gather_lumber"
const GATHER_ESSENCE := &"gather_essence"
const HUNT := &"hunt"
const DEPOSIT := &"deposit"
const REPAIR := &"repair"
const BUILD := &"build"
const FORBIDDEN := &"forbidden"
const PAN := &"pan"

const ORDER: Array[StringName] = [
	SELECT,
	UI_ACTION,
	BOX_SELECT,
	MOVE,
	ATTACK,
	ATTACK_MOVE,
	PATROL,
	RALLY,
	GATHER_JADE,
	GATHER_LUMBER,
	GATHER_ESSENCE,
	HUNT,
	DEPOSIT,
	REPAIR,
	BUILD,
	FORBIDDEN,
	PAN,
]

const DEFINITIONS := {
	SELECT: {
		"shape": Input.CURSOR_ARROW,
		"texture": preload("res://assets/runtime/cursors/select.png"),
		"hotspot": Vector2(3.0, 3.0),
		"label_key": &"cursor.select",
	},
	UI_ACTION: {
		"shape": Input.CURSOR_POINTING_HAND,
		"texture": preload("res://assets/runtime/cursors/ui_action.png"),
		"hotspot": Vector2(20.0, 4.0),
		"label_key": &"cursor.activate",
	},
	BOX_SELECT: {
		"shape": Input.CURSOR_CROSS,
		"texture": preload("res://assets/runtime/cursors/box_select.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.box_select",
	},
	MOVE: {
		"shape": Input.CURSOR_MOVE,
		"texture": preload("res://assets/runtime/cursors/move.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.move",
	},
	ATTACK: {
		"shape": Input.CURSOR_BDIAGSIZE,
		"texture": preload("res://assets/runtime/cursors/attack.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.attack",
	},
	ATTACK_MOVE: {
		"shape": Input.CURSOR_FDIAGSIZE,
		"texture": preload("res://assets/runtime/cursors/attack_move.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.attack_move",
	},
	PATROL: {
		"shape": Input.CURSOR_HSPLIT,
		"texture": preload("res://assets/runtime/cursors/patrol.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.patrol",
	},
	RALLY: {
		"shape": Input.CURSOR_VSPLIT,
		"texture": preload("res://assets/runtime/cursors/rally.png"),
		"hotspot": Vector2(32.0, 49.0),
		"label_key": &"cursor.rally",
	},
	GATHER_JADE: {
		"shape": Input.CURSOR_HSIZE,
		"texture": preload("res://assets/runtime/cursors/gather_jade.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.gather_jade",
	},
	GATHER_LUMBER: {
		"shape": Input.CURSOR_VSIZE,
		"texture": preload("res://assets/runtime/cursors/gather_lumber.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.gather_lumber",
	},
	GATHER_ESSENCE: {
		"shape": Input.CURSOR_IBEAM,
		"texture": preload("res://assets/runtime/cursors/gather_essence.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.gather_essence",
	},
	HUNT: {
		"shape": Input.CURSOR_HELP,
		"texture": preload("res://assets/runtime/cursors/hunt.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.hunt",
	},
	DEPOSIT: {
		"shape": Input.CURSOR_CAN_DROP,
		"texture": preload("res://assets/runtime/cursors/deposit.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.deposit",
	},
	REPAIR: {
		"shape": Input.CURSOR_BUSY,
		"texture": preload("res://assets/runtime/cursors/repair.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.repair",
	},
	BUILD: {
		"shape": Input.CURSOR_WAIT,
		"texture": preload("res://assets/runtime/cursors/build.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.build",
	},
	FORBIDDEN: {
		"shape": Input.CURSOR_FORBIDDEN,
		"texture": preload("res://assets/runtime/cursors/forbidden.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.forbidden",
	},
	PAN: {
		"shape": Input.CURSOR_DRAG,
		"texture": preload("res://assets/runtime/cursors/pan.png"),
		"hotspot": Vector2(32.0, 32.0),
		"label_key": &"cursor.pan",
	},
}

static var _installed := false
static var _suspended := false


static func install() -> void:
	if _installed or _suspended:
		return
	for state in ORDER:
		var definition := DEFINITIONS[state] as Dictionary
		Input.set_custom_mouse_cursor(
			definition["texture"] as Texture2D,
			int(definition["shape"]) as Input.CursorShape,
			definition["hotspot"] as Vector2,
		)
	_installed = true


static func suspend() -> void:
	if _suspended:
		return
	_suspended = true
	for state in ORDER:
		Input.set_custom_mouse_cursor(null, shape_for(state))
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_installed = false


static func resume() -> void:
	_suspended = false
	install()


static func is_installed() -> bool:
	return _installed


static func is_suspended() -> bool:
	return _suspended


static func apply(control: Control, state: StringName) -> void:
	if control == null:
		return
	control.mouse_default_cursor_shape = int(shape_for(state)) as Control.CursorShape


static func shape_for(state: StringName) -> Input.CursorShape:
	var definition := DEFINITIONS.get(state, DEFINITIONS[SELECT]) as Dictionary
	return int(definition["shape"]) as Input.CursorShape


static func texture_for(state: StringName) -> Texture2D:
	var definition := DEFINITIONS.get(state, DEFINITIONS[SELECT]) as Dictionary
	return definition["texture"] as Texture2D


static func label_for(state: StringName) -> String:
	var definition := DEFINITIONS.get(state, DEFINITIONS[SELECT]) as Dictionary
	return I18n.t(definition["label_key"] as StringName)
