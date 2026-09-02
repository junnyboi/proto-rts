extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_verify_camera_input_bindings(failures)
	var simulation := RtsSimulation.new()
	simulation.setup(&"celestial")
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	battlefield.set_simulation(simulation)
	root.add_child(battlefield)
	await process_frame
	var camera_offset_before := battlefield.camera_offset
	Input.action_press(&"camera_right")
	battlefield.call("_process", 0.1)
	Input.action_release(&"camera_right")
	if battlefield.camera_offset.x >= camera_offset_before.x:
		failures.append("camera_right input did not pan the battlefield")
	_verify_zoom_input(battlefield, failures)
	_verify_deterministic_entity_depth_sort(battlefield, failures)

	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	var worker_id := workers[0]
	var worker_screen_position := battlefield.entity_screen_position(simulation.entity(worker_id))
	battlefield.call("_handle_left_press", worker_screen_position)
	battlefield.call("_handle_left_release", worker_screen_position)
	if battlefield.selected_ids.size() != 1 or battlefield.selected_ids[0] != worker_id:
		failures.append("clicking a worker did not select it")
	var worker_selection_rect := Rect2(
		worker_screen_position - Vector2.ONE * 2.0,
		Vector2.ONE * 4.0,
	)
	battlefield.select_entities([])
	battlefield.call("_select_in_rect", worker_selection_rect, false)
	if battlefield.selected_ids != [worker_id]:
		failures.append("drag selection did not produce a typed unit selection")
	var second_worker_id := workers[1]
	battlefield.select_entities([second_worker_id])
	battlefield.call("_select_in_rect", worker_selection_rect, true)
	if not battlefield.selected_ids.has(worker_id) or not battlefield.selected_ids.has(second_worker_id):
		failures.append("Shift-drag selection did not preserve and extend its typed unit selection")

	battlefield.call("_handle_left_press", Vector2(-1000.0, -1000.0))
	battlefield.call("_handle_left_release", Vector2(-1000.0, -1000.0))
	if not battlefield.selected_ids.is_empty():
		failures.append("clicking empty ground did not clear the selection")

	battlefield.set_fog_enabled(false)
	var cave_id := simulation.cave_ids()[0]
	var cave_position := battlefield.entity_screen_position(simulation.entity(cave_id))
	battlefield.call("_handle_left_press", cave_position)
	battlefield.call("_handle_left_release", cave_position)
	if battlefield.selected_ids.size() != 1 or battlefield.selected_ids[0] != cave_id:
		failures.append("clicking a neutral Yaoguai Den did not select its status panel")
	var hunter_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", MapCatalog.PLAYER_WORKERS[0])
	battlefield.select_entities([hunter_id])
	battlefield.call("_handle_right_click", cave_position)
	var hunter := simulation.entity(hunter_id)
	if hunter.get("order") != &"attack_move":
		failures.append("right-clicking a Yaoguai Den did not issue its contextual hunt order")

	battlefield.select_player_stronghold()
	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	if battlefield.selected_ids.size() != 1 or battlefield.selected_ids[0] != stronghold_id:
		failures.append("Stronghold shortcut did not select the player Stronghold")
	var worker := simulation.entity(worker_id)
	worker["cargo_kind"] = &"lumber"
	worker["cargo_amount"] = 20.0
	var lumber_before_deposit := int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"])
	battlefield.select_entities([worker_id])
	var stronghold_position := battlefield.entity_screen_position(simulation.entity(stronghold_id))
	battlefield.call("_handle_right_click", stronghold_position)
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != lumber_before_deposit:
		failures.append("right-clicking the Stronghold deposited remote cargo immediately")
	if worker.get("order") != &"return" or worker.get("cargo_kind") != &"lumber":
		failures.append("right-clicking the Stronghold did not start a physical cargo return")
	var deposit_timeout := 10.0
	while float(worker.get("cargo_amount", 0.0)) > 0.0 and deposit_timeout > 0.0:
		simulation.advance(RtsSimulation.TICK_SECONDS)
		deposit_timeout -= RtsSimulation.TICK_SECONDS
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != lumber_before_deposit + 20:
		failures.append("the contextual return did not deposit after reaching the Stronghold")
	if float(worker.get("cargo_amount", -1.0)) != 0.0 or worker.get("cargo_kind") != &"":
		failures.append("the contextual return did not clear the worker's cargo")

	var tree_id := -1
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			entity_state.get("resource_kind") == &"lumber"
			and simulation.is_entity_explored_by_team(RtsSimulation.TEAM_PLAYER, entity_state)
		):
			tree_id = int(entity_state["id"])
			break
	if tree_id < 0:
		failures.append("no Lumber tree was available for contextual input")
	else:
		battlefield.select_entities([worker_id])
		var tree_position := battlefield.entity_screen_position(simulation.entity(tree_id))
		battlefield.call("_handle_right_click", tree_position)
		worker = simulation.entity(worker_id)
		if worker.get("order") != &"gather" or int(worker.get("gather_source_id", -1)) != tree_id:
			failures.append("right-clicking a Lumber tree did not issue a gather order")

	simulation.players[RtsSimulation.TEAM_PLAYER]["jade"] = 1000
	simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"] = 1000
	battlefield.select_entities([worker_id])
	battlefield.begin_structure_placement(&"rice_farm")
	if battlefield.placement_kind != &"rice_farm" or battlefield.placement_worker_id != worker_id:
		failures.append("Rice Farm command did not arm generic structure placement")
	else:
		var farm_site := simulation._find_build_site(
			RtsSimulation.TEAM_PLAYER,
			&"rice_farm",
			MapCatalog.PLAYER_STRONGHOLD,
		)
		var farm_screen_position := battlefield.camera_offset + IsoProjection.cell_center(farm_site) * battlefield.camera_scale
		battlefield.call("_handle_left_press", farm_screen_position)
		if simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"rice_farm") < 0:
			failures.append("Rice Farm placement input did not create a foundation")
		if battlefield.placement_worker_id >= 0 or not battlefield.placement_kind.is_empty():
			failures.append("successful Rice Farm placement did not clear placement mode")

	var hunting_simulation := RtsSimulation.new()
	hunting_simulation.setup(&"human")
	battlefield.set_simulation(hunting_simulation)
	battlefield.set_fog_enabled(false)
	var wildlife_id := hunting_simulation.wildlife_ids(&"deer")[0]
	var wildlife := hunting_simulation.entity(wildlife_id)
	var hunter_cell := (wildlife["cell"] as Vector2i) + Vector2i(-2, 0)
	var hunting_unit_id := hunting_simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"hunter",
		hunter_cell,
	)
	hunting_simulation._refresh_visibility()
	battlefield.select_entities([hunting_unit_id])
	battlefield.call("_handle_right_click", battlefield.entity_screen_position(wildlife), false)
	var hunting_unit := hunting_simulation.entity(hunting_unit_id)
	if hunting_unit.get("order") != &"attack" or int(hunting_unit.get("target_id", -1)) != wildlife_id:
		failures.append("right-clicking visible wildlife did not issue a Hunter hunt order")

	_verify_procedural_movement_visuals(battlefield, hunting_simulation, hunting_unit_id, wildlife_id, failures)
	_verify_command_visualizations(battlefield, failures)

	battlefield.queue_free()
	if failures.is_empty():
		print("PASS interaction_test: camera, selection, contextual economy, building placement, wildlife hunting, and command visualization")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _verify_procedural_movement_visuals(
	battlefield: Battlefield,
	simulation: RtsSimulation,
	hunter_id: int,
	wildlife_id: int,
	failures: Array[String],
) -> void:
	battlefield.call("_update_movement_visuals", 0.016)
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			bool(entity_state.get("alive", false))
			and entity_state.get("category") in [&"unit", &"wildlife"]
			and not battlefield._movement_visuals.has(int(entity_state.get("id", -1)))
		):
			failures.append("a movable unit was missing its procedural animation state")
			break

	var hunter := simulation.entity(hunter_id)
	var hunter_position := hunter["position"] as Vector2
	hunter["position"] = hunter_position + Vector2(0.0, 0.25)
	battlefield.call("_update_movement_visuals", 0.016)
	if not battlefield.call("_movement_faces_left", hunter):
		failures.append("Hunter sprite did not face left for leftward projected movement")
	battlefield._walk_animation_time = 0.37
	if float(battlefield.call("_movement_bounce_offset", hunter)) >= 0.0:
		failures.append("moving Hunter did not receive an upward procedural bounce")

	hunter["position"] = hunter_position + Vector2(0.25, 0.0)
	battlefield.call("_update_movement_visuals", 0.016)
	if battlefield.call("_movement_faces_left", hunter):
		failures.append("Hunter sprite did not face right for rightward projected movement")

	var wildlife := simulation.entity(wildlife_id)
	var wildlife_position := wildlife["position"] as Vector2
	wildlife["position"] = wildlife_position + Vector2(0.0, 0.25)
	battlefield.call("_update_movement_visuals", 0.016)
	if not battlefield.call("_movement_faces_left", wildlife):
		failures.append("wildlife sprite did not face left for leftward projected movement")
	if float(battlefield.call("_movement_bounce_offset", wildlife)) >= 0.0:
		failures.append("moving wildlife did not receive an upward procedural bounce")
	battlefield.call("_update_movement_visuals", 1.0)
	if not battlefield.call("_movement_faces_left", wildlife):
		failures.append("wildlife did not preserve its last horizontal facing while idle")
	if not is_zero_approx(float(battlefield.call("_movement_bounce_offset", wildlife))):
		failures.append("idle wildlife continued its procedural walking bounce")


func _verify_command_visualizations(
	battlefield: Battlefield,
	failures: Array[String],
) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	battlefield.set_simulation(simulation)
	battlefield.set_fog_enabled(false)
	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	var worker_id := workers[0]
	var worker := simulation.entity(worker_id)
	var move_destination := simulation._nearest_walkable(
		(worker["cell"] as Vector2i) + Vector2i(5, -2),
	)
	simulation.command_move([worker_id], move_destination)
	battlefield.select_entities([worker_id])
	var records: Array = battlefield.call("_command_visualization_records") as Array
	if records.size() != 1 or (records[0] as Dictionary).get("kind") != &"flag":
		failures.append("selected move order did not project one destination flag")

	var resource_id := -1
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			entity_state.get("category") == &"resource"
			and simulation.is_entity_explored_by_team(RtsSimulation.TEAM_PLAYER, entity_state)
		):
			resource_id = int(entity_state["id"])
			break
	if resource_id < 0:
		failures.append("no explored resource was available for command visualization")
	else:
		simulation.command_gather([worker_id], resource_id)
		records = battlefield.call("_command_visualization_records") as Array
		if (
			records.size() != 1
			or (records[0] as Dictionary).get("kind") != &"interact"
			or int((records[0] as Dictionary).get("target_id", -1)) != resource_id
		):
			failures.append("selected gather order did not project its resource interaction ring")

	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	worker["cargo_kind"] = &"jade"
	worker["cargo_amount"] = 5.0
	simulation.command_deposit([worker_id], stronghold_id)
	records = battlefield.call("_command_visualization_records") as Array
	if (
		records.size() != 1
		or (records[0] as Dictionary).get("kind") != &"interact"
		or int((records[0] as Dictionary).get("target_id", -1)) != stronghold_id
	):
		failures.append("selected structure interaction did not project its Stronghold ring")

	var combat_origin := simulation._nearest_walkable(
		(worker["cell"] as Vector2i) + Vector2i(1, -1),
	)
	var attacker_id := simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"vanguard",
		combat_origin,
	)
	var second_attacker_id := simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"vanguard",
		combat_origin,
	)
	var target_cell := simulation._nearest_walkable(combat_origin + Vector2i(2, 0))
	var target_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", target_cell)
	simulation._refresh_visibility()
	simulation.command_attack([attacker_id, second_attacker_id], target_id)
	battlefield.select_entities([attacker_id])
	records = battlefield.call("_command_visualization_records") as Array
	if records.size() != 1 or (records[0] as Dictionary).get("kind") != &"attack":
		failures.append("selected attack order did not project crossed swords")
	else:
		var target := simulation.entity(target_id)
		var first_endpoint := (records[0] as Dictionary).get("endpoint", Vector2.ZERO) as Vector2
		target["position"] = target["position"] as Vector2 + Vector2(0.5, 0.25)
		records = battlefield.call("_command_visualization_records") as Array
		var moved_record := records[0] as Dictionary
		var moved_endpoint := moved_record.get("endpoint", Vector2.ZERO) as Vector2
		if moved_endpoint.is_equal_approx(first_endpoint) or not moved_endpoint.is_equal_approx(target["position"] as Vector2):
			failures.append("attack swords did not follow the target's live position")
		var moved_points := moved_record.get("points", []) as Array
		if moved_points.is_empty() or not (moved_points.back() as Vector2).is_equal_approx(moved_endpoint):
			failures.append("attack dotted path did not follow the target's live position")

	battlefield.select_entities([attacker_id, second_attacker_id])
	records = battlefield.call("_command_visualization_records") as Array
	if records.size() != 1:
		failures.append("identical selected attack paths and endpoint icons were not deduplicated")

	var capped_ids: Array[int] = []
	for index in range(Battlefield.MAX_VISIBLE_COMMAND_PATHS + 1):
		var unit_id := simulation._spawn_unit(
			RtsSimulation.TEAM_PLAYER,
			&"vanguard",
			combat_origin,
		)
		var unit := simulation.entity(unit_id)
		unit["order"] = &"move"
		unit["path"] = [
			unit["position"] as Vector2 + Vector2(float(index + 2), float(index % 2)),
		]
		unit["path_index"] = 0
		capped_ids.append(unit_id)
	battlefield.select_entities(capped_ids)
	records = battlefield.call("_command_visualization_records") as Array
	if records.size() != Battlefield.MAX_VISIBLE_COMMAND_PATHS:
		failures.append("command visualization did not cap projection at ten selected units")
	battlefield.select_entities([])
	if not (battlefield.call("_command_visualization_records") as Array).is_empty():
		failures.append("command visualizations remained after deselection")


func _verify_camera_input_bindings(failures: Array[String]) -> void:
	var expected_bindings := {
		&"camera_up": KEY_W,
		&"camera_down": KEY_S,
		&"camera_left": KEY_A,
		&"camera_right": KEY_D,
	}
	for action in expected_bindings:
		var expected_key := expected_bindings[action] as Key
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventKey and (event as InputEventKey).physical_keycode == expected_key:
				found = true
				break
		if not found:
			failures.append("%s is not bound to %s" % [action, OS.get_keycode_string(expected_key)])


func _verify_zoom_input(battlefield: Battlefield, failures: Array[String]) -> void:
	var zoom_position := Vector2(640.0, 360.0)
	var initial_scale := battlefield.camera_scale
	var plain_wheel := InputEventMouseButton.new()
	plain_wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	plain_wheel.pressed = true
	plain_wheel.position = zoom_position
	battlefield.call("_gui_input", plain_wheel)
	if not is_equal_approx(battlefield.camera_scale, initial_scale):
		failures.append("plain mouse-wheel input zoomed without Command or Control")

	var command_wheel_up := InputEventMouseButton.new()
	command_wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	command_wheel_up.pressed = true
	command_wheel_up.meta_pressed = true
	command_wheel_up.position = zoom_position
	battlefield.call("_gui_input", command_wheel_up)
	if battlefield.camera_scale <= initial_scale:
		failures.append("Command-scroll up did not zoom in")

	var scale_after_wheel_up := battlefield.camera_scale
	var command_wheel_down := InputEventMouseButton.new()
	command_wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	command_wheel_down.pressed = true
	command_wheel_down.meta_pressed = true
	command_wheel_down.position = zoom_position
	battlefield.call("_gui_input", command_wheel_down)
	if battlefield.camera_scale >= scale_after_wheel_up:
		failures.append("Command-scroll down did not zoom out")

	var spread := InputEventMagnifyGesture.new()
	spread.factor = 1.1
	spread.position = zoom_position
	var scale_before_spread := battlefield.camera_scale
	battlefield.call("_gui_input", spread)
	if battlefield.camera_scale <= scale_before_spread:
		failures.append("trackpad spread gesture did not zoom in")

	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 0.9
	pinch.position = zoom_position
	var scale_before_pinch := battlefield.camera_scale
	battlefield.call("_gui_input", pinch)
	if battlefield.camera_scale >= scale_before_pinch:
		failures.append("trackpad pinch gesture did not zoom out")


func _verify_deterministic_entity_depth_sort(battlefield: Battlefield, failures: Array[String]) -> void:
	var first_order: Array[Dictionary] = [
		{"id": 30, "position": Vector2(6.0, 4.0)},
		{"id": 20, "position": Vector2(4.0, 6.0)},
		{"id": 10, "position": Vector2(5.0, 5.0)},
	]
	var second_order: Array[Dictionary] = [
		first_order[2],
		first_order[0],
		first_order[1],
	]
	first_order.sort_custom(battlefield._entity_draws_before)
	second_order.sort_custom(battlefield._entity_draws_before)
	var first_ids := first_order.map(func(entity_state: Dictionary) -> int: return int(entity_state["id"]))
	var second_ids := second_order.map(func(entity_state: Dictionary) -> int: return int(entity_state["id"]))
	if first_ids != second_ids or first_ids != [20, 10, 30]:
		failures.append("equal-depth tree sprites did not retain a deterministic overlap order")
