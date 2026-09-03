class_name PresentationState
extends RefCounted

const ATTACK_DURATION := 0.24
const HIT_DURATION := 0.18
const WILDLIFE_FADE_IN_DURATION := 0.85
const HEALTH_SETTLE_SPEED := 8.0

var records: Dictionary = {}
var wildlife_fades: Dictionary = {}
var hovered_entity_id := -1
var reduced_motion := false


func clear() -> void:
	records.clear()
	wildlife_fades.clear()
	hovered_entity_id = -1


func configure(new_reduced_motion: bool) -> void:
	reduced_motion = new_reduced_motion


func synchronize(entities: Dictionary) -> void:
	var seen: Dictionary = {}
	for raw_entity in entities.values():
		var entity := raw_entity as Dictionary
		var entity_id := int(entity.get("id", -1))
		if entity_id < 0:
			continue
		seen[entity_id] = true
		var hp := float(entity.get("hp", 0.0))
		if not records.has(entity_id):
			records[entity_id] = {
				"display_hp": hp,
				"target_hp": hp,
				"attack_elapsed": ATTACK_DURATION,
				"hit_elapsed": HIT_DURATION,
				"selection_elapsed": 1.0,
				"hover_elapsed": 1.0,
				"attack_direction": Vector2.RIGHT,
				"attack_family": &"melee",
			}
		var record := records[entity_id] as Dictionary
		record["target_hp"] = hp
		records[entity_id] = record
	for raw_id in records.keys():
		var entity_id := int(raw_id)
		if not seen.has(entity_id):
			records.erase(entity_id)
			wildlife_fades.erase(entity_id)


func advance(delta: float) -> void:
	for raw_id in records.keys():
		var entity_id := int(raw_id)
		var record := records[entity_id] as Dictionary
		record["attack_elapsed"] = minf(ATTACK_DURATION, float(record.get("attack_elapsed", ATTACK_DURATION)) + delta)
		record["hit_elapsed"] = minf(HIT_DURATION, float(record.get("hit_elapsed", HIT_DURATION)) + delta)
		record["selection_elapsed"] = minf(1.0, float(record.get("selection_elapsed", 1.0)) + delta * 5.0)
		record["hover_elapsed"] = minf(1.0, float(record.get("hover_elapsed", 1.0)) + delta * 7.0)
		var display_hp := float(record.get("display_hp", 0.0))
		var target_hp := float(record.get("target_hp", display_hp))
		record["display_hp"] = lerpf(display_hp, target_hp, clampf(delta * HEALTH_SETTLE_SPEED, 0.0, 1.0))
		records[entity_id] = record
	for raw_id in wildlife_fades.keys():
		var entity_id := int(raw_id)
		var elapsed := minf(
			WILDLIFE_FADE_IN_DURATION,
			float(wildlife_fades[entity_id]) + delta,
		)
		if elapsed >= WILDLIFE_FADE_IN_DURATION:
			wildlife_fades.erase(entity_id)
		else:
			wildlife_fades[entity_id] = elapsed


func consume_event(event: Dictionary) -> void:
	var event_type := event.get("type") as StringName
	if event_type == &"wildlife_regenerated":
		var entity_id := int(event.get("entity_id", -1))
		if records.has(entity_id):
			wildlife_fades[entity_id] = 0.0
		return
	if event_type != &"attack":
		return
	var attacker_id := int(event.get("attacker_id", -1))
	var target_id := int(event.get("target_id", -1))
	var direction := (event.get("to", Vector2.RIGHT) as Vector2) - (event.get("from", Vector2.ZERO) as Vector2)
	if direction.length_squared() > 0.0001:
		direction = direction.normalized()
	if records.has(attacker_id):
		var attacker_record := records[attacker_id] as Dictionary
		attacker_record["attack_elapsed"] = 0.0
		attacker_record["attack_direction"] = direction
		attacker_record["attack_family"] = event.get("attack_family", &"melee")
		records[attacker_id] = attacker_record
	if records.has(target_id):
		var target_record := records[target_id] as Dictionary
		target_record["hit_elapsed"] = 0.0
		records[target_id] = target_record


func set_hover(entity_id: int) -> void:
	if entity_id == hovered_entity_id:
		return
	hovered_entity_id = entity_id
	if records.has(entity_id):
		var record := records[entity_id] as Dictionary
		record["hover_elapsed"] = 0.0
		records[entity_id] = record


func note_selection(ids: Array[int]) -> void:
	for entity_id in ids:
		if records.has(entity_id):
			var record := records[entity_id] as Dictionary
			record["selection_elapsed"] = 0.0
			records[entity_id] = record


func visual_transform(entity_id: int) -> Dictionary:
	var record := records.get(entity_id, {}) as Dictionary
	var result := {"offset": Vector2.ZERO, "rotation": 0.0, "scale": Vector2.ONE}
	if record.is_empty() or reduced_motion:
		return result
	var elapsed := float(record.get("attack_elapsed", ATTACK_DURATION))
	if elapsed < ATTACK_DURATION:
		var progress := elapsed / ATTACK_DURATION
		var family := record.get("attack_family", &"melee") as StringName
		var amplitude := 0.12 if family in [&"melee", &"beast"] else 0.055
		var lunge := sin(progress * PI) * amplitude
		result["offset"] = (record.get("attack_direction", Vector2.RIGHT) as Vector2) * lunge
		result["rotation"] = sin(progress * PI) * (-0.035 if family == &"projectile" else 0.045)
		if family == &"beast":
			result["scale"] = Vector2(1.0 + sin(progress * PI) * 0.05, 1.0 - sin(progress * PI) * 0.04)
	return result


func hit_flash(entity_id: int) -> float:
	var record := records.get(entity_id, {}) as Dictionary
	var elapsed := float(record.get("hit_elapsed", HIT_DURATION))
	if elapsed >= HIT_DURATION:
		return 0.0
	return sin(clampf(elapsed / HIT_DURATION, 0.0, 1.0) * PI)


func display_hp(entity_id: int, fallback: float) -> float:
	return float((records.get(entity_id, {}) as Dictionary).get("display_hp", fallback))


func wildlife_opacity(entity_id: int) -> float:
	if not wildlife_fades.has(entity_id):
		return 1.0
	var progress := clampf(
		float(wildlife_fades[entity_id]) / WILDLIFE_FADE_IN_DURATION,
		0.0,
		1.0,
	)
	return smoothstep(0.0, 1.0, progress)


func has_active_wildlife_fades() -> bool:
	return not wildlife_fades.is_empty()


func hover_strength(entity_id: int) -> float:
	if entity_id != hovered_entity_id:
		return 0.0
	var elapsed := float((records.get(entity_id, {}) as Dictionary).get("hover_elapsed", 1.0))
	return sin(clampf(elapsed, 0.0, 1.0) * PI * 0.5)


func selection_strength(entity_id: int) -> float:
	var elapsed := float((records.get(entity_id, {}) as Dictionary).get("selection_elapsed", 1.0))
	return sin(clampf(elapsed, 0.0, 1.0) * PI * 0.5)
