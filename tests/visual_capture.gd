extends SceneTree

const OUTPUT := "res://captures"


func _initialize() -> void:
	call_deferred("_run")


func _settle(frames: int = 8) -> void:
	for _frame in range(frames):
		await process_frame


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
	game.call("_start_match", &"celestial")
	await _settle(20)
	_capture("skirmish")
	print("PASS visual_capture: title, faction-select, skirmish")
	quit(0)
