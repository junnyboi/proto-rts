extends SceneTree

const CATALOG := preload("res://config/tweaks/catalog.gd")
const SERVICE_SCRIPT := preload("res://scripts/tuning/tweak_service.gd")

var _boundary_service: TweakService
var _boundary_simulation: RtsSimulation


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var failures: Array[String] = []
	var save_path := "user://tweak_service_test_%d.json" % Time.get_ticks_usec()
	_cleanup(save_path)
	var service := SERVICE_SCRIPT.new() as TweakService
	root.add_child(service)
	service.setup(save_path)

	_expect(CATALOG.validation_errors().is_empty(), "tweak catalog contract is invalid", failures)
	var found_categories := {}
	for descriptor: Dictionary in CATALOG.descriptors():
		found_categories[descriptor["category"]] = true
		for required_field: String in ["id", "category", "type", "default", "apply_mode", "integrity", "label_key", "description_key"]:
			_expect(descriptor.has(required_field), "descriptor %s lacks %s" % [descriptor.get("id", "unknown"), required_field], failures)
	for category: StringName in CATALOG.CATEGORIES:
		_expect(found_categories.has(category), "catalog omits category %s" % category, failures)

	_expect(not service.set_requested(&"ui.hud.scale", 9.0), "out-of-range value was accepted", failures)
	_expect(is_equal_approx(float(service.requested_value(&"ui.hud.scale")), 1.0), "invalid value changed requested state", failures)
	_expect(service.set_requested(&"ui.hud.scale", 1.15), "valid live value was rejected", failures)
	_expect(is_equal_approx(float(service.active_value(&"ui.hud.scale")), 1.15), "live value did not activate immediately", failures)
	_expect(service.run_is_rank_eligible(), "cosmetic live value tainted an inactive run", failures)

	service.begin_run()
	service.set_requested(&"gameplay.build.duration_multiplier", 1.5)
	_expect(is_equal_approx(float(service.active_value(&"gameplay.build.duration_multiplier")), 1.0), "deferred order value activated early", failures)
	_expect(service.run_is_rank_eligible(), "requested but unapplied gameplay value tainted the run", failures)
	service.apply_boundary(CATALOG.NEXT_ACTION)
	_expect(is_equal_approx(float(service.active_value(&"gameplay.build.duration_multiplier")), 1.5), "next-order boundary did not activate the request", failures)
	_expect(not service.run_is_rank_eligible(), "applied gameplay value did not taint the run", failures)
	service.reset_control(&"gameplay.build.duration_multiplier")
	service.apply_boundary(CATALOG.NEXT_ACTION)
	_expect(not service.run_is_rank_eligible(), "reset erased sticky run taint", failures)
	_expect(service.run_configuration_marker().contains("gameplay.build.duration_multiplier"), "run marker omitted the applied gameplay tweak", failures)

	service.end_run()
	service.reset_all()
	service.apply_boundary(CATALOG.NEXT_ACTION)
	service.apply_boundary(CATALOG.NEXT_SPAWN)
	service.set_requested(&"gameplay.resource.starting_multiplier", 1.5)
	service.set_requested(&"gameplay.score.multiplier", 2.0)
	service.set_requested(&"player.move.speed_multiplier", 1.5)
	service.set_requested(&"enemies.health.multiplier", 1.5)
	service.begin_run()
	var simulation := RtsSimulation.new()
	_boundary_service = service
	_boundary_simulation = simulation
	simulation.tweak_boundary_reached.connect(_on_simulation_tweak_boundary)
	simulation.set_tweak_values(service.active_values())
	simulation.setup(&"celestial", false)
	_expect(int(simulation.players[RtsSimulation.TEAM_PLAYER]["jade"]) == 480, "next-run starting-resource tweak did not reach simulation setup", failures)
	var player_worker := simulation.entity(simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"])[0])
	var base_player_speed := float(FactionCatalog.stats(&"worker", &"celestial")["speed"])
	_expect(is_equal_approx(float(player_worker["speed"]), base_player_speed * 1.5), "next-spawn player speed tweak did not reach spawned units", failures)
	var enemy_worker := simulation.entity(simulation.team_entity_ids(RtsSimulation.TEAM_ENEMY, [&"worker"])[0])
	var enemy_faction := simulation.players[RtsSimulation.TEAM_ENEMY]["faction"] as StringName
	var base_enemy_health := float(FactionCatalog.stats(&"worker", enemy_faction)["max_hp"])
	_expect(is_equal_approx(float(enemy_worker["max_hp"]), base_enemy_health * 1.5), "next-spawn enemy health tweak did not reach spawned units", failures)
	simulation._award_score(RtsSimulation.TEAM_PLAYER, &"resources_earned", 10)
	_expect(simulation.team_score(RtsSimulation.TEAM_PLAYER) == 20, "next-run score multiplier did not affect authoritative scoring", failures)
	simulation.tweak_boundary_reached.disconnect(_on_simulation_tweak_boundary)
	_boundary_simulation = null
	_boundary_service = null
	simulation = null
	service.end_run()
	service.reset_all()
	service.apply_boundary(CATALOG.NEXT_ACTION)
	service.apply_boundary(CATALOG.NEXT_SPAWN)
	service.apply_boundary(CATALOG.NEXT_RUN)
	service.begin_run()
	service.set_requested(&"environment.filter.enabled", true)
	_expect(service.run_is_rank_eligible(), "cosmetic filter change tainted a run", failures)
	service.end_run()

	var persisted: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	_expect(persisted is Dictionary, "persisted tweak file is malformed", failures)
	if persisted is Dictionary:
		var values := (persisted as Dictionary).get("values", {}) as Dictionary
		_expect(values.size() == 1 and bool(values.get("environment.filter.enabled", false)), "persistence did not retain only the validated non-default delta", failures)

	var restored := SERVICE_SCRIPT.new() as TweakService
	root.add_child(restored)
	restored.setup(save_path)
	_expect(bool(restored.active_value(&"environment.filter.enabled")), "persisted live value was not restored", failures)
	_expect(is_equal_approx(float(restored.requested_value(&"gameplay.build.duration_multiplier")), 1.0), "baseline value was unnecessarily persisted", failures)

	root.remove_child(restored)
	restored.free()
	root.remove_child(service)
	service.free()
	_cleanup(save_path)

	if failures.is_empty():
		print("PASS tweak_service_test: catalog, validation, persistence, boundaries, and sticky integrity taint")
		quit(0)
		return
	for failure: String in failures:
		push_error(failure)
	quit(1)


func _cleanup(path: String) -> void:
	for candidate: String in [path, "%s.tmp" % path]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))


func _on_simulation_tweak_boundary(mode: StringName) -> void:
	_boundary_service.apply_boundary(mode)
	_boundary_simulation.set_tweak_values(_boundary_service.active_values())
