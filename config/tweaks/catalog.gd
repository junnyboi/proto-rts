class_name TweakCatalog
extends RefCounted

const UI := &"UI"
const GAMEPLAY := &"GAMEPLAY"
const AUDIO := &"AUDIO"
const PLAYER := &"PLAYER"
const ENEMIES := &"ENEMIES"
const ENVIRONMENT := &"ENVIRONMENT"
const CATEGORIES: Array[StringName] = [UI, GAMEPLAY, AUDIO, PLAYER, ENEMIES, ENVIRONMENT]

const LIVE := &"LIVE"
const NEXT_ACTION := &"NEXT_ACTION"
const NEXT_SPAWN := &"NEXT_SPAWN"
const NEXT_RUN := &"NEXT_RUN"
const APPLY_MODES: Array[StringName] = [LIVE, NEXT_ACTION, NEXT_SPAWN, NEXT_RUN]

const COSMETIC := &"COSMETIC"
const GAMEPLAY_INTEGRITY := &"GAMEPLAY"
const SCORE_AFFECTING := &"SCORE_AFFECTING"
const INTEGRITY_CLASSES: Array[StringName] = [COSMETIC, GAMEPLAY_INTEGRITY, SCORE_AFFECTING]

static var DESCRIPTORS: Array[Dictionary] = [
	_descriptor(&"ui.hud.scale", UI, &"float", 1.0, LIVE, COSMETIC, 0.75, 1.25, 0.05, &"tweak.unit.multiplier"),
	_descriptor(&"ui.hud.opacity", UI, &"float", 100.0, LIVE, COSMETIC, 50.0, 100.0, 5.0, &"tweak.unit.percent"),
	_descriptor(&"ui.reduced_motion", UI, &"bool", false, LIVE, COSMETIC),

	_descriptor(&"gameplay.time_scale", GAMEPLAY, &"float", 1.0, LIVE, GAMEPLAY_INTEGRITY, 0.50, 2.0, 0.25, &"tweak.unit.multiplier"),
	_descriptor(&"gameplay.resource.starting_multiplier", GAMEPLAY, &"float", 1.0, NEXT_RUN, GAMEPLAY_INTEGRITY, 0.50, 2.0, 0.10, &"tweak.unit.multiplier"),
	_descriptor(&"gameplay.build.duration_multiplier", GAMEPLAY, &"float", 1.0, NEXT_ACTION, GAMEPLAY_INTEGRITY, 0.50, 2.0, 0.10, &"tweak.unit.multiplier"),
	_descriptor(&"gameplay.score.multiplier", GAMEPLAY, &"float", 1.0, NEXT_RUN, SCORE_AFFECTING, 0.50, 2.0, 0.10, &"tweak.unit.multiplier"),

	_descriptor(&"audio.master.muted", AUDIO, &"bool", false, LIVE, COSMETIC),
	_descriptor(&"audio.music.volume_db", AUDIO, &"float", 10.0, LIVE, COSMETIC, -30.0, 12.0, 1.0, &"tweak.unit.decibels"),
	_descriptor(&"audio.sfx.volume_db", AUDIO, &"float", 5.0, LIVE, COSMETIC, -30.0, 12.0, 1.0, &"tweak.unit.decibels"),

	_descriptor(&"player.move.speed_multiplier", PLAYER, &"float", 1.0, NEXT_SPAWN, GAMEPLAY_INTEGRITY, 0.50, 1.75, 0.05, &"tweak.unit.multiplier"),
	_descriptor(&"player.attack.damage_multiplier", PLAYER, &"float", 1.0, NEXT_ACTION, GAMEPLAY_INTEGRITY, 0.50, 2.0, 0.10, &"tweak.unit.multiplier"),
	_descriptor(&"player.health.multiplier", PLAYER, &"float", 1.0, NEXT_SPAWN, GAMEPLAY_INTEGRITY, 0.50, 2.0, 0.10, &"tweak.unit.multiplier"),

	_descriptor(&"enemies.health.multiplier", ENEMIES, &"float", 1.0, NEXT_SPAWN, GAMEPLAY_INTEGRITY, 0.50, 2.0, 0.10, &"tweak.unit.multiplier"),
	_descriptor(&"enemies.speed.multiplier", ENEMIES, &"float", 1.0, NEXT_SPAWN, GAMEPLAY_INTEGRITY, 0.50, 1.75, 0.05, &"tweak.unit.multiplier"),
	_descriptor(&"enemies.ai.decision_interval", ENEMIES, &"float", 1.4, NEXT_RUN, GAMEPLAY_INTEGRITY, 0.50, 3.0, 0.10, &"tweak.unit.seconds"),

	_descriptor(&"environment.camera.zoom", ENVIRONMENT, &"float", 1.0, LIVE, COSMETIC, 0.75, 1.25, 0.05, &"tweak.unit.multiplier"),
	_descriptor(&"environment.fog.enabled", ENVIRONMENT, &"bool", true, LIVE, GAMEPLAY_INTEGRITY),
	_descriptor(&"environment.filter.enabled", ENVIRONMENT, &"bool", false, LIVE, COSMETIC),
	_descriptor(&"environment.filter.intensity", ENVIRONMENT, &"float", 18.0, LIVE, COSMETIC, 0.0, 60.0, 5.0, &"tweak.unit.percent"),
]


static func descriptors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for descriptor: Dictionary in DESCRIPTORS:
		result.append(descriptor.duplicate(true))
	return result


static func descriptor(id: StringName) -> Dictionary:
	for candidate: Dictionary in DESCRIPTORS:
		if candidate["id"] == id:
			return candidate.duplicate(true)
	return {}


static func defaults() -> Dictionary:
	var result := {}
	for descriptor: Dictionary in DESCRIPTORS:
		result[descriptor["id"]] = descriptor["default"]
	return result


static func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	var ids := {}
	var seen_categories := {}
	for descriptor: Dictionary in DESCRIPTORS:
		var id := descriptor.get("id", &"") as StringName
		if id.is_empty() or ids.has(id):
			errors.append("Tweak IDs must be non-empty and unique: %s" % id)
		ids[id] = true
		var category := descriptor.get("category", &"") as StringName
		seen_categories[category] = true
		if category not in CATEGORIES:
			errors.append("Unknown tweak category for %s" % id)
		if descriptor.get("apply_mode", &"") not in APPLY_MODES:
			errors.append("Unknown application boundary for %s" % id)
		if descriptor.get("integrity", &"") not in INTEGRITY_CLASSES:
			errors.append("Unknown integrity class for %s" % id)
		if String(descriptor.get("label_key", "")).is_empty() or String(descriptor.get("description_key", "")).is_empty():
			errors.append("Tweak %s lacks localization keys" % id)
	for category: StringName in CATEGORIES:
		if not seen_categories.has(category):
			errors.append("Tweak category has no controls: %s" % category)
	return errors


static func _descriptor(
	id: StringName,
	category: StringName,
	type: StringName,
	default_value: Variant,
	apply_mode: StringName,
	integrity: StringName,
	minimum: float = 0.0,
	maximum: float = 0.0,
	step: float = 0.0,
	unit_key: StringName = &"",
) -> Dictionary:
	var result := {
		"id": id,
		"category": category,
		"type": type,
		"default": default_value,
		"apply_mode": apply_mode,
		"integrity": integrity,
		"label_key": StringName("tweak.%s.label" % id),
		"description_key": StringName("tweak.%s.description" % id),
		"tags": PackedStringArray(String(id).replace(".", " ").split(" ")),
	}
	if type in [&"float", &"int"]:
		result["min"] = minimum
		result["max"] = maximum
		result["step"] = step
		result["unit_key"] = unit_key
	return result
