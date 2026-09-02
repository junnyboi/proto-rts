extends SceneTree

const OUTPUT := "res://captures"


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 8) -> void:
	for _frame in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT, name])
	var result := image.save_png(path)
	if result != OK:
		push_error("failed to save capture %s: %s" % [path, error_string(result)])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await _settle()
	_capture("title")
	game.call("_show_faction_select")
	await _settle()
	_capture("faction-select")
	game.call("_start_match", &"celestial")
	await _settle(20)
	_capture("skirmish")
	game.set_process(false)
	game.battlefield.set_process(false)
	game._minimap.set_process(false)
	game.call("_toggle_fog_of_war")
	game.battlefield.camera_scale = 0.72
	game.battlefield.center_on_cell(MapCatalog.CAVES[0]["cell"] as Vector2i)
	await _settle(2)
	_capture("monster-cave")
	var cave_id: int = int(game.simulation.cave_ids()[0])
	var cave: Dictionary = game.simulation.entity(cave_id)
	var hunter_id: int = int(game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"vanguard",
		(cave["cell"] as Vector2i) + Vector2i(2, 1),
	))
	var hunter: Dictionary = game.simulation.entity(hunter_id)
	for raw_guardian_id in cave["guardian_ids"] as Array:
		game.simulation._kill(game.simulation.entity(int(raw_guardian_id)), hunter)
	game.simulation._complete_cave_capture(cave, RtsSimulation.TEAM_PLAYER)
	var selected_cave_ids: Array[int] = [cave_id]
	game.battlefield.select_entities(selected_cave_ids)
	game.call("_update_hud")
	await _settle(2)
	_capture("captured-cave")
	var farm_site: Vector2i = game.simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		&"rice_farm",
		MapCatalog.PLAYER_STRONGHOLD,
	)
	var farm_id: int = game.simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"rice_farm",
		farm_site,
		true,
	)
	game.simulation._rebuild_pathfinding()
	var lodge_site: Vector2i = game.simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		&"hunters_lodge",
		farm_site + Vector2i(3, 0),
	)
	game.simulation._spawn_structure(
		RtsSimulation.TEAM_PLAYER,
		&"hunters_lodge",
		lodge_site,
		true,
	)
	game.simulation._rebuild_pathfinding()
	var worker_kinds: Array[StringName] = [&"worker"]
	var player_worker_ids: Array[int] = game.simulation.team_entity_ids(
		RtsSimulation.TEAM_PLAYER,
		worker_kinds,
	)
	var selected_worker_ids: Array[int] = [player_worker_ids[0]]
	game.battlefield.select_entities(selected_worker_ids)
	game.battlefield.camera_scale = 0.72
	game.battlefield.center_on_cell(farm_site)
	game.call("_update_hud")
	await _settle(2)
	_capture("food-build-menu")
	var selected_farm_ids: Array[int] = [farm_id]
	game.battlefield.select_entities(selected_farm_ids)
	game.call("_update_hud")
	await _settle(2)
	_capture("food-economy")
	game.battlefield.camera_scale = 0.15
	game.battlefield.center_on_cell(MapCatalog.SIZE / 2)
	await _settle(2)
	_capture("map-overview")
	print("PASS visual_capture: title, faction-select, skirmish, monster-cave, captured-cave, food-build-menu, food-economy, map-overview")
	quit(0)
