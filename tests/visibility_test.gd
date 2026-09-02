extends SceneTree

const BATTLEFIELD_MINIMAP := preload("res://scripts/view/battlefield_minimap.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var simulation := RtsSimulation.new()
	simulation.setup(&"celestial")
	var battlefield := Battlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	battlefield.set_simulation(simulation)
	root.add_child(battlefield)
	await process_frame
	battlefield.call("_refresh_visibility")

	if not simulation.is_cell_visible_to_team(RtsSimulation.TEAM_PLAYER, MapCatalog.PLAYER_STRONGHOLD):
		failures.append("the simulation did not publish player Stronghold visibility")
	if simulation.is_cell_visible_to_team(RtsSimulation.TEAM_PLAYER, MapCatalog.ENEMY_STRONGHOLD):
		failures.append("the simulation gave the player vision of the enemy Stronghold")
	if not simulation.is_cell_visible_to_team(RtsSimulation.TEAM_ENEMY, MapCatalog.ENEMY_STRONGHOLD):
		failures.append("the enemy team did not receive its own Stronghold vision")
	if simulation.is_cell_visible_to_team(RtsSimulation.TEAM_ENEMY, MapCatalog.PLAYER_STRONGHOLD):
		failures.append("team visibility was shared across opposing teams")
	if not battlefield.is_cell_visible(MapCatalog.PLAYER_STRONGHOLD):
		failures.append("the player Stronghold did not reveal its own cell")
	if battlefield.is_cell_explored(MapCatalog.ENEMY_STRONGHOLD):
		failures.append("the enemy Stronghold began in explored territory")
	var enemy_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"stronghold")
	if battlefield.should_render_entity(simulation.entity(enemy_id)):
		failures.append("an enemy in unexplored territory was renderable")

	battlefield.set_fog_enabled(false)
	if not battlefield.is_cell_visible(MapCatalog.ENEMY_STRONGHOLD):
		failures.append("disabling fog did not reveal the map")
	if not battlefield.should_render_entity(simulation.entity(enemy_id)):
		failures.append("disabling fog did not reveal the enemy")
	if simulation.is_cell_visible_to_team(RtsSimulation.TEAM_PLAYER, MapCatalog.ENEMY_STRONGHOLD):
		failures.append("the presentation fog toggle granted simulation visibility")
	battlefield.set_fog_enabled(true)
	if battlefield.should_render_entity(simulation.entity(enemy_id)):
		failures.append("re-enabling fog did not hide the enemy")

	var attacker_cell := simulation._nearest_walkable(MapCatalog.PLAYER_BUILD_TEST_SITE)
	var nearby_cells := simulation._formation_cells(attacker_cell, 2)
	var attacker_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", attacker_cell)
	var attacker := simulation.entity(attacker_id)
	var hidden_target_id := simulation.team_entity_ids(RtsSimulation.TEAM_ENEMY, [&"worker"])[0]
	var hidden_target := simulation.entity(hidden_target_id)
	simulation._refresh_visibility()
	simulation.command_attack([attacker_id], hidden_target_id)
	if attacker.get("order") == &"attack" or int(attacker.get("target_id", -1)) == hidden_target_id:
		failures.append("a direct attack command accepted an unseen target")
	if simulation._nearest_enemy(attacker, 1000.0) >= 0:
		failures.append("automatic acquisition found an enemy outside team vision")
	if nearby_cells.size() >= 2:
		hidden_target["position"] = Vector2(nearby_cells[1])
		hidden_target["cell"] = nearby_cells[1]
		simulation._refresh_visibility()
		simulation.command_attack([attacker_id], hidden_target_id)
		if int(attacker.get("target_id", -1)) != hidden_target_id:
			failures.append("a visible enemy was rejected as an attack target")
		hidden_target["position"] = Vector2(MapCatalog.ENEMY_WORKERS[0])
		hidden_target["cell"] = MapCatalog.ENEMY_WORKERS[0]
		simulation._refresh_visibility()
		simulation._advance_attack_order(attacker, RtsSimulation.TICK_SECONDS)
		if attacker.get("order") == &"attack" or int(attacker.get("target_id", -1)) >= 0:
			failures.append("a direct attack retained knowledge after its target left vision")

	var scout_home := attacker["position"] as Vector2
	attacker["position"] = Vector2(MapCatalog.ENEMY_STRONGHOLD + Vector2i(-2, 0))
	attacker["cell"] = Vector2i((attacker["position"] as Vector2).round())
	simulation._refresh_visibility()
	if not simulation.is_cell_visible_to_team(RtsSimulation.TEAM_PLAYER, MapCatalog.ENEMY_STRONGHOLD):
		failures.append("moving a scout did not reveal cells in simulation state")
	battlefield.call("_refresh_visibility")
	if not battlefield.is_cell_visible(MapCatalog.ENEMY_STRONGHOLD):
		failures.append("the battlefield did not consume updated simulation visibility")
	attacker["position"] = scout_home
	attacker["cell"] = Vector2i(scout_home.round())
	simulation._refresh_visibility()
	battlefield.call("_refresh_visibility")
	if simulation.is_cell_visible_to_team(RtsSimulation.TEAM_PLAYER, MapCatalog.ENEMY_STRONGHOLD):
		failures.append("visibility did not clear after the scout departed")
	if not simulation.is_cell_explored_by_team(RtsSimulation.TEAM_PLAYER, MapCatalog.ENEMY_STRONGHOLD):
		failures.append("simulation exploration did not persist after vision departed")
	if not battlefield.is_cell_explored(MapCatalog.ENEMY_STRONGHOLD):
		failures.append("the battlefield did not consume persistent simulation exploration")

	var minimap := BATTLEFIELD_MINIMAP.new()
	minimap.size = Vector2(208.0, 132.0)
	minimap.set_battlefield(battlefield)
	root.add_child(minimap)
	await process_frame
	if minimap.battlefield != battlefield:
		failures.append("the minimap did not retain its battlefield")

	battlefield.queue_free()
	minimap.queue_free()
	if failures.is_empty():
		print("PASS visibility_test: authoritative team vision, hidden-target rejection, exploration, rendering toggle, minimap binding")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
