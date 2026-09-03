extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	var leaderboard_save_path := "user://hud_leaderboard_test_%d.json" % Time.get_ticks_usec()
	game.leaderboard_save_path = leaderboard_save_path
	root.add_child(game)
	await process_frame
	_verify_title_leaderboard(game, failures)
	game.call("_start_match", &"human")
	await process_frame
	var battlefield: Battlefield = game.battlefield
	var simulation: RtsSimulation = game.simulation

	_verify_economy_and_objectives(game, simulation, failures)
	_verify_selection_states(game, battlefield, simulation, failures)
	_verify_stronghold_upgrade_hud(game, battlefield, simulation, failures)
	_verify_demolish_hud(game, battlefield, simulation, failures)
	_verify_fortification_hud(game, battlefield, simulation, failures)
	_verify_build_rotation_hotkey(game, battlefield, simulation, failures)
	_verify_production_hotkey(game, battlefield, simulation, failures)
	_verify_commands_and_queue(game, battlefield, simulation, failures)
	_verify_move_and_rally(game, battlefield, simulation, failures)
	_verify_toast_and_pause_menus(game, battlefield, failures)
	_verify_free_worker_command(game, battlefield, simulation, failures)
	await _verify_resign(game, simulation, failures)

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
	_cleanup_leaderboard(leaderboard_save_path)
	if not CursorSystem.is_suspended():
		failures.append("game shutdown did not release the custom cursor registry")
	if failures.is_empty():
		print("PASS hud_test: title/result leaderboards, economy ribbon, objectives, selection states, Stronghold upgrades, command card, production queue, armed modes, toasts, pause/settings menus, and resign")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _verify_title_leaderboard(game: Node, failures: Array[String]) -> void:
	if game._leaderboard_button == null or game._leaderboard_button.text != "LEADERBOARD":
		failures.append("title screen did not expose its Leaderboard action")
		return
	game._leaderboard_button.pressed.emit()
	if game._leaderboard_dialog == null or not game._leaderboard_dialog.visible:
		failures.append("title Leaderboard action did not open the dialog")
		return
	if game._leaderboard_dialog.mode != LeaderboardDialog.MODE_LOCAL:
		failures.append("leaderboard dialog did not open on Local rankings")
	game._leaderboard_dialog.global_tab.pressed.emit()
	if game._leaderboard_dialog.mode != LeaderboardDialog.MODE_GLOBAL:
		failures.append("Global tab did not switch the leaderboard mode")
	if not game._leaderboard_dialog.status_label.text.contains("GLOBAL"):
		failures.append("native Global tab did not explain its local fallback")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	game.call("_unhandled_key_input", escape)
	if game._leaderboard_dialog.visible:
		failures.append("Esc did not close the title leaderboard dialog")


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
	if game._objective_rows.size() != 4:
		failures.append("objective tracker did not create four checklist rows")
	elif not (game._objective_rows[2] as Label).text.contains("Dragon Egg"):
		failures.append("objective tracker omitted the Shenlong egg objective")
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
	if not game._selection_meta.text.contains("I IDLE"):
		failures.append("selection help did not advertise the idle Worker hotkey")
	if not game._selection_meta.text.contains("H STRONGHOLD") or game._selection_meta.text.contains("SPACE STRONGHOLD"):
		failures.append("selection help did not advertise H as the exclusive Stronghold hotkey")

	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	var busy_worker := simulation.entity(workers[1])
	busy_worker["order"] = &"move"
	var idle_worker_hotkey := InputEventKey.new()
	idle_worker_hotkey.pressed = true
	idle_worker_hotkey.keycode = KEY_I
	game.call("_unhandled_key_input", idle_worker_hotkey)
	var expected_idle_workers: Array[int] = workers.duplicate()
	expected_idle_workers.erase(int(workers[1]))
	if battlefield.selected_ids != expected_idle_workers:
		failures.append("I did not select all and only idle Workers")
	busy_worker["order"] = &"idle"
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
	battlefield.select_entities([workers[0]])
	battlefield.camera_offset = Vector2(123.0, 456.0)
	var stronghold_hotkey := InputEventKey.new()
	stronghold_hotkey.pressed = true
	stronghold_hotkey.keycode = KEY_H
	game.call("_unhandled_key_input", stronghold_hotkey)
	if battlefield.selected_ids != [stronghold_id]:
		failures.append("H did not select the player Stronghold")
	var hotkey_camera_offset := battlefield.camera_offset
	battlefield.camera_offset = Vector2(321.0, 654.0)
	battlefield.center_on_player_stronghold()
	if not battlefield.camera_offset.is_equal_approx(hotkey_camera_offset):
		failures.append("H did not center the camera on the player Stronghold")
	game.call("_update_hud")
	if game._selection_status.text != "STRUCTURE" or not game._command_buttons[&"worker"].visible:
		failures.append("Stronghold selection did not show structure state and Worker production")

	battlefield.select_entities([workers[0]])
	battlefield.camera_offset = Vector2(234.0, 567.0)
	var space_key := InputEventKey.new()
	space_key.pressed = true
	space_key.keycode = KEY_SPACE
	game.call("_input", space_key)
	if battlefield.selected_ids != [workers[0]]:
		failures.append("Space changed selection without a producer selected")
	if battlefield.camera_offset != Vector2(234.0, 567.0):
		failures.append("Space changed the camera without a producer selected")

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


func _verify_stronghold_upgrade_hud(
	game: Node,
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var team := RtsSimulation.TEAM_PLAYER
	var player := simulation.players[team] as Dictionary
	var stronghold_id := simulation.primary_structure_id(team, &"stronghold")
	var stronghold := simulation.entity(stronghold_id)
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		player[String(resource_kind)] = 199
	battlefield.select_entities([stronghold_id])
	game.call("_update_hud")
	var upgrade_button := game._command_buttons.get(&"stronghold_upgrade") as HudCommandButton
	if game._selection_title.text != "STRONGHOLD LVL 1":
		failures.append("selected Stronghold name did not append its initial level")
	if upgrade_button == null or not upgrade_button.visible:
		failures.append("selected Stronghold did not expose its HUD upgrade command")
		return
	if upgrade_button.command_title != "UPGRADE LVL 2" or not upgrade_button.disabled:
		failures.append("first Stronghold upgrade command did not show its unavailable Lvl 2 state")
	if not upgrade_button.cost_markup.contains("200J") or not upgrade_button.cost_markup.contains("200F"):
		failures.append("first Stronghold upgrade command did not show its 200-each cost")

	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		player[String(resource_kind)] = 200
	game.call("_update_hud")
	if upgrade_button.disabled:
		failures.append("first Stronghold upgrade command remained disabled at its exact cost")
	else:
		upgrade_button.pressed.emit()
	game.call("_update_hud")
	if int(stronghold.get("stronghold_level", 0)) != 2:
		failures.append("Stronghold HUD command did not complete the first upgrade")
	if int(player["population_cap"]) != RtsSimulation.POPULATION_CAP + 6:
		failures.append("Stronghold HUD command did not raise the population cap to 30")
	if game._selection_title.text != "STRONGHOLD LVL 2":
		failures.append("Stronghold name did not refresh to Lvl 2 after upgrading")
	if upgrade_button.command_title != "UPGRADE LVL 3" or not upgrade_button.cost_markup.contains("300J"):
		failures.append("second Stronghold upgrade command did not show its Lvl 3 cost")

	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		player[String(resource_kind)] = 300
	game.call("_update_hud")
	if upgrade_button.disabled:
		failures.append("second Stronghold upgrade command remained disabled at its exact cost")
	else:
		upgrade_button.pressed.emit()
	game.call("_update_hud")
	if int(stronghold.get("stronghold_level", 0)) != RtsSimulation.STRONGHOLD_MAX_LEVEL:
		failures.append("Stronghold HUD command did not complete the second upgrade")
	if int(player["population_cap"]) != RtsSimulation.POPULATION_CAP + 12:
		failures.append("Stronghold HUD command did not raise the population cap to 36")
	if game._selection_title.text != "STRONGHOLD LVL 3":
		failures.append("Stronghold name did not refresh to Lvl 3 after upgrading")
	if upgrade_button.command_title != "MAX LEVEL" or not upgrade_button.disabled:
		failures.append("maximum-level Stronghold did not show a disabled terminal upgrade state")
	if not upgrade_button.cost_markup.is_empty():
		failures.append("maximum-level Stronghold continued to display an upgrade cost")
	if not (game._resource_values[&"population"] as Label).text.ends_with("/36"):
		failures.append("population ribbon did not refresh to the fully upgraded cap")


func _verify_demolish_hud(
	game: Node,
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var team := RtsSimulation.TEAM_PLAYER
	var demolish_button := game._command_buttons.get(&"demolish") as HudCommandButton
	if demolish_button == null:
		failures.append("command card did not create a Demolish button")
		return
	var stronghold_id := simulation.primary_structure_id(team, &"stronghold")
	battlefield.select_entities([stronghold_id])
	game.call("_update_hud")
	if demolish_button.visible:
		failures.append("Stronghold selection exposed the Demolish command")

	var enemy_camp_id := simulation._spawn_structure(
		RtsSimulation.TEAM_ENEMY,
		&"war_camp",
		MapCatalog.PLAYER_BUILD_TEST_SITE,
		true,
	)
	battlefield.select_entities([enemy_camp_id])
	game.call("_update_hud")
	if demolish_button.visible:
		failures.append("enemy building inspection exposed the Demolish command")

	var camp_id := simulation._spawn_structure(
		team,
		&"war_camp",
		MapCatalog.PLAYER_BUILD_TEST_SITE,
		true,
	)
	var refund := simulation.demolition_refund(camp_id)
	var resources_before: Dictionary = {}
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		resources_before[resource_kind] = int(simulation.players[team][String(resource_kind)])
	battlefield.select_entities([camp_id])
	game.call("_update_hud")
	if not demolish_button.visible or demolish_button.command_title != "DEMOLISH":
		failures.append("selected player building did not expose the Demolish command")
		return
	if not demolish_button.tooltip_text.contains("refund 50%"):
		failures.append("Demolish command did not explain its 50% refund")
	if not demolish_button.cost_markup.contains("64J") or not demolish_button.cost_markup.contains("34L"):
		failures.append("Demolish command did not show the Human War Camp's discounted refund")
	demolish_button.pressed.emit()
	if bool(simulation.entity(camp_id).get("alive", true)):
		failures.append("Demolish HUD command did not destroy the selected building")
	if not battlefield.selected_ids.is_empty():
		failures.append("Demolish HUD command did not clear the destroyed building selection")
	for definition in [
		["jade_cost", &"jade"],
		["lumber_cost", &"lumber"],
		["essence_cost", &"essence"],
		["food_cost", &"food"],
	]:
		var expected := int(resources_before[definition[1]]) + int(refund.get(definition[0], 0))
		if int(simulation.players[team][String(definition[1])]) != expected:
			failures.append("Demolish HUD command refunded the wrong %s amount" % String(definition[1]).capitalize())
	if not game._feedback_label.text.contains("50% refund"):
		failures.append("Demolish HUD command did not confirm the 50% refund")


func _verify_fortification_hud(
	game: Node,
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var workers := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])
	battlefield.select_entities([workers[0]])
	game.call("_update_hud")
	for button_id in [&"build_wall", &"build_gate", &"build_tower"]:
		if not game._command_buttons.has(button_id) or not (game._command_buttons[button_id] as Button).visible:
			failures.append("Worker command card omitted %s" % String(button_id))
	if game._command_grid.columns != 4 or game._command_slots.size() != 12:
		failures.append("fortification commands did not expand the command card to a fixed 4x3 grid")

	var tower_cell := simulation._find_build_site(
		RtsSimulation.TEAM_PLAYER,
		&"sentry_tower",
		MapCatalog.PLAYER_STRONGHOLD + Vector2i(6, 0),
	)
	if tower_cell.x < 0:
		failures.append("no clear Sentry Tower HUD test site was available")
		return
	var tower_id := simulation._spawn_structure(RtsSimulation.TEAM_PLAYER, &"sentry_tower", tower_cell, true)
	simulation._rebuild_pathfinding()
	var hunter_cell := simulation._nearest_walkable_around(tower_cell, 4)
	var hunter_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"hunter", hunter_cell)
	simulation._enter_garrison(simulation.entity(tower_id), simulation.entity(hunter_id))
	battlefield.select_entities([tower_id])
	game.call("_update_hud")
	if not game._selection_stacks.visible or game._selection_stacks.get_child_count() != 1:
		failures.append("selected Sentry Tower did not show its garrisoned unit in the HUD")
		return
	var occupant_button := game._selection_stacks.get_child(0) as Button
	if occupant_button.name != "GarrisonUnitButton" or not occupant_button.text.contains("UNGARRISON"):
		failures.append("tower occupant HUD tile did not expose its ungarrison action")
	game.call("_update_hud")
	if occupant_button != game._selection_stacks.get_child(0):
		failures.append("HUD refresh replaced the tower occupant button during a possible mouse click")
	occupant_button.pressed.emit()
	if int(simulation.entity(hunter_id).get("garrisoned_in", -1)) >= 0:
		failures.append("clicking the tower occupant HUD tile did not ungarrison the unit")
	if simulation._astar.is_point_solid(simulation.entity(hunter_id)["cell"] as Vector2i):
		failures.append("HUD-ungarrisoned unit did not appear on walkable ground at the tower base")


func _verify_build_rotation_hotkey(
	game: Node,
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	battlefield.select_entities([worker_id])
	battlefield.begin_structure_placement(&"rice_farm")
	var rotate_key := InputEventKey.new()
	rotate_key.pressed = true
	rotate_key.keycode = KEY_R
	game.call("_unhandled_key_input", rotate_key)
	if battlefield.placement_orientation != &"x":
		failures.append("R did not rotate an armed building placement by 90 degrees")
	if battlefield.repair_armed:
		failures.append("R armed Repair while a building placement was active")
	game.call("_unhandled_key_input", rotate_key)
	if battlefield.placement_orientation != &"y":
		failures.append("a second R press did not rotate building placement back by 90 degrees")
	battlefield.cancel_modes()
	game.call("_unhandled_key_input", rotate_key)
	if not battlefield.repair_armed:
		failures.append("R no longer armed Repair outside building placement")
	battlefield.cancel_modes()


func _verify_production_hotkey(
	game: Node,
	battlefield: Battlefield,
	simulation: RtsSimulation,
	failures: Array[String],
) -> void:
	var team := RtsSimulation.TEAM_PLAYER
	var player := simulation.players[team] as Dictionary
	var audio_was_muted := game.audio_director.muted as bool
	game.audio_director.muted = true
	for resource in [&"jade", &"lumber", &"essence", &"food"]:
		player[String(resource)] = 1000

	var stronghold_id := simulation.primary_structure_id(team, &"stronghold")
	var camp_id := simulation._spawn_structure(
		team,
		&"war_camp",
		MapCatalog.PLAYER_STRONGHOLD + Vector2i(8, 5),
		true,
	)
	var lodge_id := simulation._spawn_structure(
		team,
		&"hunters_lodge",
		MapCatalog.PLAYER_STRONGHOLD + Vector2i(5, 8),
		true,
	)
	var cave_id := int(simulation.cave_ids()[0])
	var cave := simulation.entity(cave_id)
	var cave_team := int(cave.get("team", RtsSimulation.TEAM_NEUTRAL))
	var cave_faction := cave.get("faction", &"neutral") as StringName
	var cave_order := cave.get("order", &"guarded") as StringName
	cave["team"] = team
	cave["faction"] = player["faction"] as StringName
	cave["order"] = &"idle"

	var producer_cases: Array[Dictionary] = [
		{"id": stronghold_id, "kind": &"worker"},
		{"id": camp_id, "kind": &"vanguard"},
		{"id": lodge_id, "kind": &"hunter"},
		{"id": cave_id, "kind": &"jadeclaw"},
	]
	var space_key := InputEventKey.new()
	space_key.pressed = true
	space_key.keycode = KEY_SPACE
	for producer_case in producer_cases:
		var structure_id := int(producer_case["id"])
		var expected_kind := producer_case["kind"] as StringName
		battlefield.select_entities([structure_id])
		game.call("_update_hud")
		var button := game._command_buttons[expected_kind] as HudCommandButton
		if not button.visible or button.hotkey_text != "Space":
			failures.append("%s did not advertise Space on its first production option" % String(expected_kind).capitalize())
		elif (
			button._badge.text != "SPC"
			or button._badge.position.x < 0.0
			or button._badge.position.x + button._badge.size.x > button.size.x
		):
			failures.append("Space production badge did not render inside its command tile")
		if not button.tooltip_text.contains("Hotkey: Space"):
			failures.append("%s production tooltip omitted the Space hotkey" % String(expected_kind).capitalize())
		game.call("_input", space_key)
		var queue := simulation.entity(structure_id).get("queue", []) as Array
		if queue.size() != 1 or (queue[0] as Dictionary).get("kind") != expected_kind:
			failures.append("Space did not queue the first %s production option" % String(expected_kind).capitalize())
		else:
			simulation.command_cancel_training(team, structure_id)

	battlefield.select_entities([camp_id])
	game.call("_update_hud")
	if (game._command_buttons[&"mystic"] as HudCommandButton).hotkey_text == "Space":
		failures.append("Space was assigned to the War Camp's second production option")
	for resource in [&"jade", &"lumber", &"essence", &"food"]:
		player[String(resource)] = 0
	var population_before := int(player["population"])
	game.call("_input", space_key)
	if not (simulation.entity(camp_id).get("queue", []) as Array).is_empty():
		failures.append("Space queued a Vanguard without sufficient resources")
	if int(player["population"]) != population_before:
		failures.append("failed Space production reserved population")
	if not game._feedback_label.text.contains("Insufficient resources"):
		failures.append("failed Space production did not explain its affordability failure")

	for resource in [&"jade", &"lumber", &"essence", &"food"]:
		player[String(resource)] = 1000
	cave["team"] = cave_team
	cave["faction"] = cave_faction
	cave["order"] = cave_order
	game.audio_director.muted = audio_was_muted


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
	var queue := simulation.entity(stronghold_id).get("queue", []) as Array
	(queue[0] as Dictionary)["remaining"] = 1.25
	var second_order_total := float((queue[1] as Dictionary).get("total", 0.0))
	battlefield.select_entities([stronghold_id])
	game.call("_update_hud")
	if not game._queue_panel.visible or not game._queue_tiles[0].visible or not game._queue_tiles[1].visible:
		failures.append("global production queue did not display each queued unit order")
	if not game._command_buttons[&"cancel_queue"].visible:
		failures.append("selected producer did not expose Cancel Last")
	if (
		int(game._queue_tiles[0].get_meta(&"producer_id", -1)) != stronghold_id
		or int(game._queue_tiles[0].get_meta(&"queue_index", -1)) != 0
		or int(game._queue_tiles[1].get_meta(&"queue_index", -1)) != 1
		or int(game._queue_tiles[0].get_meta(&"order_id", -1)) < 0
		or int(game._queue_tiles[1].get_meta(&"order_id", -1)) < 0
	):
		failures.append("production queue tiles did not retain their exact order locations")
	if not game._queue_tiles[0].tooltip_text.contains("full refund"):
		failures.append("production queue tile did not explain click-to-cancel refunds")
	var player := simulation.players[RtsSimulation.TEAM_PLAYER] as Dictionary
	var first_order_costs := ((queue[0] as Dictionary).get("costs", {}) as Dictionary).duplicate()
	var first_order_population := int((queue[0] as Dictionary).get("reserved_population", 0))
	var resources_before_cancel: Dictionary = {}
	for resource in [&"jade", &"lumber", &"essence", &"food"]:
		resources_before_cancel[resource] = int(player[String(resource)])
	var population_before_cancel := int(player["population"])
	battlefield.select_entities([])
	game.call("_on_queue_tile_pressed", game._queue_tiles[0])
	queue = simulation.entity(stronghold_id).get("queue", []) as Array
	if queue.size() != 1 or not is_equal_approx(float((queue[0] as Dictionary).get("remaining", 0.0)), second_order_total):
		failures.append("clicking a production queue tile did not cancel that exact order")
	for resource in [&"jade", &"lumber", &"essence", &"food"]:
		var resource_key := String(resource)
		var expected_amount := int(resources_before_cancel[resource]) + int(first_order_costs.get(resource_key, 0))
		if int(player[resource_key]) != expected_amount:
			failures.append("production queue tile cancellation did not fully refund %s" % resource_key.capitalize())
	if int(player["population"]) != population_before_cancel - first_order_population:
		failures.append("production queue tile cancellation did not release reserved population")
	if not game._feedback_label.text.contains("full refund"):
		failures.append("production queue tile cancellation did not confirm the full refund")

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
	if (
		game._settings_effect_intensity_button == null
		or game._settings_reduced_motion_button == null
		or game._settings_camera_impulse_button == null
		or game._settings_damage_numbers_button == null
	):
		failures.append("settings menu is missing game-juice accessibility controls")
	else:
		game._settings_effect_intensity_button.pressed.emit()
		game._settings_reduced_motion_button.pressed.emit()
		game._settings_camera_impulse_button.pressed.emit()
		game._settings_damage_numbers_button.pressed.emit()
		if game.effect_intensity != &"low" or not game.reduced_motion:
			failures.append("effect density or reduced motion did not apply immediately")
		if game.camera_impulse != &"full" or game.damage_numbers != &"all":
			failures.append("camera impulse or damage-value settings did not cycle")
		if battlefield._effect_director.intensity != &"low" or not battlefield._presentation.reduced_motion:
			failures.append("settings did not reach the active Battlefield presentation")
		var sample_button := game._command_buttons[&"move"] as HudCommandButton
		if not bool(sample_button.animation_diagnostics()["reduced_motion"]):
			failures.append("reduced motion did not reach HUD command animations")
		sample_button.call("_on_visual_activated")
		if float(sample_button.animation_diagnostics()["release_glint"]) <= 0.0:
			failures.append("keyboard/pointer activation path did not trigger command glint")
		# Restore defaults so later assertions keep their expected presentation state.
		game._settings_effect_intensity_button.pressed.emit()
		game._settings_reduced_motion_button.pressed.emit()
		game._settings_camera_impulse_button.pressed.emit()
		game._settings_camera_impulse_button.pressed.emit()
		game._settings_damage_numbers_button.pressed.emit()
		game._settings_damage_numbers_button.pressed.emit()
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
	var match_count_before := int(game.leaderboard_store.snapshot().get("total_matches", 0))
	var expected_score := simulation.team_score(RtsSimulation.TEAM_PLAYER)
	game.call("_toggle_pause")
	game._resign_button.pressed.emit()
	if simulation.outcome != &"defeat":
		failures.append("Resign did not set the authoritative defeat outcome")
	if game.state != &"result" or game._result_overlay == null:
		failures.append("Resign did not open the match result screen")
	if game._pause_overlay.visible:
		failures.append("pause menu remained visible over the resignation result")
	var result_score := game._result_overlay.find_child("ResultScore", true, false) as Label
	if result_score == null or result_score.text != "SCORE: %d" % expected_score:
		failures.append("result screen did not show the authoritative final score")
	if game._result_leaderboard_button == null or game._result_leaderboard_button.text != "LEADERBOARD":
		failures.append("result screen did not expose its Leaderboard action")
	else:
		game._result_leaderboard_button.pressed.emit()
		if not game._leaderboard_dialog.visible:
			failures.append("result Leaderboard action did not open the dialog")
		await process_frame
		if game._leaderboard_dialog.get_index() <= game._result_overlay.get_index():
			failures.append("leaderboard did not move above the result overlay for input handling")
		if DisplayServer.get_name() != "headless":
			await _click_control(game._leaderboard_dialog.callsign_edit)
			if not game._leaderboard_dialog.callsign_edit.has_focus():
				failures.append("result overlay intercepted leaderboard name-field input")
			await _click_control(game._leaderboard_dialog.global_tab)
			if game._leaderboard_dialog.mode != LeaderboardDialog.MODE_GLOBAL:
				failures.append("result overlay intercepted leaderboard button input")
		var local_rows: Array = game.leaderboard_store.local_leaderboard()
		if local_rows.is_empty() or int(local_rows[0].get("score", -1)) != expected_score:
			failures.append("completed match score was not available in local rankings")
		if DisplayServer.get_name() == "headless":
			game._leaderboard_dialog.close_dialog()
		else:
			await _click_control(game._leaderboard_dialog.close_button)
			if game._leaderboard_dialog.visible:
				failures.append("result overlay intercepted leaderboard Close input")
	var recorded_profile: Dictionary = game.leaderboard_store.snapshot()
	if int(recorded_profile.get("total_matches", 0)) != match_count_before + 1:
		failures.append("match result was not persisted exactly once")
	game.call("_on_match_ended", &"defeat")
	if int(game.leaderboard_store.snapshot().get("total_matches", 0)) != match_count_before + 1:
		failures.append("duplicate match-ended event recorded the same score twice")


func _cleanup_leaderboard(save_path: String) -> void:
	for path in [save_path, "%s.bak" % save_path, "%s.tmp" % save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _click_control(control: Control) -> void:
	var click_position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = click_position
	motion.global_position = click_position
	root.push_input(motion)
	await process_frame
	for is_pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_pressed
		click.position = click_position
		click.global_position = click_position
		root.push_input(click)
	await process_frame
