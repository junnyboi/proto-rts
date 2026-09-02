extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var failures: Array[String] = []
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	root.add_child(battlefield)
	battlefield.set_simulation(simulation)
	battlefield.set_fog_enabled(false)
	await process_frame

	var resource_id := -1
	var enemy_worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_ENEMY, [&"worker"])[0]
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("category") == &"resource" and entity_state.get("resource_kind") == &"jade":
			resource_id = int(entity_state["id"])
			break
	_expect(resource_id >= 0, "no neutral resource was available for inspection", failures)
	if resource_id >= 0:
		var resource_screen := battlefield.entity_screen_position(simulation.entity(resource_id))
		battlefield.call("_handle_left_press", resource_screen)
		battlefield.call("_handle_left_release", resource_screen)
		_expect(battlefield.selected_ids == [resource_id], "left-click could not inspect a neutral resource", failures)
		_expect(battlefield.selected_commandable_units().is_empty(), "neutral resource became commandable", failures)

	var enemy_screen := battlefield.entity_screen_position(simulation.entity(enemy_worker_id))
	battlefield.call("_handle_left_press", enemy_screen)
	battlefield.call("_handle_left_release", enemy_screen)
	_expect(battlefield.selected_ids == [enemy_worker_id], "left-click could not inspect a visible enemy unit", failures)
	_expect(battlefield.selected_commandable_units().is_empty(), "inspected enemy unit became commandable", failures)

	var player_worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	battlefield.select_entities([player_worker_id])
	var selection_changes := [0]
	battlefield.selection_changed.connect(func(_ids: Array) -> void: selection_changes[0] += 1)
	simulation.entity(player_worker_id)["alive"] = false
	battlefield.call("_process", 0.01)
	_expect(battlefield.selected_ids.is_empty(), "dead entity remained selected", failures)
	_expect(selection_changes[0] == 1, "selection pruning did not emit exactly one state update", failures)

	var replacement_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", MapCatalog.PLAYER_WORKERS[0])
	battlefield.select_entities([replacement_id])
	var replacement := simulation.entity(replacement_id)
	var position_before := replacement["position"] as Vector2
	var order_before := replacement.get("order") as StringName
	var feedback_messages: Array[String] = []
	battlefield.feedback.connect(func(message: String, _is_error: bool) -> void: feedback_messages.append(message))
	var off_map_screen := battlefield.camera_offset + IsoProjection.cell_center(Vector2i(-20, -20)) * battlefield.camera_scale
	battlefield.call("_handle_right_click", off_map_screen)
	_expect(replacement.get("order") == order_before, "off-map right-click changed the unit order", failures)
	_expect((replacement["position"] as Vector2).is_equal_approx(position_before), "off-map right-click moved the unit", failures)
	_expect(not feedback_messages.is_empty() and "beyond" in feedback_messages[-1], "off-map right-click did not report an error", failures)

	battlefield.queue_free()
	if failures.is_empty():
		print("PASS battlefield_regression_test: resource/enemy inspection, ownership, stale selection, bounds rejection")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
