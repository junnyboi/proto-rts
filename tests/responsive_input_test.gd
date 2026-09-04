extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 4) -> void:
	for _frame: int in range(frames):
		await process_frame


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var failures: Array[String] = []
	_expect(ResponsiveLayout.is_portrait(Vector2(720.0, 1280.0)), "portrait aspect was not detected", failures)
	_expect(not ResponsiveLayout.is_portrait(Vector2(1280.0, 720.0)), "landscape aspect was misclassified", failures)
	var safe := ResponsiveLayout.safe_rect(Vector2(720.0, 1280.0))
	_expect(safe.position == Vector2(8.0, 8.0) and safe.size == Vector2(704.0, 1264.0), "fallback safe area omitted the required margin", failures)

	var router := InputRouter.new()
	root.add_child(router)
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	joy.pressed = true
	router.observe(joy)
	_expect(router.method == InputRouter.GAMEPAD, "gamepad input did not update the active method", failures)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	router.observe(touch)
	_expect(router.method == InputRouter.TOUCH, "touch input did not update the active method", failures)
	var key := InputEventKey.new()
	key.keycode = KEY_Q
	key.pressed = true
	router.observe(key)
	_expect(router.method == InputRouter.KEYBOARD_MOUSE, "keyboard input did not restore the active method", failures)

	var original_size := root.size
	root.size = Vector2i(720, 1280)
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	var suffix := Time.get_ticks_usec()
	game.leaderboard_save_path = "user://responsive_leaderboard_%d.json" % suffix
	game.tweak_save_path = "user://responsive_tweaks_%d.json" % suffix
	game.tutorial_save_path = "user://responsive_tutorial_%d.json" % suffix
	root.add_child(game)
	await _settle()
	game.call("_show_faction_select")
	await _settle()
	_expect(game._faction_grid.columns == 2, "portrait faction selector did not reflow to two columns", failures)
	game.call("_start_match", &"human")
	await _settle(6)
	_expect(game._top_bar_grid.columns == 3, "portrait top bar did not reflow", failures)
	_expect(game._command_deck_grid.columns == 1, "portrait command deck did not stack", failures)
	game.input_router.force_method(InputRouter.TOUCH)
	await _settle()
	_expect(game._touch_controls.visible, "touch controls did not appear for touch input", failures)
	for touch_button in game._touch_controls.find_children("*TouchButton", "Button", true, false):
		_expect((touch_button as Button).custom_minimum_size.y >= ResponsiveLayout.MIN_TOUCH_TARGET, "touch action fell below the minimum target", failures)
	game.battlefield.select_all_workers()
	game._touch_controls.context_requested.emit()
	await _settle()
	_expect(game.battlefield.context_armed, "touch ORDER did not arm the contextual dispatcher", failures)
	game._touch_controls.cancel_requested.emit()
	await _settle()
	_expect(not game.battlefield.context_armed, "touch CANCEL did not clear the contextual dispatcher", failures)
	game.input_router.force_method(InputRouter.GAMEPAD)
	await _settle()
	_expect(not game._touch_controls.visible and game.battlefield._gamepad_active, "gamepad route did not replace touch controls with the virtual cursor", failures)
	var cursor_before: Vector2 = game.battlefield._gamepad_cursor
	game.battlefield.gamepad_move_cursor(Vector2.RIGHT, 0.1)
	_expect(game.battlefield._gamepad_cursor.x > cursor_before.x, "gamepad virtual cursor did not move", failures)
	var camera_before: Vector2 = game.battlefield.camera_offset
	game.battlefield.gamepad_pan(Vector2.RIGHT, 0.1)
	_expect(not game.battlefield.camera_offset.is_equal_approx(camera_before), "gamepad camera pan did not move the view", failures)
	game.call("_set_paused", true)
	await _settle()
	_expect(game._restart_button != null and game._return_title_button != null, "pause menu lacks restart or return-to-title routes", failures)
	game.call("_show_abandon_confirmation", &"restart")
	await _settle()
	_expect(game._confirm_menu.visible and not game._pause_menu.visible, "restart did not require explicit confirmation", failures)
	game.call("_cancel_abandon_confirmation")
	await _settle()
	_expect(game._pause_menu.visible and not game._confirm_menu.visible, "confirmation cancel did not restore pause", failures)
	var previous_simulation: RtsSimulation = game.simulation as RtsSimulation
	game.call("_show_abandon_confirmation", &"restart")
	game.call("_accept_abandon_confirmation")
	await _settle(6)
	_expect(game.state == &"match" and not game.paused and game.simulation != previous_simulation, "confirmed restart did not create a fresh match", failures)
	game.call("_set_paused", true)
	game.call("_show_abandon_confirmation", &"title")
	game.call("_accept_abandon_confirmation")
	await _settle(5)
	_expect(game.state == &"title" and game.simulation == null, "confirmed return-to-title did not leave the match", failures)
	_expect(game._tutorial_replay_button != null, "title route lacks explicit tutorial replay", failures)

	root.size = original_size
	var director := game.audio_director as AudioDirector
	director._music_player.stop()
	for player: AudioStreamPlayer in director._players:
		player.stop()
	await create_timer(0.15).timeout
	for player: AudioStreamPlayer in director._players:
		player.stream = null
	director._music_player.stream = null
	game.queue_free()
	router.queue_free()
	await _settle(2)
	for path: String in [
		"user://responsive_leaderboard_%d.json" % suffix,
		"user://responsive_tweaks_%d.json" % suffix,
		"user://responsive_tutorial_%d.json" % suffix,
	]:
		_cleanup(path)
	if failures.is_empty():
		print("PASS responsive_input_test: safe-area portrait reflow, touch/gamepad switching, and confirmed pause routes")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _cleanup(path: String) -> void:
	for candidate: String in [path, "%s.bak" % path, "%s.tmp" % path]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
