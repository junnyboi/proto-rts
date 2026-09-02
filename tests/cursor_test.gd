extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var simulation := RtsSimulation.new()
	simulation.setup(&"celestial")
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	battlefield.set_simulation(simulation)
	battlefield.set_fog_enabled(false)
	root.add_child(battlefield)
	await process_frame

	_verify_registry(failures)
	_verify_window_lifecycle(failures)
	var empty_cell := _find_empty_cell(battlefield)
	var empty_screen := _cell_screen_position(battlefield, empty_cell)
	_expect_state(battlefield, empty_screen, CursorSystem.SELECT, "empty battlefield", failures)

	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	var worker_id := workers[0]
	battlefield.select_entities([worker_id])
	_expect_state(battlefield, empty_screen, CursorSystem.MOVE, "selected units over ground", failures)

	var resource_cells := [
		empty_cell,
		empty_cell + Vector2i(2, 0),
		empty_cell + Vector2i(4, 0),
	]
	var resource_expectations := {
		&"jade": CursorSystem.GATHER_JADE,
		&"lumber": CursorSystem.GATHER_LUMBER,
		&"essence": CursorSystem.GATHER_ESSENCE,
	}
	var resource_index := 0
	for resource_kind in resource_expectations:
		var resource_id := simulation._spawn_resource({
			"kind": resource_kind,
			"variant": &"lumber_pine",
			"cell": resource_cells[resource_index],
			"amount": 100,
		})
		resource_index += 1
		_expect_state(
			battlefield,
			battlefield.entity_screen_position(simulation.entity(resource_id)),
			resource_expectations[resource_kind] as StringName,
			"worker over %s resource" % String(resource_kind),
			failures,
		)

	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	var stronghold := simulation.entity(stronghold_id)
	var worker := simulation.entity(worker_id)
	worker["cargo_kind"] = &"jade"
	worker["cargo_amount"] = 10.0
	_expect_state(
		battlefield,
		battlefield.entity_screen_position(stronghold),
		CursorSystem.DEPOSIT,
		"carrying worker over Stronghold",
		failures,
	)
	worker["cargo_kind"] = &""
	worker["cargo_amount"] = 0.0
	stronghold["hp"] = float(stronghold["max_hp"]) - 10.0
	_expect_state(
		battlefield,
		battlefield.entity_screen_position(stronghold),
		CursorSystem.REPAIR,
		"worker over damaged allied structure",
		failures,
	)

	var enemy_ids := simulation.team_entity_ids(RtsSimulation.TEAM_ENEMY, [&"worker"])
	_expect_state(
		battlefield,
		battlefield.entity_screen_position(simulation.entity(enemy_ids[0])),
		CursorSystem.ATTACK,
		"unit over hostile target",
		failures,
	)
	var cave_id := simulation.cave_ids()[0]
	_expect_state(
		battlefield,
		battlefield.entity_screen_position(simulation.entity(cave_id)),
		CursorSystem.HUNT,
		"unit over Yaoguai Den",
		failures,
	)

	battlefield.begin_attack_move()
	_expect_state(battlefield, empty_screen, CursorSystem.ATTACK_MOVE, "armed attack-move", failures)
	_expect_state(battlefield, Vector2(-10000.0, -10000.0), CursorSystem.FORBIDDEN, "invalid attack-move", failures)
	battlefield.cancel_modes()

	var military_id := simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"vanguard",
		empty_cell + Vector2i(0, 3),
	)
	battlefield.select_entities([military_id])
	battlefield.begin_patrol()
	_expect_state(battlefield, empty_screen, CursorSystem.PATROL, "armed patrol", failures)
	battlefield.cancel_modes()

	battlefield.select_entities([worker_id])
	battlefield.begin_repair()
	_expect_state(
		battlefield,
		battlefield.entity_screen_position(stronghold),
		CursorSystem.REPAIR,
		"armed repair over valid target",
		failures,
	)
	_expect_state(battlefield, empty_screen, CursorSystem.FORBIDDEN, "armed repair over ground", failures)
	battlefield.cancel_modes()

	simulation.players[RtsSimulation.TEAM_PLAYER]["jade"] = 1000
	simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"] = 1000
	battlefield.begin_structure_placement(&"rice_farm")
	var build_cell := simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		&"rice_farm",
		MapCatalog.PLAYER_STRONGHOLD,
	)
	_expect_state(
		battlefield,
		_cell_screen_position(battlefield, build_cell),
		CursorSystem.BUILD,
		"valid structure footprint",
		failures,
	)
	_expect_state(
		battlefield,
		battlefield.entity_screen_position(stronghold),
		CursorSystem.FORBIDDEN,
		"occupied structure footprint",
		failures,
	)
	battlefield.cancel_modes()

	battlefield.select_entities([stronghold_id])
	_expect_state(battlefield, empty_screen, CursorSystem.RALLY, "selected structure over ground", failures)
	battlefield._selection_pressed = true
	battlefield._selection_dragging = true
	_expect_state(battlefield, empty_screen, CursorSystem.BOX_SELECT, "selection drag", failures)
	battlefield._selection_pressed = false
	battlefield._selection_dragging = false
	battlefield._middle_dragging = true
	_expect_state(battlefield, empty_screen, CursorSystem.PAN, "camera drag", failures)
	battlefield._middle_dragging = false

	battlefield.queue_free()
	if failures.is_empty():
		print("PASS cursor_test: 17 custom cursors and contextual resolver precedence")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _verify_registry(failures: Array[String]) -> void:
	if CursorSystem.ORDER.size() != 17:
		failures.append("expected 17 cursor states, found %d" % CursorSystem.ORDER.size())
	var shapes: Dictionary = {}
	for state in CursorSystem.ORDER:
		var shape := int(CursorSystem.shape_for(state))
		if shapes.has(shape):
			failures.append("cursor states %s and %s share native shape %d" % [shapes[shape], state, shape])
		shapes[shape] = state
		var texture := CursorSystem.texture_for(state)
		if texture == null or texture.get_size() != Vector2(64.0, 64.0):
			failures.append("cursor %s is not a 64x64 runtime texture" % state)


func _verify_window_lifecycle(failures: Array[String]) -> void:
	if not CursorSystem.is_installed():
		failures.append("cursor registry was not installed when the game window became active")
	CursorSystem.suspend()
	if not CursorSystem.is_suspended() or CursorSystem.is_installed():
		failures.append("cursor registry did not release custom cursors on window exit")
	CursorSystem.install()
	if CursorSystem.is_installed():
		failures.append("a presentation control reinstalled custom cursors while the pointer was outside")
	CursorSystem.resume()
	if CursorSystem.is_suspended() or not CursorSystem.is_installed():
		failures.append("cursor registry did not restore custom cursors on window entry")


func _expect_state(
	battlefield: Battlefield,
	screen_position: Vector2,
	expected: StringName,
	description: String,
	failures: Array[String],
) -> void:
	var context := battlefield.cursor_context_at(screen_position)
	var actual := context.get("state", &"") as StringName
	if actual != expected:
		failures.append("%s resolved %s instead of %s" % [description, actual, expected])


func _cell_screen_position(battlefield: Battlefield, cell: Vector2i) -> Vector2:
	return battlefield.camera_offset + IsoProjection.cell_center(cell) * battlefield.camera_scale


func _find_empty_cell(battlefield: Battlefield) -> Vector2i:
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			var screen_position := _cell_screen_position(battlefield, cell)
			if MapCatalog.is_buildable(cell) and battlefield.entity_at_screen(screen_position, false) < 0:
				return cell
	return MapCatalog.SIZE / 2
