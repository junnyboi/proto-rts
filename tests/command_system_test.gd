extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _walk_unit(simulation: RtsSimulation, unit: Dictionary, seconds: float) -> void:
	for _step in range(int(seconds / RtsSimulation.TICK_SECONDS)):
		simulation._advance_path(unit, RtsSimulation.TICK_SECONDS)


func _test_shift_order_queue(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	var worker := simulation.entity(worker_id)
	var origin := worker["cell"] as Vector2i
	var first := simulation._nearest_walkable(origin + Vector2i(3, 0))
	var second := simulation._nearest_walkable(origin + Vector2i(6, 0))
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [worker_id], first)
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [worker_id], second, false, true)
	if (worker.get("command_queue", []) as Array).size() != 1:
		failures.append("Shift-move did not append one queued order")
	_walk_unit(simulation, worker, 12.0)
	if (worker["position"] as Vector2).distance_to(Vector2(second)) > 0.15:
		failures.append("queued move chain did not reach its second destination")
	if worker.get("order") != &"idle" or not (worker.get("command_queue", []) as Array).is_empty():
		failures.append("completed move chain did not return to an empty idle state")

	simulation.command_move(RtsSimulation.TEAM_PLAYER, [worker_id], first)
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [worker_id], second, false, true)
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [worker_id], origin)
	if not (worker.get("command_queue", []) as Array).is_empty():
		failures.append("a replacing move did not clear queued orders")
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [worker_id], first, false, true)
	simulation.command_stop(RtsSimulation.TEAM_PLAYER, [worker_id])
	if worker.get("order") != &"idle" or not (worker.get("command_queue", []) as Array).is_empty():
		failures.append("Stop did not clear the active and queued orders")

	var enemy_cell := simulation._nearest_walkable(origin + Vector2i(2, 1))
	var enemy_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", enemy_cell)
	simulation._refresh_visibility()
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [worker_id], first)
	simulation.command_attack(RtsSimulation.TEAM_PLAYER, [worker_id], enemy_id, true)
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [worker_id], second, false, true)
	simulation.entity(enemy_id)["alive"] = false
	_walk_unit(simulation, worker, 12.0)
	simulation._advance_attack_order(worker, RtsSimulation.TICK_SECONDS)
	_walk_unit(simulation, worker, 12.0)
	if (worker["position"] as Vector2).distance_to(Vector2(second)) > 0.15:
		failures.append("an invalid queued target was not skipped in favor of the next order")


func _test_patrol(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var origin := simulation._nearest_walkable(MapCatalog.PLAYER_WORKERS[0] + Vector2i(3, 0))
	var destination := simulation._nearest_walkable(origin + Vector2i(4, 0))
	var unit_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", origin)
	var unit := simulation.entity(unit_id)
	if not simulation.command_patrol(RtsSimulation.TEAM_PLAYER, [unit_id], destination):
		failures.append("valid military patrol command was rejected")
		return
	_walk_unit(simulation, unit, 6.0)
	if unit.get("order") != &"patrol":
		failures.append("patrol stopped instead of repeating")
	if unit.get("patrol_origin") != origin or unit.get("patrol_destination") != destination:
		failures.append("patrol did not retain both route endpoints")
	unit["target_id"] = 999999
	unit["path"] = []
	simulation._advance_attack_order(unit, RtsSimulation.TICK_SECONDS)
	if unit.get("order") != &"patrol" or (unit.get("path", []) as Array).is_empty():
		failures.append("patrol did not resume its route after losing a combat target")


func _test_repair(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	var worker := simulation.entity(worker_id)
	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	var stronghold := simulation.entity(stronghold_id)
	var adjacent := stronghold["cell"] as Vector2i + Vector2i(0, -1)
	worker["position"] = Vector2(adjacent)
	worker["cell"] = adjacent
	worker["path"] = []
	stronghold["hp"] = float(stronghold["max_hp"]) - 10.0
	var lumber_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"])
	if not simulation.command_repair(RtsSimulation.TEAM_PLAYER, [worker_id], stronghold_id):
		failures.append("valid repair command was rejected")
		return
	simulation._advance_repair(worker, RtsSimulation.REPAIR_CYCLE)
	if float(stronghold["hp"]) != float(stronghold["max_hp"]):
		failures.append("repair did not restore the expected structure health")
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != lumber_before - RtsSimulation.REPAIR_LUMBER_COST:
		failures.append("repair did not consume the expected Lumber")
	if worker.get("order") != &"idle":
		failures.append("worker did not complete a fully repaired structure order")

	stronghold["hp"] = float(stronghold["max_hp"]) - 30.0
	worker["position"] = Vector2(simulation._nearest_walkable(adjacent + Vector2i(8, 0)))
	worker["cell"] = Vector2i((worker["position"] as Vector2).round())
	simulation.command_repair(RtsSimulation.TEAM_PLAYER, [worker_id], stronghold_id)
	var hp_before_travel := float(stronghold["hp"])
	simulation._advance_repair(worker, RtsSimulation.TICK_SECONDS)
	if float(stronghold["hp"]) != hp_before_travel or (worker.get("path", []) as Array).is_empty():
		failures.append("remote repair did not require worker travel")
	var enemy_hold := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"stronghold")
	if simulation.command_repair(RtsSimulation.TEAM_PLAYER, [worker_id], enemy_hold):
		failures.append("worker was allowed to repair an enemy structure")


func _test_training_cancellation(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var camp_cell := simulation._nearest_walkable(MapCatalog.PLAYER_WORKERS[0] + Vector2i(5, 0))
	var camp_id := simulation._spawn_structure(RtsSimulation.TEAM_PLAYER, &"war_camp", camp_cell, true)
	var resources_before := simulation.players[RtsSimulation.TEAM_PLAYER].duplicate(true)
	if not simulation.command_train(RtsSimulation.TEAM_PLAYER, camp_id, &"vanguard"):
		failures.append("Vanguard could not be queued for cancellation test")
		return
	if not simulation.command_train(RtsSimulation.TEAM_PLAYER, camp_id, &"mystic"):
		failures.append("Mystic could not be queued for cancellation test")
		return
	var population_with_queue := int(simulation.players[RtsSimulation.TEAM_PLAYER]["population"])
	var mystic_population := int(FactionCatalog.stats(&"mystic", &"human")["population"])
	var cancelled := simulation.command_cancel_training(RtsSimulation.TEAM_PLAYER, camp_id)
	if cancelled.get("kind") != &"mystic":
		failures.append("cancellation did not remove the newest queued unit")
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["population"]) != population_with_queue - mystic_population:
		failures.append("cancellation did not release reserved population")
	var vanguard_stats := FactionCatalog.stats(&"vanguard", &"human")
	for resource_kind in ["jade", "lumber", "essence", "food"]:
		var expected := int(resources_before[resource_kind]) - int(vanguard_stats.get("%s_cost" % resource_kind, 0))
		if int(simulation.players[RtsSimulation.TEAM_PLAYER][resource_kind]) != expected:
			failures.append("cancellation did not preserve only the remaining Vanguard's %s cost" % resource_kind)
	if not simulation.command_cancel_training(RtsSimulation.TEAM_ENEMY, camp_id).is_empty():
		failures.append("enemy team was allowed to cancel the player's production queue")


func _test_control_groups(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	battlefield.set_simulation(simulation)
	root.add_child(battlefield)
	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	battlefield.select_entities([workers[0]])
	battlefield.assign_control_group(1)
	battlefield.select_entities([stronghold_id])
	battlefield.assign_control_group(1, true)
	battlefield.select_entities([])
	battlefield.recall_control_group(1)
	if battlefield.selected_ids != [workers[0], stronghold_id]:
		failures.append("control group append and recall did not preserve stable membership")

	var second_worker := simulation.entity(workers[1])
	battlefield.select_entities([workers[1]])
	battlefield.assign_control_group(2)
	battlefield.select_entities([stronghold_id])
	battlefield.recall_control_group(2, true)
	if not battlefield.selected_ids.has(stronghold_id) or not battlefield.selected_ids.has(workers[1]):
		failures.append("Shift-recall did not merge a group into the current selection")
	second_worker["alive"] = false
	battlefield.recall_control_group(2)
	if not battlefield.selected_ids.is_empty() or not (battlefield.control_groups[2] as Array).is_empty():
		failures.append("control-group recall did not remove dead members")

	battlefield.select_entities([workers[0]])
	battlefield.assign_control_group(3)
	battlefield.select_entities([])
	battlefield.camera_offset = Vector2(123.0, 456.0)
	battlefield.recall_control_group(3)
	if battlefield.camera_offset != Vector2(123.0, 456.0):
		failures.append("first control-group recall unexpectedly centered the camera")
	battlefield.recall_control_group(3)
	var double_recall_offset := battlefield.camera_offset
	battlefield.camera_offset = Vector2(321.0, 654.0)
	battlefield.center_on_selection()
	if not battlefield.camera_offset.is_equal_approx(double_recall_offset):
		failures.append("double control-group recall did not center the camera")
	battlefield.queue_free()


func _test_modifier_input_forwarding(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	battlefield.set_simulation(simulation)
	root.add_child(battlefield)
	var origin := simulation._nearest_walkable(MapCatalog.PLAYER_WORKERS[0] + Vector2i(3, 0))
	var first := simulation._nearest_walkable(origin + Vector2i(4, 0))
	var second := simulation._nearest_walkable(origin + Vector2i(8, 0))
	var vanguard_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", origin)
	var vanguard := simulation.entity(vanguard_id)
	battlefield.select_entities([vanguard_id])
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [vanguard_id], first)
	var second_screen := (
		battlefield.camera_offset
		+ IsoProjection.position_center(Vector2(second)) * battlefield.camera_scale
	)
	battlefield.call("_handle_right_click", second_screen, true)
	var queue := vanguard.get("command_queue", []) as Array
	if queue.is_empty() or (queue[0] as Dictionary).get("type") != &"move":
		failures.append("Shift-right-click was not forwarded as an appended move")
	simulation.command_stop(RtsSimulation.TEAM_PLAYER, [vanguard_id])
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [vanguard_id], first)
	battlefield.begin_patrol(true)
	battlefield.call("_handle_left_press", second_screen)
	queue = vanguard.get("command_queue", []) as Array
	if queue.is_empty() or (queue[0] as Dictionary).get("type") != &"patrol":
		failures.append("Shift-armed patrol was not forwarded as an appended order")
	battlefield.queue_free()

	var main_script := load("res://scripts/main.gd") as GDScript
	var main_node := main_script.new() as Node
	var number_key := InputEventKey.new()
	number_key.keycode = KEY_7
	if int(main_node.call("_control_group_index", number_key)) != 7:
		failures.append("number-key input was not mapped to its control group")
	main_node.free()


func _run() -> void:
	var failures: Array[String] = []
	_test_shift_order_queue(failures)
	_test_patrol(failures)
	_test_repair(failures)
	_test_training_cancellation(failures)
	_test_control_groups(failures)
	_test_modifier_input_forwarding(failures)
	if failures.is_empty():
		print("PASS command_system_test: control groups, Shift queues, repair, patrol, cancellation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
