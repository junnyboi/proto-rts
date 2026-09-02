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
	game.call("_start_match", &"human")
	await _settle(20)
	_capture("skirmish")
	var cargo_preview_worker_kinds: Array[StringName] = [&"worker"]
	var cargo_preview_workers: Array[int] = game.simulation.team_entity_ids(
		RtsSimulation.TEAM_PLAYER,
		cargo_preview_worker_kinds,
	)
	var cargo_preview_kinds: Array[StringName] = [&"jade", &"lumber", &"essence"]
	for index in range(mini(cargo_preview_workers.size(), cargo_preview_kinds.size())):
		var cargo_worker: Dictionary = game.simulation.entity(cargo_preview_workers[index])
		cargo_worker["cargo_kind"] = cargo_preview_kinds[index]
		cargo_worker["cargo_amount"] = RtsSimulation.CARGO_CAPACITY * 0.5
	game.battlefield.queue_redraw()
	await _settle(2)
	_capture("worker-cargo-icons")
	for worker_id in cargo_preview_workers:
		var cargo_worker: Dictionary = game.simulation.entity(worker_id)
		cargo_worker["cargo_kind"] = &""
		cargo_worker["cargo_amount"] = 0.0
	game.call("_toggle_pause")
	await _settle(2)
	_capture("paused")
	game.call("_toggle_pause")
	game._toast_panel.visible = false
	var live_battlefield: Battlefield = game.battlefield
	game.set_process(false)
	live_battlefield.set_process(false)
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
	for resource in [&"jade", &"lumber", &"essence", &"food"]:
		game.simulation.players[RtsSimulation.TEAM_PLAYER][String(resource)] = 1000
	game.simulation.command_train(cave_id, &"jadeclaw")
	game.simulation.command_train(cave_id, &"jadeclaw")
	var selected_cave_ids: Array[int] = [cave_id]
	live_battlefield.select_entities(selected_cave_ids)
	game.call("_update_hud")
	await _settle(2)
	_capture("captured-cave")
	var selected_vanguard_ids: Array[int] = [hunter_id]
	live_battlefield.select_entities(selected_vanguard_ids)
	live_battlefield.begin_attack_move()
	game.call("_update_hud")
	await _settle(2)
	_capture("armed-attack-move")
	live_battlefield.cancel_modes()
	game._toast_panel.visible = false
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
	live_battlefield.select_entities(selected_worker_ids)
	game.battlefield.camera_scale = 0.72
	game.battlefield.center_on_cell(farm_site)
	game.call("_update_hud")
	await _settle(2)
	_capture("food-build-menu")
	var selected_worker_group: Array[int] = player_worker_ids.slice(0, 3)
	live_battlefield.select_entities(selected_worker_group)
	game.call("_update_hud")
	await _settle(2)
	_capture("multi-selection")
	var selected_farm_ids: Array[int] = [farm_id]
	live_battlefield.select_entities(selected_farm_ids)
	game.call("_update_hud")
	await _settle(2)
	_capture("food-economy")
	var deer_id: int = game.simulation.wildlife_ids(&"deer")[0]
	var deer: Dictionary = game.simulation.entity(deer_id)
	var wildlife_hunter_cell: Vector2i = game.simulation._nearest_walkable(
		(deer["cell"] as Vector2i) + Vector2i(-2, 0),
	)
	var wildlife_hunter_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"hunter",
		wildlife_hunter_cell,
	)
	game.simulation._refresh_visibility()
	var wildlife_hunter_ids: Array[int] = [wildlife_hunter_id]
	game.simulation.command_attack(wildlife_hunter_ids, deer_id)
	for _step in range(24):
		game.simulation.advance(RtsSimulation.TICK_SECONDS)
	live_battlefield.select_entities(wildlife_hunter_ids)
	game.battlefield.camera_scale = 0.86
	game.battlefield.center_on_cell(deer["cell"] as Vector2i)
	game.call("_update_hud")
	await _settle(2)
	_capture("wildlife-hunt")
	var nearest_resource: Dictionary = {}
	var nearest_resource_distance := INF
	for raw_entity in game.simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("category") != &"resource" or not bool(entity_state.get("alive", false)):
			continue
		var distance := (entity_state["position"] as Vector2).distance_to(deer["position"] as Vector2)
		if distance < nearest_resource_distance:
			nearest_resource_distance = distance
			nearest_resource = entity_state
	if nearest_resource.is_empty():
		push_error("command visualization capture requires a live resource")
		quit(1)
		return
	var command_center := nearest_resource["cell"] as Vector2i
	var move_worker_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"worker",
		game.simulation._nearest_walkable(command_center + Vector2i(-5, 1)),
	)
	var gather_worker_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"worker",
		game.simulation._nearest_walkable(command_center + Vector2i(-3, -1)),
	)
	var command_vanguard_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_PLAYER,
		&"vanguard",
		game.simulation._nearest_walkable(command_center + Vector2i(0, 3)),
	)
	var command_target_id: int = game.simulation._spawn_unit(
		RtsSimulation.TEAM_ENEMY,
		&"vanguard",
		game.simulation._nearest_walkable(command_center + Vector2i(2, 3)),
	)
	game.simulation._refresh_visibility()
	var move_worker_ids: Array[int] = [move_worker_id]
	var gather_worker_ids: Array[int] = [gather_worker_id]
	var command_vanguard_ids: Array[int] = [command_vanguard_id]
	game.simulation.command_move(
		move_worker_ids,
		game.simulation._nearest_walkable(command_center + Vector2i(5, 1)),
	)
	game.simulation.command_gather(gather_worker_ids, int(nearest_resource["id"]))
	game.simulation.command_attack(command_vanguard_ids, command_target_id)
	live_battlefield.select_entities([move_worker_id, gather_worker_id, command_vanguard_id])
	live_battlefield._command_indicator_time = 0.72
	live_battlefield.camera_scale = 0.86
	live_battlefield.center_on_cell(command_center)
	game.call("_update_hud")
	await _settle(2)
	_capture("command-visualization")
	game.battlefield.camera_scale = 0.15
	game.battlefield.center_on_cell(MapCatalog.SIZE / 2)
	await _settle(2)
	_capture("map-overview")
	print("PASS visual_capture: title, faction-select, skirmish, worker cargo icons, pause, caves, production queue, armed command, multi-selection, food economy, wildlife hunt, command visualization, map overview")
	quit(0)
