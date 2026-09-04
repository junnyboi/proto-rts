extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var failures: Array[String] = []
	var save_path := "user://tutorial_test_%d.json" % Time.get_ticks_usec()
	var director := TutorialDirector.new()
	root.add_child(director)
	director.setup(save_path)
	_expect(director.start_run(), "first run did not start the tutorial", failures)
	_expect(director.current_step_id() == &"select", "tutorial did not begin at selection", failures)
	director.advance(99.0, true)
	_expect(not bool(director.snapshot().get("fallback_active", false)), "tutorial timeout advanced while the match was paused", failures)
	director.advance(31.0)
	_expect(bool(director.snapshot().get("fallback_active", false)), "tutorial timeout did not reveal fallback guidance", failures)
	director.set_input_method(InputRouter.GAMEPAD)
	_expect(director.snapshot().get("input_method") == InputRouter.GAMEPAD, "tutorial did not track the active input method", failures)
	for event_name: StringName in [
		&"select_player",
		&"command_issued",
		&"production_ordered",
		&"objective_progressed",
		&"pause_opened",
		&"tweak_opened",
	]:
		_expect(director.notify_event(event_name), "tutorial rejected event %s" % event_name, failures)
	_expect(director.is_completed() and not director.is_active(), "tutorial did not persist completion", failures)

	var restored := TutorialDirector.new()
	root.add_child(restored)
	restored.setup(save_path)
	_expect(not restored.start_run(), "completed tutorial replayed without an explicit request", failures)
	restored.replay_next_run()
	_expect(restored.start_run(), "explicit tutorial replay did not arm the next run", failures)
	restored.skip()
	_expect(restored.is_completed(), "skipping did not persist completion", failures)

	director.queue_free()
	restored.queue_free()
	await process_frame
	_cleanup(save_path)
	if failures.is_empty():
		print("PASS tutorial_test: first-run guidance, contextual fallback, input prompts, progression, persistence, replay, and skip")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _cleanup(path: String) -> void:
	for candidate: String in [path, "%s.tmp" % path]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
