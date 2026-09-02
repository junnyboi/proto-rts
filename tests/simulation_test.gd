extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _advance(simulation: RtsSimulation, seconds: float) -> void:
	for _step in range(int(seconds / RtsSimulation.TICK_SECONDS)):
		simulation.advance(RtsSimulation.TICK_SECONDS)


func _test_stronghold_dropoff(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
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


func _test_unit_food_costs(failures: Array[String]) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
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
	for kind in [&"worker", &"vanguard", &"mystic", &"jadeclaw"]:
		if int(FactionCatalog.stats(kind, &"human").get("food_cost", 0)) <= 0:
			failures.append("%s does not require Food" % String(kind).capitalize())


func _test_food_building(
	structure_kind: StringName,
	failures: Array[String],
) -> void:
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
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
	simulation.setup(&"human", false)
	simulation.players[RtsSimulation.TEAM_ENEMY]["jade"] = 1000
	simulation.players[RtsSimulation.TEAM_ENEMY]["lumber"] = 1000
	simulation._try_expand_ai_food_economy()
	if simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"rice_farm") < 0:
		failures.append("computer commander did not establish a Rice Farm")
	var food_before_stipend := int(simulation.players[RtsSimulation.TEAM_ENEMY]["food"])
	simulation._ai_strategy_timer = 999.0
	simulation._advance_ai(RtsSimulation.TICK_SECONDS)
	if int(simulation.players[RtsSimulation.TEAM_ENEMY]["food"]) != food_before_stipend:
		failures.append("computer income stipend bypassed food infrastructure")


func _run() -> void:
	var failures: Array[String] = []
	_test_stronghold_dropoff(failures)
	_test_unit_food_costs(failures)
	_test_food_building(&"rice_farm", failures)
	_test_food_building(&"hunters_lodge", failures)
	_test_ai_food_economy(failures)
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
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
		simulation.command_gather(RtsSimulation.TEAM_PLAYER, [workers[0]], jade_resource_id)
		var jade_timeout := 30.0
		while int(simulation.players[RtsSimulation.TEAM_PLAYER]["jade"]) <= jade_before and jade_timeout > 0.0:
			simulation.advance(RtsSimulation.TICK_SECONDS)
			jade_timeout -= RtsSimulation.TICK_SECONDS
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

	if simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"war_camp") >= 0:
		failures.append("computer started with a free War Camp")
	simulation.players[RtsSimulation.TEAM_ENEMY]["jade"] = 1000
	simulation.players[RtsSimulation.TEAM_ENEMY]["lumber"] = 1000
	simulation.players[RtsSimulation.TEAM_ENEMY]["essence"] = 1000
	simulation._try_rebuild_ai_war_camp()
	var rebuilt_camp_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"war_camp")
	if rebuilt_camp_id < 0:
		failures.append("computer did not construct a missing War Camp")
	elif float(simulation.entity(rebuilt_camp_id).get("complete", 1.0)) >= 1.0:
		failures.append("computer War Camp bypassed normal construction")

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
		simulation.command_attack(RtsSimulation.TEAM_PLAYER, [attacker_id], enemy_hold_id)
		_advance(simulation, 3.0)
		if simulation.outcome != &"victory":
			failures.append("destroying the enemy Stronghold did not produce victory")

	if failures.is_empty():
		print("PASS simulation_test: Food costs and producers, AI food economy, guardian wandering, tree retargeting, monster bounties, cave capture and recapture, Jadeclaw production, economy, construction, combat, victory")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
