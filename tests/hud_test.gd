extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_match", &"human")
	await process_frame
	var battlefield: Battlefield = game.battlefield
	var simulation: RtsSimulation = game.simulation

	_verify_economy_and_objectives(game, simulation, failures)
	_verify_selection_states(game, battlefield, simulation, failures)
	_verify_commands_and_queue(game, battlefield, simulation, failures)
	_verify_move_and_rally(game, battlefield, simulation, failures)
	_verify_toast(game, failures)

	var director := game.audio_director as AudioDirector
	director._music_player.stop()
	for player in director._players:
		player.stop()
	await create_timer(0.15).timeout
	for player in director._players:
		player.stream = null
	director._music_player.stream = null
	game.queue_free()
	await process_frame
	if not CursorSystem.is_suspended():
		failures.append("game shutdown did not release the custom cursor registry")
	if failures.is_empty():
		print("PASS hud_test: economy ribbon, objectives, selection states, command card, production queue, armed modes, and toasts")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _verify_economy_and_objectives(game: Node, simulation: RtsSimulation, failures: Array[String]) -> void:
	var expected_chips: Array[StringName] = [&"jade", &"lumber", &"essence", &"food", &"population", &"dens", &"time"]
	for chip_id in expected_chips:
		if not game._resource_values.has(chip_id):
			failures.append("economy ribbon is missing the %s chip" % String(chip_id))
	var illustrated_chips: Array[StringName] = [&"jade", &"lumber", &"essence", &"food", &"population", &"dens"]
	for chip_id in illustrated_chips:
		if not game._resource_icons.has(chip_id):
			failures.append("economy ribbon is missing the %s icon" % String(chip_id))
		elif not (game._resource_icons[chip_id] is TextureRect):
			failures.append("economy ribbon did not use illustrated art for %s" % String(chip_id))
		elif (game._resource_icons[chip_id] as TextureRect).texture == null:
			failures.append("economy ribbon %s icon has no texture" % String(chip_id))
	if game._resource_icons.has(&"time") and game._resource_icons[&"time"] is TextureRect:
		failures.append("time chip incorrectly replaced its clock glyph with resource art")
	if game._resource_values.has(&"jade") and (game._resource_values[&"jade"] as Label).text != "320":
		failures.append("Jade chip did not bind to the simulation value")
	if game._objective_rows.size() != 3:
		failures.append("objective tracker did not create three checklist rows")
	if game._audio_button == null or not game._audio_button.text.contains("AUDIO ON"):
		failures.append("economy ribbon is missing the enabled audio control")
	var players_before := simulation.players.duplicate(true)
	game.call("_toggle_objectives")
	if not game._objective_collapsed or game._objective_panel.size.y > 60.0:
		failures.append("objective tracker did not collapse to its compact state")
	if simulation.players != players_before:
		failures.append("objective collapse mutated simulation state")
	game.call("_toggle_objectives")


func _verify_selection_states(
	game: Node,
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	battlefield.select_entities([])
	game.call("_update_hud")
	if game._selection_portrait.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED:
		failures.append("Empty selection did not fill the portrait frame with centered faction art")

	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	battlefield.select_entities([workers[0]])
	game.call("_update_hud")
	if game._selection_title.text != "WORKER" or not game._command_buttons[&"repair"].visible:
		failures.append("Worker selection did not populate identity and repair command")
	if game._selection_portrait.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
		failures.append("Unit selection did not restore uncropped entity art")
	if game._command_buttons[&"attack_move"].visible:
		failures.append("Worker selection exposed the military attack-move slot")

	battlefield.select_entities(workers.slice(0, 2))
	game.call("_update_hud")
	if not game._selection_stacks.visible or game._selection_stacks.get_child_count() != 1:
		failures.append("multi-unit selection did not create a stacked type selector")

	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	battlefield.select_entities([stronghold_id])
	game.call("_update_hud")
	if game._selection_status.text != "STRUCTURE" or not game._command_buttons[&"worker"].visible:
		failures.append("Stronghold selection did not show structure state and Worker production")

	var resource_id := -1
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("category") == &"resource":
			resource_id = int(entity_state["id"])
			break
	if resource_id >= 0:
		battlefield.select_entities([resource_id])
		game.call("_update_hud")
		if game._selection_status.text != "RESOURCE" or not game._selection_health.visible:
			failures.append("resource selection did not show amount state")

	var wildlife_id := simulation.wildlife_ids()[0]
	battlefield.select_entities([wildlife_id])
	game.call("_update_hud")
	if game._selection_status.text != "WILDLIFE" or not game._selection_meta.text.contains("FOOD BOUNTY"):
		failures.append("wildlife selection did not show behavior and Food bounty")

	var den_id := simulation.cave_ids()[0]
	battlefield.select_entities([den_id])
	game.call("_update_hud")
	if game._selection_title.text != "YAOGUAI DEN" or not game._selection_meta.text.contains("CAPTURE"):
		failures.append("Den selection did not show capture state")


func _verify_commands_and_queue(
	game: Node,
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	for resource in [&"jade", &"lumber", &"essence", &"food"]:
		simulation.players[RtsSimulation.TEAM_PLAYER][String(resource)] = 1000
	simulation.command_train(stronghold_id, &"worker")
	simulation.command_train(stronghold_id, &"worker")
	battlefield.select_entities([stronghold_id])
	game.call("_update_hud")
	if not game._queue_panel.visible or not game._queue_tiles[0].visible:
		failures.append("global production queue did not display queued units")
	if not game._command_buttons[&"cancel_queue"].visible:
		failures.append("selected producer did not expose Cancel Last")
	battlefield.select_entities([])
	game.call("_on_queue_tile_pressed", game._queue_tiles[0])
	if battlefield.selected_ids != [stronghold_id]:
		failures.append("production queue tile did not select its producer")

	var vanguard_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"vanguard", MapCatalog.PLAYER_WORKERS[0] + Vector2i(1, 0))
	battlefield.select_entities([vanguard_id])
	game.call("_update_hud")
	if not game._command_buttons[&"patrol"].visible or not game._command_buttons[&"attack_move"].visible:
		failures.append("military selection did not preserve Patrol and Attack-Move commands")


func _verify_move_and_rally(
	game: Node,
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	battlefield.select_entities([workers[0]])
	game.call("_update_hud")
	(game._command_buttons[&"move"] as Button).pressed.emit()
	if not battlefield.move_armed:
		failures.append("Move command tile did not arm destination mode")
	else:
		game.call("_update_hud")
		var move_button := game._command_buttons[&"move"] as Button
		if not move_button.toggle_mode or not move_button.button_pressed:
			failures.append("armed Move command tile did not retain its selected state")
		move_button.grab_focus()
		game.call("_update_hud")
		if not move_button.has_focus():
			failures.append("HUD refresh interrupted the focused Move command tile")
		var move_cell := MapCatalog.PLAYER_WORKERS[0] + Vector2i(2, 0)
		var move_screen := battlefield.camera_offset + IsoProjection.cell_center(move_cell) * battlefield.camera_scale
		battlefield.call("_handle_left_press", move_screen)
		if simulation.entity(workers[0]).get("order") != &"move":
			failures.append("armed Move did not issue the authoritative move order")
		if not battlefield.move_armed:
			failures.append("Move command did not remain armed after choosing a destination")
		move_button.pressed.emit()
		if battlefield.move_armed:
			failures.append("clicking the selected Move command did not unselect it")
		move_button.pressed.emit()
		var escape := InputEventKey.new()
		escape.pressed = true
		escape.keycode = KEY_ESCAPE
		game.call("_unhandled_key_input", escape)
		if battlefield.move_armed or move_button.button_pressed:
			failures.append("Esc did not immediately clear the selected Move command")

	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	var stronghold := simulation.entity(stronghold_id)
	var rally_before := stronghold["rally_cell"] as Vector2i
	battlefield.select_entities([stronghold_id])
	game.call("_update_hud")
	(game._command_buttons[&"rally"] as Button).pressed.emit()
	if not battlefield.rally_armed:
		failures.append("Rally command tile did not arm destination mode")
	else:
		var rally_cell := MapCatalog.PLAYER_STRONGHOLD + Vector2i(4, 1)
		var rally_screen := battlefield.camera_offset + IsoProjection.cell_center(rally_cell) * battlefield.camera_scale
		battlefield.call("_handle_left_press", rally_screen)
		if stronghold["rally_cell"] == rally_before:
			failures.append("armed Rally did not update the authoritative rally cell")
		if not battlefield.rally_armed:
			failures.append("Rally command did not remain armed after choosing a destination")
		(game._command_buttons[&"rally"] as Button).pressed.emit()


func _verify_toast(game: Node, failures: Array[String]) -> void:
	game.call("_show_feedback", "Insufficient Lumber.", true)
	if not game._toast_panel.visible or game._feedback_label.text != "Insufficient Lumber.":
		failures.append("actionable feedback did not show in the toast lane")
	game._feedback_timer = 0.01
	game.call("_process", 0.02)
	if game._toast_panel.visible:
		failures.append("feedback toast did not expire")
	game.call("_toggle_pause")
	if not game.paused or not game._pause_banner.visible:
		failures.append("pause did not display the centered pause state")
	game.call("_toggle_pause")
