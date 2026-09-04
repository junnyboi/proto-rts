extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		push_error("clean scaffold could not load its main scene")
		quit(1)
		return
	var game := scene.instantiate()
	game.leaderboard_save_path = "user://clean_scaffold_leaderboard.json"
	game.tweak_save_path = "user://clean_scaffold_tweaks.json"
	game.tutorial_save_path = "user://clean_scaffold_tutorial.json"
	root.add_child(game)
	for _frame in range(6):
		await process_frame
	if game.state != &"title" or game._screen == null:
		push_error("clean scaffold did not boot to the title route")
		quit(1)
		return
	var director := game.audio_director as AudioDirector
	director._music_player.stop()
	for player: AudioStreamPlayer in director._players:
		player.stop()
	await create_timer(0.15).timeout
	for player: AudioStreamPlayer in director._players:
		player.stream = null
	director._music_player.stream = null
	game.queue_free()
	for _frame in range(3):
		await process_frame
	for path in [
		"user://clean_scaffold_leaderboard.json",
		"user://clean_scaffold_tweaks.json",
		"user://clean_scaffold_tutorial.json",
	]:
		for candidate in [path, "%s.bak" % path, "%s.tmp" % path]:
			if FileAccess.file_exists(candidate):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	print("PASS template_boot_test: clean scaffold boots to a usable title route")
	quit(0)
