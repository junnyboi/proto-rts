extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var paths: Array[String] = [
		"res://assets/runtime/ui/mandate_of_myth_title.webp",
		"res://assets/runtime/terrain/jade_meadow.webp",
		"res://assets/runtime/terrain/inkstone_ridge.webp",
		"res://assets/runtime/terrain/celadon_water.webp",
		"res://assets/runtime/resources/jade_outcrop.png",
		"res://assets/runtime/resources/essence_shrine.png",
	]
	for faction in FactionCatalog.ORDER:
		paths.append(FactionCatalog.portrait_path(faction))
		for kind in [&"worker", &"vanguard", &"mystic", &"stronghold", &"war_camp"]:
			paths.append(FactionCatalog.entity_art_path(faction, kind))
	for path in paths:
		if not ResourceLoader.exists(path) or load(path) == null:
			failures.append("missing or invalid runtime asset: %s" % path)
	if paths.size() != 30:
		failures.append("expected 30 runtime assets, enumerated %d" % paths.size())
	if failures.is_empty():
		print("PASS assets_test: 30 generated runtime assets resolve")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
