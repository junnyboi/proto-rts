extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _advance(simulation: RtsSimulation, seconds: float) -> void:
	for _step in range(int(ceil(seconds / RtsSimulation.TICK_SECONDS))):
		simulation.advance(RtsSimulation.TICK_SECONDS)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _blank_simulation() -> RtsSimulation:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	simulation.entities.clear()
	simulation.players[RtsSimulation.TEAM_PLAYER]["population"] = 0
	simulation.players[RtsSimulation.TEAM_ENEMY]["population"] = 0
	simulation._next_entity_id = 1
	simulation._rebuild_pathfinding()
	return simulation


func _test_attack_move_external_kill(failures: Array[String]) -> void:
	var simulation := _blank_simulation()
	var attacker_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", Vector2i(8, 54))
	var killer_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"mystic", Vector2i(12, 54))
	var target_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"worker", Vector2i(13, 54))
	var destination := Vector2i(20, 54)
	_expect(simulation.command_move(RtsSimulation.TEAM_PLAYER, [attacker_id], destination, true), "valid attack-move command was rejected", failures)
	_advance(simulation, 0.25)
	var attacker := simulation.entity(attacker_id)
	_expect(int(attacker.get("target_id", -1)) == target_id, "attack-move unit did not acquire the nearby target", failures)
	_expect(not (attacker.get("path", []) as Array).is_empty(), "attack-move unit did not begin pursuing its target", failures)
	simulation._kill(simulation.entity(target_id), simulation.entity(killer_id))
	_advance(simulation, 15.0)
	_expect((attacker["position"] as Vector2).distance_to(Vector2(destination)) < 0.15, "attack-move abandoned its original destination after another unit killed the target", failures)
	_expect(attacker.get("order") == &"idle", "attack-move did not complete after reaching its original destination", failures)


func _test_scalable_and_partial_formations(failures: Array[String]) -> void:
	var simulation := _blank_simulation()
	var ids: Array[int] = []
	for index in range(RtsSimulation.POPULATION_CAP):
		ids.append(simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", Vector2i(8 + index % 3, 54 + index / 3)))
	var destination := Vector2i(30, 40)
	_expect(simulation.command_move(RtsSimulation.TEAM_PLAYER, ids, destination), "24-unit formation command was rejected", failures)
	var destinations := {}
	for id in ids:
		var unit := simulation.entity(id)
		var path := unit.get("path", []) as Array
		_expect(not path.is_empty(), "formation unit received no path", failures)
		if not path.is_empty():
			destinations[path[-1] as Vector2] = true
	_expect(destinations.size() == ids.size(), "formation did not assign a unique destination to every unit", failures)

	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			simulation._astar.set_point_solid(Vector2i(x, y), true)
	var slots: Array[Vector2i] = [Vector2i(20, 20), Vector2i(21, 20)]
	for slot in slots:
		simulation._astar.set_point_solid(slot, false)
	for id in ids:
		var unit := simulation.entity(id)
		unit["order"] = &"idle"
		unit["path"] = []
	var partial_issued := simulation.command_move(RtsSimulation.TEAM_PLAYER, ids.slice(0, 8), slots[0])
	_expect(partial_issued, "capacity-limited formation rejected every available destination", failures)
	var moved_count := 0
	for id in ids.slice(0, 8):
		if simulation.entity(id).get("order") == &"move":
			moved_count += 1
	_expect(moved_count == slots.size(), "capacity-limited formation did not dispatch exactly the available slots", failures)


func _test_live_placement_occupancy(failures: Array[String]) -> void:
	var simulation := _blank_simulation()
	var builder_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", Vector2i(8, 54))
	var occupied_cell := Vector2i(14, 50)
	simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", occupied_cell)
	simulation._rebuild_pathfinding()
	_expect(not simulation.can_place_structure(RtsSimulation.TEAM_PLAYER, &"war_camp", occupied_cell), "War Camp placement accepted a live-unit overlap", failures)
	_expect(not simulation.command_build(RtsSimulation.TEAM_PLAYER, builder_id, &"war_camp", occupied_cell), "construction command created a foundation on a live unit", failures)
	var farm_origin := occupied_cell - Vector2i.ONE
	_expect(not simulation.can_place_structure(RtsSimulation.TEAM_PLAYER, &"rice_farm", farm_origin), "multi-cell structure footprint accepted a live-unit overlap", failures)


func _test_role_movement_profiles(failures: Array[String]) -> void:
	var combat_kinds: Array[StringName] = [&"hunter", &"vanguard", &"mystic", &"jadeclaw"]
	for faction in FactionCatalog.ORDER:
		var worker_speed := float(FactionCatalog.stats(&"worker", faction)["speed"])
		for combat_kind in combat_kinds:
			var combat_speed := float(FactionCatalog.stats(combat_kind, faction)["speed"])
			_expect(
				worker_speed < combat_speed,
				"%s Worker was not slower than its %s" % [faction, combat_kind],
				failures,
			)

	var simulation := _blank_simulation()
	var worker_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", Vector2i(8, 54))
	var vanguard_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", Vector2i(8, 52))
	var worker := simulation.entity(worker_id)
	var vanguard := simulation.entity(vanguard_id)
	var worker_profile := simulation._separation_profile(worker)
	var combat_profile := simulation._separation_profile(vanguard)
	_expect(worker_profile.x < combat_profile.x, "Worker separation stiffness was not lower than combat stiffness", failures)
	_expect(worker_profile.y > combat_profile.y, "Worker separation damping was not stronger than combat damping", failures)
	_expect(worker_profile.z < combat_profile.z, "Worker separation speed cap was not lower than the combat cap", failures)
	_expect(
		simulation.command_move(RtsSimulation.TEAM_PLAYER, [worker_id], Vector2i(18, 54)),
		"Worker speed probe command was rejected",
		failures,
	)
	_expect(
		simulation.command_move(RtsSimulation.TEAM_PLAYER, [vanguard_id], Vector2i(18, 52)),
		"Vanguard speed probe command was rejected",
		failures,
	)
	_advance(simulation, 1.0)
	var worker_distance := (worker["position"] as Vector2).distance_to(Vector2(8, 54))
	var vanguard_distance := (vanguard["position"] as Vector2).distance_to(Vector2(8, 52))
	_expect(vanguard_distance > worker_distance + 0.4, "Vanguard did not visibly outpace the Worker", failures)

	var worker_spread := _blank_simulation()
	var first_worker_id := worker_spread._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", Vector2i(24, 54))
	var second_worker_id := worker_spread._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", Vector2i(24, 54))
	worker_spread._resolve_unit_separation(RtsSimulation.TICK_SECONDS)
	var worker_first_tick := (
		worker_spread.entity(first_worker_id)["position"] as Vector2
	).distance_to(worker_spread.entity(second_worker_id)["position"] as Vector2)

	var combat_spread := _blank_simulation()
	var first_combat_id := combat_spread._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", Vector2i(24, 54))
	var second_combat_id := combat_spread._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", Vector2i(24, 54))
	combat_spread._resolve_unit_separation(RtsSimulation.TICK_SECONDS)
	var combat_first_tick := (
		combat_spread.entity(first_combat_id)["position"] as Vector2
	).distance_to(combat_spread.entity(second_combat_id)["position"] as Vector2)
	_expect(combat_first_tick > worker_first_tick * 1.5, "Combat units did not settle more responsively than Workers", failures)


func _test_friendly_passthrough_and_idle_spacing(failures: Array[String]) -> void:
	var friendly_kinds: Array[StringName] = [&"worker", &"hunter", &"vanguard", &"mystic", &"jadeclaw"]
	var lane_y := 54
	var destination := Vector2i(18, lane_y)
	for moving_kind in friendly_kinds:
		var traversal_simulation := _blank_simulation()
		var moving_id := traversal_simulation._spawn_unit(
			RtsSimulation.TEAM_PLAYER,
			moving_kind,
			Vector2i(8, lane_y),
		)
		if moving_kind == &"hunter":
			traversal_simulation.entity(moving_id)["wander_timer"] = 999.0
		var blocker_positions: Dictionary = {}
		for blocker_index in range(friendly_kinds.size()):
			var blocker_id := traversal_simulation._spawn_unit(
				RtsSimulation.TEAM_PLAYER,
				friendly_kinds[blocker_index],
				Vector2i(9 + blocker_index * 2, lane_y),
			)
			if friendly_kinds[blocker_index] == &"hunter":
				traversal_simulation.entity(blocker_id)["wander_timer"] = 999.0
			blocker_positions[blocker_id] = traversal_simulation.entity(blocker_id)["position"]
		_expect(
			traversal_simulation.command_move(RtsSimulation.TEAM_PLAYER, [moving_id], destination),
			"%s traversal command was rejected" % moving_kind,
			failures,
		)
		_advance(traversal_simulation, 12.0)
		_expect(
			(traversal_simulation.entity(moving_id)["position"] as Vector2).distance_to(Vector2(destination)) < 0.15,
			"%s did not pass through the complete friendly unit line" % moving_kind,
			failures,
		)
		for blocker_id in blocker_positions:
			_expect(
				(traversal_simulation.entity(int(blocker_id))["position"] as Vector2).is_equal_approx(
					blocker_positions[blocker_id] as Vector2
				),
				"moving %s displaced an idle friendly unit" % moving_kind,
				failures,
			)

	var overlap_cell := Vector2i(24, lane_y)
	for first_index in range(friendly_kinds.size()):
		for second_index in range(first_index, friendly_kinds.size()):
			var idle_simulation := _blank_simulation()
			var first_idle_id := idle_simulation._spawn_unit(
				RtsSimulation.TEAM_PLAYER,
				friendly_kinds[first_index],
				overlap_cell,
			)
			var second_idle_id := idle_simulation._spawn_unit(
				RtsSimulation.TEAM_PLAYER,
				friendly_kinds[second_index],
				overlap_cell,
			)
			idle_simulation._resolve_unit_separation(RtsSimulation.TICK_SECONDS)
			var first_tick_distance := (
				idle_simulation.entity(first_idle_id)["position"] as Vector2
			).distance_to(idle_simulation.entity(second_idle_id)["position"] as Vector2)
			_expect(
				first_tick_distance > 0.0 and first_tick_distance < RtsSimulation.UNIT_SEPARATION_DISTANCE,
				"idle %s and %s units snapped apart instead of spreading smoothly" % [friendly_kinds[first_index], friendly_kinds[second_index]],
				failures,
			)
			for _step in range(int(2.0 / RtsSimulation.TICK_SECONDS)):
				idle_simulation._resolve_unit_separation(RtsSimulation.TICK_SECONDS)
			var idle_distance := (
				idle_simulation.entity(first_idle_id)["position"] as Vector2
			).distance_to(idle_simulation.entity(second_idle_id)["position"] as Vector2)
			_expect(
				idle_distance >= RtsSimulation.UNIT_SEPARATION_DISTANCE - 0.001,
				"idle %s and %s units did not spread apart" % [friendly_kinds[first_index], friendly_kinds[second_index]],
				failures,
			)
			_expect(
				(idle_simulation.entity(first_idle_id).get("separation_velocity", Vector2.ZERO) as Vector2).length()
					<= RtsSimulation.UNIT_SEPARATION_STOP_SPEED,
				"idle %s retained separation drift after settling" % friendly_kinds[first_index],
				failures,
			)

	var hostile_simulation := _blank_simulation()
	var worker_id := hostile_simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", overlap_cell)
	var enemy_id := hostile_simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", overlap_cell)
	for _step in range(int(2.0 / RtsSimulation.TICK_SECONDS)):
		hostile_simulation._resolve_unit_separation(RtsSimulation.TICK_SECONDS)
	var hostile_distance := (
		hostile_simulation.entity(worker_id)["position"] as Vector2
	).distance_to(hostile_simulation.entity(enemy_id)["position"] as Vector2)
	_expect(
		hostile_distance >= RtsSimulation.UNIT_SEPARATION_DISTANCE - 0.001,
		"worker incorrectly passed through an enemy unit",
		failures,
	)


func _test_ai_natural_construction_and_fallback(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", true)
	_expect(simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"war_camp") < 0, "AI still started with a free completed War Camp", failures)
	var initial_lumber := int(simulation.players[RtsSimulation.TEAM_ENEMY]["lumber"])
	var camp_id := -1
	var timeout := 180.0
	while camp_id < 0 and timeout > 0.0:
		simulation.advance(RtsSimulation.TICK_SECONDS)
		camp_id = simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"war_camp")
		timeout -= RtsSimulation.TICK_SECONDS
	_expect(camp_id >= 0, "AI did not harvest enough Lumber to construct its first War Camp", failures)
	_expect(initial_lumber < int(FactionCatalog.stats(&"war_camp", simulation.players[RtsSimulation.TEAM_ENEMY]["faction"] as StringName)["lumber_cost"]), "AI natural-build regression did not begin below War Camp Lumber cost", failures)
	if camp_id >= 0:
		_expect(float(simulation.entity(camp_id).get("complete", 1.0)) < 1.0, "AI-created War Camp bypassed construction time", failures)

	var controlled := _blank_simulation()
	var controlled_camp_id := controlled._spawn_structure(RtsSimulation.TEAM_ENEMY, &"war_camp", Vector2i(66, 14), true)
	controlled._rebuild_pathfinding()
	controlled.players[RtsSimulation.TEAM_ENEMY]["jade"] = 500
	controlled.players[RtsSimulation.TEAM_ENEMY]["lumber"] = 500
	controlled.players[RtsSimulation.TEAM_ENEMY]["essence"] = 0
	controlled.players[RtsSimulation.TEAM_ENEMY]["food"] = 500
	controlled._ai_training_flip = true
	controlled._ai_strategy_timer = 0.0
	controlled._advance_ai(RtsSimulation.TICK_SECONDS)
	var queue := controlled.entity(controlled_camp_id)["queue"] as Array
	_expect(not queue.is_empty(), "AI stalled production when its preferred Mystic was unaffordable", failures)
	if not queue.is_empty():
		_expect((queue[0] as Dictionary)["kind"] == &"vanguard", "AI did not fall back from an unaffordable Mystic to a Vanguard", failures)

	var stipend_probe := _blank_simulation()
	var resources_before := stipend_probe.players[RtsSimulation.TEAM_ENEMY].duplicate(true)
	stipend_probe._ai_strategy_timer = 999.0
	stipend_probe._advance_ai(8.0)
	for kind in ["jade", "lumber", "essence", "food"]:
		_expect(int(stipend_probe.players[RtsSimulation.TEAM_ENEMY][kind]) == int(resources_before[kind]), "AI received an unearned %s stipend" % kind, failures)


func _find_blocked_los_pair(simulation: RtsSimulation, attacker: Dictionary, target: Dictionary) -> Array[Vector2i]:
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var start := Vector2i(x, y)
			if not MapCatalog.is_static_walkable(start):
				continue
			for offset_y in range(-4, 5):
				for offset_x in range(-4, 5):
					var finish := start + Vector2i(offset_x, offset_y)
					if finish == start or not MapCatalog.is_static_walkable(finish):
						continue
					if Vector2(start).distance_to(Vector2(finish)) > 4.0:
						continue
					attacker["position"] = Vector2(start)
					attacker["cell"] = start
					target["position"] = Vector2(finish)
					target["cell"] = finish
					if not simulation._has_line_of_sight(attacker, target):
						return [start, finish]
	return []


func _test_line_of_sight_and_invalid_commands(failures: Array[String]) -> void:
	var simulation := _blank_simulation()
	var attacker_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"mystic", Vector2i(8, 54))
	var target_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"worker", Vector2i(9, 54))
	var attacker := simulation.entity(attacker_id)
	var target := simulation.entity(target_id)
	var blocked_pair := _find_blocked_los_pair(simulation, attacker, target)
	_expect(blocked_pair.size() == 2, "expanded map contains no ridge-blocked firing fixture", failures)
	_expect(not simulation._has_line_of_sight(attacker, target), "ridge did not block line-of-sight", failures)
	_expect(not simulation._has_line_of_sight(target, attacker), "line-of-sight blocker was asymmetric", failures)
	_expect(simulation._nearest_enemy(attacker, 5.0, true) < 0, "unit acquired an enemy through a ridge", failures)
	var hp_before := float(target["hp"])
	simulation.command_attack(RtsSimulation.TEAM_PLAYER, [attacker_id], target_id)
	simulation.advance(RtsSimulation.TICK_SECONDS)
	_expect(is_equal_approx(float(target["hp"]), hp_before), "ranged unit attacked through a ridge", failures)

	var unit_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", Vector2i(8, 54))
	var unit := simulation.entity(unit_id)
	var order_before := unit.get("order") as StringName
	_expect(not simulation.command_move(RtsSimulation.TEAM_PLAYER, [unit_id], Vector2i(-50, -50)), "off-map movement command was accepted", failures)
	_expect(unit.get("order") == order_before, "rejected movement command changed unit state", failures)
	var hold_id := simulation._spawn_structure(RtsSimulation.TEAM_PLAYER, &"stronghold", Vector2i(5, 55), true)
	_expect(not simulation.set_rally(RtsSimulation.TEAM_PLAYER, hold_id, Vector2i(500, 500)), "off-map rally command was accepted", failures)


func _test_command_authority(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var enemy_worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_ENEMY, [&"worker"])[0]
	var enemy_worker := simulation.entity(enemy_worker_id)
	var enemy_order := enemy_worker.get("order") as StringName
	var player_hold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	var enemy_hold_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"stronghold")
	var resource_id := -1
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("category") == &"resource":
			resource_id = int(entity_state["id"])
			break
	_expect(resource_id >= 0, "authority test could not find a resource", failures)
	_expect(not simulation.command_move(RtsSimulation.TEAM_PLAYER, [enemy_worker_id], Vector2i(70, 15)), "player issuer moved a rival unit", failures)
	_expect(not simulation.command_attack(RtsSimulation.TEAM_PLAYER, [enemy_worker_id], player_hold_id), "player issuer gave a rival attack order", failures)
	_expect(not simulation.command_gather(RtsSimulation.TEAM_PLAYER, [enemy_worker_id], resource_id), "player issuer reassigned a rival worker", failures)
	_expect(not simulation.command_stop(RtsSimulation.TEAM_PLAYER, [enemy_worker_id]), "player issuer stopped a rival unit", failures)
	_expect(not simulation.command_build(RtsSimulation.TEAM_PLAYER, enemy_worker_id, &"war_camp", Vector2i(66, 14)), "player issuer built with a rival worker", failures)
	_expect(enemy_worker.get("order") == enemy_order, "rejected rival unit commands changed its state", failures)
	var enemy_vanguard_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", Vector2i(69, 14))
	_expect(not simulation.command_patrol(RtsSimulation.TEAM_PLAYER, [enemy_vanguard_id], Vector2i(65, 16)), "player issuer patrolled a rival military unit", failures)
	var enemy_hold := simulation.entity(enemy_hold_id)
	enemy_hold["hp"] = float(enemy_hold["max_hp"]) - 20.0
	_expect(not simulation.command_repair(RtsSimulation.TEAM_PLAYER, [enemy_worker_id], enemy_hold_id), "player issuer repaired a rival structure with a rival worker", failures)
	_expect(not simulation.command_move(-1, [enemy_worker_id], Vector2i(70, 15)), "invalid issuer team was accepted", failures)

	var player_jade_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["jade"])
	enemy_worker["cargo_kind"] = &"jade"
	enemy_worker["cargo_amount"] = 10.0
	_expect(simulation.command_deposit(RtsSimulation.TEAM_PLAYER, [enemy_worker_id], player_hold_id) == 0, "player issuer deposited rival cargo", failures)
	_expect(int(simulation.players[RtsSimulation.TEAM_PLAYER]["jade"]) == player_jade_before, "rejected rival deposit changed player resources", failures)
	_expect(is_equal_approx(float(enemy_worker["cargo_amount"]), 10.0), "rejected rival deposit cleared its cargo", failures)

	var player_population_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["population"])
	_expect(not simulation.command_train(RtsSimulation.TEAM_PLAYER, enemy_hold_id, &"worker"), "player issuer queued production in a rival structure", failures)
	_expect(int(simulation.players[RtsSimulation.TEAM_PLAYER]["population"]) == player_population_before, "rejected rival production changed player population", failures)
	_expect(simulation.command_train(RtsSimulation.TEAM_ENEMY, enemy_hold_id, &"worker"), "rival issuer could not queue its own production", failures)
	var enemy_queue_before := (enemy_hold.get("queue", []) as Array).size()
	_expect(simulation.command_cancel_training(RtsSimulation.TEAM_PLAYER, enemy_hold_id).is_empty(), "player issuer cancelled a rival production queue", failures)
	_expect((enemy_hold.get("queue", []) as Array).size() == enemy_queue_before, "rejected rival cancellation mutated the queue", failures)
	_expect(not simulation.set_rally(RtsSimulation.TEAM_PLAYER, enemy_hold_id, Vector2i(70, 15)), "player issuer changed a rival rally point", failures)
	_expect(simulation.command_move(RtsSimulation.TEAM_ENEMY, [enemy_worker_id], Vector2i(70, 15)), "rival issuer could not command its own unit", failures)


func _run() -> void:
	var failures: Array[String] = []
	_expect(MapCatalog.validation_errors().is_empty(), "authored map validation reported an error", failures)
	_test_attack_move_external_kill(failures)
	_test_scalable_and_partial_formations(failures)
	_test_live_placement_occupancy(failures)
	_test_role_movement_profiles(failures)
	_test_friendly_passthrough_and_idle_spacing(failures)
	_test_ai_natural_construction_and_fallback(failures)
	_test_line_of_sight_and_invalid_commands(failures)
	_test_command_authority(failures)
	if failures.is_empty():
		print("PASS core_regression_test: attack-move race, scalable/partial formations, occupancy, role movement profiles, friendly passthrough, idle spacing, hostile separation, fair AI economy, sight, bounds, authority")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
