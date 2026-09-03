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
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("resource_kind") == &"jade":
			jade = entity_state
			break
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
	var expected_yield := int(stats.get("food_yield", 0))
	var interval := float(stats.get("food_interval", 0.0))
	var food_before_harvest := int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"])
	_advance(simulation, interval + RtsSimulation.TICK_SECONDS * 2.0)
	if int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"]) != food_before_harvest + expected_yield:
		failures.append("%s did not deliver its exact Food harvest" % String(structure_kind))
	var expected_rate := float(expected_yield) / interval
	if not is_equal_approx(simulation.food_income_per_second(RtsSimulation.TEAM_PLAYER), expected_rate):
		failures.append("%s reported an incorrect Food income rate" % String(structure_kind))


func _test_ai_food_economy(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"demon")
	simulation.players[RtsSimulation.TEAM_ENEMY]["jade"] = 1000
	simulation.players[RtsSimulation.TEAM_ENEMY]["lumber"] = 1000
	simulation._try_expand_ai_food_economy()
	if simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"rice_farm") < 0:
		failures.append("computer commander did not establish a Rice Farm")
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
	if hunting_simulation.entity(ai_hunter_id).get("order") not in [&"attack", &"attack_move"]:
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
	if simulation.wildlife_ids().size() != 34:
		failures.append("simulation did not spawn all 34 wildlife members")
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
	if hunter.get("order") != &"wander" or (hunter.get("path", []) as Array).is_empty():
		failures.append("idle Hunter did not begin wandering toward wildlife territory")
		return
	var food_before := int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"])
	for _step in range(int(20.0 / RtsSimulation.TICK_SECONDS)):
		simulation.advance(RtsSimulation.TICK_SECONDS)
		if int(simulation.players[RtsSimulation.TEAM_PLAYER]["food"]) > food_before:
			return
	failures.append("wandering Hunter did not find and hunt prey")


func _run() -> void:
	var failures: Array[String] = []
	_test_stronghold_dropoff(failures)
	_test_manual_deposit_requires_range(failures)
	_test_cargo_reassignment_preserves_kind(failures)
	_test_attack_move_resumes_destination(failures)
	_test_large_formations_and_separation(failures)
	_test_hostile_worker_separation(failures)
	_test_units_pass_through_harmless_wildlife(failures)
	_test_units_pass_through_friendly_structures(failures)
	_test_unit_food_costs(failures)
	_test_free_worker_recovery(failures)
	_test_food_building(&"rice_farm", failures)
	_test_food_building(&"hunters_lodge", failures)
	_test_ai_food_economy(failures)
	_test_ai_base_assault_waves(failures)
	_test_ai_skill_test_invasion(failures)
	_test_faction_food_traditions(failures)
	_test_wildlife_hunting(failures)
	_test_idle_hunter_wandering(failures)
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
	if cave_ids.size() != 2:
		failures.append("expected two Yaoguai Dens, got %d" % cave_ids.size())
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
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("resource_kind") == &"jade":
			jade_resource_id = int(entity_state["id"])
			break
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
		if simulation.outcome != &"victory":
			failures.append("destroying the enemy Stronghold did not produce victory")

	if failures.is_empty():
		print("PASS simulation_test: deposits, cargo integrity, attack-move, formations, harmless-wildlife pass-through, hostile separation, Food costs and producers, AI food economy, assault waves, and one-hour skill test, guardian wandering, tree retargeting, monster bounties, cave capture and recapture, Jadeclaw production, economy, construction, combat, victory")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
