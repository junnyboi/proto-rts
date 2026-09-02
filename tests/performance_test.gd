extends SceneTree

const MAX_P95_DRAW_US := 16_700

class PerfBattlefield extends Battlefield:
	var draw_durations: Array[int] = []

	func _draw() -> void:
		var started := Time.get_ticks_usec()
		super._draw()
		draw_durations.append(Time.get_ticks_usec() - started)


class PerfMinimap extends BattlefieldMinimap:
	var draw_durations: Array[int] = []

	func _draw() -> void:
		var started := Time.get_ticks_usec()
		super._draw()
		draw_durations.append(Time.get_ticks_usec() - started)


func _initialize() -> void:
	call_deferred("_run")


func _p95(samples: Array[int]) -> int:
	var usable := samples.slice(maxi(0, samples.size() - 60))
	usable.sort()
	if usable.is_empty():
		return 0
	return usable[int(float(usable.size() - 1) * 0.95)]


func _mean(samples: Array[int]) -> float:
	var usable := samples.slice(maxi(0, samples.size() - 60))
	if usable.is_empty():
		return 0.0
	var total := 0
	for value in usable:
		total += value
	return float(total) / float(usable.size())


func _collect_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await process_frame


func _run() -> void:
	var failures: Array[String] = []
	var simulation := RtsSimulation.new()
	simulation.setup(&"human", false)
	var battlefield := PerfBattlefield.new()
	battlefield.size = Vector2(1280.0, 720.0)
	root.add_child(battlefield)
	battlefield.set_simulation(simulation)
	var minimap := PerfMinimap.new()
	minimap.size = Vector2(208.0, 132.0)
	minimap.set_battlefield(battlefield)
	root.add_child(minimap)

	battlefield.set_fog_enabled(false)
	battlefield.camera_scale = 0.15
	battlefield.center_on_cell(MapCatalog.SIZE / 2)
	await _collect_frames(140)
	var full_map_p95 := _p95(battlefield.draw_durations)
	var full_map_mean := _mean(battlefield.draw_durations)
	var minimap_clear_p95 := _p95(minimap.draw_durations)
	if full_map_p95 > MAX_P95_DRAW_US:
		failures.append("fog-off full-map Battlefield p95 draw exceeded budget: %d us" % full_map_p95)
	if minimap_clear_p95 > MAX_P95_DRAW_US:
		failures.append("fog-off minimap p95 draw exceeded budget: %d us" % minimap_clear_p95)

	battlefield.set_fog_enabled(true)
	battlefield.camera_scale = 0.62
	battlefield.center_on_player_stronghold()
	battlefield.draw_durations.clear()
	minimap.draw_durations.clear()
	await _collect_frames(140)
	var starting_p95 := _p95(battlefield.draw_durations)
	var starting_mean := _mean(battlefield.draw_durations)
	var minimap_fog_p95 := _p95(minimap.draw_durations)
	if starting_p95 > MAX_P95_DRAW_US:
		failures.append("fog-on starting-view Battlefield p95 draw exceeded budget: %d us" % starting_p95)
	if minimap_fog_p95 > MAX_P95_DRAW_US:
		failures.append("fog-on minimap p95 draw exceeded budget: %d us" % minimap_fog_p95)

	print(
		"PERF entities=%d trees=%d battlefield_full_mean_us=%.1f battlefield_full_p95_us=%d battlefield_start_mean_us=%.1f battlefield_start_p95_us=%d minimap_clear_p95_us=%d minimap_fog_p95_us=%d"
		% [simulation.entities.size(), MapCatalog.tree_definitions().size(), full_map_mean, full_map_p95, starting_mean, starting_p95, minimap_clear_p95, minimap_fog_p95]
	)
	battlefield.queue_free()
	minimap.queue_free()
	if failures.is_empty():
		print("PASS performance_test: 1,016-tree Battlefield and minimap p95 CPU draw remain within 16.7 ms")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
