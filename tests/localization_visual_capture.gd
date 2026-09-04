extends SceneTree

const OUTPUT := "res://captures/localization"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	I18n.set_locale(&"zh-CN")
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	var save_path := "user://localization_visual_test.json"
	var tweak_save_path := "user://localization_visual_tweak_test.json"
	var tutorial_save_path := "user://localization_visual_tutorial_test.json"
	_cleanup(save_path)
	_cleanup(tweak_save_path)
	_cleanup(tutorial_save_path)
	game.leaderboard_save_path = save_path
	game.tweak_save_path = tweak_save_path
	game.tutorial_save_path = tutorial_save_path
	root.add_child(game)
	await _settle(10)
	await _capture("title-cn")
	game.call("_open_tweak_panel")
	await _settle(3)
	await _capture("tweak-controls-cn")
	game._tweak_panel.close_panel()
	await _settle(3)

	game.leaderboard_store.record_match(6840, &"victory", &"human", 502)
	game.leaderboard_store.record_match(5210, &"defeat", &"beast", 417)
	game._leaderboard_button.pressed.emit()
	await _settle(3)
	await _capture("leaderboard-cn")
	game._leaderboard_dialog.close_dialog()

	game.call("_show_faction_select")
	await _settle(6)
	await _capture("faction-select-cn")
	game.call("_start_match", &"human")
	await _settle(20)
	var stronghold_kinds: Array[StringName] = [&"stronghold"]
	var strongholds: Array[int] = game.simulation.team_entity_ids(
		RtsSimulation.TEAM_PLAYER,
		stronghold_kinds,
	)
	if not strongholds.is_empty():
		var selection: Array[int] = [strongholds[0]]
		game.battlefield.select_entities(selection)
		game.call("_update_hud")
	await _settle(4)
	await _capture("skirmish-cn")

	game.call("_toggle_pause")
	await _settle(3)
	await _capture("pause-cn")
	game.call("_show_abandon_confirmation", &"title")
	await _settle(3)
	await _capture("return-title-confirmation-cn")
	game.call("_cancel_abandon_confirmation")
	await _settle(3)
	game._settings_button.pressed.emit()
	await _settle(3)
	await _capture("settings-cn")
	game._settings_back_button.pressed.emit()
	game._resume_button.pressed.emit()
	game.call("_on_match_ended", &"victory")
	await _settle(4)
	await _capture("result-cn")

	var director := game.audio_director as AudioDirector
	director._music_player.stop()
	director._music_player.stream = null
	for player: AudioStreamPlayer in director._players:
		player.stop()
		player.stream = null
	root.remove_child(game)
	game.free()
	await process_frame
	I18n.set_locale(&"en-US")
	_cleanup(save_path)
	_cleanup(tweak_save_path)
	_cleanup(tutorial_save_path)
	if _failures.is_empty():
		print("PASS localization_visual_capture: 9 Chinese UI states captured")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _settle(frames: int = 8) -> void:
	for _frame: int in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUTPUT, name])
	var error := image.save_png(path)
	if error != OK:
		_failures.append("failed to save %s: %s" % [path, error_string(error)])


func _cleanup(save_path: String) -> void:
	for path: String in [save_path, "%s.bak" % save_path, "%s.tmp" % save_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
