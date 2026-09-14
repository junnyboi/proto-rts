extends SceneTree

const REFERENCE_SCRIPT := preload("res://tests/support/runtime_reference.gd")


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _pair(enable_ai: bool = false) -> Array[RtsSimulation]:
	var actual := RtsSimulation.new()
	var reference := REFERENCE_SCRIPT.new() as RtsSimulation
	actual.setup(&"human", enable_ai)
	reference.setup(&"human", enable_ai)
	return [actual, reference]


func _copy_entities(pair: Array[RtsSimulation]) -> void:
	pair[1].entities = pair[0].entities.duplicate(true)
	pair[1].players = pair[0].players.duplicate(true)
	pair[1]._next_entity_id = pair[0]._next_entity_id
	pair[0]._rebuild_pathfinding()
	pair[1]._rebuild_pathfinding()


func _visibility_equal(pair: Array[RtsSimulation], label: String, failures: Array[String]) -> void:
	for simulation in pair:
		simulation._refresh_visibility()
	for team in range(RtsSimulation.TEAM_COUNT):
		_expect(
			pair[0].visible_cells_for_team(team) == pair[1].visible_cells_for_team(team),
			"%s: team %d visibility differs from full-refresh reference" % [label, team],
			failures,
		)
		_expect(
			pair[0].explored_cells_for_team(team) == pair[1].explored_cells_for_team(team),
			"%s: team %d exploration differs from full-refresh reference" % [label, team],
			failures,
		)


func _test_visibility(failures: Array[String]) -> void:
	var pair := _pair()
	_visibility_equal(pair, "opening", failures)
	var initial_revision := pair[0].visibility_revision_for_team(0)
	_visibility_equal(pair, "unchanged opening", failures)
	_expect(pair[0].visibility_revision_for_team(0) == initial_revision, "unchanged visibility invalidated its published revision", failures)
	var worker_id := pair[0].team_entity_ids(0, [&"worker"])[0]
	for position in [Vector2(24.99, 40.99), Vector2(25.01, 41.01), Vector2(79.75, 79.75)]:
		for simulation in pair:
			simulation.entity(worker_id)["position"] = position
			simulation.entity(worker_id)["cell"] = Vector2i(position.round())
		_visibility_equal(pair, "fractional center %s" % position, failures)
	_expect(pair[0].visibility_revision_for_team(0) > initial_revision, "moved vision did not invalidate its published revision", failures)
	for simulation in pair:
		var worker := simulation.entity(worker_id)
		worker["footprint"] = Vector2i(4, 3)
		worker["position"] = Vector2(40.5, 40.5)
	_visibility_equal(pair, "footprint center", failures)
	for simulation in pair:
		simulation.entity(worker_id)["team"] = 1
	_visibility_equal(pair, "ownership transfer", failures)
	for simulation in pair:
		simulation.entity(worker_id)["alive"] = false
	_visibility_equal(pair, "source death", failures)
	for simulation in pair:
		simulation.entities.erase(worker_id)
	_visibility_equal(pair, "source removal", failures)
	var tower_id := pair[0]._spawn_structure(0, &"sentry_tower", Vector2i(24, 40), true)
	var occupant_id := pair[0]._spawn_unit(0, &"mystic", Vector2i(24, 40))
	_copy_entities(pair)
	_visibility_equal(pair, "tower spawned", failures)
	for simulation in pair:
		simulation.entity(tower_id)["garrisoned_unit_ids"] = [occupant_id]
		simulation.entity(occupant_id)["garrisoned_in"] = tower_id
		simulation.entity(occupant_id)["range"] = 6.25
	_visibility_equal(pair, "tower occupant extends radius", failures)
	for simulation in pair:
		simulation.entity(tower_id)["garrisoned_unit_ids"] = []
		simulation.entity(occupant_id)["garrisoned_in"] = -1
	_visibility_equal(pair, "tower occupant removed", failures)
	var visible_copy := pair[0].visible_cells_for_team(0)
	visible_copy.clear()
	_expect(not pair[0].visible_cells_for_team(0).is_empty(), "visibility getter exposed a mutable authoritative dictionary", failures)
	var previous_revision := pair[0].visibility_revision_for_team(0)
	for simulation in pair:
		simulation.setup(&"human", false)
	_visibility_equal(pair, "reused simulation reset", failures)
	_expect(pair[0].visibility_revision_for_team(0) > previous_revision, "setup reused a stale visibility revision", failures)


func _test_separation(failures: Array[String]) -> void:
	var pair := _pair()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x524F5241434C45
	# Keep all existing mobile categories: hostile guardians, harmless wildlife,
	# retaliating wildlife, workers, and mixed-team units. Exercise both bucket
	# borders and coincident clusters while retaining original narrow-phase rules.
	for fixture_index in range(12):
		var mobile_index := 0
		for raw_entity in pair[0].entities.values():
			var entity_state := raw_entity as Dictionary
			if entity_state.get("category") not in [&"unit", &"wildlife"]:
				continue
			var position := Vector2(24.0, 40.0)
			match fixture_index % 3:
				0:
					position += Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
				1:
					position += Vector2(float(mobile_index % 8) + 0.999, float(mobile_index / 8) + 0.001)
				2:
					position += Vector2(float(mobile_index % 3), 0.0)
			entity_state["position"] = position
			entity_state["cell"] = Vector2i(position.round())
			entity_state["separation_velocity"] = Vector2(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.25, 0.25))
			entity_state["path"] = [position + Vector2.RIGHT] if mobile_index % 3 == 0 else []
			entity_state["path_index"] = 0
			entity_state["garrisoned_in"] = 100_000 if mobile_index % 11 == 0 else -1
			mobile_index += 1
		_copy_entities(pair)
		for step in range(3):
			for simulation in pair:
				simulation._resolve_unit_separation()
			_expect(pair[0].entities == pair[1].entities, "separation fixture %d step %d differs from original pair order" % [fixture_index, step], failures)
			if not failures.is_empty():
				return


func _test_navigation_preparation(failures: Array[String]) -> void:
	var pair := _pair()
	var worker_id := pair[0].team_entity_ids(0, [&"worker"])[0]
	pair[0]._spawn_structure(0, &"gate", Vector2i(24, 40), true, &"x")
	pair[0]._spawn_structure(0, &"wall", Vector2i(24, 40), true, &"y")
	pair[0]._spawn_structure(1, &"war_camp", Vector2i(30, 40), true)
	_copy_entities(pair)
	for carrying_egg in [false, true]:
		for team in [0, 1, -1]:
			for destination in [Vector2i(26, 40), Vector2i(40, 36), Vector2i(0, 0), Vector2i(79, 79)]:
				for simulation in pair:
					var worker := simulation.entity(worker_id)
					worker["position"] = Vector2(24, 40)
					worker["team"] = team
					worker["carrying_egg"] = carrying_egg
					simulation._set_path(worker, destination)
				_expect(pair[0].entity(worker_id) == pair[1].entity(worker_id), "path query differs for team %d carrier=%s target=%s" % [team, carrying_egg, destination], failures)
				for y in range(MapCatalog.SIZE.y):
					for x in range(MapCatalog.SIZE.x):
						var cell := Vector2i(x, y)
						if pair[0]._astar.is_point_solid(cell) != pair[1]._astar.is_point_solid(cell):
							failures.append("path preparation changed restored occupancy at %s" % cell)
							return


func _test_match_ticks(failures: Array[String]) -> void:
	var pair := _pair(true)
	for tick in range(180):
		for simulation in pair:
			simulation.advance(RtsSimulation.TICK_SECONDS)
		_expect(pair[0].entities == pair[1].entities, "live match entity state differs at tick %d" % tick, failures)
		_expect(pair[0].players == pair[1].players, "live match player state differs at tick %d" % tick, failures)
		_expect(pair[0].drain_events() == pair[1].drain_events(), "live match events differ at tick %d" % tick, failures)
		for team in range(RtsSimulation.TEAM_COUNT):
			_expect(pair[0].visible_cells_for_team(team) == pair[1].visible_cells_for_team(team), "live match fog differs at tick %d" % tick, failures)
		if not failures.is_empty():
			return


func _test_lifecycle_contract(failures: Array[String]) -> void:
	var pair := _pair()
	var worker_id := pair[0].team_entity_ids(0, [&"worker"])[0]
	var live_reference := pair[0].entity(worker_id)
	for simulation in pair:
		simulation._kill(simulation.entity(worker_id), {})
		simulation._refresh_visibility()
	_expect(not bool(live_reference.get("alive", true)), "retirement detached an existing authoritative entity reference", failures)
	_expect(pair[0].entity(worker_id) == pair[1].entity(worker_id), "dead-unit lookup contract differs from the reference", failures)
	_expect(pair[0].drain_events() == pair[1].drain_events(), "death snapshot or score events changed", failures)
	for simulation in pair:
		simulation._kill(simulation.entity(worker_id), {})
	_expect(pair[0].drain_events().is_empty() and pair[1].drain_events().is_empty(), "repeated death emitted another event", failures)
	var wildlife_id := pair[0].wildlife_ids()[0]
	for simulation in pair:
		simulation._kill(simulation.entity(wildlife_id), {})
	_expect(pair[0].entity(wildlife_id).is_empty() and pair[1].entity(wildlife_id).is_empty(), "renewable wildlife no longer retires immediately", failures)
	_expect(pair[0].players == pair[1].players, "lifecycle changes altered population or score", failures)
	_visibility_equal(pair, "lifecycle visibility", failures)


func _run() -> void:
	var failures: Array[String] = []
	_test_visibility(failures)
	_test_separation(failures)
	_test_navigation_preparation(failures)
	_test_lifecycle_contract(failures)
	_test_match_ticks(failures)
	if failures.is_empty():
		print("PASS runtime_equivalence_test: spatial, visibility and navigation match legacy reference algorithms and live AI ticks")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
