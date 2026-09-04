extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://template.json"))
	if not (parsed is Dictionary):
		failures.append("template.json is missing or invalid JSON")
	else:
		var metadata := parsed as Dictionary
		if metadata.get("id") != "game-template-rts-mandate-of-myth":
			failures.append("template metadata ID is not stable and unique")
		if metadata.get("kind") != "game" or metadata.get("game_genre") != "rts":
			failures.append("template metadata kind or genre is invalid")
		if metadata.get("status") != "ready":
			failures.append("template metadata is not marked ready")
		if String(metadata.get("name", "")).is_empty() or String(metadata.get("description", "")).is_empty():
			failures.append("template metadata lacks name or description")
		if metadata.get("capabilities", []) != ["static"]:
			failures.append("template metadata capability set must be exactly static")
	for required_path in [
		"res://project.godot",
		"res://export_presets.cfg",
		"res://assets.lock.json",
		"res://assets/runtime/backgrounds/jade_meridian_backdrop.webp",
		"res://assets/runtime/foregrounds/jade_meridian_foreground.png",
		"res://assets/runtime/ui/mandate_pause_frame.png",
		"res://scripts/tutorial/tutorial_director.gd",
		"res://scripts/input/input_router.gd",
	]:
		if not FileAccess.file_exists(required_path):
			failures.append("template package is missing %s" % required_path)
	if failures.is_empty():
		print("PASS template_metadata_test: ready RTS metadata and required package seams")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
