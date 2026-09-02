class_name AudioDirector
extends Node

const BGM_STREAM := preload("res://assets/runtime/audio/bgm/the_jade_meridian_endures.ogg")
const SFX_STREAMS := {
	&"ui_confirm": preload("res://assets/runtime/audio/sfx/ui_confirm.ogg"),
	&"ui_cancel": preload("res://assets/runtime/audio/sfx/ui_cancel.ogg"),
	&"ui_error": preload("res://assets/runtime/audio/sfx/ui_error.ogg"),
	&"unit_select": preload("res://assets/runtime/audio/sfx/unit_select.ogg"),
	&"order_move": preload("res://assets/runtime/audio/sfx/order_move.ogg"),
	&"order_attack": preload("res://assets/runtime/audio/sfx/order_attack.ogg"),
	&"order_work": preload("res://assets/runtime/audio/sfx/order_work.ogg"),
	&"gather_resource": preload("res://assets/runtime/audio/sfx/gather_resource.ogg"),
	&"deposit_resource": preload("res://assets/runtime/audio/sfx/deposit_resource.ogg"),
	&"harvest_food": preload("res://assets/runtime/audio/sfx/harvest_food.ogg"),
	&"repair_tick": preload("res://assets/runtime/audio/sfx/repair_tick.ogg"),
	&"structure_placed": preload("res://assets/runtime/audio/sfx/structure_placed.ogg"),
	&"structure_complete": preload("res://assets/runtime/audio/sfx/structure_complete.ogg"),
	&"unit_ready": preload("res://assets/runtime/audio/sfx/unit_ready.ogg"),
	&"attack_melee": preload("res://assets/runtime/audio/sfx/attack_melee.ogg"),
	&"attack_ranged": preload("res://assets/runtime/audio/sfx/attack_ranged.ogg"),
	&"attack_magic": preload("res://assets/runtime/audio/sfx/attack_magic.ogg"),
	&"attack_beast": preload("res://assets/runtime/audio/sfx/attack_beast.ogg"),
	&"impact_damage": preload("res://assets/runtime/audio/sfx/impact_damage.ogg"),
	&"unit_death": preload("res://assets/runtime/audio/sfx/unit_death.ogg"),
	&"structure_destroyed": preload("res://assets/runtime/audio/sfx/structure_destroyed.ogg"),
	&"objective_secured": preload("res://assets/runtime/audio/sfx/objective_secured.ogg"),
	&"victory": preload("res://assets/runtime/audio/sfx/victory.ogg"),
	&"defeat": preload("res://assets/runtime/audio/sfx/defeat.ogg"),
}

const CUE_POLICY := {
	&"ui_confirm": {"bus": &"UI", "volume": -2.0, "pitch": 0.015, "cooldown": 0.05, "priority": 2, "max": 2},
	&"ui_cancel": {"bus": &"UI", "volume": -2.0, "pitch": 0.01, "cooldown": 0.05, "priority": 2, "max": 2},
	&"ui_error": {"bus": &"UI", "volume": -1.0, "pitch": 0.0, "cooldown": 0.15, "priority": 3, "max": 1},
	&"unit_select": {"bus": &"UI", "volume": -5.0, "pitch": 0.025, "cooldown": 0.10, "priority": 1, "max": 1},
	&"order_move": {"bus": &"SFX", "volume": -3.0, "pitch": 0.025, "cooldown": 0.10, "priority": 2, "max": 2},
	&"order_attack": {"bus": &"SFX", "volume": -2.0, "pitch": 0.02, "cooldown": 0.10, "priority": 2, "max": 2},
	&"order_work": {"bus": &"SFX", "volume": -3.0, "pitch": 0.025, "cooldown": 0.10, "priority": 2, "max": 2},
	&"gather_resource": {"bus": &"SFX", "volume": -10.0, "pitch": 0.035, "cooldown": 0.32, "priority": 0, "max": 2},
	&"deposit_resource": {"bus": &"SFX", "volume": -6.0, "pitch": 0.025, "cooldown": 0.25, "priority": 1, "max": 2},
	&"harvest_food": {"bus": &"SFX", "volume": -9.0, "pitch": 0.025, "cooldown": 0.40, "priority": 0, "max": 2},
	&"repair_tick": {"bus": &"SFX", "volume": -9.0, "pitch": 0.035, "cooldown": 0.32, "priority": 0, "max": 2},
	&"structure_placed": {"bus": &"SFX", "volume": -4.0, "pitch": 0.01, "cooldown": 0.15, "priority": 2, "max": 2},
	&"structure_complete": {"bus": &"SFX", "volume": -2.5, "pitch": 0.01, "cooldown": 0.25, "priority": 2, "max": 2},
	&"unit_ready": {"bus": &"SFX", "volume": -3.0, "pitch": 0.02, "cooldown": 0.20, "priority": 2, "max": 2},
	&"attack_melee": {"bus": &"SFX", "volume": -7.0, "pitch": 0.04, "cooldown": 0.08, "priority": 1, "max": 3},
	&"attack_ranged": {"bus": &"SFX", "volume": -7.0, "pitch": 0.035, "cooldown": 0.08, "priority": 1, "max": 3},
	&"attack_magic": {"bus": &"SFX", "volume": -6.0, "pitch": 0.03, "cooldown": 0.10, "priority": 1, "max": 3},
	&"attack_beast": {"bus": &"SFX", "volume": -6.0, "pitch": 0.04, "cooldown": 0.10, "priority": 1, "max": 3},
	&"impact_damage": {"bus": &"SFX", "volume": -10.0, "pitch": 0.04, "cooldown": 0.06, "priority": 0, "max": 3},
	&"unit_death": {"bus": &"SFX", "volume": -4.0, "pitch": 0.025, "cooldown": 0.12, "priority": 2, "max": 3},
	&"structure_destroyed": {"bus": &"SFX", "volume": -1.0, "pitch": 0.01, "cooldown": 0.30, "priority": 3, "max": 2},
	&"objective_secured": {"bus": &"SFX", "volume": -1.5, "pitch": 0.0, "cooldown": 0.35, "priority": 3, "max": 2},
	&"victory": {"bus": &"UI", "volume": 0.0, "pitch": 0.0, "cooldown": 1.0, "priority": 3, "max": 1},
	&"defeat": {"bus": &"UI", "volume": 0.0, "pitch": 0.0, "cooldown": 1.0, "priority": 3, "max": 1},
}

const SFX_POOL_SIZE := 16
const STATE_MUSIC_DB := {
	&"title": -13.0,
	&"faction": -14.0,
	&"match": -15.0,
	&"paused": -19.0,
	&"result": -21.0,
}

var muted := false
var playback_log: Array[StringName] = []
var music_state: StringName = &"title"
var music_target_db := -13.0

var _music_player: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _player_cues: Dictionary = {}
var _player_priorities: Dictionary = {}
var _player_started_ms: Dictionary = {}
var _cooldown_until_ms: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _music_tween: Tween


func _ready() -> void:
	_rng.seed = 0x4D414E44415445
	_build_music_player()
	_build_sfx_pool()
	_apply_bus_mutes()


func _build_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.bus = &"Music"
	_music_player.volume_db = music_target_db
	var loop_stream := BGM_STREAM.duplicate() as AudioStreamOggVorbis
	loop_stream.loop = true
	_music_player.stream = loop_stream
	add_child(_music_player)


func _build_sfx_pool() -> void:
	for index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxVoice%02d" % index
		player.max_polyphony = 1
		add_child(player)
		_players.append(player)


func ensure_bgm() -> void:
	if muted or _music_player == null or _music_player.playing:
		return
	_music_player.play()


func set_music_state(next_state: StringName) -> void:
	music_state = next_state
	music_target_db = float(STATE_MUSIC_DB.get(next_state, STATE_MUSIC_DB[&"match"]))
	if _music_player == null:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_music_tween.tween_property(_music_player, "volume_db", music_target_db, 0.35)


func toggle_muted() -> bool:
	muted = not muted
	_apply_bus_mutes()
	if not muted:
		ensure_bgm()
	return muted


func _apply_bus_mutes() -> void:
	for bus_name in [&"Music", &"SFX", &"UI"]:
		var index := AudioServer.get_bus_index(bus_name)
		if index >= 0:
			AudioServer.set_bus_mute(index, muted)


func play_ui(cue: StringName) -> bool:
	return play_cue(cue)


func play_cue(cue: StringName) -> bool:
	if muted or not SFX_STREAMS.has(cue):
		return false
	var policy := CUE_POLICY.get(cue, {}) as Dictionary
	var now := Time.get_ticks_msec()
	if now < int(_cooldown_until_ms.get(cue, 0)):
		return false
	if _active_instances(cue) >= int(policy.get("max", 2)):
		return false
	var priority := int(policy.get("priority", 1))
	var player := _available_player(priority)
	if player == null:
		return false
	var cooldown_ms := int(round(float(policy.get("cooldown", 0.1)) * 1000.0))
	_cooldown_until_ms[cue] = now + cooldown_ms
	var pitch_variance := float(policy.get("pitch", 0.0))
	player.stop()
	player.stream = SFX_STREAMS[cue] as AudioStream
	player.bus = policy.get("bus", &"SFX") as StringName
	player.volume_db = float(policy.get("volume", -4.0))
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_variance, pitch_variance)
	var id := player.get_instance_id()
	_player_cues[id] = cue
	_player_priorities[id] = priority
	_player_started_ms[id] = now
	player.play()
	playback_log.append(cue)
	if playback_log.size() > 128:
		playback_log.pop_front()
	return true


func _active_instances(cue: StringName) -> int:
	var result := 0
	for player in _players:
		if player.playing and _player_cues.get(player.get_instance_id(), &"") == cue:
			result += 1
	return result


func _available_player(requested_priority: int) -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	var oldest: AudioStreamPlayer
	var oldest_started := Time.get_ticks_msec() + 1
	for player in _players:
		var id := player.get_instance_id()
		if int(_player_priorities.get(id, 0)) > requested_priority:
			continue
		var started := int(_player_started_ms.get(id, 0))
		if started < oldest_started:
			oldest = player
			oldest_started = started
	return oldest


func cue_for_event(event: Dictionary) -> StringName:
	var event_type := event.get("type", &"") as StringName
	match event_type:
		&"build":
			return &"structure_placed"
		&"complete":
			return &"unit_ready" if event.get("category") == &"unit" else &"structure_complete"
		&"gather":
			return &"gather_resource"
		&"deposit":
			return &"deposit_resource"
		&"food":
			return &"harvest_food"
		&"repair":
			return &"repair_tick"
		&"capture", &"cave_cleared", &"bounty":
			return &"objective_secured"
		&"cancel":
			return &"ui_cancel"
		&"death":
			return &"structure_destroyed" if event.get("category") == &"structure" else &"unit_death"
		&"attack":
			var attacker_kind := event.get("attacker_kind", &"") as StringName
			match attacker_kind:
				&"hunter":
					return &"attack_ranged"
				&"mystic":
					return &"attack_magic"
				&"jadeclaw", &"boar", &"bear":
					return &"attack_beast"
				_:
					return &"attack_melee"
	return &""


func handle_simulation_event(event: Dictionary) -> bool:
	var cue := cue_for_event(event)
	var played := false if cue.is_empty() else play_cue(cue)
	if event.get("type") == &"attack":
		played = play_cue(&"impact_damage") or played
	return played


func play_outcome(result: StringName) -> bool:
	set_music_state(&"result")
	return play_cue(&"victory" if result == &"victory" else &"defeat")


func is_bgm_looping() -> bool:
	return (
		_music_player != null
		and _music_player.stream is AudioStreamOggVorbis
		and (_music_player.stream as AudioStreamOggVorbis).loop
	)


func sfx_voice_count() -> int:
	return _players.size()


func registered_cue_count() -> int:
	return SFX_STREAMS.size()


func clear_diagnostics() -> void:
	playback_log.clear()
	_cooldown_until_ms.clear()
