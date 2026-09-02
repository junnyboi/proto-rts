extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	for cell in [Vector2i.ZERO, Vector2i(1, 1), Vector2i(7, 3), Vector2i(19, 15)]:
		var picked := IsoProjection.cell_at(IsoProjection.cell_center(cell))
		if picked != cell:
			failures.append("center round-trip failed for %s -> %s" % [cell, picked])
	var sample := Vector2(6.25, 9.75)
	var restored := IsoProjection.unproject(IsoProjection.project(sample))
	if restored.distance_to(sample) > 0.0001:
		failures.append("continuous round-trip failed: %s -> %s" % [sample, restored])
	var bounds := IsoProjection.map_bounds(MapCatalog.SIZE)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		failures.append("map bounds are empty")
	if failures.is_empty():
		print("PASS projection_test: centers, continuous inverse, and bounds")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
