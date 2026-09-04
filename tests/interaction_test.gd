extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_verify_camera_input_bindings(failures)
	var simulation := RtsSimulation.new()
	simulation.setup(&"celestial", false)
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	battlefield.set_simulation(simulation)
	root.add_child(battlefield)
	await process_frame
	_verify_smooth_camera_pan(battlefield, failures)
	_verify_selection_drag_camera_arbitration(battlefield, failures)
	_verify_zoom_input(battlefield, failures)
	_verify_deterministic_entity_depth_sort(battlefield, failures)
	_verify_entity_sprite_grounding(battlefield, simulation, failures)
	_verify_worker_cargo_icon_mapping(battlefield, failures)

	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	var worker_id := workers[0]
	var worker_screen_position := battlefield.entity_screen_position(simulation.entity(worker_id))
	battlefield.call("_handle_left_press", worker_screen_position)
	battlefield.call("_handle_left_release", worker_screen_position)
	if battlefield.selected_ids.size() != 1 or battlefield.selected_ids[0] != worker_id:
		failures.append("clicking a worker did not select it")
	if int(battlefield.effect_diagnostics()["pulses"]) <= 0:
		failures.append("selection click did not create immediate visual acknowledgement")
	battlefield._mouse_position = worker_screen_position
	battlefield.call("_process", 0.016)
	if battlefield._presentation.hovered_entity_id != worker_id:
		failures.append("visible hovered entity did not enter presentation state")
	if battlefield._presentation.hover_strength(worker_id) <= 0.0:
		failures.append("hover presentation did not ease in")
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
	var busy_worker := simulation.entity(second_worker_id)
	busy_worker["order"] = &"move"
	battlefield.select_all_idle_workers()
	var expected_idle_workers: Array[int] = workers.duplicate()
	expected_idle_workers.erase(second_worker_id)
	if battlefield.selected_ids != expected_idle_workers:
		failures.append("idle Worker selection did not include every idle Worker and exclude busy Workers")
	busy_worker["order"] = &"idle"

	battlefield.call("_handle_left_press", Vector2(-1000.0, -1000.0))
	battlefield.call("_handle_left_release", Vector2(-1000.0, -1000.0))
	if not battlefield.selected_ids.is_empty():
		failures.append("clicking empty ground did not clear the selection")

	battlefield.set_fog_enabled(false)
	var resource_id := _find_clickable_entity(battlefield, simulation, &"resource")
	if resource_id < 0:
		failures.append("no environmental resource was available for inspection")
	else:
		var resource_position := battlefield.entity_screen_position(simulation.entity(resource_id))
		battlefield.call("_handle_left_press", resource_position)
		battlefield.call("_handle_left_release", resource_position)
		if battlefield.selected_ids != [resource_id]:
			failures.append("clicking an environmental resource did not select its information")

	var enemy_unit_id := _find_clickable_entity(battlefield, simulation, &"unit", RtsSimulation.TEAM_ENEMY)
	if enemy_unit_id < 0:
		failures.append("no enemy unit was available for inspection")
	else:
		var enemy_unit_position := battlefield.entity_screen_position(simulation.entity(enemy_unit_id))
		battlefield.call("_handle_left_press", enemy_unit_position)
		battlefield.call("_handle_left_release", enemy_unit_position)
		if battlefield.selected_ids != [enemy_unit_id]:
			failures.append("clicking an enemy unit did not select its information")

	var enemy_structure_id := _find_clickable_entity(battlefield, simulation, &"structure", RtsSimulation.TEAM_ENEMY)
	if enemy_structure_id < 0:
		failures.append("no enemy structure was available for inspection")
	else:
		var enemy_structure_position := battlefield.entity_screen_position(simulation.entity(enemy_structure_id))
		battlefield.call("_handle_left_press", enemy_structure_position)
		battlefield.call("_handle_left_release", enemy_structure_position)
		if battlefield.selected_ids != [enemy_structure_id]:
			failures.append("clicking an enemy structure did not select its information")

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
		battlefield.call("_handle_left_release", farm_screen_position)
		if simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"rice_farm") < 0:
			failures.append("Rice Farm placement input did not create a foundation")
		if battlefield.placement_worker_id != worker_id or battlefield.placement_kind != &"rice_farm":
			failures.append("successful Rice Farm placement did not preserve placement mode")
		battlefield.begin_structure_placement(&"rice_farm")
		if battlefield.placement_worker_id >= 0 or not battlefield.placement_kind.is_empty():
			failures.append("selecting the active Rice Farm command again did not cancel placement mode")
		var completed_farm_id := simulation.primary_structure_id(
			RtsSimulation.TEAM_PLAYER,
			&"rice_farm",
		)
		var completed_farm := simulation.entity(completed_farm_id)
		completed_farm["complete"] = 1.0
		completed_farm["hp"] = completed_farm["max_hp"]
		simulation.command_stop(RtsSimulation.TEAM_PLAYER, [worker_id, second_worker_id])
		worker["position"] = Vector2(MapCatalog.PLAYER_WORKERS[0])
		worker["cell"] = MapCatalog.PLAYER_WORKERS[0]
		battlefield.select_entities([worker_id, second_worker_id])
		battlefield.call(
			"_handle_right_click",
			battlefield.entity_screen_position(completed_farm),
		)
		if simulation.farm_worker_id(completed_farm_id) != worker_id:
			failures.append("right-clicking a completed Rice Farm did not assign exactly one selected Worker")
		if not battlefield.call("_worker_has_farm_assignment", worker):
			failures.append("an assigned farm Worker did not expose its rice-icon presentation state")
		battlefield.select_entities([second_worker_id])
		battlefield.call(
			"_handle_right_click",
			battlefield.entity_screen_position(completed_farm),
		)
		if simulation.entity(second_worker_id).get("order") == &"farm":
			failures.append("right-clicking a staffed Rice Farm assigned a second Worker")
		if battlefield.call(
			"_worker_has_farm_assignment",
			simulation.entity(second_worker_id),
		):
			failures.append("an unassigned Worker exposed the rice-icon presentation state")

	var hunting_simulation := RtsSimulation.new()
	hunting_simulation.setup(&"human", false)
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
	_verify_idle_player_unit_visuals(battlefield, hunting_simulation, hunting_unit_id, wildlife_id, failures)
	_verify_stronghold_upgrade_visuals(battlefield, hunting_simulation, failures)
	_verify_shenlong_wave_visuals(battlefield, hunting_simulation, failures)
	_verify_command_visualizations(battlefield, failures)

	battlefield.queue_free()
	if failures.is_empty():
		print("PASS interaction_test: camera, selection and inspection, contextual economy, worker cargo and farm icons, building placement, movement, idle, Stronghold upgrade, and Shenlong wave visuals, wildlife hunting, and command visualization")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _find_clickable_entity(
	battlefield: Battlefield,
	simulation: RtsSimulation,
	category: StringName,
	team: int = -999,
) -> int:
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("category") != category:
			continue
		if team != -999 and int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) != team:
			continue
		var screen_position := battlefield.entity_screen_position(entity_state)
		if battlefield.entity_at_screen(screen_position, true) == int(entity_state["id"]):
			return int(entity_state["id"])
	return -1


func _verify_smooth_camera_pan(battlefield: Battlefield, failures: Array[String]) -> void:
	var camera_offset_before := battlefield.camera_offset
	Input.action_press(&"camera_right")
	battlefield.call("_update_camera_pan", 0.05)
	var first_velocity := battlefield._camera_pan_velocity.length()
	battlefield.call("_update_camera_pan", 0.05)
	var second_velocity := battlefield._camera_pan_velocity.length()
	Input.action_release(&"camera_right")
	if battlefield.camera_offset.x >= camera_offset_before.x:
		failures.append("camera_right input did not pan the battlefield")
	if second_velocity <= first_velocity:
		failures.append("keyboard camera pan did not accelerate smoothly")

	var offset_before_release_step := battlefield.camera_offset
	battlefield.call("_update_camera_pan", 0.05)
	var release_velocity := battlefield._camera_pan_velocity.length()
	if battlefield.camera_offset.x >= offset_before_release_step.x:
		failures.append("keyboard camera pan stopped without easing out")
	if release_velocity <= 0.0 or release_velocity >= second_velocity:
		failures.append("keyboard camera pan did not decelerate smoothly")

	battlefield.camera_offset = camera_offset_before
	battlefield._camera_pan_velocity = Vector2.ZERO
	Input.action_press(&"camera_right")
	for _frame in range(12):
		battlefield.call("_update_camera_pan", 1.0 / 60.0)
	var fine_step_offset := battlefield.camera_offset
	battlefield.camera_offset = camera_offset_before
	battlefield._camera_pan_velocity = Vector2.ZERO
	for _frame in range(2):
		battlefield.call("_update_camera_pan", 0.1)
	Input.action_release(&"camera_right")
	if not battlefield.camera_offset.is_equal_approx(fine_step_offset):
		failures.append("keyboard camera pan changed with frame cadence")
	battlefield.center_on_player_stronghold()


func _verify_selection_drag_camera_arbitration(
	battlefield: Battlefield,
	failures: Array[String],
) -> void:
	battlefield.center_on_player_stronghold()
	var drag_start := Vector2(420.0, 260.0)
	var drag_end := Vector2(610.0, 390.0)
	battlefield.call("_handle_left_press", drag_start)

	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 0
	touch_press.position = drag_start
	touch_press.pressed = true
	battlefield.call("_gui_input", touch_press)

	var camera_before_pointer_drag := battlefield.camera_offset
	var emulated_touch_drag := InputEventScreenDrag.new()
	emulated_touch_drag.index = 0
	emulated_touch_drag.position = drag_end
	emulated_touch_drag.relative = drag_end - drag_start
	battlefield.call("_gui_input", emulated_touch_drag)
	if not battlefield.camera_offset.is_equal_approx(camera_before_pointer_drag):
		failures.append("emulated touch input panned the camera during box selection")
	if not battlefield._selection_dragging or not battlefield._selection_current.is_equal_approx(drag_end):
		failures.append("emulated touch input did not remain captured by box selection")

	battlefield._middle_dragging = true
	var mouse_motion := InputEventMouseMotion.new()
	mouse_motion.position = drag_end + Vector2(30.0, 20.0)
	mouse_motion.relative = Vector2(30.0, 20.0)
	battlefield.call("_gui_input", mouse_motion)
	if not battlefield.camera_offset.is_equal_approx(camera_before_pointer_drag):
		failures.append("middle-button pointer motion panned the camera during box selection")

	battlefield._camera_pan_velocity = Vector2(300.0, 0.0)
	battlefield.call("_update_camera_pan", 0.05)
	if not battlefield.camera_offset.is_equal_approx(camera_before_pointer_drag):
		failures.append("keyboard pan momentum moved the camera during box selection")
	if not battlefield._camera_pan_velocity.is_zero_approx():
		failures.append("box selection did not cancel released keyboard pan momentum")

	var scale_before_zoom_input := battlefield.camera_scale
	var magnify := InputEventMagnifyGesture.new()
	magnify.position = mouse_motion.position
	magnify.factor = 1.1
	battlefield.call("_gui_input", magnify)
	var command_wheel := InputEventMouseButton.new()
	command_wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	command_wheel.pressed = true
	command_wheel.meta_pressed = true
	command_wheel.position = mouse_motion.position
	battlefield.call("_gui_input", command_wheel)
	if not is_equal_approx(battlefield.camera_scale, scale_before_zoom_input):
		failures.append("pointer zoom input changed the camera during box selection")

	Input.action_press(&"camera_right")
	var camera_before_wasd := battlefield.camera_offset
	battlefield.call("_update_camera_pan", 0.05)
	Input.action_release(&"camera_right")
	if battlefield.camera_offset.x >= camera_before_wasd.x:
		failures.append("active WASD input could not pan the camera during box selection")

	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 0
	touch_release.position = mouse_motion.position
	touch_release.pressed = false
	battlefield.call("_gui_input", touch_release)
	battlefield.call("_handle_left_release", mouse_motion.position)
	battlefield._middle_dragging = false
	battlefield._camera_pan_velocity = Vector2.ZERO
	battlefield.center_on_player_stronghold()


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


func _verify_shenlong_wave_visuals(
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var shenlong := simulation.shenlong_guardian()
	if shenlong.is_empty():
		failures.append("Shenlong was unavailable for procedural wave verification")
		return
	var display_size := Vector2(448.0, 362.0) * battlefield.camera_scale
	var sample_uv := Vector2(0.2, 0.28)
	battlefield._wind_animation_time = 0.37
	var first_offset := battlefield.call(
		"_shenlong_wave_offset",
		sample_uv,
		display_size,
		int(shenlong["id"]),
	) as Vector2
	var repeated_offset := battlefield.call(
		"_shenlong_wave_offset",
		sample_uv,
		display_size,
		int(shenlong["id"]),
	) as Vector2
	if first_offset.is_zero_approx():
		failures.append("Shenlong's upper body did not receive procedural wave deformation")
	if not first_offset.is_equal_approx(repeated_offset):
		failures.append("Shenlong wave deformation was not deterministic within a frame")
	battlefield._wind_animation_time = 0.91
	var later_offset := battlefield.call(
		"_shenlong_wave_offset",
		sample_uv,
		display_size,
		int(shenlong["id"]),
	) as Vector2
	if later_offset.is_equal_approx(first_offset):
		failures.append("Shenlong wave deformation did not evolve over time")
	var grounded_offset := battlefield.call(
		"_shenlong_wave_offset",
		Vector2(0.5, 1.0),
		display_size,
		int(shenlong["id"]),
	) as Vector2
	if not grounded_offset.is_zero_approx():
		failures.append("Shenlong wave deformation displaced its ground anchor")


func _verify_stronghold_upgrade_visuals(
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var stronghold_id := simulation.primary_structure_id(
		RtsSimulation.TEAM_PLAYER,
		&"stronghold",
	)
	var stronghold := simulation.entity(stronghold_id)
	if stronghold.is_empty():
		failures.append("Stronghold was unavailable for upgrade-effect verification")
		return
	stronghold["stronghold_level"] = RtsSimulation.STRONGHOLD_INITIAL_LEVEL
	var level_one := battlefield.call("_stronghold_effect_profile", stronghold) as Dictionary
	if (
		float(level_one.get("aura_alpha", -1.0)) != 0.0
		or int(level_one.get("aura_layers", -1)) != 0
		or float(level_one.get("particle_alpha", -1.0)) != 0.0
		or int(level_one.get("particle_count", -1)) != 0
	):
		failures.append("Lvl 1 Stronghold exposed an aura or particle effect")

	stronghold["stronghold_level"] = 2
	var level_two := battlefield.call("_stronghold_effect_profile", stronghold) as Dictionary
	if (
		float(level_two.get("aura_alpha", 0.0)) <= 0.0
		or int(level_two.get("aura_layers", 0)) <= 0
		or float(level_two.get("particle_alpha", 0.0)) <= 0.0
		or int(level_two.get("particle_count", 0)) <= 0
	):
		failures.append("Lvl 2 Stronghold did not enable both aura and particle effects")

	stronghold["stronghold_level"] = RtsSimulation.STRONGHOLD_MAX_LEVEL
	var level_three := battlefield.call("_stronghold_effect_profile", stronghold) as Dictionary
	for property_name in [
		"aura_alpha",
		"aura_layers",
		"aura_radius_scale",
		"particle_alpha",
		"particle_count",
		"particle_size",
	]:
		if float(level_three.get(property_name, 0.0)) <= float(level_two.get(property_name, 0.0)):
			failures.append("Lvl 3 Stronghold did not intensify %s" % property_name.replace("_", " "))
	stronghold["stronghold_level"] = RtsSimulation.STRONGHOLD_INITIAL_LEVEL


func _verify_idle_player_unit_visuals(
	battlefield: Battlefield,
	simulation: RtsSimulation,
	player_unit_id: int,
	wildlife_id: int,
	failures: Array[String],
) -> void:
	var player_unit := simulation.entity(player_unit_id)
	player_unit["order"] = &"idle"
	player_unit["path"] = []
	battlefield._movement_visuals.erase(player_unit_id)
	battlefield.call("_update_movement_visuals", 0.0)
	var visual := battlefield._movement_visuals[player_unit_id] as Dictionary
	var initial_wait := float(visual.get("idle_wait_remaining", 0.0))
	if (
		initial_wait < Battlefield.IDLE_WOBBLE_MIN_WAIT_SECONDS
		or initial_wait > Battlefield.IDLE_WOBBLE_MAX_WAIT_SECONDS
	):
		failures.append("idle player unit did not receive an occasional wobble interval")

	var initial_facing: bool = battlefield.call("_movement_faces_left", player_unit)
	visual["idle_wait_remaining"] = 0.0
	battlefield.call("_update_movement_visuals", Battlefield.IDLE_WOBBLE_DURATION * 0.125)
	if is_zero_approx(float(battlefield.call("_idle_wobble_rotation", player_unit))):
		failures.append("idle player unit did not wobble before turning")
	if bool(battlefield.call("_movement_faces_left", player_unit)) != initial_facing:
		failures.append("idle player unit changed facing before its wobble completed")

	battlefield.call("_update_movement_visuals", Battlefield.IDLE_WOBBLE_DURATION)
	if bool(battlefield.call("_movement_faces_left", player_unit)) == initial_facing:
		failures.append("idle player unit did not change facing after its wobble")
	if not is_zero_approx(float(battlefield.call("_idle_wobble_rotation", player_unit))):
		failures.append("idle player unit kept wobbling after changing facing")
	var next_wait := float(visual.get("idle_wait_remaining", 0.0))
	if (
		next_wait < Battlefield.IDLE_WOBBLE_MIN_WAIT_SECONDS
		or next_wait > Battlefield.IDLE_WOBBLE_MAX_WAIT_SECONDS
	):
		failures.append("idle player unit did not pause before its next wobble")

	var wildlife := simulation.entity(wildlife_id)
	if battlefield.call("_is_idle_player_unit_visual", wildlife):
		failures.append("wildlife was eligible for player-unit idle turns")
	if not is_zero_approx(float(battlefield.call("_idle_wobble_rotation", wildlife))):
		failures.append("wildlife received a player-unit idle wobble")


func _verify_command_visualizations(
	battlefield: Battlefield,
	failures: Array[String],
) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	battlefield.set_simulation(simulation)
	battlefield.set_fog_enabled(false)
	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	var worker_id := workers[0]
	var worker := simulation.entity(worker_id)
	var diagonal_step := _find_open_diagonal_step(simulation)
	if diagonal_step.is_empty():
		failures.append("no unobstructed diagonal command visualization area was available")
		return
	var move_origin := diagonal_step["origin"] as Vector2i
	var move_destination := diagonal_step["destination"] as Vector2i
	worker["position"] = Vector2(move_origin)
	worker["cell"] = move_origin
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [worker_id], move_destination)
	battlefield.select_entities([worker_id])
	var records: Array = battlefield.call("_command_visualization_records") as Array
	if records.size() != 1 or (records[0] as Dictionary).get("kind") != &"flag":
		failures.append("selected move order did not project one destination flag")
	else:
		var move_points := (records[0] as Dictionary).get("points", []) as Array
		if (
			move_points.size() != 2
			or not (move_points[0] as Vector2).is_equal_approx(Vector2(move_origin))
			or not (move_points[1] as Vector2).is_equal_approx(Vector2(move_destination))
		):
			failures.append("movement dotted path did not display the direct diagonal route")

	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	var stronghold := simulation.entity(stronghold_id)
	var rally_cell := stronghold.get("rally_cell", Vector2i(-1, -1)) as Vector2i
	battlefield.select_entities([stronghold_id])
	records = battlefield.call("_command_visualization_records") as Array
	if records.size() != 1:
		failures.append("selected structure did not project its rally visualization")
	else:
		var rally_record := records[0] as Dictionary
		var rally_points := rally_record.get("points", []) as Array
		if (
			rally_record.get("kind") != &"flag"
			or rally_record.get("endpoint") != Vector2(rally_cell)
		):
			failures.append("selected structure did not reuse the movement destination flag at its rally point")
		if (
			rally_points.size() != 2
			or not (rally_points[0] as Vector2).is_equal_approx(
				battlefield.call("_entity_world_center", stronghold) as Vector2,
			)
			or not (rally_points[1] as Vector2).is_equal_approx(Vector2(rally_cell))
		):
			failures.append("selected structure rally dotted path did not connect its center to the rally point")
	battlefield.select_entities([worker_id])

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
		simulation.command_gather(RtsSimulation.TEAM_PLAYER, [worker_id], resource_id)
		records = battlefield.call("_command_visualization_records") as Array
		if (
			records.size() != 1
			or (records[0] as Dictionary).get("kind") != &"interact"
			or int((records[0] as Dictionary).get("target_id", -1)) != resource_id
		):
			failures.append("selected gather order did not project its resource interaction ring")

	worker["cargo_kind"] = &"jade"
	worker["cargo_amount"] = 5.0
	simulation.command_deposit(RtsSimulation.TEAM_PLAYER, [worker_id], stronghold_id)
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
	simulation.command_attack(RtsSimulation.TEAM_PLAYER, [attacker_id, second_attacker_id], target_id)
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


func _find_open_diagonal_step(simulation: RtsSimulation) -> Dictionary:
	for y in range(MapCatalog.SIZE.y - 1):
		for x in range(MapCatalog.SIZE.x - 1):
			var origin := Vector2i(x, y)
			if (
				not simulation._astar.is_point_solid(origin)
				and not simulation._astar.is_point_solid(origin + Vector2i.RIGHT)
				and not simulation._astar.is_point_solid(origin + Vector2i.DOWN)
				and not simulation._astar.is_point_solid(origin + Vector2i.ONE)
			):
				return {
					"origin": origin,
					"destination": origin + Vector2i.ONE,
				}
	return {}


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


func _verify_entity_sprite_grounding(
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var checks: Array[Dictionary] = []
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("category") not in [&"unit", &"wildlife"]:
			continue
		checks.append({
			"label": "%s %s" % [
				String(entity_state.get("faction", &"neutral")),
				String(entity_state.get("kind", &"unknown")),
			],
			"entity": entity_state,
		})
	for kind in [&"stronghold", &"war_camp"]:
		var team := RtsSimulation.TEAM_PLAYER if kind == &"stronghold" else RtsSimulation.TEAM_ENEMY
		var structure_id := simulation.primary_structure_id(team, kind)
		if structure_id < 0 and kind == &"war_camp":
			structure_id = simulation._spawn_structure(team, kind, MapCatalog.ENEMY_WAR_CAMP, true)
		checks.append({"label": String(kind), "entity": simulation.entity(structure_id)})
	checks.append({
		"label": "yaoguai den",
		"entity": simulation.entity(simulation.cave_ids()[0]),
	})
	var resource_labels := {
		&"lumber": "tree",
		&"jade": "jade outcrop",
		&"essence": "essence shrine",
	}
	for resource_kind in resource_labels:
		var resource: Dictionary = {}
		for raw_entity in simulation.entities.values():
			var entity_state := raw_entity as Dictionary
			if entity_state.get("resource_kind") == resource_kind:
				resource = entity_state
				break
		if resource.is_empty():
			failures.append("no %s was available for sprite grounding" % resource_labels[resource_kind])
		else:
			checks.append({"label": resource_labels[resource_kind], "entity": resource})

	for check in checks:
		var entity_state := check["entity"] as Dictionary
		var label := check["label"] as String
		if entity_state.is_empty():
			failures.append("%s was unavailable for sprite grounding" % label)
			continue
		var logical_center := battlefield.entity_screen_position(entity_state)
		var ring_center: Vector2 = battlefield.call("_selection_ring_screen_position", entity_state)
		var sprite_center: Vector2 = battlefield.call("_grounded_sprite_screen_position", entity_state)
		var footprint := entity_state["footprint"] as Vector2i
		var is_movable: bool = entity_state.get("category") in [&"unit", &"wildlife"]
		var expected_drop := 0.0 if is_movable else (
			float(footprint.x + footprint.y)
			* IsoProjection.TILE_HEIGHT
			* 0.25
			* battlefield.camera_scale
		)
		if not ring_center.is_equal_approx(logical_center):
			failures.append("%s selection ring was not centered on its tile" % label)
		if not is_equal_approx(sprite_center.x, logical_center.x):
			failures.append("%s sprite was not horizontally centered on its footprint" % label)
		if not is_equal_approx(sprite_center.y, logical_center.y + expected_drop):
			var grounding_failure := (
				"%s feet were not centered on its selection ring"
				if is_movable
				else "%s sprite was not grounded at its footprint's lower edge"
			)
			failures.append(grounding_failure % label)
		if is_movable:
			var texture := battlefield.call(
				"_entity_texture",
				entity_state.get("faction", &"neutral") as StringName,
				entity_state.get("kind", &"") as StringName,
			) as Texture2D
			if texture == null:
				failures.append("%s art was unavailable for foot alignment" % label)
				continue
			var margin := float(battlefield.call("_character_art_bottom_margin", texture))
			var display_size := Vector2(94.0, 104.0) * battlefield.camera_scale
			var rect: Rect2 = battlefield.call("_world_texture_rect", texture, display_size, margin)
			var content_bottom := (
				rect.position.y
				+ rect.size.y * (1.0 - margin / float(texture.get_height()))
			)
			if not is_zero_approx(content_bottom):
				failures.append("%s art padding displaced its feet from the shared center" % label)


func _verify_worker_cargo_icon_mapping(battlefield: Battlefield, failures: Array[String]) -> void:
	var expected_paths := {
		&"jade": "res://assets/runtime/ui/resource_icons/jade.png",
		&"lumber": "res://assets/runtime/ui/resource_icons/lumber.png",
		&"essence": "res://assets/runtime/ui/resource_icons/essence.png",
		&"food": "res://assets/runtime/ui/resource_icons/food.png",
	}
	var texture_ids: Dictionary = {}
	for cargo_kind in expected_paths:
		var texture := battlefield.call("_cargo_icon_texture", cargo_kind) as Texture2D
		if texture == null:
			failures.append("%s cargo did not resolve a worker marker icon" % String(cargo_kind))
			continue
		if texture.resource_path != expected_paths[cargo_kind]:
			failures.append("%s cargo resolved the wrong worker marker icon" % String(cargo_kind))
		if texture_ids.has(texture.get_instance_id()):
			failures.append("%s cargo reused another resource's worker marker icon" % String(cargo_kind))
		texture_ids[texture.get_instance_id()] = true
	if battlefield.call("_cargo_icon_texture", &"population") != null:
		failures.append("non-cargo population art was exposed as a worker cargo marker")


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

	var wall := {
		"id": 1,
		"category": &"structure",
		"position": Vector2(20.0, 20.0),
		"footprint": Vector2i.ONE,
	}
	var unit_behind_wall := {
		"id": 99,
		"category": &"unit",
		"position": Vector2(20.5, 20.0),
		"footprint": Vector2i.ONE,
	}
	if (
		not battlefield._entity_draws_before(unit_behind_wall, wall)
		or battlefield._entity_draws_before(wall, unit_behind_wall)
	):
		failures.append("a unit behind a wall did not draw below the wall's ground edge")

	var gate := {
		"id": 2,
		"category": &"structure",
		"position": Vector2(10.0, 10.0),
		"footprint": Vector2i(2, 4),
	}
	var unit_behind_gate := {
		"id": 98,
		"category": &"unit",
		"position": Vector2(12.0, 11.0),
		"footprint": Vector2i.ONE,
	}
	var unit_southeast_of_gate := {
		"id": 97,
		"category": &"unit",
		"position": Vector2(14.0, 12.0),
		"footprint": Vector2i.ONE,
	}
	if not battlefield._entity_draws_before(unit_behind_gate, gate):
		failures.append("a unit behind a gate did not draw below the gate's southeast edge")
	if not battlefield._entity_draws_before(gate, unit_southeast_of_gate):
		failures.append("a unit southeast of a gate did not draw above the gate")

	var northwest_entity := {
		"id": 96,
		"category": &"unit",
		"position": Vector2(5.0, 5.0),
		"footprint": Vector2i.ONE,
	}
	var southeast_entity := {
		"id": 95,
		"category": &"unit",
		"position": Vector2(6.0, 6.0),
		"footprint": Vector2i.ONE,
	}
	if not battlefield._entity_draws_before(northwest_entity, southeast_entity):
		failures.append("a southeast entity did not receive a higher draw order")
