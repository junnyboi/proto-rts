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
	_verify_toast_and_pause_menus(game, battlefield, failures)
	_verify_free_worker_command(game, battlefield, simulation, failures)
	_verify_resign(game, simulation, failures)

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
		print("PASS hud_test: economy ribbon, objectives, selection states, command card, production queue, armed modes, toasts, pause/settings menus, and resign")
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
	if game._score_label == null or game._score_label.text != "SCORE: 0":
		failures.append("top-left score label did not replace the faction matchup text")
	else:
		simulation._deposit(RtsSimulation.TEAM_PLAYER, &"lumber", 7.0)
		game.call("_update_hud")
		if game._score_label.text != "SCORE: 7":
			failures.append("top-left score label did not bind to the authoritative score")
	if game._objective_rows.size() != 3:
		failures.append("objective tracker did not create three checklist rows")
	var pause_icon := game._pause_button.get_node_or_null("Icon") as TextureRect if game._pause_button != null else null
	var audio_icon := game._audio_button.get_node_or_null("Icon") as TextureRect if game._audio_button != null else null
	if game._pause_button == null or pause_icon == null or not game._pause_button.text.is_empty():
		failures.append("economy ribbon pause control is not icon-only")
	elif not pause_icon.position.is_equal_approx((game._pause_button.size - pause_icon.size) * 0.5):
		failures.append("economy ribbon pause icon is not centered in both axes")
	if game._audio_button == null or audio_icon == null or not game._audio_button.text.is_empty():
		failures.append("economy ribbon audio control is not icon-only")
	else:
		if not audio_icon.position.is_equal_approx((game._audio_button.size - audio_icon.size) * 0.5):
			failures.append("economy ribbon audio icon is not centered in both axes")
		if audio_icon.material == null:
			failures.append("economy ribbon audio icon is missing its procedural lightening material")
		if audio_icon.texture.resource_path != "res://assets/runtime/ui/utility_icons/audio_on.png":
			failures.append("enabled audio state did not show the audio-on icon")
		game.call("_toggle_audio")
		if audio_icon.texture.resource_path != "res://assets/runtime/ui/utility_icons/audio_muted.png":
			failures.append("muted audio state did not show the muted icon")
		game.call("_toggle_audio")
		if audio_icon.texture.resource_path != "res://assets/runtime/ui/utility_icons/audio_on.png":
			failures.append("re-enabled audio state did not restore the audio-on icon")
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

	var enemy_units := simulation.team_entity_ids(RtsSimulation.TEAM_ENEMY, [&"worker", &"vanguard", &"mystic"])
	if enemy_units.is_empty():
		failures.append("no enemy unit was available for HUD inspection")
	else:
		battlefield.select_entities([enemy_units[0]])
		game.call("_update_hud")
		if game._selection_status.text != "ENEMY UNIT":
			failures.append("enemy unit inspection did not identify its hostile ownership")
		if game._command_buttons[&"move"].visible or game._command_buttons[&"build"].visible:
			failures.append("enemy unit inspection exposed player commands")

	var enemy_stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_ENEMY, &"stronghold")
	battlefield.select_entities([enemy_stronghold_id])
	game.call("_update_hud")
	if game._selection_status.text != "ENEMY STRUCTURE":
		failures.append("enemy structure inspection did not identify its hostile ownership")
	if game._command_buttons[&"worker"].visible or game._command_buttons[&"rally"].visible:
		failures.append("enemy structure inspection exposed player commands")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	game.call("_unhandled_key_input", escape)
	if not battlefield.selected_ids.is_empty():
		failures.append("Esc did not dismiss enemy information viewing")
	if game.paused:
		failures.append("Esc paused the match instead of dismissing enemy information viewing")


func _verify_commands_and_queue(
	game: Node,
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var stronghold_id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	for resource in [&"jade", &"lumber", &"essence", &"food"]:
		simulation.players[RtsSimulation.TEAM_PLAYER][String(resource)] = 1000
	simulation.command_train(RtsSimulation.TEAM_PLAYER, stronghold_id, &"worker")
	simulation.command_train(RtsSimulation.TEAM_PLAYER, stronghold_id, &"worker")
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
		game.call("_unhandled_key_input", escape)
		if not battlefield.selected_ids.is_empty():
			failures.append("Esc did not dismiss the current selection")
		if game.paused:
			failures.append("Esc paused the match instead of dismissing the current selection")

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


func _verify_toast_and_pause_menus(
	game: Node,
	battlefield: Battlefield,
	failures: Array[String],
) -> void:
	game.call("_show_feedback", "Insufficient Lumber.", true)
	if not game._toast_panel.visible or game._feedback_label.text != "Insufficient Lumber.":
		failures.append("actionable feedback did not show in the toast lane")
	game._feedback_timer = 0.01
	game.call("_process", 0.02)
	if game._toast_panel.visible:
		failures.append("feedback toast did not expire")
	game.call("_toggle_pause")
	if not game.paused or not game._pause_overlay.visible or not game._pause_menu.visible:
		failures.append("pause did not display the modal pause menu")
	if battlefield.is_processing():
		failures.append("battlefield presentation kept processing behind the pause menu")
	if game._settings_menu.visible:
		failures.append("settings menu was visible before it was requested")
	if game._resume_button.text != "RESUME" or game._settings_button.text != "SETTINGS" or game._resign_button.text != "RESIGN":
		failures.append("pause menu is missing its Resume, Settings, or Resign action")
	var pause_icon := game._pause_button.get_node("Icon") as TextureRect
	if pause_icon.texture.resource_path != "res://assets/runtime/ui/utility_icons/resume.png":
		failures.append("paused state did not show the resume icon")
	var selection_before := battlefield.selected_ids.duplicate()
	var worker_hotkey := InputEventKey.new()
	worker_hotkey.pressed = true
	worker_hotkey.keycode = KEY_Q
	game.call("_unhandled_key_input", worker_hotkey)
	if battlefield.selected_ids != selection_before:
		failures.append("gameplay hotkey changed selection while the pause menu was open")

	game._settings_button.pressed.emit()
	if game._pause_menu.visible or not game._settings_menu.visible:
		failures.append("Settings did not replace the pause menu with the settings panel")
	var muted_before: bool = game.audio_director.muted
	game._settings_audio_button.pressed.emit()
	if game.audio_director.muted == muted_before:
		failures.append("settings audio control did not toggle audio")
	if game._settings_audio_button.text != ("AUDIO: OFF" if not muted_before else "AUDIO: ON"):
		failures.append("settings audio control did not reflect its new state")
	game._settings_audio_button.pressed.emit()
	game._settings_back_button.pressed.emit()
	if not game._pause_menu.visible or game._settings_menu.visible:
		failures.append("Settings Back did not restore the pause menu")
	game._settings_button.pressed.emit()
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	game.call("_unhandled_key_input", escape)
	if not game._pause_menu.visible or game._settings_menu.visible or not game.paused:
		failures.append("Esc did not return from Settings to the pause menu")
	var pause_key := InputEventKey.new()
	pause_key.pressed = true
	pause_key.keycode = KEY_P
	game.call("_unhandled_key_input", pause_key)
	if game.paused or game._pause_overlay.visible:
		failures.append("P did not resume from the pause menu")
	if not battlefield.is_processing():
		failures.append("battlefield presentation did not resume with the match")
	if pause_icon.texture.resource_path != "res://assets/runtime/ui/utility_icons/pause.png":
		failures.append("resumed state did not restore the pause icon")


func _verify_free_worker_command(
	game: Node,
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var team := RtsSimulation.TEAM_PLAYER
	var stronghold_id := simulation.primary_structure_id(team, &"stronghold")
	while not (simulation.entity(stronghold_id).get("queue", []) as Array).is_empty():
		simulation.command_cancel_training(team, stronghold_id)
	for worker_id in simulation.team_entity_ids(team, [&"worker"]):
		simulation._kill(simulation.entity(worker_id), {})
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		simulation.players[team][String(resource_kind)] = 0
	battlefield.select_entities([stronghold_id])
	game.call("_update_hud")
	var worker_button := game._command_buttons[&"worker"] as HudCommandButton
	if worker_button.disabled:
		failures.append("the free recovery Worker command was disabled with no resources")
	if worker_button.cost_markup != "FREE":
		failures.append("the free recovery Worker command did not display a FREE cost")
	if not worker_button.tooltip_text.contains("no Workers left"):
		failures.append("the free recovery Worker command did not explain its free cost")


func _verify_resign(game: Node, simulation: RtsSimulation, failures: Array[String]) -> void:
	game.call("_toggle_pause")
	game._resign_button.pressed.emit()
	if simulation.outcome != &"defeat":
		failures.append("Resign did not set the authoritative defeat outcome")
	if game.state != &"result" or game._result_overlay == null:
		failures.append("Resign did not open the match result screen")
	if game._pause_overlay.visible:
		failures.append("pause menu remained visible over the resignation result")
