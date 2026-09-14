extends SceneTree

class ProfileSimulation extends RtsSimulation:
	var separation_us := 0
	var visibility_us := 0
	var combat_us := 0
	func _resolve_unit_separation(delta: float = TICK_SECONDS) -> void:
		var started := Time.get_ticks_usec()
		super._resolve_unit_separation(delta)
		separation_us += Time.get_ticks_usec() - started
	func _refresh_visibility() -> void:
		var started := Time.get_ticks_usec()
		super._refresh_visibility()
		visibility_us += Time.get_ticks_usec() - started
	func _advance_combat_and_movement(delta: float) -> void:
		var started := Time.get_ticks_usec()
		super._advance_combat_and_movement(delta)
		combat_us += Time.get_ticks_usec() - started

func _initialize() -> void:
	call_deferred("_run")

func _digest(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()

func _run() -> void:
	var simulation := ProfileSimulation.new()
	var started := Time.get_ticks_usec()
	simulation.setup(&"human", true)
	var setup_us := Time.get_ticks_usec() - started
	var events := HashingContext.new()
	events.start(HashingContext.HASH_SHA256)
	var windows: Array[Dictionary] = []
	for window in range(3):
		var samples: Array[int] = []
		var total_us := 0
		simulation.separation_us = 0
		simulation.visibility_us = 0
		simulation.combat_us = 0
		for tick in range(600):
			started = Time.get_ticks_usec()
			simulation.advance(RtsSimulation.TICK_SECONDS)
			var elapsed := Time.get_ticks_usec() - started
			total_us += elapsed
			samples.append(elapsed)
			events.update(var_to_bytes([window * 600 + tick, simulation.drain_events()]))
		samples.sort()
		var vision: Array = []
		for team in range(simulation.players.size()):
			vision.append([simulation.visible_cells_for_team(team), simulation.explored_cells_for_team(team)])
		windows.append({
			"seconds_from": window * 20,
			"seconds_to": (window + 1) * 20,
			"samples": samples.size(),
			"mean_tick_us": float(total_us) / samples.size(),
			"p95_tick_us": samples[int((samples.size() - 1) * 0.95)],
			"max_tick_us": samples[-1],
			"separation_mean_us": float(simulation.separation_us) / samples.size(),
			"visibility_mean_us": float(simulation.visibility_us) / samples.size(),
			"combat_mean_us": float(simulation.combat_us) / samples.size(),
			"entity_count": simulation.entities.size(),
			"state_sha256": _digest([simulation.entities, simulation.players, simulation.elapsed_time, simulation.outcome, simulation._wander_rng.state, simulation._wildlife_rng.state, simulation._hunter_rng.state, vision]),
		})
	print("ACCEPTANCE_JSON " + JSON.stringify({
		"fixture": "original_four_player_default_ai_first_60_simulated_seconds",
		"engine": Engine.get_version_info().string,
		"processor": OS.get_processor_name(),
		"setup_us": setup_us,
		"windows": windows,
		"event_sha256": events.finish().hex_encode(),
	}))
	quit()
