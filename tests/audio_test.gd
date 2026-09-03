extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var director := AudioDirector.new()
	root.add_child(director)
	await process_frame

	if director.registered_cue_count() != 23:
		failures.append("expected 23 registered runtime SFX cues, got %d" % director.registered_cue_count())
	if director.sfx_voice_count() != AudioDirector.SFX_POOL_SIZE:
		failures.append("SFX pool does not match its bounded voice count")
	if not director.is_bgm_looping():
		failures.append("background music is not configured to loop")
	for bus_name in [&"Music", &"SFX", &"UI"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			failures.append("missing audio bus: %s" % bus_name)

	var representative_events := {
		&"structure_placed": {"type": &"build"},
		&"unit_ready": {"type": &"complete", "category": &"unit"},
		&"deposit_resource": {"type": &"deposit"},
		&"harvest_food": {"type": &"food"},
		&"repair_tick": {"type": &"repair"},
		&"attack_melee": {"type": &"attack", "attacker_kind": &"vanguard"},
		&"attack_ranged": {"type": &"attack", "attacker_kind": &"hunter"},
		&"attack_magic": {"type": &"attack", "attacker_kind": &"mystic"},
		&"attack_beast": {"type": &"attack", "attacker_kind": &"jadeclaw"},
		&"unit_death": {"type": &"death", "category": &"unit"},
		&"structure_destroyed": {"type": &"death", "category": &"structure"},
		&"objective_secured": {"type": &"capture"},
		&"ui_cancel": {"type": &"cancel"},
	}
	for expected_cue in representative_events:
		var actual := director.cue_for_event(representative_events[expected_cue] as Dictionary)
		if actual != expected_cue:
			failures.append("event mapped to %s instead of %s" % [actual, expected_cue])
	if not director.cue_for_event({"type": &"complete", "category": &"structure"}).is_empty():
		failures.append("structure completion still mapped to the disabled bronze-bell cue")
	if not director.cue_for_event({"type": &"gather", "resource_kind": &"jade"}).is_empty():
		failures.append("worker gather cycles still mapped to a repetitive work cue")

	var simulation := RtsSimulation.new()
	simulation.setup(&"human")
	var battlefield := Battlefield.new()
	root.add_child(battlefield)
	battlefield.set_simulation(simulation)
	if battlefield._event_is_audible({
		"type": &"attack",
		"team": RtsSimulation.TEAM_ENEMY,
		"to": Vector2(MapCatalog.ENEMY_STRONGHOLD),
	}):
		failures.append("hidden enemy event leaked through fog-of-war audio filtering")
	if not battlefield._event_is_audible({
		"type": &"gather",
		"team": RtsSimulation.TEAM_PLAYER,
		"position": Vector2(MapCatalog.PLAYER_STRONGHOLD),
	}):
		failures.append("player event was incorrectly filtered from audio")
	var selection_cues: Array[StringName] = []
	battlefield.audio_cue.connect(func(cue: StringName) -> void: selection_cues.append(cue))
	var worker_id := simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0]
	battlefield.select_entities([worker_id])
	if selection_cues != [&"unit_select"]:
		failures.append("player selection did not emit exactly one selection cue")
	var attacker_id := simulation._spawn_unit(RtsSimulation.TEAM_PLAYER, &"mystic", MapCatalog.PLAYER_WORKERS[0])
	var target_id := simulation._spawn_unit(RtsSimulation.TEAM_ENEMY, &"vanguard", MapCatalog.PLAYER_WORKERS[1])
	simulation._apply_attack(simulation.entity(attacker_id), simulation.entity(target_id))
	var emitted_events := simulation.drain_events()
	var attack_event: Dictionary = {}
	for emitted in emitted_events:
		if emitted.get("type") == &"attack":
			attack_event = emitted
			break
	if attack_event.get("attacker_kind") != &"mystic" or attack_event.get("team") != RtsSimulation.TEAM_PLAYER:
		failures.append("authoritative attack event omitted semantic audio metadata")
	director.clear_diagnostics()
	director.handle_simulation_event(attack_event)
	if director.playback_log != [&"attack_magic", &"impact_damage"]:
		failures.append("attack event did not layer its action and damage-impact cues")

	director.clear_diagnostics()
	if not director.play_cue(&"ui_confirm"):
		failures.append("valid UI cue was rejected")
	if director.play_cue(&"ui_confirm"):
		failures.append("per-cue cooldown did not suppress immediate repetition")
	if director.playback_log != [&"ui_confirm"]:
		failures.append("audio diagnostic log did not record the accepted cue exactly once")

	director.ensure_bgm()
	var music_player := director.get_node("Music") as AudioStreamPlayer
	var stream_before := music_player.stream
	var position_before := music_player.get_playback_position()
	director.set_music_state(&"match")
	await process_frame
	if music_player.stream != stream_before:
		failures.append("music state transition replaced the persistent stream")
	if music_player.get_playback_position() + 0.02 < position_before:
		failures.append("music state transition restarted playback")
	if not is_equal_approx(director.music_target_db, float(AudioDirector.STATE_MUSIC_DB[&"match"])):
		failures.append("match state did not select the intended music gain")

	var muted := director.toggle_muted()
	if not muted:
		failures.append("mute toggle did not enter the muted state")
	for bus_name in [&"Music", &"SFX", &"UI"]:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0 and not AudioServer.is_bus_mute(bus_index):
			failures.append("%s bus was not muted" % bus_name)
	director.toggle_muted()
	music_player.stop()
	for player in director._players:
		player.stop()
	await create_timer(0.15).timeout
	for player in director._players:
		player.stream = null
	music_player.stream = null
	stream_before = null
	root.remove_child(battlefield)
	battlefield.free()
	root.remove_child(director)
	director.free()
	await process_frame

	if failures.is_empty():
		print("PASS audio_test: 23 runtime SFX, persistent loop, semantic mapping, cooldowns, buses, and bounded voices")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
