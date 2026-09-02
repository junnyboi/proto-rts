extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _advance(simulation: RtsSimulation, seconds: float) -> void:
	for _step in range(int(ceil(seconds / RtsSimulation.TICK_SECONDS))):
		simulation.advance(RtsSimulation.TICK_SECONDS)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _test_attack_move_continuation(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var attacker_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", Vector2i(5, 13))
	var target_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", Vector2i(9, 13))
	simulation.entity(target_id)["hp"] = 1.0
	var destination := Vector2i(13, 13)
	simulation.command_move([attacker_id], destination, true)
	_advance(simulation, 10.0)
	var attacker := simulation.entity(attacker_id)
	_expect(not bool(simulation.entity(target_id)["alive"]), "attack-move did not destroy the intercepted target", failures)
	_expect((attacker["position"] as Vector2).distance_to(Vector2(destination)) < 0.1, "attack-move did not resume to its original destination", failures)
	_expect(attacker["order"] == &"idle", "attack-move did not return to idle after reaching its destination", failures)
	_expect(attacker["attack_move_destination"] == RtsSimulation.INVALID_CELL, "attack-move destination was not cleared after arrival", failures)


func _test_large_formation(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var cells := simulation._formation_cells(Vector2i(10, 8), 24)
	var unique := {}
	for cell in cells:
		unique[cell] = true
		_expect(MapCatalog.in_bounds(cell), "large formation produced an out-of-bounds cell", failures)
		_expect(not simulation._astar.is_point_solid(cell), "large formation produced a blocked cell", failures)
	_expect(cells.size() == 24, "large formation did not produce 24 destinations", failures)
	_expect(unique.size() == 24, "large formation reused one or more destinations", failures)


func _test_placement_collision(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	var worker_cell := simulation.entity(worker_id)["cell"] as Vector2i
	_expect(not simulation.can_place_war_camp(RtsSimulation.TEAM_PLAYER, worker_cell), "War Camp placement accepted a live unit cell", failures)
	_expect(not simulation.can_place_war_camp(RtsSimulation.TEAM_PLAYER, MapCatalog.RESOURCES[0]["cell"] as Vector2i), "War Camp placement accepted a resource cell", failures)
	_expect(not simulation.can_place_war_camp(RtsSimulation.TEAM_PLAYER, MapCatalog.PLAYER_STRONGHOLD), "War Camp placement accepted a structure cell", failures)
	_expect(simulation.can_place_war_camp(RtsSimulation.TEAM_PLAYER, Vector2i(5, 12)), "known-valid War Camp placement was rejected", failures)


func _test_unit_separation(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var first_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", Vector2i(10, 13))
	var second_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", Vector2i(10, 13))
	_advance(simulation, 0.5)
	var first_position := simulation.entity(first_id)["position"] as Vector2
	var second_position := simulation.entity(second_id)["position"] as Vector2
	_expect(first_position.distance_to(second_position) >= RtsSimulation.UNIT_SEPARATION_DISTANCE - 0.01, "overlapping units did not separate", failures)


func _test_ai_symmetric_construction_and_rebuild(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", true)
	_expect(simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"war_camp") < 0, "AI still begins with a completed War Camp", failures)
	_advance(simulation, 1.0)
	var camp_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"war_camp")
	_expect(camp_id >= 0, "AI did not found a War Camp through normal construction", failures)
	if camp_id < 0:
		return
	var camp := simulation.entity(camp_id)
	_expect(float(camp["complete"]) < 1.0, "AI War Camp bypassed construction time", failures)
	_advance(simulation, 10.0)
	_expect(float(camp["complete"]) >= 1.0, "AI War Camp did not complete", failures)
	simulation.players[RtsSimulation.TEAM_ENEMY]["jade"] = 500
	simulation.players[RtsSimulation.TEAM_ENEMY]["essence"] = 500
	simulation._kill(camp, {})
	_advance(simulation, 2.0)
	var rebuilt_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"war_camp")
	_expect(rebuilt_id >= 0 and rebuilt_id != camp_id, "AI did not rebuild a destroyed War Camp", failures)
	if rebuilt_id >= 0:
		_expect(float(simulation.entity(rebuilt_id)["complete"]) < 1.0, "rebuilt AI War Camp bypassed construction time", failures)


func _test_ai_training_fallback(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var camp_id := simulation._spawn_structure(RtsSimulation.TEAM_ENEMY, &"war_camp", RtsSimulation.AI_WAR_CAMP_CELL, true)
	simulation._rebuild_pathfinding()
	simulation.players[RtsSimulation.TEAM_ENEMY]["jade"] = 500
	simulation.players[RtsSimulation.TEAM_ENEMY]["essence"] = 0
	simulation._ai_training_flip = true
	simulation._ai_strategy_timer = 0.0
	simulation._advance_ai(RtsSimulation.TICK_SECONDS)
	var queue := simulation.entity(camp_id)["queue"] as Array
	_expect(not queue.is_empty(), "AI stalled production when its preferred unit was unaffordable", failures)
	if not queue.is_empty():
		_expect((queue[0] as Dictionary)["kind"] == &"vanguard", "AI did not fall back from an unaffordable Mystic to a Vanguard", failures)


func _test_line_of_sight_and_invalid_move(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var source_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"mystic", Vector2i(9, 0))
	var target_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", Vector2i(9, 2))
	var source := simulation.entity(source_id)
	var target := simulation.entity(target_id)
	_expect(not simulation._has_line_of_sight(source, target), "ridge terrain did not block combat line of sight", failures)
	_expect(simulation._nearest_enemy(source, 3.0) != target_id, "automatic acquisition selected an enemy behind a ridge", failures)
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	var worker := simulation.entity(worker_id)
	simulation.command_move([worker_id], Vector2i(-4, -4))
	_expect(worker["order"] == &"idle" and (worker["path"] as Array).is_empty(), "out-of-bounds move was silently clamped into a command", failures)


func _run() -> void:
	var failures: Array[String] = []
	_expect(MapCatalog.validation_errors().is_empty(), "authored map validation reported an error", failures)
	_test_attack_move_continuation(failures)
	_test_large_formation(failures)
	_test_placement_collision(failures)
	_test_unit_separation(failures)
	_test_ai_symmetric_construction_and_rebuild(failures)
	_test_ai_training_fallback(failures)
	_test_line_of_sight_and_invalid_move(failures)
	if failures.is_empty():
		print("PASS core_regression_test: attack-move, formation, placement, separation, AI rebuild/fallback, sight, bounds")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
