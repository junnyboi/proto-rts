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
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != lumber_before_deposit + 20:
		failures.append("right-clicking the Stronghold did not immediately deposit carried resources")
	if float(worker.get("cargo_amount", -1.0)) != 0.0 or worker.get("cargo_kind") != &"":
		failures.append("right-click deposit did not clear the worker's cargo")

	var tree_id := -1
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("resource_kind") == &"lumber" and battlefield.should_render_entity(entity_state):
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

	battlefield.queue_free()
	if failures.is_empty():
		print("PASS interaction_test: camera pan and zoom, deterministic depth sorting, selection, Yaoguai Den hunt, Stronghold shortcut and deposit, Lumber contextual gather, Rice Farm placement")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


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
