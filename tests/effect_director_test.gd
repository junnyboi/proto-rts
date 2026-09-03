extends SceneTree

const EFFECT_DIRECTOR := preload("res://scripts/view/effects/effect_director.gd")
const PRESENTATION_STATE := preload("res://scripts/view/effects/presentation_state.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var director = EFFECT_DIRECTOR.new()
	var attack := {
		"type": &"attack",
		"from": Vector2(10.0, 12.0),
		"to": Vector2(11.0, 12.0),
		"color": Color("79e1c1"),
		"attacker_id": 4,
		"target_id": 9,
		"attacker_kind": &"mystic",
		"attacker_faction": &"celestial",
		"target_category": &"unit",
		"amount": 12.0,
	}
	director.consume_event(attack)
	_expect(director.trails.size() == 1, "attack did not create one bounded trail", failures)
	_expect(director.impacts.size() == 1, "attack did not create one delayed impact", failures)
	_expect(director.particles.size() > 0, "attack did not create impact particles", failures)
	_expect(director.values.size() == 1, "contextual damage did not create a value", failures)
	director.consume_event(attack)
	_expect(director.values.size() == 1, "same-target damage did not aggregate", failures)
	if not director.values.is_empty():
		_expect(is_equal_approx(float(director.values[0]["amount"]), 24.0), "aggregated damage amount is incorrect", failures)

	director.clear()
	for index in range(160):
		director.emit_ambient(Vector2(index, 0.0), Color.WHITE)
	_expect(director.particles.size() <= 96, "full particle pool exceeded its cap", failures)
	director.configure(&"low", false, &"all", &"full")
	_expect(director.particles.size() <= 40, "low setting did not trim the particle pool", failures)
	for index in range(80):
		director.emit_click(Vector2(index, 4.0))
	_expect(director.pulses.size() <= 8, "low pulse pool exceeded its cap", failures)

	director.clear()
	director.configure(&"full", false, &"all", &"major")
	director.consume_event({
		"type": &"death",
		"position": Vector2(20.0, 20.0),
		"category": &"structure",
		"kind": &"stronghold",
		"faction": &"demon",
		"color": Color("ff685b"),
	})
	_expect(director.ambient_suppression_remaining > 0.0, "critical event did not suppress ambience", failures)
	_expect(not director.camera_kicks.is_empty(), "major structure death did not create planar camera impulse", failures)
	var ambient_before: int = director.particles.size()
	director.emit_ambient(Vector2.ZERO, Color.WHITE)
	_expect(director.particles.size() == ambient_before, "ambient emitted during critical suppression", failures)
	director.advance(8.0)
	var diagnostics := director.diagnostics()
	for pool_name in [&"particles", &"trails", &"impacts", &"values", &"traces", &"pulses", &"deaths", &"camera_kicks"]:
		_expect(int(diagnostics[pool_name]) == 0, "%s records did not expire" % pool_name, failures)

	var presentation = PRESENTATION_STATE.new()
	var entities := {
		4: {"id": 4, "hp": 80.0},
		9: {"id": 9, "hp": 60.0},
	}
	presentation.synchronize(entities)
	presentation.consume_event(attack)
	_expect((presentation.visual_transform(4)["offset"] as Vector2).is_zero_approx(), "attack transform began past its anticipation frame", failures)
	presentation.advance(0.08)
	_expect((presentation.visual_transform(4)["offset"] as Vector2).length() > 0.0, "attack transform did not lunge", failures)
	_expect(presentation.hit_flash(9) > 0.0, "target hit flash did not animate", failures)
	presentation.configure(true)
	_expect((presentation.visual_transform(4)["offset"] as Vector2).is_zero_approx(), "reduced motion retained positional lunge", failures)

	var regenerated_wildlife := {"id": 12, "hp": 36.0, "category": &"wildlife"}
	entities[12] = regenerated_wildlife
	presentation.synchronize(entities)
	_expect(is_equal_approx(presentation.wildlife_opacity(12), 1.0), "ordinary wildlife did not begin fully visible", failures)
	presentation.consume_event({"type": &"wildlife_regenerated", "entity_id": 12})
	_expect(is_zero_approx(presentation.wildlife_opacity(12)), "regenerated wildlife did not begin transparent", failures)
	_expect(presentation.has_active_wildlife_fades(), "regenerated wildlife did not register an active fade", failures)
	presentation.advance(PresentationState.WILDLIFE_FADE_IN_DURATION * 0.5)
	var midpoint_opacity := presentation.wildlife_opacity(12)
	_expect(midpoint_opacity > 0.0 and midpoint_opacity < 1.0, "regenerated wildlife did not fade gradually", failures)
	presentation.advance(PresentationState.WILDLIFE_FADE_IN_DURATION * 0.5)
	_expect(is_equal_approx(presentation.wildlife_opacity(12), 1.0), "regenerated wildlife did not finish fully opaque", failures)
	_expect(not presentation.has_active_wildlife_fades(), "completed wildlife fade remained active", failures)
	presentation.consume_event({"type": &"wildlife_regenerated", "entity_id": 12})
	entities.erase(12)
	presentation.synchronize(entities)
	_expect(not presentation.has_active_wildlife_fades(), "removed wildlife retained stale fade state", failures)

	if failures.is_empty():
		print("PASS effect_director_test: capped pools, aggregation, priority suppression, expiry, transforms, reduced motion, wildlife fade-in")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
