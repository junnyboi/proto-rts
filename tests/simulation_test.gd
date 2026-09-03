extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _advance(simulation: RtsSimulation, seconds: float) -> void:
	for _step in range(int(seconds / RtsSimulation.TICK_SECONDS)):
		simulation.advance(RtsSimulation.TICK_SECONDS)


func _test_stronghold_dropoff(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	var worker := simulation.entity(worker_id)
	var stronghold := simulation.entity(
		simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	)
	var dropoff_cell := stronghold["cell"] as Vector2i + Vector2i(0, -1)
	worker["position"] = Vector2(dropoff_cell)
	worker["cell"] = dropoff_cell
	worker["order"] = &"return"
	worker["path"] = []
	worker["cargo_kind"] = &"lumber"
	worker["cargo_amount"] = RtsSimulation.CARGO_CAPACITY
	worker["gather_source_id"] = -1
	var lumber_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"])
	simulation.advance(RtsSimulation.TICK_SECONDS)
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != lumber_before + int(RtsSimulation.CARGO_CAPACITY):
		failures.append("worker stalled beside the Stronghold instead of depositing cargo")
	if float(worker.get("cargo_amount", 0.0)) > 0.0 or worker.get("order") == &"return":
		failures.append("worker remained stuck in the resource return order after reaching the Stronghold")


func _test_manual_deposit_requires_range(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	var worker := simulation.entity(worker_id)
	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	worker["cargo_kind"] = &"lumber"
	worker["cargo_amount"] = 20.0
	var lumber_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"])
	var deposited_workers := simulation.command_deposit(RtsSimulation.TEAM_PLAYER, [worker_id], stronghold_id)
	if deposited_workers != 0:
		failures.append("a remote worker deposited immediately")
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != lumber_before:
		failures.append("a remote deposit command changed the stockpile")
	if worker.get("cargo_kind") != &"lumber" or float(worker.get("cargo_amount", 0.0)) != 20.0:
		failures.append("a remote deposit command changed carried cargo before arrival")
	if worker.get("order") != &"return":
		failures.append("a remote deposit command did not start a return order")
	var timeout := 10.0
	while float(worker.get("cargo_amount", 0.0)) > 0.0 and timeout > 0.0:
		simulation.advance(RtsSimulation.TICK_SECONDS)
		timeout -= RtsSimulation.TICK_SECONDS
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != lumber_before + 20:
		failures.append("a returning worker did not deposit after reaching the Stronghold")
	if float(worker.get("cargo_amount", 0.0)) > 0.0:
		failures.append("a returning worker retained cargo after the physical drop-off")


func _test_cargo_reassignment_preserves_kind(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	var worker := simulation.entity(worker_id)
	var jade: Dictionary = {}
	var jade_distance := INF
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("resource_kind") == &"jade":
			var distance := (entity_state["position"] as Vector2).distance_to(worker["position"] as Vector2)
			if distance >= jade_distance:
				continue
			jade_distance = distance
			jade = entity_state
	if jade.is_empty():
		failures.append("no Jade node was available for the cargo reassignment test")
		return
	var visible_cell := simulation._nearest_walkable_around(jade["cell"] as Vector2i, 3)
	worker["position"] = Vector2(visible_cell)
	worker["cell"] = visible_cell
	worker["path"] = []
	worker["cargo_kind"] = &"lumber"
	worker["cargo_amount"] = 20.0
	simulation._refresh_visibility()
	var lumber_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"])
	simulation.command_gather(RtsSimulation.TEAM_PLAYER, [worker_id], int(jade["id"]))
	if worker.get("order") != &"return":
		failures.append("reassigning mixed cargo did not start a return order")
	if int(worker.get("gather_source_id", -1)) != int(jade["id"]):
		failures.append("reassigning mixed cargo did not remember the new source")
	if worker.get("cargo_kind") != &"lumber" or float(worker.get("cargo_amount", 0.0)) != 20.0:
		failures.append("reassigning to Jade converted the existing Lumber cargo")
	var timeout := 15.0
	while int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) == lumber_before and timeout > 0.0:
		simulation.advance(RtsSimulation.TICK_SECONDS)
		timeout -= RtsSimulation.TICK_SECONDS
		if float(worker.get("cargo_amount", 0.0)) > 0.0 and worker.get("cargo_kind") != &"lumber":
			failures.append("cargo kind changed before the old load was deposited")
			break
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != lumber_before + 20:
		failures.append("the old Lumber load was not banked before gathering Jade")
	if worker.get("order") != &"gather" or int(worker.get("gather_source_id", -1)) != int(jade["id"]):
		failures.append("the worker did not resume the requested Jade source after deposit")
	worker["position"] = Vector2(visible_cell)
	worker["cell"] = visible_cell
	worker["path"] = []
	_advance(simulation, RtsSimulation.GATHER_CYCLE + RtsSimulation.TICK_SECONDS * 2.0)
	if float(worker.get("cargo_amount", 0.0)) <= 0.0 or worker.get("cargo_kind") != &"jade":
		failures.append("the empty worker did not begin a new Jade load after returning Lumber")


func _test_attack_move_resumes_destination(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var start := simulation._nearest_walkable(MapCatalog.PLAYER_BUILD_TEST_SITE)
	var nearby_cells := simulation._formation_cells(start, 2)
	if nearby_cells.size() < 2:
		failures.append("no nearby walkable cells were available for the attack-move test")
		return
	var destination := simulation._nearest_walkable(start + Vector2i(12, -6))
	var attacker_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", start)
	var target_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", nearby_cells[1])
	var attacker := simulation.entity(attacker_id)
	var target := simulation.entity(target_id)
	target["hp"] = 1.0
	simulation._refresh_visibility()
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [attacker_id], destination, true)
	var saved_destination := attacker.get("attack_move_destination", Vector2i(-1, -1)) as Vector2i
	var timeout := 4.0
	while bool(target.get("alive", false)) and timeout > 0.0:
		simulation.advance(RtsSimulation.TICK_SECONDS)
		timeout -= RtsSimulation.TICK_SECONDS
	if bool(target.get("alive", false)):
		failures.append("attack-move did not engage the nearby visible enemy")
		return
	var distance_after_kill := (attacker["position"] as Vector2).distance_to(Vector2(saved_destination))
	_advance(simulation, 1.0)
	var distance_after_resume := (attacker["position"] as Vector2).distance_to(Vector2(saved_destination))
	if distance_after_resume >= distance_after_kill - 0.05:
		failures.append("attack-move did not resume progress toward its saved destination")
	if bool(attacker.get("attack_move", false)) and attacker.get("attack_move_destination") != saved_destination:
		failures.append("attack-move lost its final destination after combat")


func _test_diagonal_pathfinding(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	simulation.entities.clear()
	simulation._rebuild_pathfinding()
	var origin := Vector2i(-1, -1)
	for y in range(MapCatalog.SIZE.y - 1):
		for x in range(MapCatalog.SIZE.x - 1):
			var candidate := Vector2i(x, y)
			if (
				not simulation._astar.is_point_solid(candidate)
				and not simulation._astar.is_point_solid(candidate + Vector2i.RIGHT)
				and not simulation._astar.is_point_solid(candidate + Vector2i.DOWN)
				and not simulation._astar.is_point_solid(candidate + Vector2i.ONE)
			):
				origin = candidate
				break
		if origin.x >= 0:
			break
	if origin.x < 0:
		failures.append("no unobstructed diagonal test area was available")
		return

	var destination := origin + Vector2i.ONE
	var unit_kinds: Array[StringName] = [
		&"worker",
		&"hunter",
		&"vanguard",
		&"mystic",
		&"jadeclaw",
		&"shenlong",
	]
	for unit_kind in unit_kinds:
		var unit_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, unit_kind, origin)
		var unit := simulation.entity(unit_id)
		simulation._set_path(unit, destination)
		var path := unit.get("path", []) as Array
		if path.size() != 1 or not (path[0] as Vector2).is_equal_approx(Vector2(destination)):
			failures.append("%s did not receive a direct unobstructed diagonal path" % unit_kind)
		else:
			for _step in range(int(2.0 / RtsSimulation.TICK_SECONDS)):
				simulation._advance_path(unit, RtsSimulation.TICK_SECONDS)
				if (unit["position"] as Vector2).is_equal_approx(Vector2(destination)):
					break
			if not (unit["position"] as Vector2).is_equal_approx(Vector2(destination)):
				failures.append("%s did not move onto its diagonal destination tile" % unit_kind)
		simulation.entities.erase(unit_id)

	var corner_test_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", origin)
	var corner_test_unit := simulation.entity(corner_test_id)
	simulation._astar.set_point_solid(origin + Vector2i.RIGHT, true)
	simulation._set_path(corner_test_unit, destination)
	var corner_path := corner_test_unit.get("path", []) as Array
	if not corner_path.is_empty() and (corner_path[0] as Vector2).is_equal_approx(Vector2(destination)):
		failures.append("a diagonal path cut through an obstructed corner")


func _test_large_formations_and_separation(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var destination := simulation._nearest_walkable(MapCatalog.PLAYER_BUILD_TEST_SITE)
	var formation := simulation._formation_cells(destination, 14)
	var unique_cells: Dictionary = {}
	for cell in formation:
		unique_cells[cell] = true
	if formation.size() != 14 or unique_cells.size() != 14:
		failures.append("formation generation did not provide 14 unique destinations")
	var unit_ids: Array[int] = []
	var origin := simulation._nearest_walkable(destination + Vector2i(0, 6))
	for _index in range(14):
		unit_ids.append(simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", origin))
	simulation.command_move(RtsSimulation.TEAM_PLAYER, unit_ids, destination, true)
	var assigned_destinations: Dictionary = {}
	for unit_id in unit_ids:
		assigned_destinations[simulation.entity(unit_id).get("attack_move_destination")] = true
	if assigned_destinations.size() != unit_ids.size():
		failures.append("a large command group reused formation destinations")
	var separation_simulation := RtsSimulation.new()
	separation_simulation.setup(&"human")
	var separation_cell := separation_simulation._nearest_walkable(MapCatalog.SIZE / 2)
	var first_id := separation_simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", separation_cell)
	var second_id := separation_simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", separation_cell)
	for _step in range(int(2.0 / RtsSimulation.TICK_SECONDS)):
		separation_simulation._resolve_unit_separation(RtsSimulation.TICK_SECONDS)
	var separation := (
		separation_simulation.entity(first_id)["position"] as Vector2
	).distance_to(separation_simulation.entity(second_id)["position"] as Vector2)
	if separation < RtsSimulation.UNIT_SEPARATION_DISTANCE - 0.01:
		failures.append("overlapping military units did not separate locally")


func _test_hostile_worker_separation(failures: Array[String]) -> void:
	var hostile_simulation := RtsSimulation.new()
	hostile_simulation.setup(&"human")
	var hostile_overlap_cell := hostile_simulation._nearest_walkable(MapCatalog.SIZE / 2)
	var hostile_worker_id := hostile_simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"worker",
		hostile_overlap_cell,
	)
	var hostile_unit_id := hostile_simulation._spawn_unit(
		RtsSimulation.TEAM_ENEMY,
		&"vanguard",
		hostile_overlap_cell,
	)
	for _step in range(int(2.0 / RtsSimulation.TICK_SECONDS)):
		hostile_simulation._resolve_unit_separation(RtsSimulation.TICK_SECONDS)
	var hostile_separation := (
		hostile_simulation.entity(hostile_worker_id)["position"] as Vector2
	).distance_to(hostile_simulation.entity(hostile_unit_id)["position"] as Vector2)
	if hostile_separation < RtsSimulation.UNIT_SEPARATION_DISTANCE - 0.01:
		failures.append("an enemy unit passed through a worker")


func _test_units_pass_through_harmless_wildlife(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var overlap_cell := simulation._nearest_walkable(MapCatalog.SIZE / 2)
	var harmless_kinds: Array[StringName] = [&"chicken", &"deer", &"bison"]
	var unit_kinds: Array[StringName] = [&"worker", &"hunter", &"vanguard", &"mystic", &"jadeclaw"]
	for unit_kind in unit_kinds:
		for wildlife_kind in harmless_kinds:
			var unit_id := simulation._spawn_unit(
				RtsSimulation.TEAM_PLAYER,
				unit_kind,
				overlap_cell,
			)
			var wildlife_id := simulation._spawn_wildlife(
				wildlife_kind,
				overlap_cell,
				-1,
				overlap_cell,
				3.0,
			)
			simulation._resolve_unit_separation()
			var separation := (
				simulation.entity(unit_id)["position"] as Vector2
			).distance_to(simulation.entity(wildlife_id)["position"] as Vector2)
			if separation > 0.01:
				failures.append(
					"%s could not pass through harmless %s wildlife"
					% [String(unit_kind).capitalize(), String(wildlife_kind).capitalize()]
				)
			simulation.entities.erase(unit_id)
			simulation.entities.erase(wildlife_id)

	for aggressive_kind in [&"boar", &"bear"]:
		var unit_id := simulation._spawn_unit(
			RtsSimulation.TEAM_PLAYER,
			&"vanguard",
			overlap_cell,
		)
		var wildlife_id := simulation._spawn_wildlife(
			aggressive_kind,
			overlap_cell,
			-1,
			overlap_cell,
			3.0,
		)
		for _step in range(int(2.0 / RtsSimulation.TICK_SECONDS)):
			simulation._resolve_unit_separation(RtsSimulation.TICK_SECONDS)
		var separation := (
			simulation.entity(unit_id)["position"] as Vector2
		).distance_to(simulation.entity(wildlife_id)["position"] as Vector2)
		if separation < RtsSimulation.UNIT_SEPARATION_DISTANCE - 0.01:
			failures.append("a unit passed through aggressive %s wildlife" % aggressive_kind)
		simulation.entities.erase(unit_id)
		simulation.entities.erase(wildlife_id)


func _test_units_pass_through_friendly_structures(failures: Array[String]) -> void:
	var unit_kinds: Array[StringName] = [&"worker", &"hunter", &"vanguard", &"mystic", &"jadeclaw"]
	for unit_kind in unit_kinds:
		var simulation := RtsSimulation.new()
		simulation.setup(&"human", false)
		simulation.entities.clear()
		simulation.players[RtsSimulation.TEAM_PLAYER]["population"] = 0
		simulation.players[RtsSimulation.TEAM_ENEMY]["population"] = 0
		simulation._next_entity_id = 1
		simulation._rebuild_pathfinding()
		var structure_cell := MapCatalog.PLAYER_BUILD_TEST_SITE
		var structure_id := simulation._spawn_structure(
			RtsSimulation.TEAM_PLAYER,
			&"rice_farm",
			structure_cell,
			true,
		)
		var structure := simulation.entity(structure_id)
		var footprint_cells := MapCatalog.footprint_cells(
			structure_cell,
			structure["footprint"] as Vector2i,
		)
		var start := structure_cell + Vector2i(-2, 0)
		var destination := structure_cell + Vector2i(3, 0)
		var unit_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, unit_kind, start)
		var unit := simulation.entity(unit_id)
		if unit_kind == &"hunter":
			unit["wander_timer"] = 999.0
		simulation._rebuild_pathfinding()
		simulation._set_path(unit, destination)
		var friendly_path := unit.get("path", []) as Array
		var crosses_friendly_structure := false
		for point in friendly_path:
			if Vector2i(point as Vector2) in footprint_cells:
				crosses_friendly_structure = true
				break
		if not crosses_friendly_structure:
			failures.append("%s path did not pass through its friendly structure" % unit_kind)
		unit["order"] = &"move"
		_advance(simulation, 8.0)
		if (unit["position"] as Vector2).distance_to(Vector2(destination)) > 0.05:
			failures.append("%s did not reach its destination through a friendly structure" % unit_kind)

	var enemy_simulation := RtsSimulation.new()
	enemy_simulation.setup(&"human", false)
	enemy_simulation.entities.clear()
	enemy_simulation.players[RtsSimulation.TEAM_PLAYER]["population"] = 0
	enemy_simulation.players[RtsSimulation.TEAM_ENEMY]["population"] = 0
	enemy_simulation._next_entity_id = 1
	enemy_simulation._rebuild_pathfinding()
	var enemy_structure_cell := MapCatalog.PLAYER_BUILD_TEST_SITE
	var enemy_structure_id := enemy_simulation._spawn_structure(
		RtsSimulation.TEAM_ENEMY,
		&"rice_farm",
		enemy_structure_cell,
		true,
	)
	var enemy_structure := enemy_simulation.entity(enemy_structure_id)
	var enemy_footprint_cells := MapCatalog.footprint_cells(
		enemy_structure_cell,
		enemy_structure["footprint"] as Vector2i,
	)
	var enemy_start := enemy_structure_cell + Vector2i(-2, 0)
	var enemy_destination := enemy_structure_cell + Vector2i(3, 0)
	var player_unit_id := enemy_simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", enemy_start)
	var player_unit := enemy_simulation.entity(player_unit_id)
	enemy_simulation._rebuild_pathfinding()
	enemy_simulation._set_path(player_unit, enemy_destination)
	var enemy_path := player_unit.get("path", []) as Array
	if enemy_path.is_empty():
		failures.append("an enemy structure prevented pathfinding around its footprint")
	for point in enemy_path:
		if Vector2i(point as Vector2) in enemy_footprint_cells:
			failures.append("a unit path passed through an enemy structure")
			break


func _test_unit_food_costs(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	var worker_stats := FactionCatalog.stats(&"worker", &"human")
	var food_cost := int(worker_stats.get("food_cost", 0))
	if food_cost <= 0:
		failures.append("Worker does not have a positive Food cost")
		return
	simulation.players[RtsSimulation.TEAM_PLAYER]["food"] = food_cost - 1
	var jade_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["jade"])
	var population_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["population"])
	if simulation.command_train(RtsSimulation.TEAM_PLAYER, stronghold_id, &"worker"):
		failures.append("Stronghold queued a Worker without enough Food")
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["jade"]) != jade_before:
		failures.append("failed Food affordability check partially charged Jade")
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["population"]) != population_before:
		failures.append("failed Food affordability check reserved population")
	simulation.players[RtsSimulation.TEAM_PLAYER]["food"] = food_cost
	if not simulation.command_train(RtsSimulation.TEAM_PLAYER, stronghold_id, &"worker"):
		failures.append("Stronghold rejected a Worker with exactly enough Food")
	elif int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"]) != 0:
		failures.append("Worker queue did not deduct its exact Food cost")
	for kind in [&"worker", &"hunter", &"vanguard", &"mystic", &"jadeclaw"]:
		if int(FactionCatalog.stats(kind, &"human").get("food_cost", 0)) <= 0:
			failures.append("%s does not require Food" % String(kind).capitalize())


func _test_stronghold_population_upgrades(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var team := RtsSimulation.TEAM_PLAYER
	var stronghold_id := simulation.primary_structure_id(team, &"stronghold")
	var stronghold := simulation.entity(stronghold_id)
	var player := simulation.players[team] as Dictionary
	if int(stronghold.get("stronghold_level", 0)) != RtsSimulation.STRONGHOLD_INITIAL_LEVEL:
		failures.append("Stronghold did not begin at Lvl 1")
	if int(player["population_cap"]) != RtsSimulation.POPULATION_CAP:
		failures.append("Stronghold did not begin with the base population cap")

	var first_cost := simulation.stronghold_upgrade_cost(stronghold_id)
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		if int(first_cost.get("%s_cost" % String(resource_kind), -1)) != 200:
			failures.append("first Stronghold upgrade did not cost 200 %s" % String(resource_kind).capitalize())
		player[String(resource_kind)] = 199
	if simulation.can_upgrade_stronghold(team, stronghold_id):
		failures.append("Stronghold upgrade appeared available below its resource cost")
	if simulation.command_upgrade_stronghold(team, stronghold_id):
		failures.append("Stronghold upgraded without enough of every resource")
	if (
		int(stronghold.get("stronghold_level", 0)) != RtsSimulation.STRONGHOLD_INITIAL_LEVEL
		or int(player["population_cap"]) != RtsSimulation.POPULATION_CAP
	):
		failures.append("failed Stronghold upgrade changed its level or population cap")

	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		player[String(resource_kind)] = 200
	if not simulation.can_upgrade_stronghold(team, stronghold_id):
		failures.append("first Stronghold upgrade was unavailable at its exact resource cost")
	elif not simulation.command_upgrade_stronghold(team, stronghold_id):
		failures.append("first Stronghold upgrade was rejected")
	if int(stronghold.get("stronghold_level", 0)) != 2:
		failures.append("first Stronghold upgrade did not advance it to Lvl 2")
	if int(player["population_cap"]) != RtsSimulation.POPULATION_CAP + 6:
		failures.append("first Stronghold upgrade did not add six population capacity")
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		if int(player[String(resource_kind)]) != 0:
			failures.append("first Stronghold upgrade did not deduct exactly 200 %s" % String(resource_kind).capitalize())

	var second_cost := simulation.stronghold_upgrade_cost(stronghold_id)
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		if int(second_cost.get("%s_cost" % String(resource_kind), -1)) != 300:
			failures.append("second Stronghold upgrade did not cost 300 %s" % String(resource_kind).capitalize())
		player[String(resource_kind)] = 300
	if simulation.command_upgrade_stronghold(RtsSimulation.TEAM_ENEMY, stronghold_id):
		failures.append("a rival upgraded the player's Stronghold")
	if not simulation.command_upgrade_stronghold(team, stronghold_id):
		failures.append("second Stronghold upgrade was rejected")
	if int(stronghold.get("stronghold_level", 0)) != RtsSimulation.STRONGHOLD_MAX_LEVEL:
		failures.append("second Stronghold upgrade did not advance it to the maximum level")
	if int(player["population_cap"]) != RtsSimulation.POPULATION_CAP + 12:
		failures.append("second Stronghold upgrade did not raise the total capacity by twelve")
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		if int(player[String(resource_kind)]) != 0:
			failures.append("second Stronghold upgrade did not deduct exactly 300 %s" % String(resource_kind).capitalize())
		player[String(resource_kind)] = 1000
	if not simulation.stronghold_upgrade_cost(stronghold_id).is_empty():
		failures.append("maximum-level Stronghold still exposed another upgrade cost")
	if simulation.command_upgrade_stronghold(team, stronghold_id):
		failures.append("Stronghold accepted a third upgrade")
	if int(player["population_cap"]) != RtsSimulation.POPULATION_CAP + 12:
		failures.append("rejected third Stronghold upgrade changed the population cap")
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		if int(player[String(resource_kind)]) != 1000:
			failures.append("rejected third Stronghold upgrade charged %s" % String(resource_kind).capitalize())


func _test_targeted_production_cancellation(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var team := RtsSimulation.TEAM_PLAYER
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		simulation.players[team][String(resource_kind)] = 2000
	var camp_id := simulation._spawn_structure(
		team,
		&"war_camp",
		MapCatalog.PLAYER_BUILD_TEST_SITE,
		true,
	)
	if (
		not simulation.command_train(team, camp_id, &"vanguard")
		or not simulation.command_train(team, camp_id, &"mystic")
		or not simulation.command_train(team, camp_id, &"vanguard")
	):
		failures.append("targeted cancellation test could not build a mixed production queue")
		return
	var queue := simulation.entity(camp_id).get("queue", []) as Array
	var expected_costs := ((queue[1] as Dictionary).get("costs", {}) as Dictionary).duplicate()
	var target_order_id := int((queue[1] as Dictionary).get("order_id", -1))
	var resources_before: Dictionary = {}
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		resources_before[resource_kind] = int(simulation.players[team][String(resource_kind)])
	var population_before := int(simulation.players[team]["population"])
	var cancelled := simulation.command_cancel_training(team, camp_id, 1, target_order_id)
	if cancelled.get("kind") != &"mystic":
		failures.append("targeted production cancellation removed the wrong queue order")
	queue = simulation.entity(camp_id).get("queue", []) as Array
	if (
		queue.size() != 2
		or (queue[0] as Dictionary).get("kind") != &"vanguard"
		or (queue[1] as Dictionary).get("kind") != &"vanguard"
	):
		failures.append("targeted production cancellation did not preserve the surrounding orders")
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		var resource_key := String(resource_kind)
		var expected_amount := int(resources_before[resource_kind]) + int(expected_costs.get(resource_key, 0))
		if int(simulation.players[team][resource_key]) != expected_amount:
			failures.append("targeted production cancellation did not fully refund %s" % resource_key.capitalize())
	var expected_population := population_before - int(cancelled.get("reserved_population", 0))
	if int(simulation.players[team]["population"]) != expected_population:
		failures.append("targeted production cancellation did not release reserved population")
	if not simulation.command_cancel_training(team, camp_id, 0, target_order_id).is_empty():
		failures.append("a stale production order identity cancelled a different unit")
	if not simulation.command_cancel_training(team, camp_id, 2).is_empty():
		failures.append("an out-of-range production cancellation was accepted")
	if (simulation.entity(camp_id).get("queue", []) as Array).size() != 2:
		failures.append("an out-of-range production cancellation mutated the queue")


func _test_free_worker_recovery(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var team := RtsSimulation.TEAM_PLAYER
	var stronghold_id := simulation.primary_structure_id(team, &"stronghold")
	for worker_id in simulation.team_entity_ids(team, [&"worker"]):
		simulation._kill(simulation.entity(worker_id), {})
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		simulation.players[team][String(resource_kind)] = 0
	if not simulation.can_train_free_worker(team):
		failures.append("a player with no Workers was not offered a free recovery Worker")
	if not simulation.can_afford_kind(team, &"worker"):
		failures.append("the free recovery Worker failed the affordability query")
	if not simulation.command_train(team, stronghold_id, &"worker"):
		failures.append("the Stronghold rejected a free recovery Worker")
		return
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		if int(simulation.players[team][String(resource_kind)]) != 0:
			failures.append("the free recovery Worker charged %s" % String(resource_kind).capitalize())
	var queue := simulation.entity(stronghold_id).get("queue", []) as Array
	if queue.is_empty():
		failures.append("the free recovery Worker was not added to the production queue")
	else:
		var costs := (queue[0] as Dictionary).get("costs", {}) as Dictionary
		for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
			if int(costs.get(String(resource_kind), -1)) != 0:
				failures.append("the free recovery Worker recorded a %s refund" % String(resource_kind).capitalize())
	if simulation.can_train_free_worker(team):
		failures.append("another free Worker was offered while a recovery Worker was queued")
	if simulation.can_afford_kind(team, &"worker"):
		failures.append("a second Worker appeared affordable with no resources")
	if simulation.command_train(team, stronghold_id, &"worker"):
		failures.append("the Stronghold queued a second free Worker")
	var cancelled := simulation.command_cancel_training(team, stronghold_id)
	if cancelled.is_empty() or not simulation.can_train_free_worker(team):
		failures.append("cancelling the recovery Worker did not restore free Worker eligibility")
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		if int(simulation.players[team][String(resource_kind)]) != 0:
			failures.append("cancelling the free recovery Worker granted %s" % String(resource_kind).capitalize())


func _test_food_building(
	structure_kind: StringName,
	failures: Array[String],
) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	simulation.players[RtsSimulation.TEAM_PLAYER]["jade"] = 1000
	simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"] = 1000
	simulation.players[RtsSimulation.TEAM_PLAYER]["essence"] = 1000
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	var site := simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		structure_kind,
		MapCatalog.PLAYER_STRONGHOLD,
	)
	if site.x < 0:
		failures.append("no valid %s test site was found" % String(structure_kind))
		return
	if not simulation.command_build(RtsSimulation.TEAM_PLAYER, worker_id, structure_kind, site):
		failures.append("valid %s placement was rejected" % String(structure_kind))
		return
	var structure_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, structure_kind)
	var structure := simulation.entity(structure_id)
	var food_after_payment := int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"])
	_advance(simulation, 1.0)
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"]) != food_after_payment:
		failures.append("incomplete %s produced Food" % String(structure_kind))
	var construction_timeout := 30.0
	while float(structure.get("complete", 0.0)) < 1.0 and construction_timeout > 0.0:
		simulation.advance(RtsSimulation.TICK_SECONDS)
		construction_timeout -= RtsSimulation.TICK_SECONDS
	if float(structure.get("complete", 0.0)) < 1.0:
		failures.append("%s did not finish construction" % String(structure_kind))
		return
	var stats := FactionCatalog.stats(structure_kind, &"human")
	var expected_yield := simulation.structure_food_yield(structure_id)
	var interval := float(stats.get("food_interval", 0.0))
	var food_before_harvest := int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"])
	simulation._advance_food_production(interval + RtsSimulation.TICK_SECONDS * 2.0)
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"]) != food_before_harvest + expected_yield:
		failures.append("%s did not deliver its exact Food harvest" % String(structure_kind))
	var expected_rate := float(expected_yield) / interval
	if not is_equal_approx(simulation.food_income_per_second(RtsSimulation.TEAM_PLAYER), expected_rate):
		failures.append("%s reported an incorrect Food income rate" % String(structure_kind))
	var expected_interval := 40.0 if structure_kind == &"rice_farm" else 50.0
	if not is_equal_approx(interval, expected_interval):
		failures.append("%s passive Food production was not reduced to one tenth" % String(structure_kind))


func _test_farm_worker_assignment(failures: Array[String]) -> void:
	var construction_simulation := RtsSimulation.new()
	construction_simulation.setup(&"human", false)
	var construction_team := RtsSimulation.TEAM_PLAYER
	var construction_site := construction_simulation._find_build_site(
		construction_team,
		&"rice_farm",
		MapCatalog.PLAYER_STRONGHOLD,
	)
	if construction_site.x < 0:
		failures.append("no valid automatic Rice Farm staffing test site was found")
		return
	var incomplete_farm_id := construction_simulation._spawn_structure(
		construction_team,
		&"rice_farm",
		construction_site,
		false,
	)
	construction_simulation._rebuild_pathfinding()
	var construction_workers := construction_simulation.team_entity_ids(
		construction_team,
		[&"worker"],
	)
	var build_cell := construction_simulation._nearest_walkable_around(construction_site, 3)
	for worker_id in construction_workers:
		var builder := construction_simulation.entity(worker_id)
		construction_simulation.command_stop(construction_team, [worker_id])
		builder["position"] = Vector2(build_cell)
		builder["cell"] = build_cell
	if not construction_simulation.command_construct(
		construction_team,
		construction_workers,
		incomplete_farm_id,
	):
		failures.append("Workers could not be assigned to the automatic Rice Farm staffing test")
		return
	var incomplete_farm := construction_simulation.entity(incomplete_farm_id)
	incomplete_farm["complete"] = 0.999
	construction_simulation._advance_construction(RtsSimulation.TICK_SECONDS)
	var assigned_farmers := 0
	for worker_id in construction_workers:
		var builder := construction_simulation.entity(worker_id)
		if builder.get("order") == &"farm":
			assigned_farmers += 1
			if int(builder.get("target_id", -1)) != incomplete_farm_id:
				failures.append("the automatic Farmer targeted the wrong Rice Farm")
		elif builder.get("order") != &"idle":
			failures.append("an extra Rice Farm builder did not become idle after completion")
	if assigned_farmers != 1:
		failures.append("Rice Farm completion assigned %d builders instead of exactly one" % assigned_farmers)
	if construction_simulation.farm_worker_id(incomplete_farm_id) < 0:
		failures.append("the completed Rice Farm did not retain its automatic Farmer")

	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var team := RtsSimulation.TEAM_PLAYER
	var farm_site := simulation._find_build_site(team, &"rice_farm", MapCatalog.PLAYER_STRONGHOLD)
	if farm_site.x < 0:
		failures.append("no valid staffed Rice Farm test site was found")
		return
	var farm_id := simulation._spawn_structure(team, &"rice_farm", farm_site, true)
	simulation._rebuild_pathfinding()
	var workers := simulation.team_entity_ids(team, [&"worker"])
	if workers.size() < 3:
		failures.append("staffed Rice Farm test requires three Workers")
		return
	for worker_id in workers:
		simulation.command_stop(team, [worker_id])
	var first_worker := simulation.entity(workers[0])
	var staffed_cell := simulation._nearest_walkable_around(farm_site, 3)
	first_worker["position"] = Vector2(staffed_cell)
	first_worker["cell"] = staffed_cell
	if not simulation.command_assign_farm_worker(team, [workers[0]], farm_id):
		failures.append("an empty-handed Worker could not be assigned to a completed Rice Farm")
		return
	if simulation.farm_worker_id(farm_id) != workers[0]:
		failures.append("Rice Farm did not retain its assigned Worker")
	if simulation.command_assign_farm_worker(team, [workers[1]], farm_id):
		failures.append("Rice Farm accepted more than its maximum of one Worker")
	if not simulation.is_farm_staffed(farm_id):
		failures.append("a Worker beside the Rice Farm did not begin staffing it")
	var stats := FactionCatalog.stats(&"rice_farm", &"human")
	var passive_yield := int(stats.get("food_yield", 0))
	var expected_staffed_yield := passive_yield * RtsSimulation.FARM_WORKER_FOOD_MULTIPLIER
	if simulation.structure_food_yield(farm_id) != expected_staffed_yield:
		failures.append("an assigned Worker did not multiply Rice Farm production by exactly five")
	var food_before_harvest := int(simulation.players[team]["food"])
	simulation._advance_food_production(
		float(stats["food_interval"]) + RtsSimulation.TICK_SECONDS * 2.0
	)
	if int(simulation.players[team]["food"]) != food_before_harvest + expected_staffed_yield:
		failures.append("staffed Rice Farm did not deliver its fivefold harvest")
	simulation.command_move(team, [workers[0]], first_worker["cell"] as Vector2i + Vector2i(1, 0))
	if simulation.farm_worker_id(farm_id) >= 0:
		failures.append("reassigning a Farmer did not release the Rice Farm slot")
	if not simulation.command_assign_farm_worker(team, [workers[1]], farm_id):
		failures.append("Rice Farm slot could not be reassigned after its Worker left")
	simulation._kill(simulation.entity(workers[1]), {})
	if simulation.farm_worker_id(farm_id) >= 0:
		failures.append("a defeated Farmer did not release the Rice Farm slot")
	if not simulation.command_assign_farm_worker(team, [workers[2]], farm_id):
		failures.append("Rice Farm slot could not be reassigned after its Worker was defeated")
	simulation._kill(simulation.entity(farm_id), {})
	if simulation.entity(workers[2]).get("order") == &"farm":
		failures.append("destroying a Rice Farm left its Worker in a farm order")


func _test_food_strategy_balance(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var total_wildlife_bounty := 0
	for wildlife_id in simulation.wildlife_ids():
		total_wildlife_bounty += int(simulation.entity(wildlife_id).get("food_bounty", 0))
	var farm_stats := FactionCatalog.stats(&"rice_farm", &"human")
	var lodge_stats := FactionCatalog.stats(&"hunters_lodge", &"human")
	var farm_food := (
		float(farm_stats["food_yield"])
		* RtsSimulation.FARM_WORKER_FOOD_MULTIPLIER
		/ float(farm_stats["food_interval"])
		* RtsSimulation.FOOD_BALANCE_HORIZON_SECONDS
	)
	var hunting_food := (
		float(total_wildlife_bounty) / RtsSimulation.TEAM_COUNT
		+ float(lodge_stats["food_yield"])
		/ float(lodge_stats["food_interval"])
		* RtsSimulation.FOOD_BALANCE_HORIZON_SECONDS
	)
	if absf(farm_food - hunting_food) > farm_food * 0.01:
		failures.append(
			"12-minute farming and hunting paths differ by more than one percent (%0.1f vs %0.1f Food)"
			% [farm_food, hunting_food]
		)
	var lodge_site := simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		&"hunters_lodge",
		MapCatalog.PLAYER_STRONGHOLD,
	)
	var lodge_id := simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"hunters_lodge",
		lodge_site,
		true,
	)
	var passive_lodge_yield := simulation.structure_food_yield(lodge_id)
	simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"hunter", lodge_site + Vector2i(1, 0))
	if simulation.structure_food_yield(lodge_id) != passive_lodge_yield:
		failures.append("training a Hunter passively increased Hunter's Lodge Food production")


func _test_ai_food_economy(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"demon")
	simulation.players[RtsSimulation.TEAM_ENEMY]["jade"] = 1000
	simulation.players[RtsSimulation.TEAM_ENEMY]["lumber"] = 1000
	simulation._try_expand_ai_food_economy()
	var ai_farm_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"rice_farm")
	if ai_farm_id < 0:
		failures.append("computer commander did not establish a Rice Farm")
	else:
		var ai_farm := simulation.entity(ai_farm_id)
		ai_farm["complete"] = 1.0
		ai_farm["hp"] = ai_farm["max_hp"]
		for worker_id in simulation.team_entity_ids(RtsSimulation.TEAM_ENEMY, [&"worker"]):
			simulation.command_stop(RtsSimulation.TEAM_ENEMY, [worker_id])
		simulation._try_assign_ai_farmer()
		if simulation.farm_worker_id(ai_farm_id) < 0:
			failures.append("computer farming faction did not assign a Worker to its Rice Farm")
	var resources_before_strategy := simulation.players[RtsSimulation.TEAM_ENEMY].duplicate(true)
	simulation._ai_strategy_timer = 999.0
	simulation._advance_ai(RtsSimulation.TICK_SECONDS)
	for resource_kind in ["jade", "lumber", "essence", "food"]:
		if int(simulation.players[RtsSimulation.TEAM_ENEMY][resource_kind]) != int(resources_before_strategy[resource_kind]):
			failures.append("computer commander received a free %s stipend" % resource_kind)

	var hunting_simulation := RtsSimulation.new()
	hunting_simulation.setup(&"human")
	hunting_simulation.players[RtsSimulation.TEAM_ENEMY]["jade"] = 1000
	hunting_simulation.players[RtsSimulation.TEAM_ENEMY]["lumber"] = 1000
	hunting_simulation.players[RtsSimulation.TEAM_ENEMY]["essence"] = 1000
	hunting_simulation.players[RtsSimulation.TEAM_ENEMY]["food"] = 1000
	hunting_simulation._try_expand_ai_food_economy()
	var lodge_id := hunting_simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"hunters_lodge")
	if lodge_id < 0:
		failures.append("hunt-only computer commander did not establish a Hunter's Lodge")
	if hunting_simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"rice_farm") >= 0:
		failures.append("hunt-only computer commander established a forbidden Rice Farm")
	if lodge_id >= 0:
		var lodge := hunting_simulation.entity(lodge_id)
		lodge["complete"] = 1.0
		lodge["hp"] = lodge["max_hp"]
		hunting_simulation._try_train_ai_hunters()
		var queue := lodge.get("queue", []) as Array
		if queue.is_empty() or (queue[0] as Dictionary).get("kind") != &"hunter":
			failures.append("hunt-only computer commander did not queue a Hunter")
	var ai_hunter_id := hunting_simulation._spawn_unit(
		RtsSimulation.TEAM_ENEMY,
		&"hunter",
		MapCatalog.ENEMY_STRONGHOLD + Vector2i(-1, 2),
	)
	hunting_simulation._issue_ai_hunt_orders()
	if hunting_simulation.entity(ai_hunter_id).get("order") not in [&"attack", &"seek_hunting_pasture"]:
		failures.append("computer Hunter did not pursue living wildlife")


func _test_ai_base_assault_waves(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var caves := simulation.cave_ids()
	if caves.is_empty():
		failures.append("no cave was available to satisfy the computer assault prerequisite")
		return
	simulation.entity(caves[0])["team"] = RtsSimulation.TEAM_ENEMY
	var assault_ids: Array[int] = []
	for offset in range(7):
		assault_ids.append(simulation._spawn_unit(
			RtsSimulation.TEAM_ENEMY,
			&"vanguard",
			MapCatalog.ENEMY_STRONGHOLD + Vector2i(-2 - offset, 2),
		))
	simulation._ai_attack_timer = 0.0
	simulation._ai_strategy_timer = 0.0
	simulation._advance_ai(RtsSimulation.TICK_SECONDS)
	var first_wave_size := 0
	for unit_id in assault_ids:
		if simulation.entity(unit_id).get("order") in [&"attack", &"attack_move"]:
			first_wave_size += 1
	if first_wave_size != RtsSimulation.AI_ASSAULT_WAVE_SIZE:
		failures.append(
			"computer base assault sent %d units instead of a %d-unit wave"
			% [first_wave_size, RtsSimulation.AI_ASSAULT_WAVE_SIZE]
		)
	if not is_equal_approx(simulation._ai_attack_timer, RtsSimulation.AI_ASSAULT_INTERVAL):
		failures.append("computer base assault did not reset the reduced-aggression interval")
	simulation._ai_strategy_timer = 0.0
	simulation._advance_ai(RtsSimulation.TICK_SECONDS)
	var units_committed_during_cooldown := 0
	for unit_id in assault_ids:
		if simulation.entity(unit_id).get("order") in [&"attack", &"attack_move"]:
			units_committed_during_cooldown += 1
	if units_committed_during_cooldown != RtsSimulation.AI_ASSAULT_WAVE_SIZE:
		failures.append("a large computer army bypassed the base-assault cooldown")


func _test_ai_avoids_shenlong_until_ten_minutes(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var guardian := simulation.shenlong_guardian()
	if guardian.is_empty():
		failures.append("Shenlong was unavailable for the computer avoidance test")
		return
	var guardian_id := int(guardian["id"])
	var army: Array[Dictionary] = []
	for offset in range(RtsSimulation.AI_SHENLONG_MIN_READY_UNITS):
		var spawn_cell := MapCatalog.SHENLONG_CELL + Vector2i(2 + offset, 0)
		var unit_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", spawn_cell)
		army.append(simulation.entity(unit_id))
	simulation._refresh_visibility()
	var nearby_attacker := army[0]
	if simulation.command_attack(
		RtsSimulation.TEAM_ENEMY,
		[int(nearby_attacker["id"])],
		guardian_id,
	):
		failures.append("computer units could explicitly target Shenlong before ten minutes")
	if simulation._nearest_enemy(nearby_attacker, 4.0, true) == guardian_id:
		failures.append("computer units automatically acquired Shenlong before ten minutes")
	if simulation._issue_ai_shenlong_order(RtsSimulation.TEAM_ENEMY, army):
		failures.append("computer strategy pursued Shenlong before ten minutes")

	var pathfinder := army.back() as Dictionary
	pathfinder["position"] = Vector2(MapCatalog.SHENLONG_EGG_CELL + Vector2i(-16, 0))
	pathfinder["cell"] = Vector2i((pathfinder["position"] as Vector2).round())
	simulation._set_path(pathfinder, MapCatalog.SHENLONG_EGG_CELL + Vector2i(16, 0))
	var avoidance_path := pathfinder.get("path", []) as Array
	if avoidance_path.is_empty():
		failures.append("computer Shenlong avoidance could not find an alternate central route")
	for raw_point in avoidance_path:
		if (
			(raw_point as Vector2).distance_to(Vector2(MapCatalog.SHENLONG_EGG_CELL))
			<= RtsSimulation.AI_SHENLONG_AVOID_RADIUS
		):
			failures.append("computer path entered Shenlong's avoidance zone before ten minutes")
			break

	simulation.elapsed_time = RtsSimulation.AI_SHENLONG_UNLOCK_TIME_SECONDS
	if not simulation.command_attack(
		RtsSimulation.TEAM_ENEMY,
		[int(nearby_attacker["id"])],
		guardian_id,
	):
		failures.append("computer units could not target Shenlong at the ten-minute mark")
	if not simulation._issue_ai_shenlong_order(RtsSimulation.TEAM_ENEMY, army):
		failures.append("computer strategy did not unlock Shenlong at the ten-minute mark")

	var player_attacker_id := simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"vanguard",
		MapCatalog.SHENLONG_CELL + Vector2i(-2, 0),
	)
	simulation.elapsed_time = 0.0
	simulation._refresh_visibility()
	if not simulation.command_attack(
		RtsSimulation.TEAM_PLAYER,
		[player_attacker_id],
		guardian_id,
	):
		failures.append("the computer-only Shenlong lock prevented a player attack")


func _test_ai_skill_test_invasion(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var invasion_ids: Array[int] = []
	for offset in range(6):
		invasion_ids.append(simulation._spawn_unit(
			RtsSimulation.TEAM_ENEMY,
			&"vanguard",
			MapCatalog.ENEMY_STRONGHOLD + Vector2i(-2 - offset, 2),
		))
	simulation.command_move(
		RtsSimulation.TEAM_ENEMY,
		[invasion_ids[0], invasion_ids[1]],
		MapCatalog.ENEMY_STRONGHOLD + Vector2i(-8, 4),
	)
	simulation._ai_strategy_timer = 999.0
	simulation.elapsed_time = RtsSimulation.AI_SKILL_TEST_TIME_SECONDS - 0.01
	simulation._advance_ai(RtsSimulation.TICK_SECONDS)
	if simulation._ai_skill_test_launched:
		failures.append("computer launched the skill-test invasion before the one-hour mark")
	simulation.elapsed_time = RtsSimulation.AI_SKILL_TEST_TIME_SECONDS
	simulation._advance_ai(RtsSimulation.TICK_SECONDS)
	if not simulation._ai_skill_test_launched:
		failures.append("computer did not launch the skill-test invasion at the one-hour mark")
	for unit_id in invasion_ids:
		if simulation.entity(unit_id).get("order") not in [&"attack", &"attack_move"]:
			failures.append("skill-test invasion did not commit the entire reserve army")
			break
	simulation.command_stop(RtsSimulation.TEAM_ENEMY, [invasion_ids[0]])
	simulation._advance_ai(RtsSimulation.TICK_SECONDS)
	if simulation.entity(invasion_ids[0]).get("order") != &"idle":
		failures.append("skill-test invasion was issued more than once")


func _test_faction_food_traditions(failures: Array[String]) -> void:
	var expectations := {
		&"celestial": {"farm": true, "hunt": false},
		&"demon": {"farm": false, "hunt": true},
		&"beast": {"farm": false, "hunt": true},
		&"human": {"farm": true, "hunt": true},
	}
	for faction in expectations:
		var simulation := RtsSimulation.new()
		simulation.setup(faction)
		var expected := expectations[faction] as Dictionary
		var farm_available := simulation.is_kind_available(RtsSimulation.TEAM_PLAYER, &"rice_farm")
		var lodge_available := simulation.is_kind_available(RtsSimulation.TEAM_PLAYER, &"hunters_lodge")
		var hunter_available := simulation.is_kind_available(RtsSimulation.TEAM_PLAYER, &"hunter")
		if farm_available != bool(expected["farm"]):
			failures.append("%s farming availability is incorrect" % String(faction).capitalize())
		if lodge_available != bool(expected["hunt"]) or hunter_available != bool(expected["hunt"]):
			failures.append("%s hunting availability is incorrect" % String(faction).capitalize())
		var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
		simulation.players[RtsSimulation.TEAM_PLAYER]["jade"] = 1000
		simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"] = 1000
		simulation.players[RtsSimulation.TEAM_PLAYER]["essence"] = 1000
		var blocked_kind := &"hunters_lodge" if bool(expected["farm"]) and not bool(expected["hunt"]) else &"rice_farm"
		if bool(expected["farm"]) == bool(expected["hunt"]):
			continue
		if simulation.command_build(RtsSimulation.TEAM_PLAYER, worker_id, blocked_kind, MapCatalog.PLAYER_BUILD_TEST_SITE):
			failures.append("%s constructed forbidden %s infrastructure" % [faction, blocked_kind])

	var human_simulation := RtsSimulation.new()
	human_simulation.setup(&"human")
	human_simulation.players[RtsSimulation.TEAM_PLAYER]["jade"] = 1000
	human_simulation.players[RtsSimulation.TEAM_PLAYER]["food"] = 1000
	var lodge_site := human_simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		&"hunters_lodge",
		MapCatalog.PLAYER_STRONGHOLD,
	)
	var lodge_id := human_simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"hunters_lodge",
		lodge_site,
		true,
	)
	human_simulation._rebuild_pathfinding()
	if not human_simulation.command_train(RtsSimulation.TEAM_PLAYER, lodge_id, &"hunter"):
		failures.append("Human Hunter's Lodge rejected Hunter production")
	else:
		_advance(human_simulation, 7.0)
		if human_simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"hunter"]).is_empty():
			failures.append("Hunter's Lodge did not finish training a Hunter")

	var celestial_simulation := RtsSimulation.new()
	celestial_simulation.setup(&"celestial")
	var forbidden_lodge_id := celestial_simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"hunters_lodge",
		MapCatalog.PLAYER_BUILD_TEST_SITE,
		true,
	)
	if celestial_simulation.command_train(RtsSimulation.TEAM_PLAYER, forbidden_lodge_id, &"hunter"):
		failures.append("Celestial Court trained a forbidden Hunter")


func _test_wildlife_hunting(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	if simulation.wildlife_ids().size() != 68:
		failures.append("simulation did not spawn all 68 wildlife members")
	for kind in FactionCatalog.WILDLIFE_KINDS:
		if simulation.wildlife_ids(kind).is_empty():
			failures.append("simulation did not spawn %s wildlife" % kind)

	var deer := simulation.entity(simulation.wildlife_ids(&"deer")[0])
	var deer_start := deer["position"] as Vector2
	deer["wander_timer"] = 0.0
	for _step in range(90):
		simulation._advance_wildlife(deer, RtsSimulation.TICK_SECONDS)
	if (deer["position"] as Vector2).distance_to(deer_start) <= 0.1:
		failures.append("idle deer did not wander")
	if (deer["position"] as Vector2).distance_to(deer["herd_origin"] as Vector2) > float(deer["herd_radius"]) + 0.01:
		failures.append("wandering deer left its herd territory")

	var hunter_cell := Vector2i((deer["position"] as Vector2).round()) + Vector2i(-1, 0)
	var hunter_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"hunter", hunter_cell)
	var hunter := simulation.entity(hunter_id)
	var deer_hp_before := float(deer["hp"])
	simulation._apply_attack(hunter, deer)
	if not is_equal_approx(float(deer["hp"]), deer_hp_before - 24.0):
		failures.append("Hunter did not deal triple damage to wildlife")
	if deer.get("order") != &"flee":
		failures.append("passive wildlife did not flee after a nonlethal hit")

	var vanguard_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", hunter_cell)
	if simulation.are_hostile(simulation.entity(vanguard_id), deer):
		failures.append("a non-Hunter unit was allowed to target wildlife")

	for aggressive_kind in [&"boar", &"bear"]:
		var aggressive := simulation.entity(simulation.wildlife_ids(aggressive_kind)[0])
		hunter["position"] = aggressive["position"] as Vector2 + Vector2(-0.5, 0.0)
		hunter["cell"] = Vector2i((hunter["position"] as Vector2).round())
		simulation._apply_attack(hunter, aggressive)
		if aggressive.get("order") != &"attack" or int(aggressive.get("target_id", -1)) != hunter_id:
			failures.append("%s did not retaliate against its Hunter" % String(aggressive_kind).capitalize())
		var hunter_hp_before := float(hunter["hp"])
		aggressive["attack_cooldown"] = 0.0
		simulation._advance_wildlife(aggressive, RtsSimulation.TICK_SECONDS)
		if float(hunter["hp"]) >= hunter_hp_before:
			failures.append("%s retaliation did not damage the Hunter" % String(aggressive_kind).capitalize())

	var chicken := simulation.entity(simulation.wildlife_ids(&"chicken")[0])
	chicken["hp"] = 1.0
	var food_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"])
	simulation._apply_attack(hunter, chicken)
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"]) != food_before + int(chicken["food_bounty"]):
		failures.append("wildlife kill did not grant its exact Food bounty")

	var celestial_simulation := RtsSimulation.new()
	celestial_simulation.setup(&"celestial")
	var celestial_deer := celestial_simulation.entity(celestial_simulation.wildlife_ids(&"deer")[0])
	var forbidden_hunter_id := celestial_simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"hunter",
		celestial_deer["cell"] as Vector2i,
	)
	if celestial_simulation.are_hostile(celestial_simulation.entity(forbidden_hunter_id), celestial_deer):
		failures.append("Celestial Court could hunt through a directly spawned Hunter")


func _test_idle_hunter_wandering(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var hunter_id := simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"hunter",
		MapCatalog.PLAYER_WORKERS[0],
	)
	var hunter := simulation.entity(hunter_id)
	var commanded_destination := MapCatalog.PLAYER_WORKERS[0] + Vector2i(1, 0)
	simulation.command_move(RtsSimulation.TEAM_PLAYER, [hunter_id], commanded_destination)
	hunter["wander_timer"] = 0.0
	simulation._advance_hunter_wander(hunter, RtsSimulation.TICK_SECONDS)
	if hunter.get("order") != &"move":
		failures.append("Hunter wandering overrode an explicit move order")
		return
	simulation.command_stop(RtsSimulation.TEAM_PLAYER, [hunter_id])
	hunter["wander_timer"] = 0.0
	simulation.advance(RtsSimulation.TICK_SECONDS)
	if hunter.get("order") not in [&"seek_hunting_pasture", &"attack"]:
		failures.append("idle Hunter did not begin scouting or hunting toward wildlife territory")
		return
	if hunter.get("order") == &"seek_hunting_pasture" and (hunter.get("path", []) as Array).is_empty():
		failures.append("idle Hunter began searching without a wildlife pasture destination")
		return
	var food_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"])
	for _step in range(int(20.0 / RtsSimulation.TICK_SECONDS)):
		simulation.advance(RtsSimulation.TICK_SECONDS)
		if int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"]) > food_before:
			return
	failures.append("searching Hunter did not find and hunt prey")


func _test_hunter_hunting_pasture_priority(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var team := RtsSimulation.TEAM_PLAYER
	var stronghold := simulation.entity(simulation.primary_structure_id(team, &"stronghold"))
	var home := simulation._entity_center(stronghold)
	var local_herd_ids: Dictionary = {}
	for wildlife_id in simulation.wildlife_ids():
		var wildlife := simulation.entity(wildlife_id)
		if (wildlife["herd_origin"] as Vector2).distance_to(home) <= RtsSimulation.HUNTER_HOME_GAME_RADIUS:
			local_herd_ids[int(wildlife["herd_id"])] = true
	if local_herd_ids.is_empty():
		failures.append("the player Stronghold has no wildlife pasture inside the Hunter home radius")
		return

	var hunter_id := simulation._spawn_unit(team, &"hunter", MapCatalog.PLAYER_WORKERS[0])
	var hunter := simulation.entity(hunter_id)
	hunter["wander_timer"] = 0.0
	simulation._advance_hunter_wander(hunter, RtsSimulation.TICK_SECONDS)
	var first_pasture_id := int(hunter.get("hunting_pasture_id", -1))
	if not local_herd_ids.has(first_pasture_id):
		failures.append("Hunter left the Stronghold vicinity before choosing its living local game")
		return
	if hunter.get("order") != &"seek_hunting_pasture":
		failures.append("Hunter did not receive a purposeful local hunting-pasture search order")
	var first_pasture_center := Vector2i(-1, -1)
	for wildlife_id in simulation.wildlife_ids():
		var wildlife := simulation.entity(wildlife_id)
		if int(wildlife.get("herd_id", -1)) == first_pasture_id:
			first_pasture_center = Vector2i((wildlife["herd_origin"] as Vector2).round())
			break
	simulation._explored_cells_by_team[team][first_pasture_center] = true
	hunter["position"] = Vector2(MapCatalog.SHENLONG_CELL)
	hunter["cell"] = MapCatalog.SHENLONG_CELL
	hunter["order"] = &"idle"
	hunter["path"] = []
	hunter["wander_timer"] = 0.0
	simulation._advance_hunter_wander(hunter, RtsSimulation.TICK_SECONDS)
	if int(hunter.get("hunting_pasture_id", -1)) != first_pasture_id:
		failures.append("Hunter abandoned living local game after its pasture was explored")

	for wildlife_id in simulation.wildlife_ids():
		var wildlife := simulation.entity(wildlife_id)
		if local_herd_ids.has(int(wildlife.get("herd_id", -1))):
			wildlife["alive"] = false
	hunter["order"] = &"idle"
	hunter["path"] = []
	hunter["wander_timer"] = 0.0
	simulation._advance_hunter_wander(hunter, RtsSimulation.TICK_SECONDS)
	var new_pasture_id := int(hunter.get("hunting_pasture_id", -1))
	if new_pasture_id < 0 or local_herd_ids.has(new_pasture_id):
		failures.append("Hunter did not seek a new pasture after exhausting local game")
		return
	var new_pasture_has_game := false
	for wildlife_id in simulation.wildlife_ids():
		if int(simulation.entity(wildlife_id).get("herd_id", -1)) == new_pasture_id:
			new_pasture_has_game = true
			break
	if not new_pasture_has_game:
		failures.append("Hunter selected a depleted location instead of a living hunting pasture")
	hunter["order"] = &"idle"
	hunter["path"] = []
	hunter["wander_timer"] = 0.0
	simulation._advance_hunter_wander(hunter, RtsSimulation.TICK_SECONDS)
	if int(hunter.get("hunting_pasture_id", -1)) != new_pasture_id:
		failures.append("Hunter abandoned its current living pasture to roam elsewhere")

	for wildlife_id in simulation.wildlife_ids():
		simulation.entity(wildlife_id)["alive"] = false
	hunter["order"] = &"idle"
	hunter["path"] = []
	hunter["wander_timer"] = 0.0
	simulation._advance_hunter_wander(hunter, RtsSimulation.TICK_SECONDS)
	if hunter.get("order") != &"idle" or int(hunter.get("hunting_pasture_id", -1)) >= 0:
		failures.append("Hunter wandered after every living hunting pasture was depleted")


func _test_hunter_avoids_unordered_combat(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	simulation.entities.clear()
	for player in simulation.players:
		player["population"] = 0
	simulation._next_entity_id = 1
	simulation._rebuild_pathfinding()

	var hunter_id := simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"hunter",
		Vector2i(24, 40),
	)
	var enemy_id := simulation._spawn_unit(
		RtsSimulation.TEAM_ENEMY,
		&"vanguard",
		Vector2i(28, 40),
	)
	var hunter := simulation.entity(hunter_id)
	var enemy := simulation.entity(enemy_id)
	hunter["wander_timer"] = 999.0
	simulation._refresh_visibility()
	var hunter_start := hunter["position"] as Vector2
	var away_from_threat := hunter_start.direction_to(enemy["position"] as Vector2) * -1.0
	var enemy_hp_before := float(enemy["hp"])
	_advance(simulation, 0.5)
	if hunter.get("order") == &"attack" or int(hunter.get("target_id", -1)) == enemy_id:
		failures.append("idle Hunter automatically attacked an enemy unit")
	if float(enemy["hp"]) < enemy_hp_before:
		failures.append("idle Hunter damaged an enemy unit without a combat order")
	if ((hunter["position"] as Vector2) - hunter_start).dot(away_from_threat) <= 0.0:
		failures.append("idle Hunter did not move away from a nearby enemy unit")

	hunter["position"] = Vector2(24, 40)
	hunter["cell"] = Vector2i(24, 40)
	hunter["attack_cooldown"] = 0.0
	simulation.command_stop(RtsSimulation.TEAM_PLAYER, [hunter_id])
	simulation._refresh_visibility()
	enemy_hp_before = float(enemy["hp"])
	if not simulation.command_attack(RtsSimulation.TEAM_PLAYER, [hunter_id], enemy_id):
		failures.append("Hunter rejected an explicit attack order against an enemy unit")
	else:
		simulation.advance(RtsSimulation.TICK_SECONDS)
		if float(enemy["hp"]) >= enemy_hp_before:
			failures.append("Hunter did not follow an explicit attack order against an enemy unit")

	enemy["alive"] = false
	hunter["position"] = Vector2(24, 40)
	hunter["cell"] = Vector2i(24, 40)
	hunter["attack_cooldown"] = 0.0
	simulation.command_stop(RtsSimulation.TEAM_PLAYER, [hunter_id])
	var guardian_id := simulation._spawn_unit(
		RtsSimulation.TEAM_NEUTRAL,
		&"jadeclaw",
		Vector2i(28, 40),
		99,
	)
	var guardian := simulation.entity(guardian_id)
	guardian["wander_timer"] = 999.0
	simulation._refresh_visibility()
	hunter_start = hunter["position"] as Vector2
	away_from_threat = hunter_start.direction_to(guardian["position"] as Vector2) * -1.0
	var guardian_hp_before := float(guardian["hp"])
	_advance(simulation, 0.5)
	if hunter.get("order") == &"attack" or int(hunter.get("target_id", -1)) == guardian_id:
		failures.append("idle Hunter automatically attacked a Yaoguai guardian")
	if float(guardian["hp"]) < guardian_hp_before:
		failures.append("idle Hunter damaged a Yaoguai guardian without a combat order")
	if ((hunter["position"] as Vector2) - hunter_start).dot(away_from_threat) <= 0.0:
		failures.append("idle Hunter did not move away from a nearby Yaoguai guardian")

	hunter["position"] = Vector2(24, 40)
	hunter["cell"] = Vector2i(24, 40)
	hunter["attack_cooldown"] = 0.0
	simulation.command_stop(RtsSimulation.TEAM_PLAYER, [hunter_id])
	simulation._refresh_visibility()
	guardian_hp_before = float(guardian["hp"])
	if not simulation.command_attack(RtsSimulation.TEAM_PLAYER, [hunter_id], guardian_id):
		failures.append("Hunter rejected an explicit attack order against a Yaoguai guardian")
	else:
		simulation.advance(RtsSimulation.TICK_SECONDS)
		if float(guardian["hp"]) >= guardian_hp_before:
			failures.append("Hunter did not follow an explicit attack order against a Yaoguai guardian")


func _test_lifetime_scoring(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var team := RtsSimulation.TEAM_PLAYER
	if simulation.team_score(team) != 0:
		failures.append("starting resources or entities incorrectly awarded score")

	simulation._deposit(team, &"lumber", 20.0)
	simulation._deposit(team, &"essence", 10.0)
	if simulation.team_score(team) != 40:
		failures.append("earned resources did not award their configured score")
	var earned_resources := simulation.lifetime_stats(team).get("resources_earned", {}) as Dictionary
	if int(earned_resources.get("lumber", 0)) != 20 or int(earned_resources.get("essence", 0)) != 10:
		failures.append("lifetime resource totals did not preserve gathered amounts")

	var stronghold_id := simulation.primary_structure_id(team, &"stronghold")
	if not simulation.command_train(team, stronghold_id, &"worker"):
		failures.append("score test could not queue its cancellation Worker")
	else:
		if simulation.team_score(team) != 40:
			failures.append("queued production awarded score before completion")
		simulation.command_cancel_training(team, stronghold_id)
		if simulation.team_score(team) != 40:
			failures.append("cancelled production retained unearned score")
	if not simulation.command_train(team, stronghold_id, &"worker"):
		failures.append("score test could not queue its completed Worker")
	else:
		simulation._advance_production(7.0)
		if simulation.team_score(team) != 40 + int(RtsSimulation.SCORE_UNIT_POINTS[&"worker"]):
			failures.append("completed unit production did not award score")
	if not (
		int(RtsSimulation.SCORE_UNIT_POINTS[&"jadeclaw"])
		> int(RtsSimulation.SCORE_UNIT_POINTS[&"mystic"])
		and int(RtsSimulation.SCORE_UNIT_POINTS[&"mystic"])
		> int(RtsSimulation.SCORE_UNIT_POINTS[&"vanguard"])
		and int(RtsSimulation.SCORE_UNIT_POINTS[&"vanguard"])
		> int(RtsSimulation.SCORE_UNIT_POINTS[&"worker"])
	):
		failures.append("unit score values do not increase with unit strength and cost")

	var worker_id := simulation.team_entity_ids(team, [&"worker"])[0]
	var worker := simulation.entity(worker_id)
	var camp_id := simulation._spawn_structure(team, &"war_camp", MapCatalog.PLAYER_BUILD_TEST_SITE, false)
	var camp := simulation.entity(camp_id)
	camp["complete"] = 0.999
	camp["hp"] = float(camp["max_hp"]) * 0.999
	var worker_cell := MapCatalog.PLAYER_BUILD_TEST_SITE + Vector2i(-1, 0)
	worker["position"] = Vector2(worker_cell)
	worker["cell"] = worker_cell
	worker["path"] = []
	var before_building := simulation.team_score(team)
	if not simulation.command_construct(team, [worker_id], camp_id):
		failures.append("score test could not resume its nearly complete building")
	else:
		simulation._advance_construction(0.1)
		if simulation.team_score(team) != before_building + int(RtsSimulation.SCORE_BUILDING_COMPLETED_POINTS[&"war_camp"]):
			failures.append("completed building did not award score")

	camp["hp"] = float(camp["max_hp"]) - RtsSimulation.REPAIR_AMOUNT
	worker["position"] = Vector2(worker_cell)
	worker["cell"] = worker_cell
	worker["path"] = []
	var before_repair := simulation.team_score(team)
	if not simulation.command_repair(team, [worker_id], camp_id):
		failures.append("score test could not issue a valid repair")
	else:
		simulation._advance_repair(worker, RtsSimulation.REPAIR_CYCLE)
		if simulation.team_score(team) != before_repair + roundi(RtsSimulation.REPAIR_AMOUNT):
			failures.append("repaired hit points did not award score")

	var attacker_id := simulation._spawn_unit(
		team,
		&"vanguard",
		MapCatalog.ENEMY_STRONGHOLD + Vector2i(-2, 0),
	)
	var attacker := simulation.entity(attacker_id)
	var enemy_mystic_id := simulation._spawn_unit(
		RtsSimulation.TEAM_ENEMY,
		&"mystic",
		MapCatalog.ENEMY_STRONGHOLD + Vector2i(-1, 0),
	)
	var enemy_mystic := simulation.entity(enemy_mystic_id)
	enemy_mystic["hp"] = 1.0
	var before_defeat := simulation.team_score(team)
	simulation._apply_attack(attacker, enemy_mystic)
	if simulation.team_score(team) != before_defeat + int(RtsSimulation.SCORE_UNIT_POINTS[&"mystic"]):
		failures.append("defeating a strong enemy unit did not award its score value")

	var enemy_camp_id := simulation._spawn_structure(
		RtsSimulation.TEAM_ENEMY,
		&"war_camp",
		MapCatalog.ENEMY_STRONGHOLD + Vector2i(-3, 0),
		true,
	)
	var enemy_camp := simulation.entity(enemy_camp_id)
	enemy_camp["hp"] = 1.0
	var before_destruction := simulation.team_score(team)
	simulation._apply_attack(attacker, enemy_camp)
	if simulation.team_score(team) != before_destruction + int(RtsSimulation.SCORE_BUILDING_DESTROYED_POINTS[&"war_camp"]):
		failures.append("destroying an enemy building did not award score")

	var cave := simulation.entity(simulation.cave_ids()[0])
	var guardian := simulation.entity(int((cave["guardian_ids"] as Array)[0]))
	guardian["hp"] = 1.0
	var before_guardian := simulation.team_score(team)
	simulation._apply_attack(attacker, guardian)
	var guardian_resource_points := 0
	for resource_kind in RtsSimulation.MONSTER_BOUNTY:
		guardian_resource_points += (
			int(RtsSimulation.MONSTER_BOUNTY[resource_kind])
			* int(RtsSimulation.SCORE_RESOURCE_POINTS[StringName(resource_kind)])
		)
	var expected_guardian_points := (
		int(RtsSimulation.SCORE_UNIT_POINTS[&"jadeclaw"])
		+ guardian_resource_points
	)
	if simulation.team_score(team) != before_guardian + expected_guardian_points:
		failures.append("defeating a neutral guardian did not award defeat and bounty score")
	var before_capture := simulation.team_score(team)
	simulation._complete_cave_capture(cave, team)
	if simulation.team_score(team) != before_capture + RtsSimulation.SCORE_CAVE_CAPTURED_POINTS:
		failures.append("capturing a Yaoguai Den did not award score")
	simulation._complete_cave_capture(cave, RtsSimulation.TEAM_ENEMY)
	simulation._complete_cave_capture(cave, team)
	if simulation.team_score(team) != before_capture + RtsSimulation.SCORE_CAVE_CAPTURED_POINTS * 2:
		failures.append("recapturing a Yaoguai Den did not count as a lifetime capture")

	var breakdown := simulation.score_breakdown(team)
	var breakdown_total := 0
	for points in breakdown.values():
		breakdown_total += int(points)
	if breakdown_total != simulation.team_score(team):
		failures.append("score total diverged from its authoritative category breakdown")
	var stats := simulation.lifetime_stats(team)
	if int((stats.get("units_created", {}) as Dictionary).get("worker", 0)) != 1:
		failures.append("lifetime unit creation count included starting or cancelled units")
	if int((stats.get("buildings_completed", {}) as Dictionary).get("war_camp", 0)) != 1:
		failures.append("lifetime building completion count was not recorded")
	if int((stats.get("enemies_defeated", {}) as Dictionary).get("mystic", 0)) != 1:
		failures.append("lifetime enemy defeat count was not recorded")
	if int((stats.get("enemies_defeated", {}) as Dictionary).get("jadeclaw", 0)) != 1:
		failures.append("lifetime enemy defeat count omitted a neutral guardian")
	if int((stats.get("buildings_destroyed", {}) as Dictionary).get("war_camp", 0)) != 1:
		failures.append("lifetime building destruction count was not recorded")
	if int(stats.get("caves_captured", 0)) != 2:
		failures.append("lifetime Yaoguai Den capture count omitted a recapture")
	if not is_equal_approx(float(stats.get("hit_points_repaired", 0.0)), RtsSimulation.REPAIR_AMOUNT):
		failures.append("lifetime repair total did not record actual restored health")


func _test_resignation_outcome(failures: Array[String]) -> void:
	var player_simulation := RtsSimulation.new()
	player_simulation.setup(&"human", false)
	var player_results: Array[StringName] = []
	player_simulation.match_ended.connect(
		func(result: StringName) -> void: player_results.append(result)
	)
	if player_simulation.command_resign(RtsSimulation.TEAM_NEUTRAL):
		failures.append("neutral team was allowed to resign a match")
	if not player_simulation.outcome.is_empty():
		failures.append("invalid resignation changed the match outcome")
	if not player_simulation.command_resign(RtsSimulation.TEAM_PLAYER):
		failures.append("player resignation was rejected")
	if player_simulation.outcome != &"defeat" or player_results != [&"defeat"]:
		failures.append("player resignation did not emit exactly one defeat outcome")
	if player_simulation.command_resign(RtsSimulation.TEAM_PLAYER):
		failures.append("completed match accepted a second resignation")

	var enemy_simulation := RtsSimulation.new()
	enemy_simulation.setup(&"human", false)
	if not enemy_simulation.command_resign(RtsSimulation.TEAM_ENEMY):
		failures.append("enemy resignation was rejected")
	if not enemy_simulation.outcome.is_empty() or enemy_simulation.living_rival_count() != 2:
		failures.append("one rival resignation ended the four-player match early")
	enemy_simulation.command_resign(RtsSimulation.TEAM_RIVAL_TWO)
	if not enemy_simulation.outcome.is_empty():
		failures.append("two rival resignations ended the four-player match early")
	enemy_simulation.command_resign(RtsSimulation.TEAM_RIVAL_THREE)
	if enemy_simulation.outcome != &"victory":
		failures.append("the final rival resignation did not award victory")


func _test_four_player_shenlong_objective(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	if simulation.players.size() != RtsSimulation.TEAM_COUNT:
		failures.append("simulation did not create four player states")
	var factions: Dictionary = {}
	for team in range(simulation.players.size()):
		factions[simulation.players[team]["faction"]] = true
		if simulation.primary_structure_id(team, &"stronghold") < 0:
			failures.append("team %d did not receive a Stronghold" % team)
		if simulation.team_entity_ids(team, [&"worker"]).size() != 3:
			failures.append("team %d did not receive three Workers" % team)
	if factions.size() != RtsSimulation.TEAM_COUNT:
		failures.append("the four teams did not receive unique factions")

	var egg := simulation.shenlong_egg()
	var guardian := simulation.shenlong_guardian()
	if egg.is_empty() or guardian.is_empty() or bool(egg.get("claimable", true)):
		failures.append("the guarded Dragon Egg did not spawn locked at the center")
		return
	var attacker_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", MapCatalog.SHENLONG_CELL + Vector2i(1, 0))
	simulation._kill(guardian, simulation.entity(attacker_id))
	if not bool(egg.get("claimable", false)) or not simulation.shenlong_guardian().is_empty():
		failures.append("defeating guardian Shenlong did not unlock exactly one egg")

	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	var worker := simulation.entity(worker_id)
	worker["position"] = Vector2(MapCatalog.SHENLONG_EGG_CELL + Vector2i(0, 1))
	worker["cell"] = MapCatalog.SHENLONG_EGG_CELL + Vector2i(0, 1)
	simulation.command_stop(RtsSimulation.TEAM_PLAYER, [worker_id])
	if not simulation.command_move(
		RtsSimulation.TEAM_PLAYER,
		[worker_id],
		egg["cell"] as Vector2i,
	):
		failures.append("an empty-handed Worker could not move to the unlocked egg")
	else:
		if worker.get("order") != &"claim_egg" or int(worker.get("target_id", -1)) != int(egg["id"]):
			failures.append("moving a Worker to the unlocked egg did not create a claim order")
		simulation.advance(RtsSimulation.TICK_SECONDS * 2.0)
		if not bool(worker.get("carrying_egg", false)) or worker.get("order") != &"return_egg":
			failures.append("moving to the egg did not claim it and create a physical return order")
		var rival_attacker_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", worker["cell"] as Vector2i)
		simulation._kill(worker, simulation.entity(rival_attacker_id))
		if not bool(egg.get("claimable", false)) or int(egg.get("carried_by", -1)) >= 0:
			failures.append("killing the carrier did not drop and unlock the egg")

	var replacement_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"worker", egg["cell"] as Vector2i + Vector2i(0, 1))
	var replacement := simulation.entity(replacement_id)
	if not simulation.command_claim_egg(RtsSimulation.TEAM_PLAYER, [replacement_id], int(egg["id"])):
		failures.append("a dropped egg could not be reclaimed")
	else:
		simulation.advance(RtsSimulation.TICK_SECONDS * 2.0)
		var stronghold := simulation.entity(simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold"))
		replacement["position"] = Vector2(stronghold["cell"] as Vector2i + Vector2i(2, 1))
		replacement["cell"] = Vector2i((replacement["position"] as Vector2).round())
		simulation.advance(RtsSimulation.TICK_SECONDS * 2.0)
		if bool(egg.get("alive", true)) or bool(replacement.get("carrying_egg", true)):
			failures.append("delivering the egg did not consume the carried objective")
		if simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"shenlong"]).size() != 1:
			failures.append("delivering the egg did not hatch exactly one allied Shenlong")

	var victory_simulation := RtsSimulation.new()
	victory_simulation.setup(&"human", false)
	var victor_id := victory_simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", MapCatalog.SHENLONG_EGG_CELL)
	var victor := victory_simulation.entity(victor_id)
	for team in [RtsSimulation.TEAM_ENEMY, RtsSimulation.TEAM_RIVAL_TWO]:
		victory_simulation._kill(victory_simulation.entity(victory_simulation.primary_structure_id(team, &"stronghold")), victor)
		if not victory_simulation.outcome.is_empty():
			failures.append("destroying fewer than three rival Strongholds ended the match")
	victory_simulation._kill(victory_simulation.entity(victory_simulation.primary_structure_id(RtsSimulation.TEAM_RIVAL_THREE, &"stronghold")), victor)
	if victory_simulation.outcome != &"victory":
		failures.append("destroying all three rival Strongholds did not award victory")

	var defeat_simulation := RtsSimulation.new()
	defeat_simulation.setup(&"human", false)
	var defeat_attacker_id := defeat_simulation._spawn_unit(
		RtsSimulation.TEAM_ENEMY,
		&"vanguard",
		MapCatalog.PLAYER_STRONGHOLD + Vector2i(2, 0),
	)
	defeat_simulation._kill(
		defeat_simulation.entity(defeat_simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")),
		defeat_simulation.entity(defeat_attacker_id),
	)
	if defeat_simulation.outcome != &"defeat":
		failures.append("destroying the human Stronghold did not produce defeat")

	var elimination_simulation := RtsSimulation.new()
	elimination_simulation.setup(&"human", false)
	var eliminated_unit_id := elimination_simulation._spawn_unit(
		RtsSimulation.TEAM_ENEMY,
		&"vanguard",
		MapCatalog.ENEMY_STRONGHOLD + Vector2i(-1, 0),
	)
	var elimination_victor_id := elimination_simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"vanguard",
		MapCatalog.ENEMY_STRONGHOLD + Vector2i(-2, 0),
	)
	var eliminated_structure_id := elimination_simulation._spawn_structure(
		RtsSimulation.TEAM_ENEMY,
		&"war_camp",
		MapCatalog.ENEMY_STRONGHOLD + Vector2i(-3, 0),
		true,
	)
	var eliminated_cave := elimination_simulation.entity(elimination_simulation.cave_ids()[0])
	elimination_simulation._complete_cave_capture(eliminated_cave, RtsSimulation.TEAM_ENEMY)
	var eliminated_unit := elimination_simulation.entity(eliminated_unit_id)
	eliminated_unit["order"] = &"attack"
	eliminated_unit["target_id"] = elimination_victor_id
	elimination_simulation._kill(
		elimination_simulation.entity(elimination_simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"stronghold")),
		elimination_simulation.entity(elimination_victor_id),
	)
	if bool(eliminated_unit.get("alive", true)) or eliminated_unit.get("order") != &"idle":
		failures.append("an eliminated rival retained a living unit")
	if bool(elimination_simulation.entity(eliminated_structure_id).get("alive", true)):
		failures.append("an eliminated rival retained a living building")
	if not elimination_simulation.team_entity_ids(RtsSimulation.TEAM_ENEMY).is_empty():
		failures.append("an eliminated rival retained owned entities")
	if int(elimination_simulation.players[RtsSimulation.TEAM_ENEMY]["population"]) != 0:
		failures.append("an eliminated rival retained population after its units were culled")
	if (
		not bool(eliminated_cave.get("alive", false))
		or int(eliminated_cave.get("team", RtsSimulation.TEAM_ENEMY)) != RtsSimulation.TEAM_NEUTRAL
	):
		failures.append("an eliminated rival's captured Yaoguai Den did not return to neutral control")


func _test_four_faction_free_for_all(failures: Array[String]) -> void:
	var expected_factions: Dictionary = {}
	for faction in FactionCatalog.ORDER:
		expected_factions[faction] = true
	for chosen_faction in FactionCatalog.ORDER:
		var simulation := RtsSimulation.new()
		simulation.setup(chosen_faction, false)
		if simulation.players.size() != RtsSimulation.TEAM_COUNT:
			failures.append("%s match did not create exactly four players" % chosen_faction)
			continue
		var match_factions: Dictionary = {}
		for team in range(RtsSimulation.TEAM_COUNT):
			var player := simulation.players[team]
			match_factions[player["faction"]] = true
			if bool(player.get("is_ai", false)) != (team != RtsSimulation.TEAM_PLAYER):
				failures.append("%s match assigned the wrong controller to team %d" % [chosen_faction, team])
			var stronghold := simulation.entity(simulation.primary_structure_id(team, &"stronghold"))
			var expected_start := MapCatalog.start_definition(team)
			if stronghold.is_empty() or stronghold.get("cell") != expected_start.get("stronghold"):
				failures.append("%s match did not place team %d on its own island" % [chosen_faction, team])
			var expected_worker_cells: Dictionary = {}
			for raw_cell in expected_start.get("workers", []) as Array:
				expected_worker_cells[raw_cell as Vector2i] = true
			var actual_worker_cells: Dictionary = {}
			for worker_id in simulation.team_entity_ids(team, [&"worker"]):
				actual_worker_cells[simulation.entity(worker_id)["cell"] as Vector2i] = true
			if actual_worker_cells != expected_worker_cells:
				failures.append("%s match did not place team %d Workers on its island" % [chosen_faction, team])
		if match_factions != expected_factions:
			failures.append("%s match did not feature all four factions exactly once" % chosen_faction)
		if simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] != chosen_faction:
			failures.append("%s selection was not preserved for the human player" % chosen_faction)
		for first_team in range(RtsSimulation.TEAM_COUNT):
			for second_team in range(first_team + 1, RtsSimulation.TEAM_COUNT):
				var first_hold := simulation.entity(simulation.primary_structure_id(first_team, &"stronghold"))
				var second_hold := simulation.entity(simulation.primary_structure_id(second_team, &"stronghold"))
				if (
					not simulation.are_hostile(first_hold, second_hold)
					or not simulation.are_hostile(second_hold, first_hold)
				):
					failures.append(
						"%s match created an alliance between teams %d and %d"
						% [chosen_faction, first_team, second_team]
					)


func _run() -> void:
	var failures: Array[String] = []
	_test_stronghold_dropoff(failures)
	_test_manual_deposit_requires_range(failures)
	_test_cargo_reassignment_preserves_kind(failures)
	_test_attack_move_resumes_destination(failures)
	_test_diagonal_pathfinding(failures)
	_test_large_formations_and_separation(failures)
	_test_hostile_worker_separation(failures)
	_test_units_pass_through_harmless_wildlife(failures)
	_test_units_pass_through_friendly_structures(failures)
	_test_unit_food_costs(failures)
	_test_stronghold_population_upgrades(failures)
	_test_targeted_production_cancellation(failures)
	_test_free_worker_recovery(failures)
	_test_food_building(&"rice_farm", failures)
	_test_food_building(&"hunters_lodge", failures)
	_test_farm_worker_assignment(failures)
	_test_food_strategy_balance(failures)
	_test_ai_food_economy(failures)
	_test_ai_base_assault_waves(failures)
	_test_ai_avoids_shenlong_until_ten_minutes(failures)
	_test_ai_skill_test_invasion(failures)
	_test_faction_food_traditions(failures)
	_test_wildlife_hunting(failures)
	_test_idle_hunter_wandering(failures)
	_test_hunter_hunting_pasture_priority(failures)
	_test_hunter_avoids_unordered_combat(failures)
	_test_lifetime_scoring(failures)
	_test_resignation_outcome(failures)
	_test_four_faction_free_for_all(failures)
	_test_four_player_shenlong_objective(failures)
	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) != 30:
		failures.append("unexpected starting Lumber amount")
	var human_camp_stats := FactionCatalog.stats(&"war_camp", &"human")
	if int(human_camp_stats.get("lumber_cost", 0)) != 68:
		failures.append("Human War Camp discount did not apply to Lumber")
	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	if workers.size() != 3:
		failures.append("expected 3 initial workers, got %d" % workers.size())
	else:
		var deposit_worker := simulation.entity(workers[0])
		var player_stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
		var player_stronghold := simulation.entity(player_stronghold_id)
		var adjacent_cell := (player_stronghold["cell"] as Vector2i) + Vector2i(0, -1)
		deposit_worker["position"] = Vector2(adjacent_cell)
		deposit_worker["cell"] = adjacent_cell
		var essence_before_deposit := int(simulation.players[RtsSimulation.TEAM_PLAYER]["essence"])
		deposit_worker["cargo_kind"] = &"essence"
		deposit_worker["cargo_amount"] = 17.0
		var deposited_workers := simulation.command_deposit(RtsSimulation.TEAM_PLAYER, [workers[0]], player_stronghold_id)
		if deposited_workers != 1:
			failures.append("valid Stronghold deposit command was rejected")
		if int(simulation.players[RtsSimulation.TEAM_PLAYER]["essence"]) != essence_before_deposit + 17:
			failures.append("Stronghold deposit command did not immediately bank all cargo")
		if float(deposit_worker.get("cargo_amount", -1.0)) != 0.0 or deposit_worker.get("cargo_kind") != &"":
			failures.append("Stronghold deposit command did not clear worker cargo")

	var cave_ids := simulation.cave_ids()
	if cave_ids.size() != 4:
		failures.append("expected four Yaoguai Dens, got %d" % cave_ids.size())
	else:
		var cave := simulation.entity(cave_ids[0])
		if simulation.cave_guardian_count(cave_ids[0]) != 3:
			failures.append("Yaoguai Den did not spawn three neutral guardians")
		var roaming_guardian := simulation.entity(int((cave["guardian_ids"] as Array)[0]))
		var cave_entrance := cave["entrance"] as Vector2i
		if roaming_guardian["leash_origin"] as Vector2 != Vector2(cave_entrance):
			failures.append("neutral guardian was not anchored to its cave entrance")
		var guardian_start := roaming_guardian["position"] as Vector2
		var guardian_max_distance := guardian_start.distance_to(Vector2(cave_entrance))
		var guardian_moved := false
		roaming_guardian["wander_timer"] = 0.0
		for _step in range(int(8.0 / RtsSimulation.TICK_SECONDS)):
			simulation.advance(RtsSimulation.TICK_SECONDS)
			var guardian_position := roaming_guardian["position"] as Vector2
			guardian_moved = guardian_moved or guardian_position.distance_to(guardian_start) > 0.25
			guardian_max_distance = maxf(
				guardian_max_distance,
				guardian_position.distance_to(Vector2(cave_entrance)),
			)
		if not guardian_moved:
			failures.append("neutral guardian did not wander while idle")
		if guardian_max_distance > RtsSimulation.GUARDIAN_WANDER_RADIUS + 0.01:
			failures.append("neutral guardian wandered too far from its cave entrance")
		if simulation.command_train(RtsSimulation.TEAM_PLAYER, cave_ids[0], &"jadeclaw"):
			failures.append("an uncaptured Yaoguai Den accepted production")
		var hunter_id := simulation._spawn_unit(
			RtsSimulation.TEAM_PLAYER,
			&"vanguard",
			(cave["cell"] as Vector2i) + Vector2i(2, 1),
		)
		var hunter := simulation.entity(hunter_id)
		var bounty_before := {
			"jade": int(simulation.players[RtsSimulation.TEAM_PLAYER]["jade"]),
			"lumber": int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]),
			"essence": int(simulation.players[RtsSimulation.TEAM_PLAYER]["essence"]),
		}
		for raw_guardian_id in cave["guardian_ids"] as Array:
			var guardian := simulation.entity(int(raw_guardian_id))
			guardian["hp"] = 1.0
			simulation._apply_attack(hunter, guardian)
		if simulation.cave_guardian_count(cave_ids[0]) != 0 or not bool(cave.get("capture_unlocked", false)):
			failures.append("clearing the guardian pack did not unlock cave capture")
		for resource_kind in RtsSimulation.MONSTER_BOUNTY:
			var expected := int(bounty_before[resource_kind]) + int(RtsSimulation.MONSTER_BOUNTY[resource_kind]) * 3
			if int(simulation.players[RtsSimulation.TEAM_PLAYER][resource_kind]) != expected:
				failures.append("guardian kills did not grant the expected %s bounty" % resource_kind)
		hunter["position"] = Vector2(cave["cell"] as Vector2i) + Vector2(2.0, 1.0)
		hunter["cell"] = Vector2i((hunter["position"] as Vector2).round())
		simulation.command_stop(RtsSimulation.TEAM_PLAYER, [hunter_id])
		_advance(simulation, RtsSimulation.CAVE_CAPTURE_SECONDS + 1.0)
		if int(cave.get("team", RtsSimulation.TEAM_NEUTRAL)) != RtsSimulation.TEAM_PLAYER:
			failures.append("an uncontested military unit did not capture the cleared Yaoguai Den")
		else:
			var jadeclaws_before := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"jadeclaw"]).size()
			if not simulation.command_train(RtsSimulation.TEAM_PLAYER, cave_ids[0], &"jadeclaw"):
				failures.append("captured Yaoguai Den rejected Jadeclaw production")
			else:
				_advance(simulation, 13.0)
				var player_jadeclaws := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"jadeclaw"])
				if player_jadeclaws.size() <= jadeclaws_before:
					failures.append("captured Yaoguai Den did not produce a player-aligned Jadeclaw")
				else:
					var produced_jadeclaw_id := player_jadeclaws[-1]
					var population_before_recapture_queue := int(simulation.players[RtsSimulation.TEAM_PLAYER]["population"])
					if not simulation.command_train(RtsSimulation.TEAM_PLAYER, cave_ids[0], &"jadeclaw"):
						failures.append("player Den rejected a second Jadeclaw before recapture")
					else:
						for player_unit_id in simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"vanguard", &"mystic", &"jadeclaw"]):
							var player_unit := simulation.entity(player_unit_id)
							player_unit["position"] = Vector2(MapCatalog.PLAYER_WORKERS[0])
							player_unit["cell"] = MapCatalog.PLAYER_WORKERS[0]
							player_unit["order"] = &"idle"
							player_unit["path"] = []
						var rival_capturer_id := simulation._spawn_unit(
							RtsSimulation.TEAM_ENEMY,
							&"vanguard",
							(cave["cell"] as Vector2i) + Vector2i(2, 1),
						)
						simulation.command_stop(RtsSimulation.TEAM_ENEMY, [rival_capturer_id])
						simulation._ai_strategy_timer = 999.0
						_advance(simulation, RtsSimulation.CAVE_CAPTURE_SECONDS + 1.0)
						if int(cave.get("team", RtsSimulation.TEAM_NEUTRAL)) != RtsSimulation.TEAM_ENEMY:
							failures.append("the rival did not recapture an undefended player Yaoguai Den")
						if int(simulation.players[RtsSimulation.TEAM_PLAYER]["population"]) != population_before_recapture_queue:
							failures.append("recapture did not release population reserved by the cancelled queue")
						if int(simulation.entity(produced_jadeclaw_id).get("team", -1)) != RtsSimulation.TEAM_PLAYER:
							failures.append("recapture converted an already-produced Jadeclaw")
	var jade_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["jade"])
	var jade_resource_id := -1
	var jade_resource_distance := INF
	var jade_origin := simulation.entity(workers[0])["position"] as Vector2
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("resource_kind") == &"jade":
			var distance := (entity_state["position"] as Vector2).distance_to(jade_origin)
			if distance < jade_resource_distance:
				jade_resource_distance = distance
				jade_resource_id = int(entity_state["id"])
	if jade_resource_id < 0:
		failures.append("no jade resource spawned")
	else:
		var jade_resource := simulation.entity(jade_resource_id)
		var jade_approach := simulation._nearest_walkable_around(jade_resource["cell"] as Vector2i, 3)
		var jade_worker := simulation.entity(workers[0])
		jade_worker["position"] = Vector2(jade_approach)
		jade_worker["cell"] = jade_approach
		jade_worker["path"] = []
		simulation._refresh_visibility()
		simulation.command_gather(RtsSimulation.TEAM_PLAYER, [workers[0]], jade_resource_id)
		_advance(simulation, 12.0)
		if int(simulation.players[RtsSimulation.TEAM_PLAYER]["jade"]) <= jade_before:
			failures.append("worker did not gather and deposit Jade")

	var lumber_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"])
	var tree_id := -1
	var tree_cell := Vector2i.ZERO
	var tree_distance := INF
	var worker_position := simulation.entity(workers[0])["position"] as Vector2
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("resource_kind") == &"lumber":
			var candidate_cell := entity_state["cell"] as Vector2i
			var candidate_distance := Vector2(candidate_cell).distance_to(worker_position)
			if candidate_distance < tree_distance:
				tree_id = int(entity_state["id"])
				tree_cell = candidate_cell
				tree_distance = candidate_distance
	if tree_id < 0:
		failures.append("no Lumber tree spawned")
	else:
		var tree := simulation.entity(tree_id)
		tree["amount"] = 50.0
		tree["max_amount"] = 50.0
		if simulation.can_place_war_camp(RtsSimulation.TEAM_PLAYER, tree_cell):
			failures.append("a standing tree did not block War Camp placement")
		if simulation.can_place_structure(RtsSimulation.TEAM_PLAYER, &"rice_farm", tree_cell):
			failures.append("a standing tree did not block the Rice Farm footprint")
		simulation.command_gather(RtsSimulation.TEAM_PLAYER, [workers[0]], tree_id)
		var depletion_timeout := 20.0
		while bool(simulation.entity(tree_id).get("alive", false)) and depletion_timeout > 0.0:
			simulation.advance(RtsSimulation.TICK_SECONDS)
			depletion_timeout -= RtsSimulation.TICK_SECONDS
		var worker := simulation.entity(workers[0])
		var next_tree_id := -1
		var next_tree_distance := INF
		for raw_entity in simulation.entities.values():
			var entity_state := raw_entity as Dictionary
			if not bool(entity_state.get("alive", false)) or entity_state.get("resource_kind") != &"lumber":
				continue
			var candidate_distance := (entity_state["position"] as Vector2).distance_to(worker["position"] as Vector2)
			if candidate_distance < next_tree_distance:
				next_tree_id = int(entity_state["id"])
				next_tree_distance = candidate_distance
		if next_tree_id < 0:
			failures.append("no replacement Lumber tree was available")
		elif int(worker.get("gather_source_id", -1)) != next_tree_id:
			failures.append("worker did not retarget the nearest tree after depletion")
		var lumber_at_depletion := int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"])
		var deposit_timeout := 12.0
		while int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) <= lumber_at_depletion and deposit_timeout > 0.0:
			simulation.advance(RtsSimulation.TICK_SECONDS)
			deposit_timeout -= RtsSimulation.TICK_SECONDS
		if int(simulation.players[RtsSimulation.TEAM_PLAYER]["lumber"]) <= lumber_before:
			failures.append("worker did not gather and deposit Lumber")
		if bool(simulation.entity(tree_id).get("alive", true)):
			failures.append("depleted tree remained alive")
		if next_tree_id >= 0:
			worker = simulation.entity(workers[0])
			if worker.get("order") != &"gather" or int(worker.get("gather_source_id", -1)) != next_tree_id:
				failures.append("worker did not resume harvesting from the replacement tree after depositing")
		if simulation._cell_occupied_by_static_entity(tree_cell):
			failures.append("depleted tree cell remained occupied")

	simulation.command_stop(RtsSimulation.TEAM_PLAYER, [workers[0]])
	var build_site := MapCatalog.PLAYER_BUILD_TEST_SITE
	if not simulation.command_build_war_camp(RtsSimulation.TEAM_PLAYER, workers[0], build_site):
		failures.append("valid War Camp placement was rejected")
	else:
		_advance(simulation, 14.0)
		var camp_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"war_camp")
		var camp := simulation.entity(camp_id)
		if camp.is_empty() or float(camp.get("complete", 0.0)) < 1.0:
			failures.append("War Camp did not complete")
		else:
			simulation.players[RtsSimulation.TEAM_PLAYER]["food"] = 1000
		if not camp.is_empty() and float(camp.get("complete", 0.0)) >= 1.0 and not simulation.command_train(RtsSimulation.TEAM_PLAYER, camp_id, &"vanguard"):
			failures.append("Vanguard training was rejected")
		elif not camp.is_empty() and float(camp.get("complete", 0.0)) >= 1.0:
			_advance(simulation, 9.0)
			if simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"vanguard"]).is_empty():
				failures.append("Vanguard did not finish training")

	var original_enemy_camp_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"war_camp")
	var original_enemy_camp := simulation.entity(original_enemy_camp_id)
	if original_enemy_camp.is_empty():
		failures.append("enemy War Camp missing before rebuild test")
	else:
		original_enemy_camp["alive"] = false
		simulation._rebuild_pathfinding()
		simulation.players[RtsSimulation.TEAM_ENEMY]["jade"] = 1000
		simulation.players[RtsSimulation.TEAM_ENEMY]["lumber"] = 1000
		simulation.players[RtsSimulation.TEAM_ENEMY]["essence"] = 1000
		simulation._try_rebuild_ai_war_camp()
		var rebuilt_camp_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"war_camp")
		if rebuilt_camp_id < 0 or rebuilt_camp_id == original_enemy_camp_id:
			failures.append("computer did not replace its destroyed War Camp")

	var enemy_hold_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"stronghold")
	var enemy_hold := simulation.entity(enemy_hold_id)
	if enemy_hold.is_empty():
		failures.append("enemy Stronghold missing")
	else:
		enemy_hold["hp"] = 1.0
		var attacker_id := simulation._spawn_unit(
			RtsSimulation.TEAM_PLAYER,
			&"vanguard",
			MapCatalog.ENEMY_STRONGHOLD + Vector2i(-1, 0),
		)
		simulation._refresh_visibility()
		simulation.command_attack(RtsSimulation.TEAM_PLAYER, [attacker_id], enemy_hold_id)
		_advance(simulation, 3.0)
		if not simulation.outcome.is_empty():
			failures.append("destroying one rival Stronghold ended the match early")
		for remaining_team in [RtsSimulation.TEAM_RIVAL_TWO, RtsSimulation.TEAM_RIVAL_THREE]:
			var remaining_hold := simulation.entity(
				simulation.primary_structure_id(remaining_team, &"stronghold")
			)
			simulation._kill(remaining_hold, simulation.entity(attacker_id))
		if simulation.outcome != &"victory":
			failures.append("destroying all rival Strongholds did not produce victory")

	if failures.is_empty():
		print("PASS simulation_test: four-faction free-for-all roster and island starts, deposits, cargo integrity, attack-move, formations, harmless-wildlife pass-through, hostile separation, Food costs and producers, Stronghold population upgrades, AI food economy, assault waves, and one-hour skill test, guardian wandering, tree retargeting, monster bounties, cave capture and recapture, Jadeclaw production, economy, construction, combat, victory, and resignation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
