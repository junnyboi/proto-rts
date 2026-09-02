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
	_expect(focus_owner is Button and (focus_owner as Button).text == "ENTER THE JADE MERIDIAN", "title screen did not focus its primary keyboard action", failures)

	game.call("_show_faction_select")
	await _settle()
	focus_owner = root.gui_get_focus_owner()
	_expect(focus_owner is Button and (focus_owner as Button).text == "COMMAND CELESTIAL COURT", "faction screen did not focus its first keyboard action", failures)

	if failures.is_empty():
		print("PASS ui_regression_test: title and faction keyboard focus")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
