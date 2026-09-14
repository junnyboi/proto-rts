extends SceneTree

const REFERENCE_SCRIPT := preload("res://tests/support/runtime_reference.gd")
const GRID_SCRIPT := preload("res://scripts/sim/spatial_grid.gd")
const SAMPLE_TICKS := 120
const WARMUP_TICKS := 30


func _initialize() -> void:
	call_deferred("_run")


func _measure(simulation: RtsSimulation) -> Dictionary:
	simulation.setup(&"human", true)
	for _tick in range(WARMUP_TICKS):
		simulation.advance(RtsSimulation.TICK_SECONDS)
		simulation.drain_events()
	var samples: Array[int] = []
	var total := 0
	for _tick in range(SAMPLE_TICKS):
		var started := Time.get_ticks_usec()
		simulation.advance(RtsSimulation.TICK_SECONDS)
		var elapsed := Time.get_ticks_usec() - started
		samples.append(elapsed)
		total += elapsed
		simulation.drain_events()
	samples.sort()
	return {"mean_us": float(total) / SAMPLE_TICKS, "p95_us": samples[int((samples.size() - 1) * 0.95)]}


func _run() -> void:
	var failures: Array[String] = []
	var fixture := RtsSimulation.new()
	fixture.setup(&"human", false)
	var unit_ids: Array[int] = []
	for raw_entity in fixture.entities.values():
		var entity_state := raw_entity as Dictionary
		if bool(entity_state.get("alive", false)) and entity_state.get("category") in [&"unit", &"wildlife"]:
			unit_ids.append(int(entity_state["id"]))
	unit_ids.sort()
	var grid := GRID_SCRIPT.new()
	grid.rebuild(unit_ids, fixture.entities)
	var candidate_count := 0
	for unit_id in unit_ids:
		candidate_count += grid.later_neighbors(unit_id, fixture.entity(unit_id)["position"] as Vector2).size()
	var all_pairs := unit_ids.size() * (unit_ids.size() - 1) / 2
	if candidate_count * 10 > all_pairs:
		failures.append("opening spatial broad phase no longer rejects at least 90%% of distant pairs: %d/%d" % [candidate_count, all_pairs])
	# Alternate run order to reduce first-run and short-lived scheduling bias.
	var actual_a := _measure(RtsSimulation.new())
	var reference_a := _measure(REFERENCE_SCRIPT.new())
	var reference_b := _measure(REFERENCE_SCRIPT.new())
	var actual_b := _measure(RtsSimulation.new())
	var actual_mean := (float(actual_a["mean_us"]) + float(actual_b["mean_us"])) * 0.5
	var reference_mean := (float(reference_a["mean_us"]) + float(reference_b["mean_us"])) * 0.5
	# A comparative smoke gate, not a hardware-independent FPS claim. Longer
	# before/after acceptance runs record the complete unchanged 60-second game.
	var report_only_timings := OS.get_environment("RTS_REPORT_ONLY_TIMINGS") == "1"
	if not report_only_timings and actual_mean > reference_mean * 0.9:
		failures.append("optimized active simulation lost its 10%% reference margin: %.1f vs %.1f us/tick" % [actual_mean, reference_mean])
	print("RUNTIME_PERF %s" % JSON.stringify({
		"fixture": "unchanged_four_player_opening",
		"ticks_per_run": SAMPLE_TICKS,
		"optimized_mean_us": actual_mean,
		"reference_mean_us": reference_mean,
		"optimized_p95_us": maxi(int(actual_a["p95_us"]), int(actual_b["p95_us"])),
		"reference_p95_us": maxi(int(reference_a["p95_us"]), int(reference_b["p95_us"])),
		"broad_phase_candidates_per_pass": candidate_count,
		"original_pairs_per_pass": all_pairs,
		"report_only_timings": report_only_timings,
	}))
	if failures.is_empty():
		print("PASS runtime_performance_test: unchanged-content timings recorded and distant separation pairs rejected (report_only_timings=%s)" % report_only_timings)
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
