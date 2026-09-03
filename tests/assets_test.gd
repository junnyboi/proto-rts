extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var paths: Array[String] = [
		"res://assets/runtime/ui/mandate_of_myth_title.webp",
		"res://assets/runtime/ui/idle_worker_alert.png",
		"res://assets/runtime/terrain/jade_meadow.webp",
		"res://assets/runtime/terrain/inkstone_ridge.webp",
		"res://assets/runtime/terrain/celadon_water.webp",
		"res://assets/runtime/terrain/jade_forest.webp",
		"res://assets/runtime/terrain/meridian_road.webp",
		"res://assets/runtime/terrain/moon_bridge.webp",
		"res://assets/runtime/resources/jade_outcrop.png",
		"res://assets/runtime/resources/essence_shrine.png",
		"res://assets/runtime/resources/lumber_pine.png",
		"res://assets/runtime/resources/lumber_cedar.png",
		"res://assets/runtime/resources/lumber_fir.png",
		"res://assets/runtime/resources/lumber_juniper.png",
		FactionCatalog.entity_art_path(&"neutral", &"jadeclaw"),
		FactionCatalog.entity_art_path(&"neutral", &"shenlong"),
		FactionCatalog.entity_art_path(&"neutral", &"shenlong_egg"),
		FactionCatalog.entity_art_path(&"neutral", &"yaoguai_den"),
		FactionCatalog.entity_art_path(&"human", &"rice_farm"),
		FactionCatalog.entity_art_path(&"beast", &"hunters_lodge"),
		"res://assets/runtime/command_indicators/destination_flag.png",
		"res://assets/runtime/command_indicators/interaction_ring.png",
		"res://assets/runtime/command_indicators/attack_swords.png",
		"res://assets/runtime/audio/bgm/the_jade_meridian_endures.ogg",
	]
	for audio_name in [
		"attack_beast", "attack_magic", "attack_melee", "attack_ranged",
		"defeat", "deposit_resource", "harvest_food",
		"impact_damage", "objective_secured", "order_attack", "order_move",
		"order_work", "repair_tick", "structure_complete", "structure_destroyed",
		"structure_placed", "ui_cancel", "ui_confirm", "ui_error",
		"unit_death", "unit_ready", "unit_select", "victory",
	]:
		paths.append("res://assets/runtime/audio/sfx/%s.ogg" % audio_name)
	for wildlife_kind in FactionCatalog.WILDLIFE_KINDS:
		paths.append(FactionCatalog.entity_art_path(&"neutral", wildlife_kind))
	for cursor_state in CursorSystem.ORDER:
		paths.append("res://assets/runtime/cursors/%s.png" % cursor_state)
	for resource_icon in [&"jade", &"lumber", &"essence", &"food", &"population", &"dens"]:
		paths.append("res://assets/runtime/ui/resource_icons/%s.png" % resource_icon)
	for utility_icon in [&"pause", &"resume", &"audio_on", &"audio_muted"]:
		paths.append("res://assets/runtime/ui/utility_icons/%s.png" % utility_icon)
	for faction in FactionCatalog.ORDER:
		paths.append(FactionCatalog.portrait_path(faction))
		for kind in [&"worker", &"vanguard", &"mystic", &"stronghold", &"war_camp"]:
			paths.append(FactionCatalog.entity_art_path(faction, kind))
		if FactionCatalog.can_hunt(faction):
			paths.append(FactionCatalog.entity_art_path(faction, &"hunter"))
	for path in paths:
		if not ResourceLoader.exists(path) or load(path) == null:
			failures.append("missing or invalid runtime asset: %s" % path)
	var retired_gather_sfx := "res://assets/runtime/audio/sfx/gather_resource.ogg"
	if ResourceLoader.exists(retired_gather_sfx):
		failures.append("retired worker gather SFX still exists: %s" % retired_gather_sfx)
	if paths.size() != 106:
		failures.append("expected 106 runtime assets, enumerated %d" % paths.size())
	if failures.is_empty():
		print("PASS assets_test: 106 generated runtime assets resolve")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
