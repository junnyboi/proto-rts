class_name EffectCatalog
extends RefCounted

const PRIORITY_AMBIENT := 0
const PRIORITY_ROUTINE := 1
const PRIORITY_MAJOR := 2
const PRIORITY_CRITICAL := 3

const FULL_CAPS := {
	&"particles": 96,
	&"trails": 24,
	&"impacts": 24,
	&"values": 12,
	&"traces": 24,
	&"pulses": 12,
}
const LOW_CAPS := {
	&"particles": 40,
	&"trails": 12,
	&"impacts": 12,
	&"values": 6,
	&"traces": 10,
	&"pulses": 8,
}

const FACTION_COLORS := {
	&"celestial": Color("79e1c1"),
	&"demon": Color("ff685b"),
	&"beast": Color("d6a45b"),
	&"human": Color("f1cb67"),
	&"neutral": Color("d7bd6c"),
}


static func caps(intensity: StringName) -> Dictionary:
	return LOW_CAPS if intensity == &"low" else FULL_CAPS


static func attack_family(kind: StringName, faction: StringName = &"") -> StringName:
	if kind == &"shenlong":
		return &"dragon"
	if kind == &"jadeclaw" or faction == &"beast":
		return &"beast"
	if kind == &"hunter":
		return &"projectile"
	if kind == &"mystic":
		return &"mystic"
	return &"melee"


static func faction_color(faction: StringName, fallback: Color = Color.WHITE) -> Color:
	return FACTION_COLORS.get(faction, fallback) as Color


static func resource_color(resource_kind: StringName) -> Color:
	match resource_kind:
		&"jade":
			return Color("73dfab")
		&"lumber":
			return Color("d5a85d")
		&"essence":
			return Color("77c6ff")
		&"food":
			return Color("f2c85b")
		_:
			return Color("f1d477")


static func event_priority(event_type: StringName, category: StringName = &"") -> int:
	if event_type == &"death" and category == &"structure":
		return PRIORITY_CRITICAL
	if event_type in [&"death", &"capture", &"shenlong_hatched", &"shenlong_defeated"]:
		return PRIORITY_MAJOR
	if event_type in [&"attack", &"complete", &"bounty", &"cave_cleared", &"stronghold_upgrade"]:
		return PRIORITY_ROUTINE
	return PRIORITY_AMBIENT if event_type == &"ambient" else PRIORITY_ROUTINE


static func faction_shape(faction: StringName) -> StringName:
	match faction:
		&"celestial":
			return &"circle"
		&"demon":
			return &"triangle"
		&"beast":
			return &"claw"
		&"human":
			return &"diamond"
		_:
			return &"circle"
