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
	battlefield.set_fog_enabled(true)
	if battlefield.should_render_entity(simulation.entity(enemy_id)):
		failures.append("re-enabling fog did not hide the enemy")

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
		print("PASS visibility_test: reveal, hide, toggle, minimap binding")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
