extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 3) -> void:
	for _frame in range(frames):
		await process_frame


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var failures: Array[String] = []
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await _settle()
	var focus_owner := root.gui_get_focus_owner()
	_expect(focus_owner is Button and (focus_owner as Button).text == "START GAME", "title screen did not focus its primary keyboard action", failures)

	game.call("_show_faction_select")
	await _settle()
	focus_owner = root.gui_get_focus_owner()
	_expect(focus_owner is Button and (focus_owner as Button).text == "COMMAND CELESTIAL COURT", "faction screen did not focus its first keyboard action", failures)

	game.call("_start_match", &"celestial")
	await _settle()
	var hunter_button := game._command_buttons[&"hunter"] as HudCommandButton
	_expect(hunter_button.art_texture == null and not hunter_button.visible, "Celestial HUD loaded or exposed unavailable Hunter art", failures)
	var worker_kinds: Array[StringName] = [&"worker"]
	var enemy_worker_id := int(game.simulation.team_entity_ids(RtsSimulation.TEAM_ENEMY, worker_kinds)[0])
	game.battlefield.set_fog_enabled(false)
	var selection: Array[int] = [enemy_worker_id]
	game.battlefield.select_entities(selection)
	game.call("_update_hud")
	for button_id in [&"build", &"build_farm", &"build_lodge"]:
		_expect(not (game._command_buttons[button_id] as Button).visible, "enemy Worker inspection exposed %s" % button_id, failures)

	if failures.is_empty():
		print("PASS ui_regression_test: title/faction keyboard focus, unavailable art guard, and enemy command isolation")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
