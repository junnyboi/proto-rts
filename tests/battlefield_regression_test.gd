extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _central_resource_id(simulation: RtsSimulation) -> int:
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("category") == &"resource" and entity_state.get("cell") == Vector2i(8, 7):
			return int(entity_state["id"])
	return -1


func _run() -> void:
	var failures: Array[String] = []
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280, 720)
	root.add_child(battlefield)
	battlefield.set_simulation(simulation)
	battlefield._fit_camera()
	await process_frame

	var resource_id := _central_resource_id(simulation)
	_expect(resource_id >= 0, "central resource fixture is missing", failures)
	if resource_id >= 0:
		var resource_position := battlefield.entity_screen_position(simulation.entity(resource_id))
		battlefield._selection_pressed = true
		battlefield._selection_dragging = false
		battlefield._handle_left_release(resource_position)
		_expect(battlefield.selected_ids == [resource_id], "left click did not select a neutral resource for inspection", failures)

	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	battlefield.select_entities([worker_id])
	var worker := simulation.entity(worker_id)
	var outside_position := battlefield.camera_offset + IsoProjection.cell_center(Vector2i(-5, -5)) * battlefield.camera_scale
	battlefield._handle_right_click(outside_position)
	_expect(worker["order"] == &"idle" and (worker["path"] as Array).is_empty(), "off-map right click issued a clamped move order", failures)

	worker["alive"] = false
	battlefield._prune_invalid_selection()
	_expect(battlefield.selected_ids.is_empty(), "dead entity remained in battlefield selection", failures)
	_expect(battlefield.selected_commandable_units().is_empty(), "dead entity remained commandable", failures)

	if failures.is_empty():
		print("PASS battlefield_regression_test: neutral inspection, bounds rejection, selection pruning")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
