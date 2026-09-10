extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	var suffix := str(Time.get_ticks_usec())
	game.leaderboard_save_path = "user://economy_type_score_" + suffix + ".json"
	game.tweak_save_path = "user://economy_type_tweaks_" + suffix + ".json"
	game.tutorial_save_path = "user://economy_type_tutorial_" + suffix + ".json"
	var owned_save_paths: Array[String] = [game.leaderboard_save_path, game.tweak_save_path, game.tutorial_save_path]
	root.add_child(game)
	await process_frame
	game.set_process(false)
	for locale: StringName in [&"en-US", &"zh-CN"]:
		I18n.set_locale(locale)
		game.call("_start_match", &"human")
		game.audio_director.set_muted(true)
		await _settle()
		var simulation := game.simulation as RtsSimulation
		var player: Dictionary = simulation.players[RtsSimulation.TEAM_PLAYER]
		for key: StringName in [&"jade", &"lumber", &"essence", &"food"]:
			player[key] = 99999999.0
		player["population"] = 99999
		player["population_cap"] = 999999
		simulation.elapsed_time = 999999.0
		game.call("_update_hud")
		game._score_label.text = I18n.t(&"ui.hud.score", {"score": 99999999})
		for viewport: Vector2i in [Vector2i(540, 960), Vector2i(720, 1280), Vector2i(960, 540), Vector2i(1280, 720)]:
			root.size = viewport
			game.call("_apply_responsive_layout")
			await _settle()
			var top := game._screen.get_node("TopBar") as PanelContainer
			var safe := ResponsiveLayout.safe_rect(Vector2(viewport))
			var context := "%s %s" % [locale, viewport]
			_check(safe.encloses(top.get_global_rect()), context + ": economy bar escaped safe bounds")
			for child: Node in game._top_bar_grid.get_children():
				_check(top.get_global_rect().encloses((child as Control).get_global_rect()), context + ": economy control escaped its bar")
			var labels: Array[Label] = [game._score_label]
			for value: Variant in game._resource_values.values():
				labels.append(value as Label)
			for label: Label in labels:
				var font := label.get_theme_font(&"font")
				var ink_width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size(&"font_size")).x
				_check(not label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, context + ": counter truncation is enabled")
				_check(ink_width <= label.size.x + 0.5, context + ": counter loses digits: " + label.text)
			_check(game._objective_panel.position.y >= top.get_rect().end.y, context + ": objectives overlap economy bar")
			var capture_dir := OS.get_environment("MANUSCC0_CAPTURE_DIR")
			if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute(capture_dir)
				var capture := root.get_texture().get_image()
				var economy := capture.get_region(Rect2i(top.get_global_rect()))
				_check(economy.save_png(capture_dir.path_join("rts-%s-%d.png" % [locale, viewport.x])) == OK, "failed to save native economy capture")

	var director := game.audio_director as AudioDirector
	director._music_player.stop()
	for player: AudioStreamPlayer in director._players:
		player.stop()
	await create_timer(0.35).timeout
	for player: AudioStreamPlayer in director._players:
		player.stream = null
	director._music_player.stream = null
	game.queue_free()
	await _settle()
	for path: String in owned_save_paths:
		for extension: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + extension):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + extension))
	I18n.set_locale(&"en-US")
	if failures.is_empty():
		print("PASS economy_typography_test: all localized long counters remain visible across portrait and landscape")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _settle() -> void:
	for frame: int in range(4):
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
