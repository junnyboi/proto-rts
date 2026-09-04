extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 3) -> void:
	for _frame: int in range(frames):
		await process_frame


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var failures: Array[String] = []
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	var suffix := Time.get_ticks_usec()
	game.leaderboard_save_path = "user://tweak_ui_leaderboard_%d.json" % suffix
	game.tweak_save_path = "user://tweak_ui_settings_%d.json" % suffix
	root.add_child(game)
	await _settle()

	_verify_launcher(game, "title", failures)
	_expect(game._tweak_panel != null and not game._tweak_panel.visible, "title tweak panel began open", failures)
	game.call("_open_tweak_panel")
	await _settle()
	_expect(game._tweak_panel.visible, "title launcher did not open the tweak panel", failures)
	_expect(game._tweak_panel.find_children("TweakCategory*", "Button", true, false).size() == 7, "panel does not expose All plus six categories", failures)
	game._tweak_panel.close_panel()
	await _settle()

	game.call("_show_faction_select")
	await _settle()
	_verify_launcher(game, "faction", failures)
	game.call("_start_match", &"celestial")
	await _settle(5)
	_verify_launcher(game, "match", failures)
	_expect(not game.paused, "fresh match began paused", failures)
	game.call("_open_tweak_panel")
	await _settle()
	_expect(game.paused and game._tweak_panel.visible, "opening tweaks during play did not pause through the shell", failures)
	_expect(not game.battlefield.is_processing(), "battlefield kept processing behind tweak panel", failures)
	game._tweak_panel.close_panel()
	await _settle()
	_expect(not game.paused and game.battlefield.is_processing(), "closing tweaks did not restore the prior unpaused state", failures)

	game.call("_set_paused", true)
	await _settle()
	game.call("_show_settings_menu")
	await _settle()
	game.call("_open_tweak_panel")
	await _settle()
	game._tweak_panel.close_panel()
	await _settle()
	_expect(game.paused, "closing tweaks incorrectly resumed a previously paused match", failures)
	_expect(game._settings_menu.visible and not game._pause_menu.visible, "closing tweaks did not restore the prior pause submenu", failures)

	game.call("_set_paused", false)
	game.call("_on_match_ended", &"defeat")
	await _settle()
	_verify_launcher(game, "result", failures)

	var director := game.audio_director as AudioDirector
	director._music_player.stop()
	for player: AudioStreamPlayer in director._players:
		player.stop()
	await create_timer(0.15).timeout
	for player: AudioStreamPlayer in director._players:
		player.stream = null
	director._music_player.stream = null
	game.queue_free()
	await _settle(2)
	_cleanup("user://tweak_ui_leaderboard_%d.json" % suffix)
	_cleanup("user://tweak_ui_settings_%d.json" % suffix)

	if failures.is_empty():
		print("PASS tweak_ui_test: persistent launcher, six categories, and exact pause/focus lifecycle")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _verify_launcher(game: Node, route: String, failures: Array[String]) -> void:
	var button := game._tweak_button as Button
	_expect(button != null and button.visible, "%s route lacks the persistent tweak launcher" % route, failures)
	if button == null:
		return
	_expect(is_equal_approx(button.modulate.a, 0.5), "%s launcher rest opacity is not exactly 0.5" % route, failures)
	_expect(not button.tooltip_text.is_empty() and not button.accessibility_name.is_empty(), "%s launcher lacks tooltip or accessibility copy" % route, failures)


func _cleanup(path: String) -> void:
	for candidate: String in [path, "%s.bak" % path, "%s.tmp" % path]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
