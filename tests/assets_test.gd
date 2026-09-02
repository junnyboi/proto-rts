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
		FactionCatalog.entity_art_path(&"neutral", &"yaoguai_den"),
		FactionCatalog.entity_art_path(&"human", &"rice_farm"),
		FactionCatalog.entity_art_path(&"beast", &"hunters_lodge"),
		"res://assets/runtime/command_indicators/destination_flag.png",
		"res://assets/runtime/command_indicators/interaction_ring.png",
		"res://assets/runtime/command_indicators/attack_swords.png",
	]
	for wildlife_kind in FactionCatalog.WILDLIFE_KINDS:
		paths.append(FactionCatalog.entity_art_path(&"neutral", wildlife_kind))
	for cursor_state in CursorSystem.ORDER:
		paths.append("res://assets/runtime/cursors/%s.png" % cursor_state)
	for faction in FactionCatalog.ORDER:
		paths.append(FactionCatalog.portrait_path(faction))
		for kind in [&"worker", &"vanguard", &"mystic", &"stronghold", &"war_camp"]:
			paths.append(FactionCatalog.entity_art_path(faction, kind))
		if FactionCatalog.can_hunt(faction):
			paths.append(FactionCatalog.entity_art_path(faction, &"hunter"))
	for path in paths:
		if not ResourceLoader.exists(path) or load(path) == null:
			failures.append("missing or invalid runtime asset: %s" % path)
	if paths.size() != 70:
		failures.append("expected 70 runtime assets, enumerated %d" % paths.size())
	if failures.is_empty():
		print("PASS assets_test: 70 generated runtime assets resolve")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
