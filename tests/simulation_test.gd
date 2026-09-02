extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _advance(simulation: RtsSimulation, seconds: float) -> void:
	for _step in range(int(seconds / RtsSimulation.TICK_SECONDS)):
		simulation.advance(RtsSimulation.TICK_SECONDS)


func _run() -> void:
	var failures: Array[String] = []
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	if workers.size() != 3:
		failures.append("expected 3 initial workers, got %d" % workers.size())
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
		simulation.command_gather([workers[0]], jade_resource_id)
		_advance(simulation, 12.0)
		if int(simulation.players[RtsSimulation.TEAM_PLAYER]["jade"]) <= jade_before:
			failures.append("worker did not gather and deposit Jade")

	simulation.command_stop([workers[0]])
	if not simulation.command_build_war_camp(workers[0], Vector2i(5, 12)):
		failures.append("valid War Camp placement was rejected")
	else:
		_advance(simulation, 14.0)
		var camp_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"war_camp")
		var camp := simulation.entity(camp_id)
		if camp.is_empty() or float(camp.get("complete", 0.0)) < 1.0:
			failures.append("War Camp did not complete")
		elif not simulation.command_train(camp_id, &"vanguard"):
			failures.append("Vanguard training was rejected")
		else:
			_advance(simulation, 9.0)
			if simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"vanguard"]).is_empty():
				failures.append("Vanguard did not finish training")

	var enemy_hold_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"stronghold")
	var enemy_hold := simulation.entity(enemy_hold_id)
	if enemy_hold.is_empty():
		failures.append("enemy Stronghold missing")
	else:
		enemy_hold["hp"] = 1.0
		var attacker_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", Vector2i(16, 2))
		simulation.command_attack([attacker_id], enemy_hold_id)
		_advance(simulation, 3.0)
		if simulation.outcome != &"victory":
			failures.append("destroying the enemy Stronghold did not produce victory")

	if failures.is_empty():
		print("PASS simulation_test: economy, construction, production, combat, victory")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
