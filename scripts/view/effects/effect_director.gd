class_name EffectDirector
extends RefCounted

const CATALOG := preload("res://scripts/view/effects/effect_catalog.gd")
const AGGREGATE_SECONDS := 0.15
const CRITICAL_AMBIENT_SUPPRESSION_SECONDS := 0.35

var particles: Array[Dictionary] = []
var trails: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var values: Array[Dictionary] = []
var traces: Array[Dictionary] = []
var pulses: Array[Dictionary] = []
var deaths: Array[Dictionary] = []
var camera_kicks: Array[Dictionary] = []

var intensity: StringName = &"full"
var reduced_motion := false
var damage_numbers: StringName = &"contextual"
var camera_impulse: StringName = &"major"
var ambient_suppression_remaining := 0.0
var _serial := 0


func configure(
	new_intensity: StringName = &"full",
	new_reduced_motion: bool = false,
	new_damage_numbers: StringName = &"contextual",
	new_camera_impulse: StringName = &"major",
) -> void:
	intensity = &"low" if new_intensity == &"low" else &"full"
	reduced_motion = new_reduced_motion
	damage_numbers = new_damage_numbers if new_damage_numbers in [&"off", &"contextual", &"all"] else &"contextual"
	camera_impulse = new_camera_impulse if new_camera_impulse in [&"off", &"major", &"full"] else &"major"
	_trim_all()


func clear() -> void:
	particles.clear()
	trails.clear()
	impacts.clear()
	values.clear()
	traces.clear()
	pulses.clear()
	deaths.clear()
	camera_kicks.clear()
	ambient_suppression_remaining = 0.0


func consume_event(event: Dictionary) -> void:
	var event_type := event.get("type", &"") as StringName
	var category := event.get("category", event.get("target_category", &"")) as StringName
	var priority := CATALOG.event_priority(event_type, category)
	var color := event.get("color", Color.WHITE) as Color
	var faction := event.get("faction", event.get("attacker_faction", &"neutral")) as StringName
	if priority >= CATALOG.PRIORITY_CRITICAL:
		ambient_suppression_remaining = CRITICAL_AMBIENT_SUPPRESSION_SECONDS
	match event_type:
		&"attack":
			_emit_attack(event, color, faction, priority)
		&"death":
			_emit_death(event, color, faction, priority)
		&"command":
			emit_click(event.get("position", Vector2.ZERO) as Vector2, &"order", color, bool(event.get("queued", false)))
		&"build":
			_emit_pulse(event.get("position", Vector2.ZERO), &"build", color, 0.62, priority, faction)
			_emit_burst(event.get("position", Vector2.ZERO), color, &"spark", 5, priority, 22.0)
		&"complete":
			_emit_pulse(event.get("position", Vector2.ZERO), &"complete", color, 0.82, priority, faction)
			_emit_burst(event.get("position", Vector2.ZERO), color, &"ray", 9, priority, 38.0)
			_emit_trace(event.get("position", Vector2.ZERO), color, &"foundation", 4.0, priority, faction)
		&"repair":
			_emit_pulse(event.get("position", Vector2.ZERO), &"repair", color, 0.48, priority, faction)
			_emit_burst(event.get("position", Vector2.ZERO), color, &"inward", 4, priority, 18.0)
			_emit_value(event, &"repair", color, true)
		&"gather":
			var gather_color := CATALOG.resource_color(event.get("resource_kind", &"") as StringName)
			_emit_burst(event.get("position", Vector2.ZERO), gather_color, &"fleck", 4, priority, 17.0)
		&"deposit", &"food", &"bounty":
			var resource_color := CATALOG.resource_color(event.get("resource_kind", &"food") as StringName)
			_emit_pulse(event.get("position", Vector2.ZERO), &"income", resource_color, 0.58, priority, faction)
			_emit_burst(event.get("position", Vector2.ZERO), resource_color, &"inward", 6, priority, 26.0)
			_emit_value(event, &"income", resource_color, true)
		&"capture", &"cave_cleared", &"shenlong_hatched", &"shenlong_defeated", &"egg_claimed":
			_emit_pulse(event.get("position", Vector2.ZERO), event_type, color, 1.0, priority, faction)
			_emit_burst(event.get("position", Vector2.ZERO), color, CATALOG.faction_shape(faction), 14, priority, 48.0)
			_emit_trace(event.get("position", Vector2.ZERO), color, &"sigil", 5.5, priority, faction)
			_emit_camera_kick(event.get("position", Vector2.ZERO), priority, 4.0)
		&"stronghold_upgrade":
			_emit_pulse(event.get("position", Vector2.ZERO), &"upgrade", color, 1.15, CATALOG.PRIORITY_MAJOR, faction)
			_emit_burst(event.get("position", Vector2.ZERO), color, CATALOG.faction_shape(faction), 18, CATALOG.PRIORITY_MAJOR, 58.0)


func emit_click(
	position: Vector2,
	kind: StringName = &"select",
	color: Color = Color("78dfb7"),
	queued: bool = false,
) -> void:
	for pulse in pulses:
		if (
			pulse.get("kind") == kind
			and (pulse.get("position", Vector2.ZERO) as Vector2).distance_squared_to(position) < 0.25
			and float(pulse.get("elapsed", 1.0)) <= 0.1
		):
			pulse["elapsed"] = 0.0
			pulse["queued"] = bool(pulse.get("queued", false)) or queued
			return
	_emit_pulse(position, kind, color, 0.46, CATALOG.PRIORITY_ROUTINE, &"neutral", queued)


func emit_invalid(position: Vector2) -> void:
	_emit_pulse(position, &"invalid", Color("ff685b"), 0.38, CATALOG.PRIORITY_ROUTINE, &"demon")


func emit_foot_dust(position: Vector2, color: Color) -> void:
	if intensity == &"low" or reduced_motion or ambient_suppression_remaining > 0.0:
		return
	_emit_burst(position, color, &"dust", 2, CATALOG.PRIORITY_AMBIENT, 10.0)


func emit_ambient(position: Vector2, color: Color, shape: StringName = &"leaf") -> void:
	if intensity == &"low" or ambient_suppression_remaining > 0.0:
		return
	_emit_burst(position, color, shape, 1, CATALOG.PRIORITY_AMBIENT, 9.0)


func advance(delta: float) -> void:
	ambient_suppression_remaining = maxf(0.0, ambient_suppression_remaining - delta)
	_advance_pool(particles, delta)
	_advance_pool(trails, delta)
	_advance_pool(impacts, delta)
	_advance_pool(values, delta)
	_advance_pool(traces, delta)
	_advance_pool(pulses, delta)
	_advance_pool(deaths, delta)
	_advance_pool(camera_kicks, delta)


func current_camera_offset() -> Vector2:
	if reduced_motion or camera_impulse == &"off":
		return Vector2.ZERO
	var result := Vector2.ZERO
	for kick in camera_kicks:
		var duration := float(kick.get("duration", 0.001))
		var progress := clampf(float(kick.get("elapsed", 0.0)) / duration, 0.0, 1.0)
		var envelope := (1.0 - progress) * sin(progress * PI * 5.0)
		result += (kick.get("direction", Vector2.RIGHT) as Vector2) * float(kick.get("strength", 0.0)) * envelope
	return result.limit_length(5.0)


func diagnostics() -> Dictionary:
	return {
		"particles": particles.size(),
		"trails": trails.size(),
		"impacts": impacts.size(),
		"values": values.size(),
		"traces": traces.size(),
		"pulses": pulses.size(),
		"deaths": deaths.size(),
		"camera_kicks": camera_kicks.size(),
	}


func _emit_attack(event: Dictionary, color: Color, faction: StringName, priority: int) -> void:
	var from := event.get("from", Vector2.ZERO) as Vector2
	var to := event.get("to", from) as Vector2
	var family := CATALOG.attack_family(
		event.get("attacker_kind", &"") as StringName,
		faction,
	)
	var duration := 0.16
	if family == &"projectile":
		duration = 0.24
	elif family == &"mystic":
		duration = 0.29
	elif family == &"dragon":
		duration = 0.38
	_push(trails, &"trails", {
		"from": from,
		"to": to,
		"family": family,
		"faction": faction,
		"color": color,
		"elapsed": 0.0,
		"duration": duration,
		"priority": priority,
		"seed": _next_seed(from),
	})
	_push(impacts, &"impacts", {
		"position": to,
		"family": family,
		"faction": faction,
		"color": color,
		"elapsed": -duration * 0.64,
		"duration": 0.28,
		"priority": priority,
		"seed": _next_seed(to),
	})
	_emit_burst(to, color, CATALOG.faction_shape(faction), 5 if intensity == &"full" else 2, priority, 30.0, duration * 0.64)
	_emit_value(event, &"damage", Color("fff1cb"), false, duration * 0.62)


func _emit_death(event: Dictionary, color: Color, faction: StringName, priority: int) -> void:
	var position := event.get("position", Vector2.ZERO) as Vector2
	var category := event.get("category", &"") as StringName
	var is_structure := category == &"structure"
	_push(deaths, &"deaths", {
		"position": position,
		"category": category,
		"kind": event.get("kind", &""),
		"faction": faction,
		"footprint": event.get("footprint", Vector2i.ONE),
		"color": color,
		"elapsed": 0.0,
		"duration": 0.82 if not is_structure else 1.18,
		"priority": priority,
		"seed": _next_seed(position),
	}, 16)
	_emit_pulse(position, &"death", color, 0.72 if not is_structure else 1.08, priority, faction)
	_emit_burst(position, color, &"debris" if is_structure else CATALOG.faction_shape(faction), 16 if is_structure else 7, priority, 54.0 if is_structure else 30.0)
	_emit_trace(position, Color(color, 0.58), &"rubble" if is_structure else &"residue", 7.0 if is_structure else 3.2, priority, faction)
	if is_structure:
		_emit_camera_kick(position, priority, 3.5 if event.get("kind") != &"stronghold" else 5.0)


func _emit_pulse(
	position_value: Variant,
	kind: StringName,
	color: Color,
	duration: float,
	priority: int,
	faction: StringName,
	queued: bool = false,
) -> void:
	_push(pulses, &"pulses", {
		"position": position_value as Vector2,
		"kind": kind,
		"color": color,
		"faction": faction,
		"queued": queued,
		"elapsed": 0.0,
		"duration": duration,
		"priority": priority,
	})


func _emit_burst(
	position_value: Variant,
	color: Color,
	shape: StringName,
	count: int,
	priority: int,
	speed: float,
	delay: float = 0.0,
) -> void:
	var position := position_value as Vector2
	var actual_count := count if intensity == &"full" else mini(count, 3)
	for index in range(actual_count):
		var seed := _next_seed(position + Vector2(index, -index))
		var angle := _unit_float(seed) * TAU
		var magnitude := lerpf(speed * 0.55, speed, _unit_float(seed * 31 + 7))
		var velocity := Vector2.from_angle(angle) * magnitude
		if shape == &"inward":
			velocity = -velocity
		_push(particles, &"particles", {
			"position": position,
			"velocity": velocity,
			"shape": shape,
			"color": color,
			"elapsed": -delay - float(index) * 0.008,
			"duration": 0.42 if shape != &"dust" else 0.5,
			"priority": priority,
			"seed": seed,
		})


func _emit_value(
	event: Dictionary,
	kind: StringName,
	color: Color,
	positive: bool,
	delay: float = 0.0,
) -> void:
	if damage_numbers == &"off":
		return
	var amount := float(event.get("amount", 0.0))
	if is_zero_approx(amount):
		return
	var target_id := int(event.get("target_id", event.get("entity_id", -1)))
	if damage_numbers == &"contextual" and kind == &"damage" and amount < 8.0:
		return
	for value in values:
		if int(value.get("target_id", -2)) == target_id and value.get("kind") == kind and float(value.get("elapsed", 1.0)) <= AGGREGATE_SECONDS:
			value["amount"] = float(value.get("amount", 0.0)) + amount
			value["elapsed"] = -delay
			return
	_push(values, &"values", {
		"position": event.get("to", event.get("position", Vector2.ZERO)) as Vector2,
		"target_id": target_id,
		"kind": kind,
		"amount": amount,
		"positive": positive,
		"color": color,
		"elapsed": -delay,
		"duration": 0.82,
		"priority": CATALOG.PRIORITY_ROUTINE,
	})


func _emit_trace(
	position_value: Variant,
	color: Color,
	kind: StringName,
	duration: float,
	priority: int,
	faction: StringName,
) -> void:
	_push(traces, &"traces", {
		"position": position_value as Vector2,
		"kind": kind,
		"faction": faction,
		"color": color,
		"elapsed": 0.0,
		"duration": duration,
		"priority": priority,
		"seed": _next_seed(position_value as Vector2),
	})


func _emit_camera_kick(position: Vector2, priority: int, strength: float) -> void:
	if reduced_motion or camera_impulse == &"off":
		return
	if camera_impulse == &"major" and priority < CATALOG.PRIORITY_MAJOR:
		return
	var seed := _next_seed(position)
	_push(camera_kicks, &"camera_kicks", {
		"direction": Vector2.from_angle(_unit_float(seed) * TAU),
		"strength": strength,
		"elapsed": 0.0,
		"duration": 0.2,
		"priority": priority,
	}, 4)


func _advance_pool(pool: Array[Dictionary], delta: float) -> void:
	for index in range(pool.size() - 1, -1, -1):
		pool[index]["elapsed"] = float(pool[index].get("elapsed", 0.0)) + delta
		if float(pool[index]["elapsed"]) >= float(pool[index].get("duration", 0.0)):
			pool.remove_at(index)


func _push(
	pool: Array[Dictionary],
	pool_name: StringName,
	record: Dictionary,
	explicit_cap: int = -1,
) -> void:
	var cap := explicit_cap if explicit_cap >= 0 else int(CATALOG.caps(intensity).get(pool_name, 12))
	if pool.size() >= cap:
		var remove_index := -1
		var incoming_priority := int(record.get("priority", CATALOG.PRIORITY_ROUTINE))
		for index in range(pool.size()):
			if int(pool[index].get("priority", CATALOG.PRIORITY_ROUTINE)) <= incoming_priority:
				remove_index = index
				break
		if remove_index < 0:
			return
		pool.remove_at(remove_index)
	pool.append(record)
func _trim_all() -> void:
	var caps := CATALOG.caps(intensity)
	_trim_pool(particles, int(caps[&"particles"]))
	_trim_pool(trails, int(caps[&"trails"]))
	_trim_pool(impacts, int(caps[&"impacts"]))
	_trim_pool(values, int(caps[&"values"]))
	_trim_pool(traces, int(caps[&"traces"]))
	_trim_pool(pulses, int(caps[&"pulses"]))
	_trim_pool(deaths, 8 if intensity == &"low" else 16)


func _trim_pool(pool: Array[Dictionary], cap: int) -> void:
	while pool.size() > cap:
		pool.pop_front()


func _next_seed(position: Vector2) -> int:
	_serial += 1
	return absi(int(position.x * 92821.0) ^ int(position.y * 68917.0) ^ (_serial * 19349663))


func _unit_float(seed: int) -> float:
	return float(posmod(seed, 10007)) / 10006.0
