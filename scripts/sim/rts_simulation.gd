class_name RtsSimulation
extends RefCounted

signal match_ended(result: StringName)
signal state_changed
signal battle_notice(key: StringName, placeholder_values: Dictionary, team: int)
signal tweak_boundary_reached(mode: StringName)

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const TEAM_RIVAL_TWO := 2
const TEAM_RIVAL_THREE := 3
const TEAM_NEUTRAL := -1
const TEAM_COUNT := 4
const POPULATION_CAP := 24
const STRONGHOLD_INITIAL_LEVEL := 1
const STRONGHOLD_MAX_LEVEL := 3
const STRONGHOLD_POPULATION_PER_UPGRADE := 6
const STRONGHOLD_UPGRADE_COSTS := {
	2: 200,
	3: 300,
}
const DEMOLITION_REFUND_RATE := 0.5
const TICK_SECONDS := 1.0 / 30.0
const GATHER_CYCLE := 0.8
const CARGO_CAPACITY := 50.0
const GATHER_AMOUNT := 10.0
const WORKER_INTERACTION_RANGE := 1.25
const GARRISON_INTERACTION_RANGE := 1.35
const GARRISON_RANGE_MULTIPLIER := 2.0
const EGG_INTERACTION_RANGE := 1.4
const REPAIR_CYCLE := 0.5
const REPAIR_AMOUNT := 15.0
const REPAIR_LUMBER_COST := 1
const REPAIR_NOTICE_SECONDS := 2.0
const UNIT_SEPARATION_DISTANCE := 0.62
const UNIT_SEPARATION_ITERATIONS := 2
const UNIT_SEPARATION_STIFFNESS := 85.0
const UNIT_SEPARATION_DAMPING := 12.0
const UNIT_SEPARATION_MAX_SPEED := 2.0
const UNIT_SEPARATION_STOP_SPEED := 0.01
const WORKER_SEPARATION_STIFFNESS := 58.0
const WORKER_SEPARATION_DAMPING := 16.0
const WORKER_SEPARATION_MAX_SPEED := 0.95
const COMBAT_SEPARATION_STIFFNESS := 108.0
const COMBAT_SEPARATION_DAMPING := 9.5
const COMBAT_SEPARATION_MAX_SPEED := 2.35
const RANGED_REPOSITION_MIN_RANGE := 2.0
const STRUCTURE_VISION_RADIUS := 6
const MYSTIC_VISION_RADIUS := 5
const DEFAULT_VISION_RADIUS := 4
const CAVE_CAPTURE_SECONDS := 6.0
const CAVE_CAPTURE_RADIUS := 2.8
const GUARDIAN_LEASH_RADIUS := 5.5
const GUARDIAN_WANDER_RADIUS := 3.0
const GUARDIAN_WANDER_MIN_DELAY := 1.4
const GUARDIAN_WANDER_MAX_DELAY := 3.2
const GUARDIAN_WANDER_SEED := 0x4D595448
const WILDLIFE_WANDER_MIN_DELAY := 1.8
const WILDLIFE_WANDER_MAX_DELAY := 4.5
const WILDLIFE_WANDER_SEED := 0x57494C44
const WILDLIFE_REGENERATION_CYCLE_SECONDS := 5.0 * 60.0
const WILDLIFE_FLEE_DISTANCE := 4.5
const WILDLIFE_RETALIATION_LEASH_BONUS := 3.0
const HUNTER_WILDLIFE_DAMAGE_MULTIPLIER := 3.0
const FARM_WORKER_FOOD_MULTIPLIER := 5
# One staffed Farm yields 720 Food over this horizon; one quarter of the map's
# wildlife bounties plus a Lodge's passive yield produces 723.2 Food.
const FOOD_BALANCE_HORIZON_SECONDS := 12.0 * 60.0
const HUNTER_WANDER_MIN_DELAY := 0.8
const HUNTER_WANDER_MAX_DELAY := 1.6
const HUNTER_WANDER_SEED := 0x48554E54
# Covers each corner island's safe herd without reaching central hunting grounds.
const HUNTER_HOME_GAME_RADIUS := 14.0
const HUNTER_COMBAT_EVADE_DISTANCE := 5.0
const HUNTER_COMBAT_EVADE_REPATH_SECONDS := 0.55
const PATH_RECOVERY_RETRY_SECONDS := 0.55
const AI_INITIAL_ASSAULT_DELAY := 20.0
const AI_ASSAULT_INTERVAL := 28.0
const AI_ASSAULT_MIN_READY_UNITS := 4
const AI_ASSAULT_WAVE_SIZE := 3
const AI_SHENLONG_MIN_READY_UNITS := 8
const AI_SHENLONG_UNLOCK_TIME_SECONDS := 10.0 * 60.0
const AI_SHENLONG_AVOID_RADIUS := 9.0
const AI_SKILL_TEST_TIME_SECONDS := 60.0 * 60.0
const AI_RESOURCE_KINDS: Array[StringName] = [&"jade", &"lumber", &"essence"]
const AI_RESOURCE_RESERVES := {
	&"jade": 300.0,
	&"lumber": 160.0,
	&"essence": 160.0,
}
const HERD_SPAWN_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]
const BUILDABLE_STRUCTURE_KINDS: Array[StringName] = [
	&"war_camp",
	&"rice_farm",
	&"hunters_lodge",
	&"wall",
	&"gate",
	&"sentry_tower",
]
const FORTIFICATION_STRUCTURE_KINDS: Array[StringName] = [&"wall", &"gate", &"sentry_tower"]
const GARRISON_UNIT_KINDS: Array[StringName] = [&"hunter", &"mystic"]
const SOLID_FRIENDLY_STRUCTURE_KINDS: Array[StringName] = [&"wall", &"sentry_tower"]
const FOOD_PRODUCER_KINDS: Array[StringName] = [&"rice_farm", &"hunters_lodge"]
const MONSTER_BOUNTY := {
	"jade": 45,
	"lumber": 30,
	"essence": 25,
}
const SCORE_RESOURCE_POINTS := {
	&"jade": 1,
	&"lumber": 1,
	&"essence": 2,
	&"food": 1,
}
const SCORE_UNIT_POINTS := {
	&"worker": 100,
	&"hunter": 125,
	&"vanguard": 225,
	&"mystic": 300,
	&"jadeclaw": 450,
	&"shenlong": 1600,
}
const SCORE_BUILDING_COMPLETED_POINTS := {
	&"wall": 75,
	&"gate": 200,
	&"sentry_tower": 350,
	&"rice_farm": 200,
	&"hunters_lodge": 250,
	&"war_camp": 400,
}
const SCORE_BUILDING_DESTROYED_POINTS := {
	&"wall": 125,
	&"gate": 300,
	&"sentry_tower": 500,
	&"rice_farm": 300,
	&"hunters_lodge": 350,
	&"war_camp": 600,
	&"stronghold": 2500,
}
const SCORE_CAVE_CAPTURED_POINTS := 1000
const SCORE_PER_HIT_POINT_REPAIRED := 1.0

var players: Array[Dictionary] = []
var entities: Dictionary = {}
var elapsed_time := 0.0
var outcome: StringName = &""

var _next_entity_id := 1
var _next_production_order_id := 1
var _accumulator := 0.0
var _astar := AStarGrid2D.new()
var _pathfinding_revision := 0
var _wander_rng := RandomNumberGenerator.new()
var _wildlife_rng := RandomNumberGenerator.new()
var _hunter_rng := RandomNumberGenerator.new()
var _wildlife_regeneration_progress: Array[float] = []
var _wildlife_live_counts: Array[int] = []
var _events: Array[Dictionary] = []
var _ai_strategy_timer := 0.5
var _ai_attack_timer := AI_INITIAL_ASSAULT_DELAY
var _ai_cave_timer := 3.0
var _ai_hunt_timer := 4.0
var _ai_training_flip := false
var _ai_skill_test_launched := false
var _ai_enabled := true
var _extra_ai_attack_timers: Dictionary = {}
var _extra_ai_cave_timers: Dictionary = {}
var _extra_ai_hunt_timers: Dictionary = {}
var _extra_ai_training_flips: Dictionary = {}
var _extra_ai_skill_tests: Dictionary = {}
var _line_of_sight_blockers: Dictionary = {}
var _visible_cells_by_team: Array[Dictionary] = []
var _explored_cells_by_team: Array[Dictionary] = []
var _tweak_values: Dictionary = {}


func set_tweak_values(values: Dictionary) -> void:
	_tweak_values = values.duplicate(true)


func tweak_value(id: StringName, fallback: Variant) -> Variant:
	return _tweak_values.get(id, fallback)


func setup(player_faction: StringName, enable_ai: bool = true) -> void:
	assert(player_faction in FactionCatalog.ORDER, "A match requires one of the four playable factions")
	assert(FactionCatalog.ORDER.size() == TEAM_COUNT, "Every match requires exactly four playable factions")
	var map_errors := MapCatalog.validation_errors()
	assert(map_errors.is_empty(), "Invalid authored map: %s" % "; ".join(map_errors))
	entities.clear()
	_events.clear()
	_next_entity_id = 1
	_next_production_order_id = 1
	elapsed_time = 0.0
	outcome = &""
	_accumulator = 0.0
	_pathfinding_revision = 0
	_ai_enabled = enable_ai
	_ai_strategy_timer = 0.5
	_ai_attack_timer = AI_INITIAL_ASSAULT_DELAY
	_ai_cave_timer = 3.0
	_ai_hunt_timer = 4.0
	_ai_training_flip = false
	_ai_skill_test_launched = false
	_wander_rng.seed = GUARDIAN_WANDER_SEED
	_wildlife_rng.seed = WILDLIFE_WANDER_SEED
	_hunter_rng.seed = HUNTER_WANDER_SEED
	_reset_wildlife_population_tracking()
	var rival_factions := FactionCatalog.opposing_factions(player_faction)
	assert(rival_factions.size() == TEAM_COUNT - 1, "Every match requires exactly three rival factions")
	players = [_player_state(player_faction, false)]
	for rival_faction in rival_factions:
		players.append(_player_state(rival_faction, true))
	assert(players.size() == TEAM_COUNT, "Every match requires one human and three AI players")
	_extra_ai_attack_timers.clear()
	_extra_ai_cave_timers.clear()
	_extra_ai_hunt_timers.clear()
	_extra_ai_training_flips.clear()
	_extra_ai_skill_tests.clear()
	for team in range(TEAM_RIVAL_TWO, players.size()):
		_extra_ai_attack_timers[team] = AI_INITIAL_ASSAULT_DELAY + float(team - 1) * 4.0
		_extra_ai_cave_timers[team] = 3.0 + float(team)
		_extra_ai_hunt_timers[team] = 4.0 + float(team)
		_extra_ai_training_flips[team] = team % 2 == 0
		_extra_ai_skill_tests[team] = false
	_rebuild_pathfinding()
	for team in range(players.size()):
		var start := MapCatalog.start_definition(team)
		_spawn_structure(team, &"stronghold", start["stronghold"] as Vector2i, true)
		for raw_cell in start["workers"] as Array:
			_spawn_unit(team, &"worker", raw_cell as Vector2i)
	for resource in MapCatalog.RESOURCES:
		_spawn_resource(resource)
	for tree in MapCatalog.tree_definitions():
		_spawn_resource(tree)
	for cave in MapCatalog.CAVES:
		_spawn_cave(cave)
	_spawn_shenlong_objective()
	_rebuild_pathfinding()
	for herd_index in range(MapCatalog.WILDLIFE_HERDS.size()):
		_spawn_wildlife_herd(herd_index, MapCatalog.WILDLIFE_HERDS[herd_index])
	_reset_visibility()
	_refresh_visibility()
	for team in range(1, players.size()):
		_auto_assign_workers(team)
	state_changed.emit()


func advance(delta: float) -> void:
	if not outcome.is_empty():
		_accumulator = 0.0
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator >= TICK_SECONDS:
		_accumulator -= TICK_SECONDS
		_tick(TICK_SECONDS)
		if not outcome.is_empty():
			_accumulator = 0.0
			break


func _tick(delta: float) -> void:
	elapsed_time += delta
	_auto_assign_idle_workers_to_construction()
	_advance_construction(delta)
	_advance_food_production(delta)
	_advance_production(delta)
	_advance_worker_orders(delta)
	_advance_combat_and_movement(delta)
	if not outcome.is_empty():
		state_changed.emit()
		return
	_resolve_unit_separation(delta)
	_advance_wildlife_regeneration(delta)
	_sync_carried_eggs()
	_refresh_visibility()
	_advance_cave_capture(delta)
	if _ai_enabled:
		_advance_ai(delta)
	state_changed.emit()


func _player_state(faction: StringName, is_ai: bool) -> Dictionary:
	var starting_multiplier := 1.0 if is_ai else float(tweak_value(&"gameplay.resource.starting_multiplier", 1.0))
	return {
		"faction": faction,
		"jade": roundi(320.0 * starting_multiplier),
		"lumber": roundi(30.0 * starting_multiplier),
		"essence": roundi(160.0 * starting_multiplier),
		"food": roundi(160.0 * starting_multiplier),
		"population": 0,
		"population_cap": POPULATION_CAP,
		"is_ai": is_ai,
		"eliminated": false,
		"score": 0,
		"score_breakdown": {
			"resources_earned": 0,
			"units_created": 0,
			"enemies_defeated": 0,
			"caves_captured": 0,
			"buildings_completed": 0,
			"buildings_destroyed": 0,
			"hit_points_repaired": 0,
		},
		"lifetime_stats": {
			"resources_earned": {
				"jade": 0,
				"lumber": 0,
				"essence": 0,
				"food": 0,
			},
			"units_created": {},
			"enemies_defeated": {},
			"caves_captured": 0,
			"buildings_completed": {},
			"buildings_destroyed": {},
			"hit_points_repaired": 0.0,
		},
	}


func team_score(team: int) -> int:
	if not _is_valid_team(team):
		return 0
	return int(players[team].get("score", 0))


func score_breakdown(team: int) -> Dictionary:
	if not _is_valid_team(team):
		return {}
	return (players[team].get("score_breakdown", {}) as Dictionary).duplicate(true)


func lifetime_stats(team: int) -> Dictionary:
	if not _is_valid_team(team):
		return {}
	return (players[team].get("lifetime_stats", {}) as Dictionary).duplicate(true)


func _award_score(team: int, category: StringName, points: int) -> void:
	if not _is_valid_team(team) or points <= 0:
		return
	if team == TEAM_PLAYER:
		points = maxi(1, roundi(float(points) * float(tweak_value(&"gameplay.score.multiplier", 1.0))))
	players[team]["score"] = team_score(team) + points
	var breakdown := players[team]["score_breakdown"] as Dictionary
	var category_key := String(category)
	breakdown[category_key] = int(breakdown.get(category_key, 0)) + points


func _record_resource_earned(team: int, resource_kind: StringName, amount: int) -> void:
	if not _is_valid_team(team) or amount <= 0:
		return
	var stats := players[team]["lifetime_stats"] as Dictionary
	var resources := stats["resources_earned"] as Dictionary
	var resource_key := String(resource_kind)
	resources[resource_key] = int(resources.get(resource_key, 0)) + amount
	_award_score(
		team,
		&"resources_earned",
		amount * int(SCORE_RESOURCE_POINTS.get(resource_kind, 1)),
	)


func _grant_resource_income(team: int, resource_kind: StringName, amount: int) -> void:
	if not _is_valid_team(team) or amount <= 0:
		return
	var resource_key := String(resource_kind)
	players[team][resource_key] = int(players[team].get(resource_key, 0)) + amount
	_record_resource_earned(team, resource_kind, amount)


func _increment_lifetime_kind(team: int, category: StringName, kind: StringName) -> void:
	var stats := players[team]["lifetime_stats"] as Dictionary
	var counts := stats[String(category)] as Dictionary
	var kind_key := String(kind)
	counts[kind_key] = int(counts.get(kind_key, 0)) + 1


func _record_unit_created(team: int, kind: StringName) -> void:
	if not _is_valid_team(team):
		return
	_increment_lifetime_kind(team, &"units_created", kind)
	_award_score(team, &"units_created", int(SCORE_UNIT_POINTS.get(kind, 100)))


func _record_building_completed(team: int, kind: StringName) -> void:
	if not _is_valid_team(team):
		return
	_increment_lifetime_kind(team, &"buildings_completed", kind)
	_award_score(
		team,
		&"buildings_completed",
		int(SCORE_BUILDING_COMPLETED_POINTS.get(kind, 150)),
	)


func _record_cave_captured(team: int) -> void:
	if not _is_valid_team(team):
		return
	var stats := players[team]["lifetime_stats"] as Dictionary
	stats["caves_captured"] = int(stats.get("caves_captured", 0)) + 1
	_award_score(team, &"caves_captured", SCORE_CAVE_CAPTURED_POINTS)


func _record_hit_points_repaired(team: int, amount: float) -> void:
	if not _is_valid_team(team) or amount <= 0.0:
		return
	var stats := players[team]["lifetime_stats"] as Dictionary
	stats["hit_points_repaired"] = float(stats.get("hit_points_repaired", 0.0)) + amount
	_award_score(
		team,
		&"hit_points_repaired",
		roundi(amount * SCORE_PER_HIT_POINT_REPAIRED),
	)


func _record_combat_score(killer_team: int, target: Dictionary) -> void:
	if not _is_valid_team(killer_team):
		return
	var target_team := int(target.get("team", TEAM_NEUTRAL))
	var category := target.get("category", &"") as StringName
	var kind := target.get("kind", &"") as StringName
	if category == &"unit" and (
		target_team >= 0 and target_team != killer_team
		or _is_neutral_guardian(target)
	):
		_increment_lifetime_kind(killer_team, &"enemies_defeated", kind)
		_award_score(
			killer_team,
			&"enemies_defeated",
			int(SCORE_UNIT_POINTS.get(kind, 100)),
		)
	elif category == &"structure" and target_team >= 0 and target_team != killer_team:
		_increment_lifetime_kind(killer_team, &"buildings_destroyed", kind)
		_award_score(
			killer_team,
			&"buildings_destroyed",
			int(SCORE_BUILDING_DESTROYED_POINTS.get(kind, 250)),
		)


func _spawn_unit(team: int, kind: StringName, cell: Vector2i, home_cave_id: int = -1) -> int:
	tweak_boundary_reached.emit(&"NEXT_SPAWN")
	var faction := &"neutral" if team == TEAM_NEUTRAL else players[team]["faction"] as StringName
	var stats := FactionCatalog.stats(kind, faction)
	var health_multiplier := 1.0
	var speed_multiplier := 1.0
	if team == TEAM_PLAYER:
		health_multiplier = float(tweak_value(&"player.health.multiplier", 1.0))
		speed_multiplier = float(tweak_value(&"player.move.speed_multiplier", 1.0))
	elif team >= TEAM_ENEMY:
		health_multiplier = float(tweak_value(&"enemies.health.multiplier", 1.0))
		speed_multiplier = float(tweak_value(&"enemies.speed.multiplier", 1.0))
	var maximum_health := float(stats["max_hp"]) * health_multiplier
	var entity_state := {
		"id": _next_entity_id,
		"team": team,
		"faction": faction,
		"kind": kind,
		"category": &"unit",
		"position": Vector2(cell),
		"cell": cell,
		"footprint": Vector2i.ONE,
		"hp": maximum_health,
		"max_hp": maximum_health,
		"alive": true,
		"complete": 1.0,
		"speed": float(stats["speed"]) * speed_multiplier,
		"damage": float(stats["damage"]),
		"range": float(stats["range"]),
		"attack_period": float(stats["attack_period"]),
		"attack_cooldown": 0.0,
		"acquire_range": float(stats["acquire_range"]),
		"order": &"idle",
		"target_id": -1,
		"path": [],
		"path_index": 0,
		"path_destination": Vector2i(-1, -1),
		"path_endpoint": Vector2i(-1, -1),
		"pathfinding_revision": -1,
		"separation_velocity": Vector2.ZERO,
		"command_queue": [],
		"attack_move": false,
		"attack_move_destination": Vector2i(-1, -1),
		"combat_reposition_target_id": -1,
		"patrol_origin": Vector2i(-1, -1),
		"patrol_destination": Vector2i(-1, -1),
		"patrol_target": Vector2i(-1, -1),
		"repath_timer": 0.0,
		"cargo_kind": &"",
		"cargo_amount": 0.0,
		"carrying_egg": false,
		"carried_egg_id": -1,
		"gather_source_id": -1,
		"gather_timer": 0.0,
		"repair_timer": 0.0,
		"repair_notice_cooldown": 0.0,
		"return_resume_gather": true,
		"garrisoned_in": -1,
		"population": int(stats["population"]),
		"flash_timer": 0.0,
		"home_cave_id": home_cave_id,
		"leash_origin": Vector2(cell),
		"leash_radius": GUARDIAN_LEASH_RADIUS,
		"wander_timer": _next_hunter_wander_delay() if kind == &"hunter" else 0.0,
		"hunting_pasture_id": -1,
	}
	entities[_next_entity_id] = entity_state
	if team >= 0:
		players[team]["population"] = int(players[team]["population"]) + int(stats["population"])
	_next_entity_id += 1
	return int(entity_state["id"])


func _spawn_cave(definition: Dictionary) -> int:
	var cell := definition["cell"] as Vector2i
	var entrance := definition["entrance"] as Vector2i
	var stats := FactionCatalog.stats(&"yaoguai_den", &"neutral")
	var cave_id := _next_entity_id
	var entity_state := {
		"id": cave_id,
		"team": TEAM_NEUTRAL,
		"faction": &"neutral",
		"kind": &"yaoguai_den",
		"category": &"structure",
		"position": Vector2(cell),
		"cell": cell,
		"entrance": entrance,
		"footprint": stats["footprint"],
		"hp": float(stats["max_hp"]),
		"max_hp": float(stats["max_hp"]),
		"alive": true,
		"complete": 1.0,
		"order": &"guarded",
		"queue": [],
		"rally_cell": cell + Vector2i(3, 1),
		"flash_timer": 0.0,
		"guardian_ids": [],
		"capture_unlocked": false,
		"capture_team": TEAM_NEUTRAL,
		"capture_progress": 0.0,
		"capture_contested": false,
		"indestructible": true,
	}
	entities[cave_id] = entity_state
	_next_entity_id += 1
	var guardian_ids: Array[int] = []
	for raw_cell in definition["guardians"] as Array:
		var guardian_id := _spawn_unit(TEAM_NEUTRAL, &"jadeclaw", raw_cell as Vector2i, cave_id)
		var guardian := entity(guardian_id)
		guardian["leash_origin"] = Vector2(entrance)
		guardian["wander_timer"] = _next_guardian_wander_delay()
		guardian_ids.append(guardian_id)
	entity_state["guardian_ids"] = guardian_ids
	return cave_id


func _spawn_structure(
	team: int,
	kind: StringName,
	cell: Vector2i,
	completed: bool,
	orientation: StringName = &"y",
) -> int:
	var faction := players[team]["faction"] as StringName
	var stats := FactionCatalog.stats(kind, faction)
	var completion := 1.0 if completed else 0.06
	var normalized_orientation: StringName = &"x" if orientation == &"x" else &"y"
	var entity_state := {
		"id": _next_entity_id,
		"team": team,
		"faction": faction,
		"kind": kind,
		"category": &"structure",
		"position": Vector2(cell),
		"cell": cell,
		"footprint": structure_footprint(team, kind, normalized_orientation),
		"orientation": normalized_orientation,
		"hp": float(stats["max_hp"]) * completion,
		"max_hp": float(stats["max_hp"]),
		"alive": true,
		"complete": completion,
		"order": &"idle" if completed else &"constructing",
		"queue": [],
		"rally_cell": cell + Vector2i(2, 1),
		"stronghold_level": STRONGHOLD_INITIAL_LEVEL if kind == &"stronghold" else 0,
		"food_timer": 0.0,
		"farm_worker_id": -1,
		"garrison_capacity": int(stats.get("garrison_capacity", 0)),
		"garrisoned_unit_ids": [],
		"flash_timer": 0.0,
	}
	entities[_next_entity_id] = entity_state
	_next_entity_id += 1
	return int(entity_state["id"])


func _spawn_resource(definition: Dictionary) -> int:
	var kind := definition["kind"] as StringName
	var entity_kind: StringName
	match kind:
		&"jade":
			entity_kind = &"jade_node"
		&"essence":
			entity_kind = &"essence_node"
		&"lumber":
			entity_kind = definition.get("variant", &"lumber_pine") as StringName
		_:
			entity_kind = &"jade_node"
	var entity_state := {
		"id": _next_entity_id,
		"team": TEAM_NEUTRAL,
		"faction": &"neutral",
		"kind": entity_kind,
		"resource_kind": kind,
		"category": &"resource",
		"position": Vector2(definition["cell"]),
		"cell": definition["cell"],
		"footprint": Vector2i.ONE,
		"amount": float(definition["amount"]),
		"max_amount": float(definition["amount"]),
		"hp": 1.0,
		"max_hp": 1.0,
		"alive": true,
		"complete": 1.0,
		"flash_timer": 0.0,
	}
	entities[_next_entity_id] = entity_state
	_next_entity_id += 1
	return int(entity_state["id"])


func _spawn_wildlife_herd(herd_id: int, definition: Dictionary) -> void:
	var center := definition["center"] as Vector2i
	var kind := definition["kind"] as StringName
	var count := int(definition.get("count", 1))
	var radius := float(definition.get("radius", 3.0))
	for member_index in range(count):
		var desired := center + HERD_SPAWN_OFFSETS[member_index % HERD_SPAWN_OFFSETS.size()]
		var spawn_cell := desired if not _astar.is_point_solid(desired) else _nearest_walkable_around(desired, 5)
		_spawn_wildlife(kind, spawn_cell, herd_id, center, radius)


func _advance_wildlife_regeneration(delta: float) -> void:
	if delta <= 0.0:
		return
	_ensure_wildlife_population_tracking()
	for herd_id in range(MapCatalog.WILDLIFE_HERDS.size()):
		var definition := MapCatalog.WILDLIFE_HERDS[herd_id]
		var target_count := maxi(1, int(definition.get("count", 1)))
		var living_count := _wildlife_live_counts[herd_id]
		if living_count >= target_count:
			_wildlife_regeneration_progress[herd_id] = 0.0
			continue
		var spawn_interval := WILDLIFE_REGENERATION_CYCLE_SECONDS / float(target_count)
		_wildlife_regeneration_progress[herd_id] += delta
		while (
			(
				_wildlife_regeneration_progress[herd_id] >= spawn_interval
				or is_equal_approx(_wildlife_regeneration_progress[herd_id], spawn_interval)
			)
			and living_count < target_count
		):
			if not _regenerate_wildlife_member(herd_id, definition):
				_wildlife_regeneration_progress[herd_id] = minf(
					_wildlife_regeneration_progress[herd_id],
					spawn_interval,
				)
				break
			_wildlife_regeneration_progress[herd_id] = maxf(
				0.0,
				_wildlife_regeneration_progress[herd_id] - spawn_interval,
			)
			living_count += 1
			_wildlife_live_counts[herd_id] = living_count


func _regenerate_wildlife_member(herd_id: int, definition: Dictionary) -> bool:
	var spawn_cell := _wildlife_regeneration_cell(definition)
	if not MapCatalog.in_bounds(spawn_cell):
		return false
	var wildlife_id := _spawn_wildlife(
		definition["kind"] as StringName,
		spawn_cell,
		herd_id,
		definition["center"] as Vector2i,
		float(definition.get("radius", 3.0)),
	)
	_add_event(
		&"wildlife_regenerated",
		Vector2(spawn_cell),
		Color("d5b963"),
		{
			"entity_id": wildlife_id,
			"herd_id": herd_id,
			"kind": definition["kind"] as StringName,
			"category": &"wildlife",
		},
	)
	return true


func _wildlife_regeneration_cell(definition: Dictionary) -> Vector2i:
	var center := definition["center"] as Vector2i
	var radius := float(definition.get("radius", 3.0))
	var candidates: Array[Vector2i] = []
	var seen: Dictionary = {}
	for offset in HERD_SPAWN_OFFSETS:
		var authored_candidate := center + offset
		if Vector2(authored_candidate).distance_to(Vector2(center)) <= radius:
			candidates.append(authored_candidate)
			seen[authored_candidate] = true
	var cell_radius := int(ceil(radius))
	for y in range(-cell_radius, cell_radius + 1):
		for x in range(-cell_radius, cell_radius + 1):
			var candidate := center + Vector2i(x, y)
			if seen.has(candidate) or Vector2(candidate).distance_to(Vector2(center)) > radius:
				continue
			candidates.append(candidate)
			seen[candidate] = true
	for candidate in candidates:
		if not MapCatalog.in_bounds(candidate) or _astar.is_point_solid(candidate):
			continue
		if not _cell_occupied_by_live_unit(candidate):
			return candidate
	return Vector2i(-1, -1)


func _reset_wildlife_population_tracking() -> void:
	_wildlife_regeneration_progress.clear()
	_wildlife_regeneration_progress.resize(MapCatalog.WILDLIFE_HERDS.size())
	_wildlife_regeneration_progress.fill(0.0)
	_wildlife_live_counts.clear()
	_wildlife_live_counts.resize(MapCatalog.WILDLIFE_HERDS.size())
	_wildlife_live_counts.fill(0)


func _ensure_wildlife_population_tracking() -> void:
	if (
		_wildlife_regeneration_progress.size() == MapCatalog.WILDLIFE_HERDS.size()
		and _wildlife_live_counts.size() == MapCatalog.WILDLIFE_HERDS.size()
	):
		return
	_reset_wildlife_population_tracking()
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)) or entity_state.get("category") != &"wildlife":
			continue
		var herd_id := int(entity_state.get("herd_id", -1))
		if herd_id >= 0 and herd_id < _wildlife_live_counts.size():
			_wildlife_live_counts[herd_id] += 1


func _living_wildlife_count_for_herd(herd_id: int) -> int:
	if herd_id < 0 or herd_id >= MapCatalog.WILDLIFE_HERDS.size():
		return 0
	_ensure_wildlife_population_tracking()
	return _wildlife_live_counts[herd_id]


func _spawn_shenlong_objective() -> void:
	var egg_id := _next_entity_id
	var egg := {
		"id": egg_id,
		"team": TEAM_NEUTRAL,
		"faction": &"neutral",
		"kind": &"shenlong_egg",
		"category": &"objective",
		"position": Vector2(MapCatalog.SHENLONG_EGG_CELL),
		"cell": MapCatalog.SHENLONG_EGG_CELL,
		"footprint": Vector2i.ONE,
		"hp": 1.0,
		"max_hp": 1.0,
		"alive": true,
		"complete": 1.0,
		"claimable": false,
		"carried_by": -1,
		"guardian_id": -1,
		"claimed_team": TEAM_NEUTRAL,
		"flash_timer": 0.0,
	}
	entities[egg_id] = egg
	_next_entity_id += 1
	var dragon_id := _spawn_unit(TEAM_NEUTRAL, &"shenlong", MapCatalog.SHENLONG_CELL)
	var dragon := entity(dragon_id)
	dragon["is_shenlong_guardian"] = true
	dragon["leash_origin"] = Vector2(MapCatalog.SHENLONG_EGG_CELL)
	dragon["leash_radius"] = 8.0
	dragon["wander_timer"] = _next_guardian_wander_delay()
	egg["guardian_id"] = dragon_id


func _spawn_wildlife(
	kind: StringName,
	cell: Vector2i,
	herd_id: int,
	herd_origin: Vector2i,
	herd_radius: float,
) -> int:
	if herd_id >= 0:
		_ensure_wildlife_population_tracking()
	var stats := FactionCatalog.stats(kind, &"neutral")
	var entity_state := {
		"id": _next_entity_id,
		"team": TEAM_NEUTRAL,
		"faction": &"neutral",
		"kind": kind,
		"category": &"wildlife",
		"position": Vector2(cell),
		"cell": cell,
		"footprint": Vector2i.ONE,
		"hp": float(stats["max_hp"]),
		"max_hp": float(stats["max_hp"]),
		"alive": true,
		"complete": 1.0,
		"speed": float(stats["speed"]),
		"damage": float(stats["damage"]),
		"range": float(stats["range"]),
		"attack_period": float(stats["attack_period"]),
		"attack_cooldown": 0.0,
		"acquire_range": 0.0,
		"order": &"idle",
		"target_id": -1,
		"path": [],
		"path_index": 0,
		"path_destination": Vector2i(-1, -1),
		"path_endpoint": Vector2i(-1, -1),
		"pathfinding_revision": -1,
		"separation_velocity": Vector2.ZERO,
		"attack_move": false,
		"attack_move_destination": Vector2i(-1, -1),
		"repath_timer": 0.0,
		"population": 0,
		"flash_timer": 0.0,
		"herd_id": herd_id,
		"herd_origin": Vector2(herd_origin),
		"herd_radius": herd_radius,
		"wander_timer": _next_wildlife_wander_delay(),
		"retaliates": bool(stats.get("retaliates", false)),
		"food_bounty": int(stats.get("food_bounty", 0)),
	}
	entities[_next_entity_id] = entity_state
	if herd_id >= 0 and herd_id < _wildlife_live_counts.size():
		_wildlife_live_counts[herd_id] += 1
	_next_entity_id += 1
	return int(entity_state["id"])


func command_move(
	issuer_team: int,
	ids: Array[int],
	destination: Vector2i,
	attack_move: bool = false,
	append: bool = false,
) -> bool:
	if not _can_issue_command(issuer_team) or not MapCatalog.in_bounds(destination):
		return false
	var units: Array[Dictionary] = []
	for id in ids:
		var unit := entity(id)
		if _is_commandable_unit(unit) and int(unit["team"]) == issuer_team:
			units.append(unit)
	var claimable_egg := _claimable_shenlong_egg_at(destination) if not attack_move else {}
	var formation := _formation_cells(destination, units.size())
	var issued := false
	var issued_egg_claim := false
	for index in range(mini(units.size(), formation.size())):
		var unit := units[index]
		if not claimable_egg.is_empty() and _can_worker_claim_egg(unit, claimable_egg):
			var claim_issued := _issue_unit_order(
				unit,
				{"type": &"claim_egg", "target_id": int(claimable_egg["id"])},
				append,
			)
			issued_egg_claim = claim_issued or issued_egg_claim
			issued = claim_issued or issued
			continue
		issued = _issue_unit_order(
			unit,
			{
				"type": &"attack_move" if attack_move else &"move",
				"destination": formation[index],
			},
			append,
		) or issued
	if issued:
		if issued_egg_claim:
			_add_event(
				&"command",
				_entity_center(claimable_egg),
				Color("b7ffd8"),
				{"team": issuer_team, "kind": &"shenlong_egg"},
			)
		else:
			_add_event(&"command", Vector2(destination), Color("8de8c0"))
	return issued


func command_attack(issuer_team: int, ids: Array[int], target_id: int, append: bool = false) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var target := entity(target_id)
	if target.is_empty() or not bool(target.get("alive", false)):
		return false
	var issued := false
	for id in ids:
		var attacker := entity(id)
		if (
			not _is_commandable_unit(attacker)
			or int(attacker["team"]) != issuer_team
			or not are_hostile(attacker, target)
			or not is_entity_visible_to_team(int(attacker["team"]), target)
		):
			continue
		issued = _issue_unit_order(
			attacker,
			{"type": &"attack", "target_id": target_id},
			append,
		) or issued
	if issued:
		_add_event(&"command", _entity_center(target), Color("f16a57"))
	return issued


func command_gather(issuer_team: int, ids: Array[int], resource_id: int, append: bool = false) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var resource := entity(resource_id)
	if (
		resource.is_empty()
		or not bool(resource.get("alive", false))
		or resource.get("category") != &"resource"
	):
		return false
	var issued := false
	for id in ids:
		var worker := entity(id)
		if (
			not _is_commandable_unit(worker)
			or int(worker["team"]) != issuer_team
			or worker.get("kind") != &"worker"
			or bool(worker.get("carrying_egg", false))
			or not is_entity_explored_by_team(int(worker["team"]), resource)
		):
			continue
		issued = _issue_unit_order(worker, {"type": &"gather", "target_id": resource_id}, append) or issued
	if issued:
		_add_event(&"command", _entity_center(resource), Color("73e6bc"))
	return issued


func command_assign_farm_worker(
	issuer_team: int,
	ids: Array[int],
	farm_id: int,
	append: bool = false,
) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var farm := entity(farm_id)
	if (
		farm.is_empty()
		or farm.get("kind") != &"rice_farm"
		or int(farm.get("team", TEAM_NEUTRAL)) != issuer_team
	):
		return false
	var issued := false
	for id in ids:
		var worker := entity(id)
		if int(worker.get("team", TEAM_NEUTRAL)) != issuer_team:
			continue
		if not _can_worker_farm(worker, farm):
			continue
		issued = _issue_unit_order(
			worker,
			{"type": &"farm", "target_id": farm_id},
			append,
		) or issued
		if issued:
			break
	if issued:
		_add_event(
			&"command",
			_entity_center(farm),
			Color("f2c85b"),
			{"team": issuer_team, "category": &"structure", "kind": &"rice_farm"},
		)
	return issued


func command_claim_egg(issuer_team: int, ids: Array[int], egg_id: int, append: bool = false) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var egg := entity(egg_id)
	if not _is_claimable_shenlong_egg(egg):
		return false
	var issued := false
	for id in ids:
		var worker := entity(id)
		if (
			int(worker.get("team", TEAM_NEUTRAL)) != issuer_team
			or not _can_worker_claim_egg(worker, egg)
		):
			continue
		issued = _issue_unit_order(worker, {"type": &"claim_egg", "target_id": egg_id}, append) or issued
	if issued:
		_add_event(&"command", _entity_center(egg), Color("b7ffd8"), {"team": issuer_team, "kind": &"shenlong_egg"})
	return issued


func _claimable_shenlong_egg_at(cell: Vector2i) -> Dictionary:
	var egg := shenlong_egg()
	if _is_claimable_shenlong_egg(egg) and egg.get("cell") == cell:
		return egg
	return {}


func _is_claimable_shenlong_egg(egg: Dictionary) -> bool:
	return (
		not egg.is_empty()
		and bool(egg.get("alive", false))
		and egg.get("kind") == &"shenlong_egg"
		and bool(egg.get("claimable", false))
		and int(egg.get("carried_by", -1)) < 0
	)


func _can_worker_claim_egg(worker: Dictionary, egg: Dictionary) -> bool:
	return (
		_is_commandable_unit(worker)
		and worker.get("kind") == &"worker"
		and float(worker.get("cargo_amount", 0.0)) <= 0.0
		and not bool(worker.get("carrying_egg", false))
		and _is_claimable_shenlong_egg(egg)
	)


func command_return_egg(issuer_team: int, ids: Array[int], stronghold_id: int, append: bool = false) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var stronghold := entity(stronghold_id)
	if (
		stronghold.is_empty()
		or not bool(stronghold.get("alive", false))
		or stronghold.get("kind") != &"stronghold"
		or int(stronghold.get("team", TEAM_NEUTRAL)) != issuer_team
	):
		return false
	var issued := false
	for id in ids:
		var worker := entity(id)
		if (
			not _is_commandable_unit(worker)
			or worker.get("kind") != &"worker"
			or int(worker.get("team", TEAM_NEUTRAL)) != issuer_team
			or not bool(worker.get("carrying_egg", false))
		):
			continue
		issued = _issue_unit_order(worker, {"type": &"return_egg", "target_id": stronghold_id}, append) or issued
	return issued


func command_deposit(issuer_team: int, ids: Array[int], stronghold_id: int, append: bool = false) -> int:
	if not _can_issue_command(issuer_team):
		return 0
	var stronghold := entity(stronghold_id)
	if (
		stronghold.is_empty()
		or not bool(stronghold.get("alive", false))
		or stronghold.get("kind") != &"stronghold"
		or int(stronghold.get("team", TEAM_NEUTRAL)) != issuer_team
	):
		return 0
	var stronghold_team := int(stronghold.get("team", TEAM_NEUTRAL))
	var deposited_workers := 0
	for id in ids:
		var worker := entity(id)
		if (
			not _is_commandable_unit(worker)
			or worker.get("kind") != &"worker"
			or int(worker.get("team", TEAM_NEUTRAL)) != issuer_team
			or int(worker.get("team", TEAM_NEUTRAL)) != stronghold_team
		):
			continue
		var cargo_kind := worker.get("cargo_kind", &"") as StringName
		var cargo_amount := float(worker.get("cargo_amount", 0.0))
		if cargo_kind.is_empty() or cargo_amount <= 0.0:
			continue
		if append:
			_issue_unit_order(
				worker,
				{"type": &"deposit", "target_id": stronghold_id},
				true,
			)
			continue
		if _entity_footprint_distance(worker, stronghold) > WORKER_INTERACTION_RANGE:
			_issue_unit_order(
				worker,
				{"type": &"deposit", "target_id": stronghold_id},
				false,
			)
			continue
		_cancel_all_unit_orders(worker)
		_deposit(stronghold_team, cargo_kind, cargo_amount)
		worker["cargo_amount"] = 0.0
		worker["cargo_kind"] = &""
		deposited_workers += 1
	if deposited_workers > 0:
		_add_event(
			&"deposit",
			_entity_center(stronghold),
			Color("f1d477"),
			{"team": stronghold_team, "category": &"structure", "kind": &"stronghold"},
		)
	return deposited_workers


func command_stop(issuer_team: int, ids: Array[int]) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var issued := false
	for id in ids:
		var unit := entity(id)
		if not _is_commandable_unit(unit) or int(unit["team"]) != issuer_team:
			continue
		_cancel_all_unit_orders(unit)
		issued = true
	return issued


func command_resign(issuer_team: int) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	players[issuer_team]["eliminated"] = true
	var stronghold := _stronghold_for_team(issuer_team)
	if not stronghold.is_empty():
		stronghold["alive"] = false
		stronghold["hp"] = 0.0
	_resolve_stronghold_elimination(issuer_team)
	state_changed.emit()
	return true


func command_repair(issuer_team: int, ids: Array[int], target_id: int, append: bool = false) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var target := entity(target_id)
	if int(target.get("team", TEAM_NEUTRAL)) != issuer_team:
		return false
	var issued := false
	for id in ids:
		var worker := entity(id)
		if int(worker.get("team", TEAM_NEUTRAL)) != issuer_team or not _can_worker_repair(worker, target):
			continue
		issued = _issue_unit_order(
			worker,
			{"type": &"repair", "target_id": target_id},
			append,
		) or issued
	if issued:
		_add_event(&"command", _entity_center(target), Color("e4c66d"))
	return issued


func command_construct(issuer_team: int, ids: Array[int], target_id: int, append: bool = false) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var target := entity(target_id)
	if int(target.get("team", TEAM_NEUTRAL)) != issuer_team:
		return false
	var issued := false
	for id in ids:
		var worker := entity(id)
		if int(worker.get("team", TEAM_NEUTRAL)) != issuer_team or not _can_worker_construct(worker, target):
			continue
		issued = _issue_unit_order(
			worker,
			{"type": &"construct", "target_id": target_id},
			append,
		) or issued
	if issued:
		_add_event(&"command", _entity_center(target), Color("f3d47b"))
	return issued


func command_garrison(
	issuer_team: int,
	ids: Array[int],
	tower_id: int,
	append: bool = false,
) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var tower := entity(tower_id)
	if not _is_available_sentry_tower(tower, issuer_team):
		return false
	var occupants := tower.get("garrisoned_unit_ids", []) as Array
	var slots_remaining := int(tower.get("garrison_capacity", 0)) - occupants.size()
	var issued := false
	for id in ids:
		var unit := entity(id)
		if (
			not _is_commandable_unit(unit)
			or int(unit.get("team", TEAM_NEUTRAL)) != issuer_team
			or unit.get("kind") not in GARRISON_UNIT_KINDS
		):
			continue
		var unit_issued := _issue_unit_order(
			unit,
			{"type": &"garrison", "target_id": tower_id},
			append,
		)
		if not unit_issued:
			continue
		issued = true
		slots_remaining -= 1
		if slots_remaining <= 0:
			break
	if issued:
		_add_event(&"command", _entity_center(tower), Color("f1d477"))
	return issued


func command_ungarrison(issuer_team: int, tower_id: int, unit_id: int) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var tower := entity(tower_id)
	var unit := entity(unit_id)
	if (
		tower.is_empty()
		or unit.is_empty()
		or not bool(tower.get("alive", false))
		or int(tower.get("team", TEAM_NEUTRAL)) != issuer_team
		or int(unit.get("team", TEAM_NEUTRAL)) != issuer_team
		or int(unit.get("garrisoned_in", -1)) != tower_id
	):
		return false
	_exit_garrison(tower, unit)
	_add_event(&"command", unit["position"] as Vector2, Color("f1d477"))
	return true


func command_patrol(issuer_team: int, ids: Array[int], destination: Vector2i, append: bool = false) -> bool:
	if not _can_issue_command(issuer_team) or not MapCatalog.in_bounds(destination):
		return false
	var units: Array[Dictionary] = []
	for id in ids:
		var unit := entity(id)
		if _is_commandable_unit(unit) and int(unit["team"]) == issuer_team and _is_military_unit(unit):
			units.append(unit)
	if units.is_empty():
		return false
	var formation := _formation_cells(destination, units.size())
	var issued := false
	for index in range(mini(units.size(), formation.size())):
		issued = _issue_unit_order(
			units[index],
			{"type": &"patrol", "destination": formation[index]},
			append,
		) or issued
	if issued:
		_add_event(&"command", Vector2(destination), Color("79c9ee"))
	return issued


func _issue_unit_order(unit: Dictionary, order_data: Dictionary, append: bool) -> bool:
	var queue := unit.get("command_queue", []) as Array
	if append and (unit.get("order", &"idle") != &"idle" or not queue.is_empty()):
		queue.append(order_data.duplicate(true))
		unit["command_queue"] = queue
		if unit.get("order", &"idle") == &"idle":
			_activate_next_queued_order(unit)
		return true
	if not append:
		queue.clear()
		unit["command_queue"] = queue
	_clear_active_order_state(unit)
	if _activate_unit_order(unit, order_data):
		return true
	return _activate_next_queued_order(unit)


func _activate_unit_order(unit: Dictionary, order_data: Dictionary) -> bool:
	var order_type := order_data.get("type", &"") as StringName
	match order_type:
		&"move", &"attack_move":
			var destination := order_data.get("destination", Vector2i(-1, -1)) as Vector2i
			if not MapCatalog.in_bounds(destination):
				return false
			unit["order"] = order_type
			unit["attack_move"] = order_type == &"attack_move"
			unit["attack_move_destination"] = destination if order_type == &"attack_move" else Vector2i(-1, -1)
			_set_path(unit, destination)
			return true
		&"attack":
			var attack_target := entity(int(order_data.get("target_id", -1)))
			if (
				attack_target.is_empty()
				or not are_hostile(unit, attack_target)
				or not is_entity_visible_to_team(int(unit["team"]), attack_target)
			):
				return false
			unit["order"] = &"attack"
			unit["target_id"] = int(attack_target["id"])
			return true
		&"gather":
			var resource := entity(int(order_data.get("target_id", -1)))
			if (
				unit.get("kind") != &"worker"
				or resource.is_empty()
				or not bool(resource.get("alive", false))
				or resource.get("category") != &"resource"
				or not is_entity_explored_by_team(int(unit["team"]), resource)
			):
				return false
			_set_gather_source(unit, resource)
			return true
		&"farm":
			var farm := entity(int(order_data.get("target_id", -1)))
			if not _can_worker_farm(unit, farm):
				return false
			farm["farm_worker_id"] = int(unit["id"])
			unit["order"] = &"farm"
			unit["target_id"] = int(farm["id"])
			_set_path(unit, farm["cell"] as Vector2i)
			return true
		&"claim_egg":
			var egg := entity(int(order_data.get("target_id", -1)))
			if not _can_worker_claim_egg(unit, egg):
				return false
			unit["order"] = &"claim_egg"
			unit["target_id"] = int(egg["id"])
			_set_path(unit, egg["cell"] as Vector2i)
			return true
		&"return_egg":
			var egg_stronghold := entity(int(order_data.get("target_id", -1)))
			if (
				unit.get("kind") != &"worker"
				or not bool(unit.get("carrying_egg", false))
				or egg_stronghold.is_empty()
				or not bool(egg_stronghold.get("alive", false))
				or egg_stronghold.get("kind") != &"stronghold"
				or int(egg_stronghold.get("team", TEAM_NEUTRAL)) != int(unit["team"])
			):
				return false
			unit["order"] = &"return_egg"
			unit["target_id"] = int(egg_stronghold["id"])
			_set_path(unit, egg_stronghold["cell"] as Vector2i)
			return true
		&"deposit":
			var stronghold := entity(int(order_data.get("target_id", -1)))
			if (
				unit.get("kind") != &"worker"
				or stronghold.is_empty()
				or not bool(stronghold.get("alive", false))
				or stronghold.get("kind") != &"stronghold"
				or int(stronghold.get("team", TEAM_NEUTRAL)) != int(unit["team"])
				or float(unit.get("cargo_amount", 0.0)) <= 0.0
			):
				return false
			unit["order"] = &"return"
			unit["target_id"] = int(stronghold["id"])
			unit["return_resume_gather"] = false
			_set_path(unit, stronghold["cell"] as Vector2i)
			return true
		&"repair":
			var repair_target := entity(int(order_data.get("target_id", -1)))
			if not _can_worker_repair(unit, repair_target):
				return false
			unit["order"] = &"repair"
			unit["target_id"] = int(repair_target["id"])
			unit["repair_timer"] = 0.0
			_set_path(unit, repair_target["cell"] as Vector2i)
			return true
		&"construct":
			var construction_target := entity(int(order_data.get("target_id", -1)))
			if not _can_worker_construct(unit, construction_target):
				return false
			unit["order"] = &"build"
			unit["target_id"] = int(construction_target["id"])
			_set_path(unit, construction_target["cell"] as Vector2i)
			return true
		&"garrison":
			var sentry_tower := entity(int(order_data.get("target_id", -1)))
			if unit.get("kind") not in GARRISON_UNIT_KINDS or not _is_available_sentry_tower(
				sentry_tower,
				int(unit.get("team", TEAM_NEUTRAL)),
			):
				return false
			unit["order"] = &"garrison"
			unit["target_id"] = int(sentry_tower["id"])
			_set_path(unit, sentry_tower["cell"] as Vector2i)
			return true
		&"patrol":
			if not _is_military_unit(unit):
				return false
			var patrol_destination := order_data.get("destination", Vector2i(-1, -1)) as Vector2i
			if not MapCatalog.in_bounds(patrol_destination):
				return false
			unit["order"] = &"patrol"
			unit["patrol_origin"] = Vector2i((unit["position"] as Vector2).round())
			unit["patrol_destination"] = patrol_destination
			unit["patrol_target"] = patrol_destination
			_set_path(unit, patrol_destination)
			return true
	return false


func _activate_next_queued_order(unit: Dictionary) -> bool:
	var queue := unit.get("command_queue", []) as Array
	while not queue.is_empty():
		var next_order := queue.pop_front() as Dictionary
		unit["command_queue"] = queue
		_clear_active_order_state(unit)
		if _activate_unit_order(unit, next_order):
			return true
	_clear_active_order_state(unit)
	return false


func _finish_unit_order(unit: Dictionary) -> void:
	_clear_active_order_state(unit)
	_activate_next_queued_order(unit)


func _cancel_all_unit_orders(unit: Dictionary) -> void:
	var queue := unit.get("command_queue", []) as Array
	queue.clear()
	unit["command_queue"] = queue
	_clear_active_order_state(unit)


func _clear_active_order_state(unit: Dictionary) -> void:
	_release_farm_assignment(unit)
	unit["order"] = &"idle"
	unit["target_id"] = -1
	unit["path"] = []
	unit["path_index"] = 0
	unit["path_destination"] = Vector2i(-1, -1)
	unit["path_endpoint"] = Vector2i(-1, -1)
	unit["pathfinding_revision"] = -1
	unit["repair_timer"] = 0.0
	unit["return_resume_gather"] = true
	_clear_attack_move(unit)
	unit["combat_reposition_target_id"] = -1
	_clear_patrol(unit)


func _clear_patrol(unit: Dictionary) -> void:
	unit["patrol_origin"] = Vector2i(-1, -1)
	unit["patrol_destination"] = Vector2i(-1, -1)
	unit["patrol_target"] = Vector2i(-1, -1)


func _can_worker_repair(worker: Dictionary, target: Dictionary) -> bool:
	return (
		_is_commandable_unit(worker)
		and worker.get("kind") == &"worker"
		and not target.is_empty()
		and bool(target.get("alive", false))
		and target.get("category") == &"structure"
		and int(target.get("team", TEAM_NEUTRAL)) == int(worker.get("team", TEAM_NEUTRAL))
		and float(target.get("complete", 0.0)) >= 1.0
		and float(target.get("hp", 0.0)) < float(target.get("max_hp", 0.0))
	)


func _can_worker_farm(worker: Dictionary, farm: Dictionary) -> bool:
	if (
		not _is_commandable_unit(worker)
		or worker.get("kind") != &"worker"
		or bool(worker.get("carrying_egg", false))
		or float(worker.get("cargo_amount", 0.0)) > 0.0
		or farm.is_empty()
		or not bool(farm.get("alive", false))
		or farm.get("kind") != &"rice_farm"
		or int(farm.get("team", TEAM_NEUTRAL)) != int(worker.get("team", TEAM_NEUTRAL))
		or float(farm.get("complete", 0.0)) < 1.0
	):
		return false
	var assigned_worker_id := farm_worker_id(int(farm["id"]))
	return assigned_worker_id < 0 or assigned_worker_id == int(worker["id"])


func _release_farm_assignment(worker: Dictionary) -> void:
	if worker.get("order", &"idle") != &"farm":
		return
	var farm := entity(int(worker.get("target_id", -1)))
	if not farm.is_empty() and int(farm.get("farm_worker_id", -1)) == int(worker.get("id", -1)):
		farm["farm_worker_id"] = -1


func _can_worker_construct(worker: Dictionary, target: Dictionary) -> bool:
	return (
		_is_commandable_unit(worker)
		and worker.get("kind") == &"worker"
		and not target.is_empty()
		and bool(target.get("alive", false))
		and target.get("category") == &"structure"
		and int(target.get("team", TEAM_NEUTRAL)) == int(worker.get("team", TEAM_NEUTRAL))
		and float(target.get("complete", 1.0)) < 1.0
	)


func _is_available_sentry_tower(tower: Dictionary, team: int) -> bool:
	if (
		tower.is_empty()
		or not bool(tower.get("alive", false))
		or tower.get("kind") != &"sentry_tower"
		or int(tower.get("team", TEAM_NEUTRAL)) != team
		or float(tower.get("complete", 0.0)) < 1.0
	):
		return false
	var occupants := tower.get("garrisoned_unit_ids", []) as Array
	return occupants.size() < int(tower.get("garrison_capacity", 0))


func _advance_garrison_order(unit: Dictionary) -> void:
	var tower := entity(int(unit.get("target_id", -1)))
	if not _is_available_sentry_tower(tower, int(unit.get("team", TEAM_NEUTRAL))):
		_finish_unit_order(unit)
		return
	if _entity_footprint_distance(unit, tower) > GARRISON_INTERACTION_RANGE:
		if (unit.get("path", []) as Array).is_empty():
			_set_path(unit, tower["cell"] as Vector2i)
		return
	_enter_garrison(tower, unit)


func _enter_garrison(tower: Dictionary, unit: Dictionary) -> void:
	var occupants := tower.get("garrisoned_unit_ids", []) as Array
	if int(unit.get("id", -1)) not in occupants:
		occupants.append(int(unit["id"]))
	tower["garrisoned_unit_ids"] = occupants
	unit["garrisoned_in"] = int(tower["id"])
	unit["position"] = _entity_center(tower)
	unit["cell"] = Vector2i(_entity_center(tower).round())
	unit["order"] = &"garrisoned"
	unit["target_id"] = -1
	unit["path"] = []
	unit["path_index"] = 0
	unit["separation_velocity"] = Vector2.ZERO
	var queue := unit.get("command_queue", []) as Array
	queue.clear()
	unit["command_queue"] = queue


func _exit_garrison(tower: Dictionary, unit: Dictionary) -> void:
	var occupants := tower.get("garrisoned_unit_ids", []) as Array
	occupants.erase(int(unit.get("id", -1)))
	tower["garrisoned_unit_ids"] = occupants
	unit["garrisoned_in"] = -1
	unit["order"] = &"idle"
	unit["target_id"] = -1
	unit["path"] = []
	unit["path_index"] = 0
	unit["attack_move"] = false
	unit["combat_reposition_target_id"] = -1
	var base_cell := Vector2i(_entity_center(tower).round())
	var exit_cell := _nearest_walkable_around(base_cell, 5)
	unit["position"] = Vector2(exit_cell)
	unit["cell"] = exit_cell


func _eject_garrisoned_units(tower: Dictionary) -> void:
	var occupant_ids := (tower.get("garrisoned_unit_ids", []) as Array).duplicate()
	for raw_id in occupant_ids:
		var unit := entity(int(raw_id))
		if not unit.is_empty() and bool(unit.get("alive", false)):
			_exit_garrison(tower, unit)
	tower["garrisoned_unit_ids"] = []


func command_build(
	issuer_team: int,
	worker_id: int,
	structure_kind: StringName,
	cell: Vector2i,
	orientation: StringName = &"y",
) -> bool:
	if not _can_issue_command(issuer_team) or structure_kind not in BUILDABLE_STRUCTURE_KINDS:
		return false
	var worker := entity(worker_id)
	if (
		worker.is_empty()
		or worker.get("kind") != &"worker"
		or not _is_commandable_unit(worker)
		or int(worker["team"]) != issuer_team
	):
		return false
	var team := issuer_team
	var faction := players[team]["faction"] as StringName
	if not FactionCatalog.can_build_structure(faction, structure_kind):
		return false
	var stats := FactionCatalog.stats(structure_kind, faction)
	if not can_place_structure(team, structure_kind, cell, orientation) or not _can_afford(team, stats):
		return false
	_pay(team, stats)
	var structure_id := _spawn_structure(team, structure_kind, cell, false, orientation)
	_rebuild_pathfinding()
	command_construct(issuer_team, [worker_id], structure_id)
	_add_event(
		&"build",
		Vector2(cell),
		FactionCatalog.definition(faction)["accent"] as Color,
		{
			"team": team,
			"category": &"structure",
			"kind": structure_kind,
			"faction": faction,
			"entity_id": structure_id,
		},
	)
	return true


func command_build_war_camp(issuer_team: int, worker_id: int, cell: Vector2i) -> bool:
	return command_build(issuer_team, worker_id, &"war_camp", cell)


func demolition_refund(structure_id: int) -> Dictionary:
	var structure := entity(structure_id)
	if structure.is_empty() or structure.get("kind") not in BUILDABLE_STRUCTURE_KINDS:
		return {}
	var stats := FactionCatalog.stats(
		structure["kind"] as StringName,
		structure["faction"] as StringName,
	)
	var refund := {}
	for cost_key in ["jade_cost", "lumber_cost", "essence_cost", "food_cost"]:
		refund[cost_key] = floori(float(stats.get(cost_key, 0)) * DEMOLITION_REFUND_RATE)
	return refund


func can_demolish_structure(issuer_team: int, structure_id: int) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var structure := entity(structure_id)
	return (
		not structure.is_empty()
		and bool(structure.get("alive", false))
		and structure.get("category") == &"structure"
		and structure.get("kind") in BUILDABLE_STRUCTURE_KINDS
		and int(structure.get("team", TEAM_NEUTRAL)) == issuer_team
	)


func command_demolish(issuer_team: int, structure_id: int) -> Dictionary:
	if not can_demolish_structure(issuer_team, structure_id):
		return {}
	var structure := entity(structure_id)
	var refund := demolition_refund(structure_id)
	for definition in [
		["jade_cost", "jade"],
		["lumber_cost", "lumber"],
		["essence_cost", "essence"],
		["food_cost", "food"],
	]:
		players[issuer_team][definition[1]] = (
			int(players[issuer_team][definition[1]])
			+ int(refund.get(definition[0], 0))
		)
	_kill(structure, {})
	return refund.duplicate(true)


func wall_line_cells(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offset := finish - start
	var along_x := absi(offset.x) >= absi(offset.y)
	var distance := absi(offset.x) if along_x else absi(offset.y)
	var step := Vector2i(signi(offset.x), 0) if along_x else Vector2i(0, signi(offset.y))
	if distance == 0:
		result.append(start)
		return result
	for index in range(distance + 1):
		result.append(start + step * index)
	return result


func gate_orientation(start: Vector2i, finish: Vector2i) -> StringName:
	var offset := finish - start
	return &"x" if absi(offset.x) > absi(offset.y) else &"y"


func structure_footprint(
	team: int,
	structure_kind: StringName,
	orientation: StringName = &"y",
) -> Vector2i:
	var faction := &"human"
	if team >= 0 and team < players.size():
		faction = players[team]["faction"] as StringName
	var footprint := FactionCatalog.stats(structure_kind, faction).get("footprint", Vector2i.ONE) as Vector2i
	if orientation == &"x":
		return Vector2i(footprint.y, footprint.x)
	return footprint


func can_place_wall_line(
	team: int,
	start: Vector2i,
	finish: Vector2i,
	orientation: StringName = &"y",
) -> bool:
	var cells := wall_line_cells(start, finish)
	if cells.is_empty() or not can_afford_structure_count(team, &"wall", cells.size()):
		return false
	for cell in cells:
		if not can_place_structure(team, &"wall", cell, orientation):
			return false
	return true


func command_build_wall_line(
	issuer_team: int,
	worker_id: int,
	start: Vector2i,
	finish: Vector2i,
	orientation: StringName = &"y",
) -> Array[int]:
	var result: Array[int] = []
	var worker := entity(worker_id)
	if (
		not _can_issue_command(issuer_team)
		or worker.is_empty()
		or worker.get("kind") != &"worker"
		or not _is_commandable_unit(worker)
		or int(worker.get("team", TEAM_NEUTRAL)) != issuer_team
		or not can_place_wall_line(issuer_team, start, finish, orientation)
	):
		return result
	var faction := players[issuer_team]["faction"] as StringName
	var stats := FactionCatalog.stats(&"wall", faction)
	var cells := wall_line_cells(start, finish)
	for _cell in cells:
		_pay(issuer_team, stats)
	for cell in cells:
		result.append(_spawn_structure(issuer_team, &"wall", cell, false, orientation))
	_rebuild_pathfinding()
	for index in range(result.size()):
		command_construct(issuer_team, [worker_id], result[index], index > 0)
		_add_event(
			&"build",
			Vector2(cells[index]),
			FactionCatalog.definition(faction)["accent"] as Color,
			{
				"team": issuer_team,
				"category": &"structure",
				"kind": &"wall",
				"faction": faction,
				"entity_id": result[index],
			},
		)
	return result


func can_afford_structure_count(team: int, structure_kind: StringName, count: int) -> bool:
	if not _is_valid_team(team) or count <= 0:
		return false
	var faction := players[team]["faction"] as StringName
	var stats := FactionCatalog.stats(structure_kind, faction)
	return (
		int(players[team]["jade"]) >= int(stats.get("jade_cost", 0)) * count
		and int(players[team]["lumber"]) >= int(stats.get("lumber_cost", 0)) * count
		and int(players[team]["essence"]) >= int(stats.get("essence_cost", 0)) * count
		and int(players[team]["food"]) >= int(stats.get("food_cost", 0)) * count
	)


func can_place_structure(
	team: int,
	structure_kind: StringName,
	cell: Vector2i,
	orientation: StringName = &"y",
) -> bool:
	if team < 0 or team >= players.size() or structure_kind not in BUILDABLE_STRUCTURE_KINDS:
		return false
	var faction := players[team]["faction"] as StringName
	if not FactionCatalog.can_build_structure(faction, structure_kind):
		return false
	var footprint := structure_footprint(team, structure_kind, orientation)
	for footprint_cell in MapCatalog.footprint_cells(cell, footprint):
		var terrain_is_valid := (
			MapCatalog.is_static_walkable(footprint_cell)
			if structure_kind in FORTIFICATION_STRUCTURE_KINDS
			else MapCatalog.is_buildable(footprint_cell)
		)
		if not terrain_is_valid:
			return false
		if _cell_occupied_by_static_entity(
			footprint_cell,
			team,
			structure_kind,
			orientation,
		):
			return false
		if _cell_occupied_by_live_unit(footprint_cell):
			return false
	return true


func can_place_war_camp(team: int, cell: Vector2i) -> bool:
	return can_place_structure(team, &"war_camp", cell)


func command_train(issuer_team: int, structure_id: int, unit_kind: StringName) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var structure := entity(structure_id)
	if structure.is_empty() or not bool(structure.get("alive", false)):
		return false
	if int(structure.get("team", TEAM_NEUTRAL)) != issuer_team:
		return false
	if float(structure.get("complete", 0.0)) < 1.0:
		return false
	if unit_kind == &"worker" and structure.get("kind") != &"stronghold":
		return false
	if unit_kind in [&"vanguard", &"mystic"] and structure.get("kind") != &"war_camp":
		return false
	if unit_kind == &"hunter" and structure.get("kind") != &"hunters_lodge":
		return false
	if unit_kind == &"jadeclaw" and structure.get("kind") != &"yaoguai_den":
		return false
	if unit_kind not in [&"worker", &"hunter", &"vanguard", &"mystic", &"jadeclaw"]:
		return false
	var team := int(structure["team"])
	if team < 0:
		return false
	var faction := players[team]["faction"] as StringName
	if not FactionCatalog.can_train_unit(faction, unit_kind):
		return false
	var stats := FactionCatalog.stats(unit_kind, faction)
	var free_recovery_worker := unit_kind == &"worker" and can_train_free_worker(team)
	if (
		not free_recovery_worker
		and not _can_afford(team, stats)
	) or not _has_population_room(team, int(stats["population"])):
		return false
	if not free_recovery_worker:
		_pay(team, stats)
	players[team]["population"] = int(players[team]["population"]) + int(stats["population"])
	var queue := structure["queue"] as Array
	queue.append({
		"order_id": _next_production_order_id,
		"kind": unit_kind,
		"remaining": float(stats["train_time"]),
		"total": float(stats["train_time"]),
		"reserved_population": int(stats["population"]),
		"costs": {
			"jade": 0 if free_recovery_worker else int(stats.get("jade_cost", 0)),
			"lumber": 0 if free_recovery_worker else int(stats.get("lumber_cost", 0)),
			"essence": 0 if free_recovery_worker else int(stats.get("essence_cost", 0)),
			"food": 0 if free_recovery_worker else int(stats.get("food_cost", 0)),
		},
	})
	_next_production_order_id += 1
	structure["queue"] = queue
	return true


func stronghold_upgrade_cost(stronghold_id: int) -> Dictionary:
	var stronghold := entity(stronghold_id)
	if stronghold.is_empty() or stronghold.get("kind") != &"stronghold":
		return {}
	var next_level := int(stronghold.get("stronghold_level", STRONGHOLD_INITIAL_LEVEL)) + 1
	if next_level > STRONGHOLD_MAX_LEVEL or not STRONGHOLD_UPGRADE_COSTS.has(next_level):
		return {}
	var amount := int(STRONGHOLD_UPGRADE_COSTS[next_level])
	return {
		"name": "Stronghold Lvl %d" % next_level,
		"jade_cost": amount,
		"lumber_cost": amount,
		"essence_cost": amount,
		"food_cost": amount,
	}


func can_upgrade_stronghold(issuer_team: int, stronghold_id: int) -> bool:
	if not _can_issue_command(issuer_team):
		return false
	var stronghold := entity(stronghold_id)
	if (
		stronghold.is_empty()
		or not bool(stronghold.get("alive", false))
		or stronghold.get("category") != &"structure"
		or stronghold.get("kind") != &"stronghold"
		or float(stronghold.get("complete", 0.0)) < 1.0
		or int(stronghold.get("team", TEAM_NEUTRAL)) != issuer_team
	):
		return false
	var cost := stronghold_upgrade_cost(stronghold_id)
	return not cost.is_empty() and _can_afford(issuer_team, cost)


func command_upgrade_stronghold(issuer_team: int, stronghold_id: int) -> bool:
	if not can_upgrade_stronghold(issuer_team, stronghold_id):
		return false
	var stronghold := entity(stronghold_id)
	var cost := stronghold_upgrade_cost(stronghold_id)
	_pay(issuer_team, cost)
	stronghold["stronghold_level"] = (
		int(stronghold.get("stronghold_level", STRONGHOLD_INITIAL_LEVEL)) + 1
	)
	players[issuer_team]["population_cap"] = (
		int(players[issuer_team]["population_cap"]) + STRONGHOLD_POPULATION_PER_UPGRADE
	)
	_add_event(
		&"stronghold_upgrade",
		_entity_center(stronghold),
		FactionCatalog.definition(stronghold["faction"] as StringName)["accent"] as Color,
		{
			"team": issuer_team,
			"category": &"structure",
			"kind": &"stronghold",
			"faction": stronghold["faction"],
			"entity_id": stronghold_id,
			"level": stronghold["stronghold_level"],
		},
	)
	return true


func command_cancel_training(
	requesting_team: int,
	structure_id: int,
	queue_index: int = -1,
	expected_order_id: int = -1,
) -> Dictionary:
	if not _can_issue_command(requesting_team):
		return {}
	var structure := entity(structure_id)
	if (
		structure.is_empty()
		or not bool(structure.get("alive", false))
		or structure.get("category") != &"structure"
		or float(structure.get("complete", 0.0)) < 1.0
		or int(structure.get("team", TEAM_NEUTRAL)) != requesting_team
	):
		return {}
	var queue := structure.get("queue", []) as Array
	if queue.is_empty():
		return {}
	var cancel_index := queue.size() - 1 if queue_index == -1 else queue_index
	if cancel_index < 0 or cancel_index >= queue.size():
		return {}
	var queued_order := queue[cancel_index] as Dictionary
	if expected_order_id >= 0 and int(queued_order.get("order_id", -1)) != expected_order_id:
		return {}
	var cancelled := queue.pop_at(cancel_index) as Dictionary
	structure["queue"] = queue
	players[requesting_team]["population"] = maxi(
		0,
		int(players[requesting_team]["population"])
		- int(cancelled.get("reserved_population", 0)),
	)
	var costs := cancelled.get("costs", {}) as Dictionary
	for resource_kind in [&"jade", &"lumber", &"essence", &"food"]:
		var resource_key := String(resource_kind)
		players[requesting_team][resource_key] = (
			int(players[requesting_team][resource_key])
			+ int(costs.get(resource_key, 0))
		)
	_add_event(
		&"cancel",
		_entity_center(structure),
		Color("f0d278"),
		{"team": requesting_team, "category": &"unit", "kind": cancelled.get("kind", &"")},
	)
	return cancelled.duplicate(true)


func set_rally(issuer_team: int, structure_id: int, cell: Vector2i) -> bool:
	if not _can_issue_command(issuer_team) or not MapCatalog.in_bounds(cell):
		return false
	var structure := entity(structure_id)
	if (
		structure.is_empty()
		or structure.get("category") != &"structure"
		or not bool(structure.get("alive", false))
		or int(structure.get("team", TEAM_NEUTRAL)) != issuer_team
	):
		return false
	structure["rally_cell"] = _nearest_walkable(cell)
	_add_event(&"command", Vector2(structure["rally_cell"]), Color("f0d278"))
	return true


func _rebuild_pathfinding() -> void:
	_astar.clear()
	_line_of_sight_blockers.clear()
	_astar.region = Rect2i(Vector2i.ZERO, MapCatalog.SIZE)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			var blocked := not MapCatalog.is_static_walkable(cell)
			_astar.set_point_solid(cell, blocked)
			if blocked:
				_line_of_sight_blockers[cell] = -1
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)):
			continue
		if entity_state.get("category") not in [&"structure", &"resource"]:
			continue
		for cell in MapCatalog.footprint_cells(
			entity_state["cell"] as Vector2i,
			entity_state.get("footprint", Vector2i.ONE) as Vector2i,
		):
			if MapCatalog.in_bounds(cell):
				_astar.set_point_solid(cell, true)
				_line_of_sight_blockers[cell] = int(entity_state["id"])
	_pathfinding_revision += 1


func _set_path(entity_state: Dictionary, destination: Vector2i) -> void:
	entity_state["path"] = []
	entity_state["path_index"] = 0
	entity_state["path_destination"] = destination
	entity_state["path_endpoint"] = Vector2i(-1, -1)
	entity_state["pathfinding_revision"] = _pathfinding_revision
	var start := Vector2i((entity_state["position"] as Vector2).round())
	if not MapCatalog.in_bounds(start):
		return
	var team := int(entity_state.get("team", TEAM_NEUTRAL))
	var can_phase_through_friendly_structures := not bool(entity_state.get("carrying_egg", false))
	if can_phase_through_friendly_structures:
		_set_friendly_structures_solid(team, false)
	var shenlong_avoidance_cells := _block_ai_shenlong_avoidance_zone(entity_state)
	var start_was_solid := _astar.is_point_solid(start)
	if start_was_solid:
		_astar.set_point_solid(start, false)
	var target := _nearest_walkable(destination)
	var cell_path := _astar.get_id_path(start, target, true)
	if start_was_solid:
		_astar.set_point_solid(start, true)
	for cell in shenlong_avoidance_cells:
		_astar.set_point_solid(cell, false)
	if can_phase_through_friendly_structures:
		_set_friendly_structures_solid(team, true)
	entity_state["path_endpoint"] = target
	var path: Array[Vector2] = []
	for cell in cell_path:
		path.append(Vector2(cell))
	if not path.is_empty() and Vector2i(path[0]) == start:
		path.pop_front()
	entity_state["path"] = path
	entity_state["path_index"] = 0


func _block_ai_shenlong_avoidance_zone(entity_state: Dictionary) -> Array[Vector2i]:
	var blocked_cells: Array[Vector2i] = []
	var team := int(entity_state.get("team", TEAM_NEUTRAL))
	if not _ai_shenlong_lock_active(team):
		return blocked_cells
	var guardian := shenlong_guardian()
	if guardian.is_empty():
		return blocked_cells
	var center := guardian.get("leash_origin", guardian["position"]) as Vector2
	var radius := int(ceil(AI_SHENLONG_AVOID_RADIUS))
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var cell := Vector2i(center.round()) + Vector2i(x, y)
			if (
				not MapCatalog.in_bounds(cell)
				or Vector2(cell).distance_to(center) > AI_SHENLONG_AVOID_RADIUS
				or _astar.is_point_solid(cell)
			):
				continue
			_astar.set_point_solid(cell, true)
			blocked_cells.append(cell)
	return blocked_cells


func _set_friendly_structures_solid(team: int, solid: bool) -> void:
	if team < 0:
		return
	var structure_cells: Dictionary = {}
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			not bool(entity_state.get("alive", false))
			or entity_state.get("category") != &"structure"
			or int(entity_state.get("team", TEAM_NEUTRAL)) != team
		):
			continue
		for cell in MapCatalog.footprint_cells(
			entity_state["cell"] as Vector2i,
			entity_state.get("footprint", Vector2i.ONE) as Vector2i,
		):
			if MapCatalog.in_bounds(cell):
				var remains_solid: bool = entity_state.get("kind") in SOLID_FRIENDLY_STRUCTURE_KINDS
				structure_cells[cell] = bool(structure_cells.get(cell, false)) or remains_solid
	for raw_cell in structure_cells:
		var cell := raw_cell as Vector2i
		_astar.set_point_solid(cell, solid or bool(structure_cells[cell]))


func _nearest_walkable(desired: Vector2i) -> Vector2i:
	var clamped := Vector2i(
		clampi(desired.x, 0, MapCatalog.SIZE.x - 1),
		clampi(desired.y, 0, MapCatalog.SIZE.y - 1),
	)
	if not _astar.is_point_solid(clamped):
		return clamped
	for radius in range(1, 7):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if abs(x) + abs(y) != radius:
					continue
				var candidate := clamped + Vector2i(x, y)
				if MapCatalog.in_bounds(candidate) and not _astar.is_point_solid(candidate):
					return candidate
	return clamped


func _nearest_walkable_around(origin: Vector2i, max_radius: int) -> Vector2i:
	for radius in range(1, max_radius + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if abs(x) + abs(y) != radius:
					continue
				var candidate := origin + Vector2i(x, y)
				if MapCatalog.in_bounds(candidate) and not _astar.is_point_solid(candidate):
					return candidate
	return _nearest_walkable(origin)


func _advance_construction(delta: float) -> void:
	for raw_worker in entities.values():
		var worker := raw_worker as Dictionary
		if not bool(worker.get("alive", false)) or worker.get("kind") != &"worker":
			continue
		if worker.get("order") != &"build":
			continue
		var target := entity(int(worker.get("target_id", -1)))
		if target.is_empty() or not bool(target.get("alive", false)):
			_finish_unit_order(worker)
			continue
		if float(target.get("complete", 1.0)) >= 1.0:
			_finish_unit_order(worker)
			continue
		if _entity_footprint_distance(worker, target) > 1.35:
			if (worker["path"] as Array).is_empty():
				_set_path(worker, target["cell"] as Vector2i)
			continue
		worker["path"] = []
		var duration_multiplier := (
			float(tweak_value(&"gameplay.build.duration_multiplier", 1.0))
			if int(worker.get("team", TEAM_NEUTRAL)) == TEAM_PLAYER
			else 1.0
		)
		var progress := minf(1.0, float(target["complete"]) + delta / (8.0 * duration_multiplier))
		target["complete"] = progress
		target["hp"] = maxf(float(target["hp"]), float(target["max_hp"]) * progress)
		if progress >= 1.0:
			target["order"] = &"idle"
			_finish_construction_order(worker, target)
			_record_building_completed(int(target["team"]), target["kind"] as StringName)
			_add_event(
				&"complete",
				_entity_center(target),
				Color("f3d47b"),
				{
					"team": int(target["team"]),
					"category": &"structure",
					"kind": target["kind"],
					"faction": target["faction"],
					"entity_id": int(target["id"]),
				},
			)


func _finish_construction_order(completing_worker: Dictionary, structure: Dictionary) -> void:
	if structure.get("kind") != &"rice_farm":
		_finish_unit_order(completing_worker)
		return
	var farm_id := int(structure["id"])
	for raw_worker in entities.values():
		var worker := raw_worker as Dictionary
		if (
			bool(worker.get("alive", false))
			and worker.get("kind") == &"worker"
			and worker.get("order") == &"build"
			and int(worker.get("target_id", -1)) == farm_id
		):
			_cancel_all_unit_orders(worker)
	_activate_unit_order(
		completing_worker,
		{"type": &"farm", "target_id": farm_id},
	)


func _advance_production(delta: float) -> void:
	for raw_structure in entities.values():
		var structure := raw_structure as Dictionary
		if not bool(structure.get("alive", false)) or structure.get("category") != &"structure":
			continue
		if float(structure.get("complete", 0.0)) < 1.0:
			continue
		var queue := structure.get("queue", []) as Array
		if queue.is_empty():
			continue
		var item := queue[0] as Dictionary
		item["remaining"] = float(item["remaining"]) - delta
		queue[0] = item
		if float(item["remaining"]) > 0.0:
			continue
		queue.pop_front()
		var spawn_cell := _nearest_walkable_around(structure["cell"] as Vector2i, 4)
		var unit_id := _spawn_unit(int(structure["team"]), item["kind"] as StringName, spawn_cell)
		# Population was reserved when queued; remove the spawn helper's second charge.
		players[int(structure["team"])]["population"] = (
			int(players[int(structure["team"])]["population"]) - int(item["reserved_population"])
		)
		_record_unit_created(int(structure["team"]), item["kind"] as StringName)
		command_move(int(structure["team"]), [unit_id], structure.get("rally_cell", spawn_cell) as Vector2i)
		_add_event(
			&"complete",
			Vector2(spawn_cell),
			Color("f3d47b"),
			{
				"team": int(structure["team"]),
				"category": &"unit",
				"kind": item["kind"],
				"faction": structure["faction"],
				"entity_id": unit_id,
			},
		)


func _advance_food_production(delta: float) -> void:
	for raw_structure in entities.values():
		var structure := raw_structure as Dictionary
		if (
			not bool(structure.get("alive", false))
			or structure.get("kind") not in FOOD_PRODUCER_KINDS
			or float(structure.get("complete", 0.0)) < 1.0
		):
			continue
		var team := int(structure.get("team", TEAM_NEUTRAL))
		if team < 0:
			continue
		var stats := FactionCatalog.stats(
			structure["kind"] as StringName,
			structure["faction"] as StringName,
		)
		var interval := float(stats.get("food_interval", 0.0))
		var food_yield := structure_food_yield(int(structure["id"]))
		if interval <= 0.0 or food_yield <= 0:
			continue
		structure["food_timer"] = float(structure.get("food_timer", 0.0)) + delta
		while float(structure["food_timer"]) >= interval:
			structure["food_timer"] = float(structure["food_timer"]) - interval
			_grant_resource_income(team, &"food", food_yield)
			_add_event(
				&"food",
				_entity_center(structure),
				Color("f2c85b"),
				{
					"team": team,
					"category": &"structure",
					"kind": structure["kind"],
					"faction": structure["faction"],
					"entity_id": int(structure["id"]),
					"resource_kind": &"food",
					"amount": food_yield,
				},
			)


func _advance_cave_capture(delta: float) -> void:
	for raw_cave in entities.values():
		var cave := raw_cave as Dictionary
		if not bool(cave.get("alive", false)) or cave.get("kind") != &"yaoguai_den":
			continue
		if not bool(cave.get("capture_unlocked", false)):
			cave["capture_contested"] = false
			cave["capture_progress"] = 0.0
			cave["capture_team"] = TEAM_NEUTRAL
			continue

		var nearby_teams: Array[int] = []
		for team in range(players.size()):
			if _team_has_capture_unit_near(team, cave):
				nearby_teams.append(team)
		if nearby_teams.size() > 1:
			cave["capture_contested"] = true
			continue

		cave["capture_contested"] = false
		if nearby_teams.is_empty():
			cave["capture_progress"] = maxf(0.0, float(cave.get("capture_progress", 0.0)) - delta * 0.5)
			if float(cave["capture_progress"]) <= 0.0:
				cave["capture_team"] = TEAM_NEUTRAL
			continue

		var capturing_team := nearby_teams[0]
		if capturing_team == int(cave.get("team", TEAM_NEUTRAL)):
			cave["capture_progress"] = 0.0
			cave["capture_team"] = TEAM_NEUTRAL
			continue
		if int(cave.get("capture_team", TEAM_NEUTRAL)) != capturing_team:
			cave["capture_team"] = capturing_team
			cave["capture_progress"] = 0.0
		cave["capture_progress"] = float(cave["capture_progress"]) + delta
		if float(cave["capture_progress"]) >= CAVE_CAPTURE_SECONDS:
			_complete_cave_capture(cave, capturing_team)


func _team_has_capture_unit_near(team: int, cave: Dictionary) -> bool:
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			bool(entity_state.get("alive", false))
			and int(entity_state.get("team", TEAM_NEUTRAL)) == team
			and _is_military_unit(entity_state)
			and _entity_distance(entity_state, cave) <= CAVE_CAPTURE_RADIUS
		):
			return true
	return false


func _complete_cave_capture(cave: Dictionary, team: int) -> void:
	var previous_team := int(cave.get("team", TEAM_NEUTRAL))
	if previous_team >= 0 and previous_team != team:
		_cancel_structure_queue(cave, previous_team)
	cave["team"] = team
	cave["faction"] = players[team]["faction"]
	cave["order"] = &"idle"
	cave["capture_team"] = TEAM_NEUTRAL
	cave["capture_progress"] = 0.0
	cave["capture_contested"] = false
	_record_cave_captured(team)
	_add_event(
		&"capture",
		_entity_center(cave),
		_team_color(team),
		{"team": team, "category": &"structure", "kind": &"yaoguai_den"},
	)
	if team == TEAM_PLAYER:
		battle_notice.emit(&"notice.den_captured", {}, team)
	else:
		battle_notice.emit(&"notice.den_captured", {}, team)


func _cancel_structure_queue(structure: Dictionary, team: int) -> void:
	for queued_item in structure.get("queue", []) as Array:
		players[team]["population"] = maxi(
			0,
			int(players[team]["population"]) - int(queued_item.get("reserved_population", 0)),
		)
	structure["queue"] = []


func _advance_worker_orders(delta: float) -> void:
	for raw_worker in entities.values():
		var worker := raw_worker as Dictionary
		if not bool(worker.get("alive", false)) or worker.get("kind") != &"worker":
			continue
		match worker.get("order", &"idle"):
			&"gather":
				_advance_gather(worker, delta)
			&"farm":
				_advance_farm_work(worker)
			&"return":
				_advance_return(worker)
			&"claim_egg":
				_advance_claim_egg(worker)
			&"return_egg":
				_advance_return_egg(worker)
			&"repair":
				_advance_repair(worker, delta)


func _advance_farm_work(worker: Dictionary) -> void:
	var farm := entity(int(worker.get("target_id", -1)))
	if not _can_worker_farm(worker, farm) or farm_worker_id(int(farm.get("id", -1))) != int(worker["id"]):
		_finish_unit_order(worker)
		return
	if _entity_footprint_distance(worker, farm) > WORKER_INTERACTION_RANGE:
		if (worker.get("path", []) as Array).is_empty():
			_set_path(worker, farm["cell"] as Vector2i)
		return
	worker["path"] = []


func _advance_gather(worker: Dictionary, delta: float) -> void:
	var resource := entity(int(worker.get("gather_source_id", -1)))
	if resource.is_empty() or not bool(resource.get("alive", false)) or float(resource.get("amount", 0.0)) <= 0.0:
		var has_queued_order := not (worker.get("command_queue", []) as Array).is_empty()
		var found_next_tree := false if has_queued_order else _retarget_after_tree_depletion(worker, resource)
		if float(worker.get("cargo_amount", 0.0)) > 0.0:
			_start_return(worker, found_next_tree)
		elif has_queued_order:
			_finish_unit_order(worker)
		elif not found_next_tree:
			_finish_unit_order(worker)
		return
	var resource_kind := resource.get("resource_kind", &"") as StringName
	var cargo_kind := worker.get("cargo_kind", &"") as StringName
	var cargo_amount := float(worker.get("cargo_amount", 0.0))
	if cargo_amount > 0.0 and cargo_kind != resource_kind:
		_start_return(worker)
		return
	if cargo_amount >= CARGO_CAPACITY:
		_start_return(worker)
		return
	if _entity_distance(worker, resource) > WORKER_INTERACTION_RANGE:
		if (worker["path"] as Array).is_empty():
			_set_path(worker, resource["cell"] as Vector2i)
		return
	worker["path"] = []
	worker["gather_timer"] = float(worker.get("gather_timer", 0.0)) + delta
	if float(worker["gather_timer"]) < GATHER_CYCLE:
		return
	worker["gather_timer"] = 0.0
	var gathered := minf(
		minf(GATHER_AMOUNT, float(resource["amount"])),
		CARGO_CAPACITY - cargo_amount,
	)
	resource["amount"] = float(resource["amount"]) - gathered
	if cargo_amount <= 0.0:
		worker["cargo_kind"] = resource_kind
	worker["cargo_amount"] = cargo_amount + gathered
	_add_event(
		&"gather",
		_entity_center(resource),
		_resource_event_color(resource_kind),
		{
			"team": int(worker["team"]),
			"category": &"resource",
			"kind": resource["kind"],
			"resource_kind": resource_kind,
			"entity_id": int(resource["id"]),
			"worker_id": int(worker["id"]),
			"amount": gathered,
		},
	)
	if float(resource["amount"]) <= 0.0:
		resource["alive"] = false
		_rebuild_pathfinding()
		if (worker.get("command_queue", []) as Array).is_empty():
			_retarget_after_tree_depletion(worker, resource)
	if float(worker["cargo_amount"]) >= CARGO_CAPACITY or not bool(resource["alive"]):
		var resume_gather := (
			(worker.get("command_queue", []) as Array).is_empty()
			and bool(entity(int(worker.get("gather_source_id", -1))).get("alive", false))
		)
		_start_return(worker, resume_gather)


func _advance_return(worker: Dictionary) -> void:
	var stronghold := _stronghold_for_team(int(worker["team"]))
	if stronghold.is_empty():
		_finish_unit_order(worker)
		return
	if _entity_footprint_distance(worker, stronghold) > WORKER_INTERACTION_RANGE:
		if (worker["path"] as Array).is_empty():
			_set_path(worker, stronghold["cell"] as Vector2i)
		return
	worker["path"] = []
	var deposited_kind := worker.get("cargo_kind", &"") as StringName
	var deposited_amount := float(worker.get("cargo_amount", 0.0))
	_deposit(int(worker["team"]), deposited_kind, deposited_amount)
	worker["cargo_amount"] = 0.0
	worker["cargo_kind"] = &""
	var should_resume_gather := bool(worker.get("return_resume_gather", true))
	var source := entity(int(worker.get("gather_source_id", -1)))
	if should_resume_gather and not source.is_empty() and bool(source.get("alive", false)):
		worker["order"] = &"gather"
		worker["target_id"] = int(source["id"])
		_set_path(worker, source["cell"] as Vector2i)
	else:
		_finish_unit_order(worker)
	_add_event(
		&"deposit",
		_entity_center(stronghold),
		Color("f1d477"),
		{
			"team": int(worker["team"]),
			"category": &"structure",
			"kind": &"stronghold",
			"faction": stronghold["faction"],
			"entity_id": int(stronghold["id"]),
			"worker_id": int(worker["id"]),
			"resource_kind": deposited_kind,
			"amount": deposited_amount,
		},
	)


func _start_return(worker: Dictionary, resume_gather: bool = true) -> void:
	worker["order"] = &"return"
	worker["target_id"] = -1
	worker["path"] = []
	worker["return_resume_gather"] = resume_gather
	_clear_attack_move(worker)


func _advance_claim_egg(worker: Dictionary) -> void:
	var egg := entity(int(worker.get("target_id", -1)))
	if (
		egg.is_empty()
		or not bool(egg.get("alive", false))
		or not bool(egg.get("claimable", false))
		or int(egg.get("carried_by", -1)) >= 0
	):
		_finish_unit_order(worker)
		return
	if _entity_distance(worker, egg) > EGG_INTERACTION_RANGE:
		if (worker.get("path", []) as Array).is_empty():
			_set_path(worker, egg["cell"] as Vector2i)
		return
	worker["path"] = []
	worker["carrying_egg"] = true
	worker["carried_egg_id"] = int(egg["id"])
	egg["carried_by"] = int(worker["id"])
	egg["claimed_team"] = int(worker["team"])
	egg["claimable"] = false
	var stronghold := _stronghold_for_team(int(worker["team"]))
	if stronghold.is_empty():
		_drop_carried_egg(worker)
		_finish_unit_order(worker)
		return
	worker["order"] = &"return_egg"
	worker["target_id"] = int(stronghold["id"])
	_set_path(worker, stronghold["cell"] as Vector2i)
	_add_event(&"egg_claimed", _entity_center(worker), Color("c9ffe5"), {"team": int(worker["team"]), "kind": &"shenlong_egg"})
	battle_notice.emit(&"notice.egg_claimed", {}, int(worker["team"]))


func _advance_return_egg(worker: Dictionary) -> void:
	if not bool(worker.get("carrying_egg", false)):
		_finish_unit_order(worker)
		return
	var egg := entity(int(worker.get("carried_egg_id", -1)))
	var stronghold := _stronghold_for_team(int(worker["team"]))
	if egg.is_empty() or not bool(egg.get("alive", false)):
		worker["carrying_egg"] = false
		worker["carried_egg_id"] = -1
		_finish_unit_order(worker)
		return
	if stronghold.is_empty():
		_drop_carried_egg(worker)
		_finish_unit_order(worker)
		return
	if _entity_footprint_distance(worker, stronghold) > WORKER_INTERACTION_RANGE:
		if (worker.get("path", []) as Array).is_empty():
			_set_path(worker, stronghold["cell"] as Vector2i)
		return
	_hatch_shenlong(worker, egg, stronghold)
	_finish_unit_order(worker)


func _sync_carried_eggs() -> void:
	for raw_entity in entities.values():
		var egg := raw_entity as Dictionary
		if not bool(egg.get("alive", false)) or egg.get("kind") != &"shenlong_egg":
			continue
		var carrier := entity(int(egg.get("carried_by", -1)))
		if carrier.is_empty() or not bool(carrier.get("alive", false)):
			if int(egg.get("carried_by", -1)) >= 0:
				egg["carried_by"] = -1
				egg["claimed_team"] = TEAM_NEUTRAL
				egg["claimable"] = true
			continue
		egg["position"] = carrier["position"] as Vector2
		egg["cell"] = carrier["cell"] as Vector2i


func _drop_carried_egg(worker: Dictionary) -> void:
	var egg := entity(int(worker.get("carried_egg_id", -1)))
	if not egg.is_empty() and bool(egg.get("alive", false)):
		var drop_cell := _nearest_walkable(Vector2i((worker["position"] as Vector2).round()))
		egg["position"] = Vector2(drop_cell)
		egg["cell"] = drop_cell
		egg["carried_by"] = -1
		egg["claimed_team"] = TEAM_NEUTRAL
		egg["claimable"] = true
		_add_event(&"egg_dropped", Vector2(drop_cell), Color("f1d477"), {"kind": &"shenlong_egg"})
	worker["carrying_egg"] = false
	worker["carried_egg_id"] = -1


func _hatch_shenlong(worker: Dictionary, egg: Dictionary, stronghold: Dictionary) -> void:
	var team := int(worker["team"])
	var spawn_cell := _nearest_walkable_around((stronghold["cell"] as Vector2i) + Vector2i(2, 1), 5)
	egg["alive"] = false
	egg["carried_by"] = -1
	egg["claimed_team"] = team
	worker["carrying_egg"] = false
	worker["carried_egg_id"] = -1
	var dragon_id := _spawn_unit(team, &"shenlong", spawn_cell)
	_add_event(&"shenlong_hatched", Vector2(spawn_cell), _team_color(team), {"team": team, "kind": &"shenlong", "entity_id": dragon_id})
	battle_notice.emit(&"notice.egg_hatched", {}, team)


func _retarget_after_tree_depletion(worker: Dictionary, resource: Dictionary) -> bool:
	if resource.is_empty() or resource.get("resource_kind") != &"lumber":
		return false
	var next_tree := _nearest_resource(worker, &"lumber")
	if next_tree.is_empty():
		return false
	_set_gather_source(worker, next_tree)
	return true


func _set_gather_source(worker: Dictionary, resource: Dictionary) -> void:
	worker["gather_source_id"] = int(resource["id"])
	worker["target_id"] = int(resource["id"])
	worker["gather_timer"] = 0.0
	worker["return_resume_gather"] = true
	_clear_attack_move(worker)
	var cargo_kind := worker.get("cargo_kind", &"") as StringName
	var cargo_amount := float(worker.get("cargo_amount", 0.0))
	var resource_kind := resource.get("resource_kind", &"") as StringName
	if cargo_amount > 0.0 and cargo_kind != resource_kind:
		_start_return(worker)
		return
	worker["order"] = &"gather"
	_set_path(worker, resource["cell"] as Vector2i)


func _advance_repair(worker: Dictionary, delta: float) -> void:
	var target := entity(int(worker.get("target_id", -1)))
	if not _can_worker_repair(worker, target):
		_finish_unit_order(worker)
		return
	if _entity_footprint_distance(worker, target) > WORKER_INTERACTION_RANGE:
		if (worker.get("path", []) as Array).is_empty():
			_set_path(worker, target["cell"] as Vector2i)
		return
	worker["path"] = []
	worker["repair_notice_cooldown"] = maxf(
		0.0,
		float(worker.get("repair_notice_cooldown", 0.0)) - delta,
	)
	worker["repair_timer"] = float(worker.get("repair_timer", 0.0)) + delta
	if float(worker["repair_timer"]) < REPAIR_CYCLE:
		return
	worker["repair_timer"] = float(worker["repair_timer"]) - REPAIR_CYCLE
	var team := int(worker["team"])
	if int(players[team]["lumber"]) < REPAIR_LUMBER_COST:
		worker["repair_timer"] = minf(float(worker["repair_timer"]), REPAIR_CYCLE)
		if float(worker["repair_notice_cooldown"]) <= 0.0:
			battle_notice.emit(&"notice.repair_paused", {}, team)
			worker["repair_notice_cooldown"] = REPAIR_NOTICE_SECONDS
		return
	players[team]["lumber"] = int(players[team]["lumber"]) - REPAIR_LUMBER_COST
	var restored := minf(REPAIR_AMOUNT, float(target["max_hp"]) - float(target["hp"]))
	target["hp"] = float(target["hp"]) + restored
	_record_hit_points_repaired(team, restored)
	_add_event(
		&"repair",
		_entity_center(target),
		Color("e4c66d"),
		{
			"team": team,
			"category": &"structure",
			"kind": target["kind"],
			"faction": target["faction"],
			"entity_id": int(target["id"]),
			"target_id": int(target["id"]),
			"worker_id": int(worker["id"]),
			"amount": restored,
		},
	)
	if float(target["hp"]) >= float(target["max_hp"]):
		_finish_unit_order(worker)


func _deposit(team: int, resource_kind: StringName, amount: float) -> void:
	var faction := players[team]["faction"] as StringName
	var multiplier := 1.0
	if faction == &"celestial" and resource_kind == &"essence":
		multiplier = 1.15
	elif faction == &"human" and resource_kind == &"jade":
		multiplier = 1.10
	var final_amount := int(round(amount * multiplier))
	_grant_resource_income(team, resource_kind, final_amount)


func _resource_event_color(resource_kind: StringName) -> Color:
	match resource_kind:
		&"jade":
			return Color("79e3b4")
		&"lumber":
			return Color("d5a85d")
		_:
			return Color("87c9ff")


func _advance_combat_and_movement(delta: float) -> void:
	for raw_id in entities.keys():
		if not outcome.is_empty():
			return
		var current := entity(int(raw_id))
		if current.is_empty() or not bool(current.get("alive", false)):
			continue
		current["flash_timer"] = maxf(0.0, float(current.get("flash_timer", 0.0)) - delta)
		if current.get("category") not in [&"unit", &"wildlife"]:
			continue
		current["attack_cooldown"] = maxf(0.0, float(current.get("attack_cooldown", 0.0)) - delta)
		current["repath_timer"] = maxf(0.0, float(current.get("repath_timer", 0.0)) - delta)
		if current.get("category") == &"wildlife":
			_advance_wildlife(current, delta)
			continue
		if int(current.get("garrisoned_in", -1)) >= 0:
			_advance_garrisoned_combat(current)
			continue
		if _is_neutral_guardian(current):
			_advance_guardian_wander(current, delta)
		elif current.get("kind") == &"hunter":
			_advance_hunter_wander(current, delta)
			if _hunter_should_avoid_combat(current):
				if not _start_hunter_competition_attack(current) and _advance_hunter_combat_avoidance(
					current,
					delta,
				):
					continue
		if current.get("order") == &"garrison":
			_advance_garrison_order(current)
			_advance_path(current, delta)
			continue
		if current.get("order") in [&"gather", &"farm", &"return", &"claim_egg", &"return_egg", &"build", &"repair"]:
			_advance_path(current, delta)
			continue
		if current.get("order") in [&"attack", &"attack_move", &"patrol"]:
			if _advance_attack_order(current, delta):
				continue
		elif current.get("order") in [&"idle", &"seek_hunting_pasture", &"evade"] and current.get("kind") != &"worker":
			if current.get("order") == &"evade":
				_advance_path(current, delta)
				continue
			var nearby := (
				_nearest_hunter_automatic_target(current, float(current.get("acquire_range", 3.8)), true)
				if current.get("kind") == &"hunter"
				else _nearest_enemy(current, float(current.get("acquire_range", 3.8)), true)
			)
			if nearby >= 0:
				if current.get("kind") == &"hunter":
					current["hunting_pasture_id"] = int(entity(nearby).get("herd_id", -1))
				current["order"] = &"attack"
				current["target_id"] = nearby
				_clear_attack_move(current)
				if _advance_attack_order(current, delta):
					continue
		_advance_path(current, delta)


func _advance_garrisoned_combat(unit: Dictionary) -> void:
	var tower_id := int(unit.get("garrisoned_in", -1))
	var tower := entity(tower_id)
	if (
		tower.is_empty()
		or not bool(tower.get("alive", false))
		or tower.get("kind") != &"sentry_tower"
	):
		unit["garrisoned_in"] = -1
		unit["order"] = &"idle"
		return
	unit["position"] = _entity_center(tower)
	unit["cell"] = Vector2i(_entity_center(tower).round())
	var attack_range := float(unit.get("range", 0.0)) * GARRISON_RANGE_MULTIPLIER
	var target := entity(int(unit.get("target_id", -1)))
	if (
		target.is_empty()
		or target.get("category") == &"wildlife"
		or not are_hostile(unit, target)
		or not is_entity_visible_to_team(int(unit.get("team", TEAM_NEUTRAL)), target)
		or _combat_distance(unit, target) > attack_range
		or not _has_line_of_sight(unit, target, [tower_id])
	):
		unit["target_id"] = _nearest_enemy_for_garrison(unit, tower_id, attack_range)
		target = entity(int(unit["target_id"]))
	if target.is_empty() or float(unit.get("attack_cooldown", 0.0)) > 0.0:
		return
	_apply_attack(unit, target)


func _nearest_enemy_for_garrison(unit: Dictionary, tower_id: int, maximum_distance: float) -> int:
	var best_id := -1
	var best_distance := maximum_distance
	var team := int(unit.get("team", TEAM_NEUTRAL))
	for raw_target in entities.values():
		var target := raw_target as Dictionary
		if (
			target.get("category") == &"wildlife"
			or not are_hostile(unit, target)
			or not is_entity_visible_to_team(team, target)
		):
			continue
		var distance := _combat_distance(unit, target)
		if distance < best_distance and _has_line_of_sight(unit, target, [tower_id]):
			best_distance = distance
			best_id = int(target["id"])
	return best_id


func _advance_hunter_wander(hunter: Dictionary, delta: float) -> void:
	if hunter.get("order", &"idle") != &"idle":
		return
	hunter["wander_timer"] = float(hunter.get("wander_timer", 0.0)) - delta
	if float(hunter["wander_timer"]) > 0.0:
		return
	hunter["wander_timer"] = _next_hunter_wander_delay()
	_start_hunter_pasture_search(hunter)


func _start_hunter_pasture_search(hunter: Dictionary) -> bool:
	var pasture := _preferred_hunter_pasture(hunter)
	if pasture.is_empty():
		hunter["hunting_pasture_id"] = -1
		return false
	var pasture_id := int(pasture["id"])
	var destination := _hunter_pasture_search_cell(
		hunter,
		pasture_id,
		pasture["center"] as Vector2i,
	)
	hunter["hunting_pasture_id"] = pasture_id
	hunter["order"] = &"seek_hunting_pasture"
	_set_path(hunter, destination)
	if (hunter.get("path", []) as Array).is_empty():
		hunter["order"] = &"idle"
		return false
	return true


func _next_hunter_wander_delay() -> float:
	return _hunter_rng.randf_range(HUNTER_WANDER_MIN_DELAY, HUNTER_WANDER_MAX_DELAY)


func _hunter_should_avoid_combat(hunter: Dictionary) -> bool:
	var order := hunter.get("order", &"idle") as StringName
	if order in [&"idle", &"seek_hunting_pasture", &"evade"]:
		return true
	if order != &"attack":
		return false
	var target := entity(int(hunter.get("target_id", -1)))
	return not target.is_empty() and target.get("category") == &"wildlife"


func _start_hunter_competition_attack(hunter: Dictionary) -> bool:
	var target_id := _nearest_enemy_hunter(
		hunter,
		float(hunter.get("acquire_range", 3.8)),
		true,
	)
	if target_id < 0:
		return false
	_clear_active_order_state(hunter)
	hunter["order"] = &"attack"
	hunter["target_id"] = target_id
	return true


func _advance_hunter_combat_avoidance(hunter: Dictionary, delta: float) -> bool:
	var threat_id := _nearest_hunter_combat_threat(
		hunter,
		float(hunter.get("acquire_range", 3.8)),
		true,
	)
	if threat_id < 0:
		return false
	var threat := entity(threat_id)
	if (
		hunter.get("order") != &"evade"
		or float(hunter.get("repath_timer", 0.0)) <= 0.0
		or (hunter.get("path", []) as Array).is_empty()
	):
		_start_hunter_combat_avoidance(hunter, threat)
	if (hunter.get("path", []) as Array).is_empty():
		return true
	_advance_path(hunter, delta)
	return true


func _start_hunter_combat_avoidance(hunter: Dictionary, threat: Dictionary) -> void:
	_clear_active_order_state(hunter)
	hunter["order"] = &"evade"
	hunter["repath_timer"] = HUNTER_COMBAT_EVADE_REPATH_SECONDS
	var position := hunter["position"] as Vector2
	var away := position - (threat["position"] as Vector2)
	if away.length_squared() <= 0.001:
		var angle := deg_to_rad(float(posmod(int(hunter["id"]) * 71, 360)))
		away = Vector2.RIGHT.rotated(angle)
	else:
		away = away.normalized()
	var current_distance := _entity_distance(hunter, threat)
	for angle_offset in [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0]:
		var desired := position + away.rotated(float(angle_offset)) * HUNTER_COMBAT_EVADE_DISTANCE
		var destination := _nearest_walkable(Vector2i(desired.round()))
		if Vector2(destination).distance_to(_entity_center(threat)) <= current_distance:
			continue
		_set_path(hunter, destination)
		if not (hunter.get("path", []) as Array).is_empty():
			return
	hunter["order"] = &"idle"


func _advance_attack_order(attacker: Dictionary, delta: float) -> bool:
	var target_id := int(attacker.get("target_id", -1))
	var had_target := target_id >= 0
	var target := entity(target_id)
	if _is_neutral_guardian(attacker) and not target.is_empty():
		var leash_origin := attacker["leash_origin"] as Vector2
		var leash_radius := float(attacker.get("leash_radius", GUARDIAN_LEASH_RADIUS))
		if (
			(attacker["position"] as Vector2).distance_to(leash_origin) > leash_radius
			or (target["position"] as Vector2).distance_to(leash_origin) > leash_radius
		):
			_return_guardian_home(attacker)
			_advance_path(attacker, delta)
			return true
	var target_is_visible: bool = (
		_is_neutral_guardian(attacker)
		or attacker.get("category") == &"wildlife"
		or is_entity_visible_to_team(int(attacker.get("team", TEAM_NEUTRAL)), target)
	)
	if (
		target.is_empty()
		or not bool(target.get("alive", false))
		or not are_hostile(attacker, target)
		or not target_is_visible
	):
		attacker["target_id"] = -1
		if attacker.get("order") == &"patrol":
			var patrol_acquired := _nearest_enemy(attacker, float(attacker["acquire_range"]), true)
			if patrol_acquired >= 0:
				attacker["target_id"] = patrol_acquired
				target = entity(patrol_acquired)
				attacker["path"] = []
				attacker["path_index"] = 0
			else:
				if had_target:
					attacker["path"] = []
				_resume_patrol(attacker)
				return false
		elif bool(attacker.get("attack_move", false)):
			var acquired := _nearest_enemy(attacker, float(attacker["acquire_range"]), true)
			if acquired >= 0:
				attacker["target_id"] = acquired
				target = entity(acquired)
				attacker["path"] = []
				attacker["path_index"] = 0
			else:
				if had_target:
					attacker["path"] = []
				_resume_attack_move(attacker)
				return false
		else:
			_finish_unit_order(attacker)
			return false
	var distance := _combat_distance(attacker, target)
	if distance <= float(attacker["range"]) and _has_line_of_sight(attacker, target):
		if float(attacker["attack_cooldown"]) <= 0.0:
			attacker["path"] = []
			attacker["path_index"] = 0
			_apply_attack(attacker, target)
			if bool(target.get("alive", false)):
				_start_ranged_combat_reposition(attacker, target)
		elif int(attacker.get("combat_reposition_target_id", -1)) == int(target["id"]):
			_advance_ranged_combat_reposition(attacker, target, delta)
		else:
			attacker["path"] = []
			attacker["path_index"] = 0
		return true
	attacker["combat_reposition_target_id"] = -1
	if float(attacker["repath_timer"]) <= 0.0 or (attacker["path"] as Array).is_empty():
		_set_path(attacker, target["cell"] as Vector2i)
		attacker["repath_timer"] = 0.55
	_advance_path(attacker, delta)
	return true


func _start_ranged_combat_reposition(attacker: Dictionary, target: Dictionary) -> void:
	attacker["combat_reposition_target_id"] = -1
	if not _is_ranged_combatant(attacker):
		return
	var start := Vector2i((attacker["position"] as Vector2).round())
	var radial := _entity_center(attacker) - _entity_center(target)
	if radial.is_zero_approx():
		radial = Vector2.RIGHT
	var tangent := Vector2(-radial.y, radial.x).normalized()
	if int(attacker.get("id", 0)) % 2 == 0:
		tangent = -tangent
	var offsets: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.DOWN,
		Vector2i.LEFT,
		Vector2i.UP,
	]
	var best_candidate := start
	var best_score := -INF
	var attack_range := float(attacker["range"])
	for offset in offsets:
		var candidate := start + offset
		if not MapCatalog.in_bounds(candidate) or _astar.is_point_solid(candidate):
			continue
		var candidate_state := attacker.duplicate()
		candidate_state["position"] = Vector2(candidate)
		candidate_state["cell"] = candidate
		var candidate_distance := _combat_distance(candidate_state, target)
		if candidate_distance > attack_range or not _has_line_of_sight(candidate_state, target):
			continue
		var score := Vector2(offset).dot(tangent) + candidate_distance / attack_range * 0.05
		if score > best_score:
			best_score = score
			best_candidate = candidate
	if best_candidate == start:
		return
	_set_path(attacker, best_candidate)
	if (attacker.get("path", []) as Array).is_empty():
		return
	attacker["combat_reposition_target_id"] = int(target["id"])


func _advance_ranged_combat_reposition(
	attacker: Dictionary,
	target: Dictionary,
	delta: float,
) -> void:
	var path := attacker.get("path", []) as Array
	var path_index := int(attacker.get("path_index", 0))
	if path.is_empty() or path_index >= path.size():
		return
	var next_position := (attacker["position"] as Vector2).move_toward(
		path[path_index] as Vector2,
		float(attacker["speed"]) * delta,
	)
	var next_state := attacker.duplicate()
	next_state["position"] = next_position
	next_state["cell"] = Vector2i(next_position.round())
	if (
		_combat_distance(next_state, target) > float(attacker["range"])
		or not _has_line_of_sight(next_state, target)
	):
		attacker["path"] = []
		attacker["path_index"] = 0
		attacker["combat_reposition_target_id"] = -1
		return
	_advance_path(attacker, delta)


func _is_ranged_combatant(entity_state: Dictionary) -> bool:
	return (
		entity_state.get("category") == &"unit"
		and float(entity_state.get("range", 0.0)) >= RANGED_REPOSITION_MIN_RANGE
	)


func _resume_attack_move(unit: Dictionary) -> void:
	var destination := unit.get("attack_move_destination", Vector2i(-1, -1)) as Vector2i
	if not MapCatalog.in_bounds(destination):
		_finish_unit_order(unit)
		return
	if (unit["position"] as Vector2).distance_to(Vector2(destination)) <= 0.1:
		_finish_unit_order(unit)
		return
	if (unit.get("path", []) as Array).is_empty():
		_set_path(unit, destination)


func _clear_attack_move(unit: Dictionary) -> void:
	unit["attack_move"] = false
	unit["attack_move_destination"] = Vector2i(-1, -1)


func _resume_patrol(unit: Dictionary) -> void:
	var destination := unit.get("patrol_target", Vector2i(-1, -1)) as Vector2i
	if not MapCatalog.in_bounds(destination):
		_finish_unit_order(unit)
		return
	if (unit["position"] as Vector2).distance_to(Vector2(destination)) <= 0.1:
		_advance_patrol_leg(unit)
	elif (unit.get("path", []) as Array).is_empty():
		_set_path(unit, destination)


func _advance_patrol_leg(unit: Dictionary) -> void:
	var origin := unit.get("patrol_origin", Vector2i(-1, -1)) as Vector2i
	var destination := unit.get("patrol_destination", Vector2i(-1, -1)) as Vector2i
	if not MapCatalog.in_bounds(origin) or not MapCatalog.in_bounds(destination):
		_finish_unit_order(unit)
		return
	var previous_target := unit.get("patrol_target", destination) as Vector2i
	var next_target := origin if previous_target == destination else destination
	unit["patrol_target"] = next_target
	unit["target_id"] = -1
	_set_path(unit, next_target)


func _advance_guardian_wander(guardian: Dictionary, delta: float) -> void:
	var order := guardian.get("order") as StringName
	if order == &"wander" and (guardian.get("path", []) as Array).is_empty():
		guardian["order"] = &"idle"
		order = &"idle"
	if order != &"idle":
		return
	var leash_origin := guardian["leash_origin"] as Vector2
	if (guardian["position"] as Vector2).distance_to(leash_origin) > GUARDIAN_WANDER_RADIUS:
		_return_guardian_home(guardian)
		return
	guardian["wander_timer"] = float(guardian.get("wander_timer", 0.0)) - delta
	if float(guardian["wander_timer"]) <= 0.0:
		_start_guardian_wander(guardian)


func _start_guardian_wander(guardian: Dictionary) -> void:
	var leash_origin := guardian["leash_origin"] as Vector2
	var start := Vector2i((guardian["position"] as Vector2).round())
	var radius := int(ceil(GUARDIAN_WANDER_RADIUS))
	var candidates: Array[Vector2i] = []
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var candidate := Vector2i(leash_origin.round()) + Vector2i(x, y)
			if (
				candidate == start
				or not MapCatalog.in_bounds(candidate)
				or _astar.is_point_solid(candidate)
				or Vector2(candidate).distance_to(leash_origin) > GUARDIAN_WANDER_RADIUS
			):
				continue
			var cell_path := _astar.get_id_path(start, candidate, true)
			if _guardian_path_stays_near_cave(cell_path, leash_origin):
				candidates.append(candidate)
	guardian["wander_timer"] = _next_guardian_wander_delay()
	if candidates.is_empty():
		return
	var destination := candidates[_wander_rng.randi_range(0, candidates.size() - 1)]
	guardian["order"] = &"wander"
	_set_path(guardian, destination)
	if (guardian.get("path", []) as Array).is_empty():
		guardian["order"] = &"idle"


func _guardian_path_stays_near_cave(cell_path: Array[Vector2i], leash_origin: Vector2) -> bool:
	if cell_path.size() <= 1:
		return false
	for cell in cell_path:
		if Vector2(cell).distance_to(leash_origin) > GUARDIAN_WANDER_RADIUS:
			return false
	return true


func _return_guardian_home(guardian: Dictionary) -> void:
	guardian["target_id"] = -1
	_clear_attack_move(guardian)
	guardian["order"] = &"return_home"
	guardian["wander_timer"] = _next_guardian_wander_delay()
	_set_path(guardian, Vector2i((guardian["leash_origin"] as Vector2).round()))


func _next_guardian_wander_delay() -> float:
	return _wander_rng.randf_range(GUARDIAN_WANDER_MIN_DELAY, GUARDIAN_WANDER_MAX_DELAY)


func _advance_wildlife(wildlife: Dictionary, delta: float) -> void:
	var order := wildlife.get("order", &"idle") as StringName
	if order == &"attack":
		var target := entity(int(wildlife.get("target_id", -1)))
		var herd_origin := wildlife["herd_origin"] as Vector2
		var leash := float(wildlife["herd_radius"]) + WILDLIFE_RETALIATION_LEASH_BONUS
		if (
			target.is_empty()
			or not bool(target.get("alive", false))
			or (target["position"] as Vector2).distance_to(herd_origin) > leash
		):
			wildlife["order"] = &"idle"
			wildlife["target_id"] = -1
			wildlife["path"] = []
			wildlife["wander_timer"] = _next_wildlife_wander_delay()
			return
		_advance_attack_order(wildlife, delta)
		return
	if order in [&"wander", &"flee"]:
		_advance_path(wildlife, delta)
		if wildlife.get("order") == &"idle":
			wildlife["wander_timer"] = _next_wildlife_wander_delay()
		return
	if order != &"idle":
		wildlife["order"] = &"idle"
		wildlife["path"] = []
	wildlife["wander_timer"] = float(wildlife.get("wander_timer", 0.0)) - delta
	if float(wildlife["wander_timer"]) <= 0.0:
		_start_wildlife_wander(wildlife)


func _start_wildlife_wander(wildlife: Dictionary) -> void:
	var herd_origin := wildlife["herd_origin"] as Vector2
	var herd_radius := float(wildlife["herd_radius"])
	var start := Vector2i((wildlife["position"] as Vector2).round())
	wildlife["wander_timer"] = _next_wildlife_wander_delay()
	for _attempt in range(8):
		var angle := _wildlife_rng.randf_range(0.0, TAU)
		var distance := _wildlife_rng.randf_range(1.0, herd_radius)
		var candidate := Vector2i((herd_origin + Vector2.RIGHT.rotated(angle) * distance).round())
		if candidate == start or not MapCatalog.in_bounds(candidate) or _astar.is_point_solid(candidate):
			continue
		var cell_path := _astar.get_id_path(start, candidate, true)
		if not _wildlife_path_stays_near_herd(cell_path, herd_origin, herd_radius):
			continue
		wildlife["order"] = &"wander"
		_set_path(wildlife, candidate)
		if (wildlife.get("path", []) as Array).is_empty():
			wildlife["order"] = &"idle"
		return


func _wildlife_path_stays_near_herd(
	cell_path: Array[Vector2i],
	herd_origin: Vector2,
	herd_radius: float,
) -> bool:
	if cell_path.size() <= 1:
		return false
	for cell in cell_path:
		if Vector2(cell).distance_to(herd_origin) > herd_radius:
			return false
	return true


func _next_wildlife_wander_delay() -> float:
	return _wildlife_rng.randf_range(WILDLIFE_WANDER_MIN_DELAY, WILDLIFE_WANDER_MAX_DELAY)


func _react_to_hunt(wildlife: Dictionary, hunter: Dictionary) -> void:
	if bool(wildlife.get("retaliates", false)):
		wildlife["order"] = &"attack"
		wildlife["target_id"] = int(hunter["id"])
		wildlife["path"] = []
		return
	var position := wildlife["position"] as Vector2
	var away := position - (hunter["position"] as Vector2)
	if away.length_squared() <= 0.001:
		var angle := deg_to_rad(float(posmod(int(wildlife["id"]) * 71, 360)))
		away = Vector2.RIGHT.rotated(angle)
	else:
		away = away.normalized()
	var herd_origin := wildlife["herd_origin"] as Vector2
	var flee_limit := float(wildlife["herd_radius"]) + 2.0
	var desired := position + away * WILDLIFE_FLEE_DISTANCE
	if desired.distance_to(herd_origin) > flee_limit:
		desired = herd_origin + (desired - herd_origin).normalized() * flee_limit
	var destination := _nearest_walkable(Vector2i(desired.round()))
	if Vector2(destination).distance_to(herd_origin) > flee_limit:
		destination = _nearest_walkable(Vector2i(herd_origin.round()))
	wildlife["order"] = &"flee"
	wildlife["target_id"] = -1
	_set_path(wildlife, destination)
	if (wildlife.get("path", []) as Array).is_empty():
		wildlife["order"] = &"idle"


func _apply_attack(attacker: Dictionary, target: Dictionary) -> void:
	if bool(target.get("indestructible", false)):
		return
	attacker["attack_cooldown"] = float(attacker["attack_period"])
	var damage := float(attacker["damage"])
	if int(attacker.get("team", TEAM_NEUTRAL)) == TEAM_PLAYER:
		damage *= float(tweak_value(&"player.attack.damage_multiplier", 1.0))
	if attacker.get("kind") == &"hunter" and target.get("category") == &"wildlife":
		damage *= HUNTER_WILDLIFE_DAMAGE_MULTIPLIER
	target["hp"] = float(target["hp"]) - damage
	target["flash_timer"] = 0.16
	_events.append({
		"type": &"attack",
		"from": _entity_center(attacker),
		"to": _entity_center(target),
		"color": _team_color(int(attacker.get("team", TEAM_NEUTRAL))),
		"team": int(attacker.get("team", TEAM_NEUTRAL)),
		"attacker_id": int(attacker.get("id", -1)),
		"attacker_kind": attacker.get("kind", &""),
		"attacker_category": attacker.get("category", &"unit"),
		"attacker_faction": attacker.get("faction", &"neutral"),
		"target_id": int(target.get("id", -1)),
		"target_kind": target.get("kind", &""),
		"target_category": target.get("category", &""),
		"target_faction": target.get("faction", &"neutral"),
		"amount": damage,
	})
	if float(target["hp"]) <= 0.0:
		_kill(target, attacker)
	elif target.get("category") == &"wildlife":
		_react_to_hunt(target, attacker)


func _kill(target: Dictionary, killer: Dictionary) -> void:
	if not bool(target.get("alive", false)):
		return
	var target_category := target.get("category", &"") as StringName
	var wildlife_herd_id := int(target.get("herd_id", -1)) if target_category == &"wildlife" else -1
	if wildlife_herd_id >= 0:
		_ensure_wildlife_population_tracking()
	var displaced_farm_worker: Dictionary = {}
	if target.get("kind") == &"worker":
		_release_farm_assignment(target)
	elif target.get("kind") == &"rice_farm":
		displaced_farm_worker = entity(farm_worker_id(int(target["id"])))
	if bool(target.get("carrying_egg", false)):
		_drop_carried_egg(target)
	if int(target.get("garrisoned_in", -1)) >= 0:
		var occupied_tower := entity(int(target.get("garrisoned_in", -1)))
		if not occupied_tower.is_empty():
			var occupants := occupied_tower.get("garrisoned_unit_ids", []) as Array
			occupants.erase(int(target.get("id", -1)))
			occupied_tower["garrisoned_unit_ids"] = occupants
		target["garrisoned_in"] = -1
	if target.get("kind") == &"sentry_tower":
		_eject_garrisoned_units(target)
	target["alive"] = false
	target["hp"] = 0.0
	if wildlife_herd_id >= 0 and wildlife_herd_id < _wildlife_live_counts.size():
		_wildlife_live_counts[wildlife_herd_id] = maxi(
			0,
			_wildlife_live_counts[wildlife_herd_id] - 1,
		)
	if not displaced_farm_worker.is_empty():
		_finish_unit_order(displaced_farm_worker)
	var killer_team := int(killer.get("team", TEAM_NEUTRAL))
	_record_combat_score(killer_team, target)
	if target.get("category") == &"unit" and int(target["team"]) >= 0:
		players[int(target["team"])]["population"] = maxi(
			0,
			int(players[int(target["team"])]["population"]) - int(target.get("population", 0)),
		)
	elif target.get("category") == &"structure" and int(target.get("team", TEAM_NEUTRAL)) >= 0:
		_cancel_structure_queue(target, int(target["team"]))
	if (
		target.get("kind") == &"jadeclaw"
		and int(target.get("team", TEAM_NEUTRAL)) == TEAM_NEUTRAL
		and int(target.get("home_cave_id", -1)) >= 0
	):
		_award_guardian_bounty(killer_team, target)
	if target.get("kind") == &"shenlong" and bool(target.get("is_shenlong_guardian", false)):
		_unlock_shenlong_egg(killer_team)
	if target.get("category") == &"wildlife" and killer.get("kind") == &"hunter":
		_award_wildlife_bounty(killer_team, target)
	if killer_team >= 0 and killer.get("faction") == &"demon":
		killer["hp"] = minf(float(killer["max_hp"]), float(killer["hp"]) + 12.0)
		_grant_resource_income(killer_team, &"essence", 3)
	_events.append({
		"type": &"death",
		"position": _entity_center(target),
		"color": Color("ff735d"),
		"entity_id": int(target.get("id", -1)),
		"team": int(target.get("team", TEAM_NEUTRAL)),
		"category": target.get("category", &""),
		"kind": target.get("kind", &""),
		"faction": target.get("faction", &"neutral"),
		"footprint": target.get("footprint", Vector2i.ONE),
		"killer_team": killer_team,
		"killer_id": int(killer.get("id", -1)),
		"killer_kind": killer.get("kind", &""),
	})
	if target.get("category") in [&"structure", &"resource"]:
		_rebuild_pathfinding()
	if target.get("kind") == &"stronghold":
		_resolve_stronghold_elimination(int(target["team"]))
	if target_category == &"wildlife":
		entities.erase(int(target.get("id", -1)))


func _unlock_shenlong_egg(killer_team: int) -> void:
	var egg := shenlong_egg()
	if egg.is_empty() or not bool(egg.get("alive", false)):
		return
	egg["claimable"] = true
	_add_event(&"shenlong_defeated", _entity_center(egg), Color("b7ffd8"), {"team": killer_team, "kind": &"shenlong_egg"})
	battle_notice.emit(&"notice.shenlong_fallen", {}, killer_team)


func _resolve_stronghold_elimination(eliminated_team: int) -> void:
	if not _is_valid_team(eliminated_team) or not outcome.is_empty():
		return
	players[eliminated_team]["eliminated"] = true
	_cull_eliminated_team(eliminated_team)
	if eliminated_team == TEAM_PLAYER:
		_finish_match(&"defeat")
		return
	var remaining := living_rival_count()
	if remaining <= 0:
		_finish_match(&"victory")
	else:
		battle_notice.emit(&"notice.rivals_remaining", {"count": remaining}, TEAM_PLAYER)


func _finish_match(result: StringName) -> void:
	if not outcome.is_empty() or result not in [&"victory", &"defeat"]:
		return
	outcome = result
	_accumulator = 0.0
	match_ended.emit(outcome)


func _cull_eliminated_team(eliminated_team: int) -> void:
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if int(entity_state.get("team", TEAM_NEUTRAL)) != eliminated_team:
			continue
		if entity_state.get("category") == &"unit":
			if not bool(entity_state.get("alive", false)):
				continue
			if bool(entity_state.get("carrying_egg", false)):
				_drop_carried_egg(entity_state)
			_cancel_all_unit_orders(entity_state)
		elif entity_state.get("category") == &"structure":
			_cancel_structure_queue(entity_state, eliminated_team)
			if entity_state.get("kind") == &"yaoguai_den":
				entity_state["team"] = TEAM_NEUTRAL
				entity_state["faction"] = &"neutral"
				entity_state["order"] = &"claimable" if bool(entity_state.get("capture_unlocked", false)) else &"guarded"
				entity_state["capture_team"] = TEAM_NEUTRAL
				entity_state["capture_progress"] = 0.0
				entity_state["capture_contested"] = false
				continue
		if bool(entity_state.get("alive", false)):
			_kill(entity_state, {})


func living_rival_count() -> int:
	var result := 0
	for team in range(1, players.size()):
		if not _stronghold_for_team(team).is_empty():
			result += 1
	return result


func _award_guardian_bounty(team: int, guardian: Dictionary) -> void:
	if team < 0:
		return
	for resource_kind in MONSTER_BOUNTY:
		_grant_resource_income(team, StringName(resource_kind), int(MONSTER_BOUNTY[resource_kind]))
	_add_event(&"bounty", _entity_center(guardian), Color("e4c66d"), {"team": team, "kind": &"jadeclaw"})
	battle_notice.emit(&"notice.jadeclaw_hunted", {}, team)
	var cave := entity(int(guardian.get("home_cave_id", -1)))
	if cave.is_empty() or cave_guardian_count(int(cave["id"])) > 0:
		return
	cave["capture_unlocked"] = true
	cave["order"] = &"claimable"
	_add_event(
		&"cave_cleared",
		_entity_center(cave),
		Color("e4c66d"),
		{"team": team, "category": &"structure", "kind": &"yaoguai_den"},
	)
	battle_notice.emit(&"notice.den_cleared", {}, team)


func _award_wildlife_bounty(team: int, wildlife: Dictionary) -> void:
	if team < 0:
		return
	var faction := players[team]["faction"] as StringName
	if not FactionCatalog.can_hunt(faction):
		return
	var bounty := int(wildlife.get("food_bounty", 0))
	_grant_resource_income(team, &"food", bounty)
	_add_event(
		&"bounty",
		_entity_center(wildlife),
		Color("f1c96b"),
		{"team": team, "category": &"wildlife", "kind": wildlife["kind"]},
	)
	battle_notice.emit(
		&"notice.wildlife_hunted",
		{"kind": wildlife["kind"], "bounty": bounty},
		team,
	)


func _advance_path(entity_state: Dictionary, delta: float) -> void:
	var path := entity_state.get("path", []) as Array
	var path_index := int(entity_state.get("path_index", 0))
	var regeneration_attempted := false
	if (
		not path.is_empty()
		and path_index >= 0
		and path_index < path.size()
		and (
			int(entity_state.get("pathfinding_revision", -1)) != _pathfinding_revision
			or not _is_path_step_walkable(entity_state, path[path_index] as Vector2)
		)
	):
		_regenerate_saved_path(entity_state)
		regeneration_attempted = true
		path = entity_state.get("path", []) as Array
		path_index = int(entity_state.get("path_index", 0))
	if path.is_empty() or path_index < 0 or path_index >= path.size():
		if _active_route_needs_recovery(entity_state):
			if not regeneration_attempted and float(entity_state.get("repath_timer", 0.0)) <= 0.0:
				_regenerate_saved_path(entity_state)
				path = entity_state.get("path", []) as Array
				path_index = int(entity_state.get("path_index", 0))
			if path.is_empty() or path_index < 0 or path_index >= path.size():
				return
		else:
			_complete_path_movement(entity_state)
			return
	var target := path[path_index] as Vector2
	var position := entity_state["position"] as Vector2
	position = position.move_toward(target, float(entity_state["speed"]) * delta)
	entity_state["position"] = position
	entity_state["cell"] = Vector2i(position.round())
	if position.distance_to(target) <= 0.025:
		entity_state["position"] = target
		entity_state["cell"] = Vector2i(target)
		path_index += 1
		entity_state["path_index"] = path_index
		if path_index >= path.size():
			entity_state["path"] = []
			entity_state["path_index"] = 0
			_complete_path_movement(entity_state)


func _regenerate_saved_path(entity_state: Dictionary) -> void:
	var destination := entity_state.get("path_destination", Vector2i(-1, -1)) as Vector2i
	entity_state["path"] = []
	entity_state["path_index"] = 0
	if MapCatalog.in_bounds(destination):
		_set_path(entity_state, destination)
	entity_state["repath_timer"] = PATH_RECOVERY_RETRY_SECONDS


func _active_route_needs_recovery(entity_state: Dictionary) -> bool:
	var order := entity_state.get("order", &"idle") as StringName
	if order == &"attack_move" and int(entity_state.get("target_id", -1)) >= 0:
		return false
	if order == &"patrol" and int(entity_state.get("target_id", -1)) >= 0:
		return false
	if order not in [&"move", &"attack_move", &"patrol"]:
		return false
	var destination := entity_state.get("path_destination", Vector2i(-1, -1)) as Vector2i
	if order == &"attack_move":
		destination = entity_state.get("attack_move_destination", destination) as Vector2i
	elif order == &"patrol":
		destination = entity_state.get("patrol_target", destination) as Vector2i
	if not MapCatalog.in_bounds(destination):
		return false
	if destination != entity_state.get("path_destination", Vector2i(-1, -1)):
		entity_state["path_destination"] = destination
		entity_state["path_endpoint"] = Vector2i(-1, -1)
	var endpoint := entity_state.get("path_endpoint", Vector2i(-1, -1)) as Vector2i
	return not MapCatalog.in_bounds(endpoint) or (
		(entity_state["position"] as Vector2).distance_to(Vector2(endpoint)) > 0.1
	)


func _is_path_step_walkable(entity_state: Dictionary, target: Vector2) -> bool:
	var target_cell := Vector2i(target.round())
	if not _is_path_cell_walkable_for(entity_state, target_cell):
		return false
	var current_cell := Vector2i((entity_state["position"] as Vector2).round())
	var offset := target_cell - current_cell
	if absi(offset.x) == 1 and absi(offset.y) == 1:
		return (
			_is_path_cell_walkable_for(entity_state, current_cell + Vector2i(offset.x, 0))
			and _is_path_cell_walkable_for(entity_state, current_cell + Vector2i(0, offset.y))
		)
	return true


func _is_path_cell_walkable_for(entity_state: Dictionary, cell: Vector2i) -> bool:
	if not MapCatalog.in_bounds(cell):
		return false
	if not _astar.is_point_solid(cell):
		return true
	var blocker_id := int(_line_of_sight_blockers.get(cell, -1))
	if blocker_id < 0:
		return false
	var blocker := entity(blocker_id)
	return (
		not bool(entity_state.get("carrying_egg", false))
		and not blocker.is_empty()
		and blocker.get("category") == &"structure"
		and int(blocker.get("team", TEAM_NEUTRAL)) == int(entity_state.get("team", TEAM_NEUTRAL))
		and blocker.get("kind") not in SOLID_FRIENDLY_STRUCTURE_KINDS
	)


func _complete_path_movement(entity_state: Dictionary) -> void:
	if entity_state.get("order") == &"move":
		_finish_unit_order(entity_state)
	elif entity_state.get("order") in [&"wander", &"flee", &"return_home"]:
		entity_state["order"] = &"idle"
	elif entity_state.get("order") == &"seek_hunting_pasture":
		_finish_unit_order(entity_state)
	elif entity_state.get("order") == &"evade":
		_finish_unit_order(entity_state)
	elif entity_state.get("order") == &"attack_move" and int(entity_state.get("target_id", -1)) < 0:
		_finish_unit_order(entity_state)
	elif entity_state.get("order") == &"patrol" and int(entity_state.get("target_id", -1)) < 0:
		_advance_patrol_leg(entity_state)


func _advance_ai(delta: float) -> void:
	_ai_strategy_timer -= delta
	_ai_attack_timer -= delta
	_ai_cave_timer -= delta
	_ai_hunt_timer -= delta
	for team in range(TEAM_RIVAL_TWO, players.size()):
		_extra_ai_attack_timers[team] = float(_extra_ai_attack_timers.get(team, AI_INITIAL_ASSAULT_DELAY)) - delta
		_extra_ai_cave_timers[team] = float(_extra_ai_cave_timers.get(team, 3.0)) - delta
		_extra_ai_hunt_timers[team] = float(_extra_ai_hunt_timers.get(team, 4.0)) - delta
	for team in range(TEAM_ENEMY, players.size()):
		if (
			bool(players[team].get("is_ai", false))
			and not _ai_skill_test_launched_for_team(team)
			and elapsed_time >= AI_SKILL_TEST_TIME_SECONDS
		):
			_set_ai_skill_test_launched(team, _issue_ai_skill_test_invasion(team))
	if _ai_strategy_timer > 0.0:
		return
	_ai_strategy_timer = float(tweak_value(&"enemies.ai.decision_interval", 1.4))
	for team in range(TEAM_ENEMY, players.size()):
		if bool(players[team].get("is_ai", false)) and not bool(players[team].get("eliminated", false)):
			_advance_ai_team(team)


func _advance_ai_team(team: int) -> void:
	var stronghold := _stronghold_for_team(team)
	if (
		not stronghold.is_empty()
		and _team_units_of_kind(team, &"worker").size() < 5
		and (stronghold.get("queue", []) as Array).is_empty()
	):
		command_train(team, int(stronghold["id"]), &"worker")
	_try_rebuild_ai_war_camp(team)
	_try_expand_ai_food_economy(team)
	_try_assign_ai_farmer(team)
	_try_train_ai_hunters(team)
	if _ai_hunt_timer_for_team(team) <= 0.0:
		_set_ai_hunt_timer(team, 5.0)
		_issue_ai_hunt_orders(team)
	for camp in _team_structures_of_kind(team, &"war_camp"):
		if (camp.get("queue", []) as Array).size() >= 2:
			continue
		var flip := _ai_training_flip_for_team(team)
		var next_kind: StringName = &"mystic" if flip else &"vanguard"
		if command_train(team, int(camp["id"]), next_kind):
			_set_ai_training_flip(team, not flip)
		else:
			var fallback_kind: StringName = &"vanguard" if next_kind == &"mystic" else &"mystic"
			if command_train(team, int(camp["id"]), fallback_kind):
				_set_ai_training_flip(team, fallback_kind == &"vanguard")
	for cave in _team_structures_of_kind(team, &"yaoguai_den"):
		if (cave.get("queue", []) as Array).size() < 2:
			command_train(team, int(cave["id"]), &"jadeclaw")
	var army := _team_military(team)
	var pursuing_shenlong := _issue_ai_shenlong_order(team, army)
	if (
		not pursuing_shenlong
		and not _ai_skill_test_launched_for_team(team)
		and captured_cave_count(team) == 0
		and army.size() >= 3
	):
		if _ai_cave_timer_for_team(team) <= 0.0:
			_set_ai_cave_timer(team, 6.0)
			_issue_ai_cave_order(army, team)
	elif not pursuing_shenlong:
		var ready := _ready_ai_assault_units(army)
		if _ai_attack_timer_for_team(team) <= 0.0 and ready.size() >= AI_ASSAULT_MIN_READY_UNITS:
			_issue_ai_base_assault(ready, team)
	_auto_assign_idle_worker(team)
	_try_scout_ai_for_resources(team)


func _ai_attack_timer_for_team(team: int) -> float:
	return _ai_attack_timer if team == TEAM_ENEMY else float(_extra_ai_attack_timers.get(team, 0.0))


func _ai_cave_timer_for_team(team: int) -> float:
	return _ai_cave_timer if team == TEAM_ENEMY else float(_extra_ai_cave_timers.get(team, 0.0))


func _set_ai_cave_timer(team: int, value: float) -> void:
	if team == TEAM_ENEMY:
		_ai_cave_timer = value
	else:
		_extra_ai_cave_timers[team] = value


func _ai_hunt_timer_for_team(team: int) -> float:
	return _ai_hunt_timer if team == TEAM_ENEMY else float(_extra_ai_hunt_timers.get(team, 0.0))


func _set_ai_hunt_timer(team: int, value: float) -> void:
	if team == TEAM_ENEMY:
		_ai_hunt_timer = value
	else:
		_extra_ai_hunt_timers[team] = value


func _ai_training_flip_for_team(team: int) -> bool:
	return _ai_training_flip if team == TEAM_ENEMY else bool(_extra_ai_training_flips.get(team, false))


func _set_ai_training_flip(team: int, value: bool) -> void:
	if team == TEAM_ENEMY:
		_ai_training_flip = value
	else:
		_extra_ai_training_flips[team] = value


func _ai_skill_test_launched_for_team(team: int) -> bool:
	return _ai_skill_test_launched if team == TEAM_ENEMY else bool(_extra_ai_skill_tests.get(team, false))


func _set_ai_skill_test_launched(team: int, value: bool) -> void:
	if team == TEAM_ENEMY:
		_ai_skill_test_launched = value
	else:
		_extra_ai_skill_tests[team] = value


func _ready_ai_assault_units(army: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for unit in army:
		if unit.get("order", &"idle") == &"idle":
			result.append(unit)
	return result


func _nearest_hostile_stronghold(team: int) -> Dictionary:
	var origin := _stronghold_for_team(team)
	if origin.is_empty():
		return {}
	var best: Dictionary = {}
	var best_distance := INF
	for rival_team in range(players.size()):
		if rival_team == team:
			continue
		var candidate := _stronghold_for_team(rival_team)
		if candidate.is_empty():
			continue
		var distance := _entity_distance(origin, candidate)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func _issue_ai_shenlong_order(team: int, army: Array[Dictionary]) -> bool:
	if _ai_shenlong_lock_active(team):
		return false
	var egg := shenlong_egg()
	if egg.is_empty() or not bool(egg.get("alive", false)):
		return false
	if int(egg.get("carried_by", -1)) >= 0:
		var carrier := entity(int(egg["carried_by"]))
		return not carrier.is_empty() and int(carrier.get("team", TEAM_NEUTRAL)) == team
	if bool(egg.get("claimable", false)):
		for worker in _team_units_of_kind(team, &"worker"):
			if float(worker.get("cargo_amount", 0.0)) <= 0.0 and not bool(worker.get("carrying_egg", false)):
				return command_claim_egg(team, [int(worker["id"])], int(egg["id"]))
		return false
	var guardian := shenlong_guardian()
	if guardian.is_empty() or army.size() < AI_SHENLONG_MIN_READY_UNITS:
		return false
	var ids: Array[int] = []
	for unit in army:
		ids.append(int(unit["id"]))
	if is_entity_visible_to_team(team, guardian):
		return command_attack(team, ids, int(guardian["id"]))
	return command_move(team, ids, guardian["cell"] as Vector2i, true)


func _issue_ai_base_assault(ready_units: Array[Dictionary], team: int = TEAM_ENEMY) -> void:
	var target_hold := _nearest_hostile_stronghold(team)
	if target_hold.is_empty():
		return
	var ids: Array[int] = []
	for index in range(mini(AI_ASSAULT_WAVE_SIZE, ready_units.size())):
		ids.append(int(ready_units[index]["id"]))
	if is_entity_visible_to_team(team, target_hold):
		command_attack(team, ids, int(target_hold["id"]))
	else:
		command_move(team, ids, target_hold["cell"] as Vector2i, true)
	if team == TEAM_ENEMY:
		_ai_attack_timer = AI_ASSAULT_INTERVAL
	else:
		_extra_ai_attack_timers[team] = AI_ASSAULT_INTERVAL


func _issue_ai_skill_test_invasion(team: int = TEAM_ENEMY) -> bool:
	var army := _team_military(team)
	var target_hold := _nearest_hostile_stronghold(team)
	if army.is_empty() or target_hold.is_empty():
		return false
	var ids: Array[int] = []
	for unit in army:
		ids.append(int(unit["id"]))
	var issued := false
	if is_entity_visible_to_team(team, target_hold):
		issued = command_attack(team, ids, int(target_hold["id"]))
	else:
		issued = command_move(team, ids, target_hold["cell"] as Vector2i, true)
	if issued:
		if team == TEAM_ENEMY:
			_ai_attack_timer = AI_ASSAULT_INTERVAL
		else:
			_extra_ai_attack_timers[team] = AI_ASSAULT_INTERVAL
		battle_notice.emit(
			&"notice.ai_invasion",
			{},
			team,
		)
	return issued


func _issue_ai_cave_order(army: Array[Dictionary], team: int = TEAM_ENEMY) -> void:
	var stronghold := _stronghold_for_team(team)
	if stronghold.is_empty():
		return
	var best_cave: Dictionary = {}
	var best_distance := INF
	for cave_id in cave_ids():
		var cave := entity(cave_id)
		if int(cave.get("team", TEAM_NEUTRAL)) == team:
			continue
		var distance := _entity_distance(stronghold, cave)
		if distance < best_distance:
			best_distance = distance
			best_cave = cave
	if best_cave.is_empty():
		return
	var ids: Array[int] = []
	for unit in army:
		ids.append(int(unit["id"]))
	if (
		is_entity_explored_by_team(team, best_cave)
		and cave_guardian_count(int(best_cave["id"])) > 0
	):
		var target_id := -1
		var target_distance := INF
		for raw_guardian_id in best_cave.get("guardian_ids", []) as Array:
			var guardian := entity(int(raw_guardian_id))
			if (
				not bool(guardian.get("alive", false))
				or not is_entity_visible_to_team(team, guardian)
			):
				continue
			var distance := _entity_distance(stronghold, guardian)
			if distance < target_distance:
				target_distance = distance
				target_id = int(guardian["id"])
			if target_id >= 0:
				command_attack(team, ids, target_id)
				return
	command_move(team, ids, best_cave["cell"] as Vector2i, true)


func _try_rebuild_ai_war_camp(team: int = TEAM_ENEMY) -> void:
	if not _team_structures_of_kind(team, &"war_camp").is_empty():
		return
	var builder := _available_builder(team)
	if builder.is_empty() or not can_afford_kind(team, &"war_camp"):
		return
	var preferred_site := MapCatalog.start_definition(team).get("war_camp", Vector2i(-1, -1)) as Vector2i
	var sites: Array[Vector2i] = [
		preferred_site,
		preferred_site + Vector2i(-1, 0),
		preferred_site + Vector2i(0, 1),
		preferred_site + Vector2i(-1, 1),
	]
	for site in sites:
		if can_place_war_camp(team, site):
			command_build_war_camp(team, int(builder["id"]), site)
			return


func _try_expand_ai_food_economy(team: int = TEAM_ENEMY) -> void:
	var farms := _team_structures_of_kind(team, &"rice_farm")
	var lodges := _team_structures_of_kind(team, &"hunters_lodge")
	var faction := players[team]["faction"] as StringName
	var structure_kind := &"" as StringName
	if FactionCatalog.can_farm(faction) and farms.is_empty():
		structure_kind = &"rice_farm"
	elif (
		FactionCatalog.can_hunt(faction)
		and lodges.is_empty()
		and (not FactionCatalog.can_farm(faction) or int(players[team]["food"]) < 100)
	):
		structure_kind = &"hunters_lodge"
	if structure_kind.is_empty() or not can_afford_kind(team, structure_kind):
		return
	var builder := _available_builder(team)
	var stronghold := _stronghold_for_team(team)
	if builder.is_empty() or stronghold.is_empty():
		return
	var site := _find_build_site(team, structure_kind, stronghold["cell"] as Vector2i)
	if site.x >= 0:
		command_build(team, int(builder["id"]), structure_kind, site)


func _try_train_ai_hunters(team: int = TEAM_ENEMY) -> void:
	var faction := players[team]["faction"] as StringName
	if not FactionCatalog.can_hunt(faction):
		return
	var hunter_total := _team_units_of_kind(team, &"hunter").size()
	for lodge in _team_structures_of_kind(team, &"hunters_lodge"):
		if float(lodge.get("complete", 0.0)) < 1.0:
			continue
		for raw_item in lodge.get("queue", []) as Array:
			if (raw_item as Dictionary).get("kind") == &"hunter":
				hunter_total += 1
		if hunter_total >= 2:
			return
		if command_train(team, int(lodge["id"]), &"hunter"):
			hunter_total += 1


func _try_assign_ai_farmer(team: int = TEAM_ENEMY) -> void:
	var available_worker: Dictionary = {}
	for worker in _team_units_of_kind(team, &"worker"):
		if (
			worker.get("order", &"idle") in [&"build", &"farm"]
			or bool(worker.get("carrying_egg", false))
			or float(worker.get("cargo_amount", 0.0)) > 0.0
		):
			continue
		if worker.get("order", &"idle") == &"idle":
			available_worker = worker
			break
		if available_worker.is_empty():
			available_worker = worker
	if available_worker.is_empty():
		return
	for farm in _team_structures_of_kind(team, &"rice_farm"):
		if float(farm.get("complete", 0.0)) < 1.0 or farm_worker_id(int(farm["id"])) >= 0:
			continue
		command_assign_farm_worker(team, [int(available_worker["id"])], int(farm["id"]))
		return


func _issue_ai_hunt_orders(team: int = TEAM_ENEMY) -> void:
	if wildlife_ids().is_empty():
		return
	for hunter in _team_units_of_kind(team, &"hunter"):
		if hunter.get("order") != &"idle":
			continue
		var pasture := _preferred_hunter_pasture(hunter)
		if pasture.is_empty():
			hunter["hunting_pasture_id"] = -1
			continue
		var pasture_id := int(pasture["id"])
		hunter["hunting_pasture_id"] = pasture_id
		var target_id := _nearest_visible_wildlife_in_pasture(hunter, pasture_id)
		if target_id >= 0 and command_attack(team, [int(hunter["id"])], target_id):
			continue
		_start_hunter_pasture_search(hunter)


func _nearest_wildlife_herd_center(origin: Vector2, team: int = TEAM_ENEMY) -> Vector2i:
	var pasture := _preferred_hunter_pasture({
		"position": origin,
		"team": team,
		"hunting_pasture_id": -1,
	})
	return pasture.get("center", Vector2i(-1, -1)) as Vector2i


func _preferred_hunter_pasture(hunter: Dictionary) -> Dictionary:
	var living_pastures: Dictionary = {}
	for raw_target in entities.values():
		var target := raw_target as Dictionary
		if not bool(target.get("alive", false)) or target.get("category") != &"wildlife":
			continue
		var herd_id := int(target.get("herd_id", -1))
		if herd_id < 0:
			continue
		living_pastures[herd_id] = Vector2i(
			(target.get("herd_origin", target["position"]) as Vector2).round()
		)
	if living_pastures.is_empty():
		return {}

	var origin := hunter.get("position", Vector2.ZERO) as Vector2
	var team := int(hunter.get("team", TEAM_NEUTRAL))
	var stronghold := _stronghold_for_team(team)
	var best_id := -1
	var best_distance := INF
	# Exhaust every living home pasture before permitting expansion.
	if not stronghold.is_empty():
		var home := _entity_center(stronghold)
		for raw_herd_id in living_pastures:
			var herd_id := int(raw_herd_id)
			var center := living_pastures[raw_herd_id] as Vector2i
			if Vector2(center).distance_to(home) > HUNTER_HOME_GAME_RADIUS:
				continue
			var distance := origin.distance_to(Vector2(center))
			if distance < best_distance:
				best_distance = distance
				best_id = herd_id
		if best_id >= 0:
			return {"id": best_id, "center": living_pastures[best_id]}

	var current_pasture_id := int(hunter.get("hunting_pasture_id", -1))
	# An explored pasture is not exhausted while any member of its herd survives.
	if living_pastures.has(current_pasture_id):
		return {
			"id": current_pasture_id,
			"center": living_pastures[current_pasture_id],
		}

	best_id = -1
	best_distance = INF
	# Once the current pasture is empty, seek genuinely new hunting grounds.
	for raw_herd_id in living_pastures:
		var herd_id := int(raw_herd_id)
		var center := living_pastures[raw_herd_id] as Vector2i
		if team >= 0 and is_cell_explored_by_team(team, center):
			continue
		var distance := origin.distance_to(Vector2(center))
		if distance < best_distance:
			best_distance = distance
			best_id = herd_id
	if best_id >= 0:
		return {"id": best_id, "center": living_pastures[best_id]}

	best_distance = INF
	for raw_herd_id in living_pastures:
		var herd_id := int(raw_herd_id)
		var center := living_pastures[raw_herd_id] as Vector2i
		var distance := origin.distance_to(Vector2(center))
		if distance < best_distance:
			best_distance = distance
			best_id = herd_id
	return {"id": best_id, "center": living_pastures[best_id]}


func _hunter_pasture_search_cell(
	hunter: Dictionary,
	pasture_id: int,
	pasture_center: Vector2i,
) -> Vector2i:
	var origin := hunter["position"] as Vector2
	if origin.distance_to(Vector2(pasture_center)) > 1.0:
		return pasture_center
	var best_cell := pasture_center
	var best_distance := INF
	for raw_target in entities.values():
		var target := raw_target as Dictionary
		if (
			not bool(target.get("alive", false))
			or target.get("category") != &"wildlife"
			or int(target.get("herd_id", -1)) != pasture_id
		):
			continue
		var candidate := Vector2i((target["position"] as Vector2).round())
		var distance := origin.distance_to(Vector2(candidate))
		if distance > 0.75 and distance < best_distance:
			best_distance = distance
			best_cell = candidate
	return best_cell


func _nearest_visible_wildlife_in_pasture(hunter: Dictionary, pasture_id: int) -> int:
	var best_id := -1
	var best_distance := INF
	var team := int(hunter.get("team", TEAM_NEUTRAL))
	for raw_target in entities.values():
		var target := raw_target as Dictionary
		if (
			not bool(target.get("alive", false))
			or target.get("category") != &"wildlife"
			or int(target.get("herd_id", -1)) != pasture_id
			or not are_hostile(hunter, target)
			or not is_entity_visible_to_team(team, target)
		):
			continue
		var distance := _entity_distance(hunter, target)
		if distance < best_distance:
			best_distance = distance
			best_id = int(target["id"])
	return best_id


func _available_builder(team: int) -> Dictionary:
	var fallback: Dictionary = {}
	for worker in _team_units_of_kind(team, &"worker"):
		if worker.get("order") == &"build":
			continue
		if worker.get("order") == &"idle":
			return worker
		if fallback.is_empty():
			fallback = worker
	return fallback


func _find_build_site(team: int, structure_kind: StringName, origin: Vector2i) -> Vector2i:
	for radius in range(2, 13):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if abs(x) + abs(y) != radius:
					continue
				var candidate := origin + Vector2i(x, y)
				if can_place_structure(team, structure_kind, candidate):
					return candidate
	return Vector2i(-1, -1)


func _auto_assign_workers(team: int) -> void:
	for worker in _team_units_of_kind(team, &"worker"):
		if team != TEAM_PLAYER:
			_assign_ai_resource(worker)
		else:
			_assign_nearest_resource(worker)


func _auto_assign_idle_workers_to_construction() -> void:
	for team in range(players.size()):
		for worker in _team_units_of_kind(team, &"worker"):
			if worker.get("order") != &"idle":
				continue
			var target := _nearest_incomplete_structure(worker)
			if not target.is_empty():
				command_construct(team, [int(worker["id"])], int(target["id"]))


func _auto_assign_idle_worker(team: int) -> void:
	for worker in _team_units_of_kind(team, &"worker"):
		if worker.get("order") == &"idle":
			if team != TEAM_PLAYER:
				_assign_ai_resource(worker)
			else:
				_assign_nearest_resource(worker)
			return


func _assign_ai_resource(worker: Dictionary) -> void:
	var team := int(worker.get("team", TEAM_NEUTRAL))
	if not _is_valid_team(team):
		return
	var preferred_kind := _preferred_ai_resource_kind(team, int(worker.get("id", -1)))
	if not _assign_nearest_resource(worker, preferred_kind):
		_assign_nearest_resource(worker)


func _preferred_ai_resource_kind(team: int, excluded_worker_id: int = -1) -> StringName:
	var assigned := {&"jade": 0, &"lumber": 0, &"essence": 0}
	for teammate in _team_units_of_kind(team, &"worker"):
		if int(teammate.get("id", -1)) == excluded_worker_id:
			continue
		var source := entity(int(teammate.get("gather_source_id", -1)))
		var kind := source.get("resource_kind", &"") as StringName
		if bool(source.get("alive", false)) and assigned.has(kind):
			assigned[kind] = int(assigned[kind]) + 1
	var preferred_kind: StringName = AI_RESOURCE_KINDS[0]
	var lowest_pressure := INF
	for resource_kind in AI_RESOURCE_KINDS:
		var reserve := float(AI_RESOURCE_RESERVES[resource_kind])
		var pressure := (
			float(players[team][String(resource_kind)]) / reserve
			+ float(assigned[resource_kind])
		)
		if pressure < lowest_pressure:
			lowest_pressure = pressure
			preferred_kind = resource_kind
	return preferred_kind


func _try_scout_ai_for_resources(team: int) -> bool:
	var scout: Dictionary = {}
	for worker in _team_units_of_kind(team, &"worker"):
		if worker.get("order", &"idle") == &"move":
			return false
		if (
			scout.is_empty()
			and worker.get("order", &"idle") == &"idle"
			and float(worker.get("cargo_amount", 0.0)) <= 0.0
			and not bool(worker.get("carrying_egg", false))
		):
			scout = worker
	if scout.is_empty() or not _nearest_resource(scout).is_empty():
		return false
	var resource_kind := _preferred_ai_resource_kind(team, int(scout["id"]))
	var target := _nearest_unexplored_resource(scout, resource_kind)
	if target.is_empty():
		target = _nearest_unexplored_resource(scout)
	if target.is_empty():
		return false
	return command_move(team, [int(scout["id"])], target["cell"] as Vector2i)


func _assign_nearest_resource(worker: Dictionary, resource_kind: StringName = &"") -> bool:
	var resource := _nearest_resource(worker, resource_kind)
	if not resource.is_empty():
		command_gather(int(worker["team"]), [int(worker["id"])], int(resource["id"]))
		return true
	return false


func _nearest_incomplete_structure(worker: Dictionary) -> Dictionary:
	var best_structure: Dictionary = {}
	var best_distance := INF
	var team := int(worker.get("team", TEAM_NEUTRAL))
	for raw_structure in entities.values():
		var structure := raw_structure as Dictionary
		if (
			not bool(structure.get("alive", false))
			or structure.get("category") != &"structure"
			or int(structure.get("team", TEAM_NEUTRAL)) != team
			or float(structure.get("complete", 1.0)) >= 1.0
		):
			continue
		var distance := _entity_distance(worker, structure)
		if distance < best_distance:
			best_distance = distance
			best_structure = structure
	return best_structure


func _nearest_resource(worker: Dictionary, resource_kind: StringName = &"") -> Dictionary:
	var best_resource: Dictionary = {}
	var best_distance := INF
	var team := int(worker.get("team", TEAM_NEUTRAL))
	for raw_resource in entities.values():
		var resource := raw_resource as Dictionary
		if not bool(resource.get("alive", false)) or resource.get("category") != &"resource":
			continue
		if not resource_kind.is_empty() and resource.get("resource_kind") != resource_kind:
			continue
		if team >= 0 and not is_entity_explored_by_team(team, resource):
			continue
		var distance := _entity_distance(worker, resource)
		if distance < best_distance:
			best_distance = distance
			best_resource = resource
	return best_resource


func _nearest_unexplored_resource(worker: Dictionary, resource_kind: StringName = &"") -> Dictionary:
	var best_resource: Dictionary = {}
	var best_distance := INF
	var team := int(worker.get("team", TEAM_NEUTRAL))
	for raw_resource in entities.values():
		var resource := raw_resource as Dictionary
		if not bool(resource.get("alive", false)) or resource.get("category") != &"resource":
			continue
		if not resource_kind.is_empty() and resource.get("resource_kind") != resource_kind:
			continue
		if team >= 0 and is_entity_explored_by_team(team, resource):
			continue
		var distance := _entity_distance(worker, resource)
		if distance < best_distance:
			best_distance = distance
			best_resource = resource
	return best_resource


func _reset_visibility() -> void:
	_visible_cells_by_team.clear()
	_explored_cells_by_team.clear()
	for _team in range(players.size()):
		_visible_cells_by_team.append({})
		_explored_cells_by_team.append({})


func _refresh_visibility() -> void:
	if _visible_cells_by_team.size() != players.size():
		_reset_visibility()
	var next_visible_by_team: Array[Dictionary] = []
	for _team in range(players.size()):
		next_visible_by_team.append({})
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		var team := int(entity_state.get("team", TEAM_NEUTRAL))
		if (
			not bool(entity_state.get("alive", false))
			or team < 0
			or team >= players.size()
			or entity_state.get("category") not in [&"unit", &"structure"]
		):
			continue
		var radius := _vision_radius(entity_state)
		var origin := Vector2i(_entity_center(entity_state).floor())
		var team_visibility := next_visible_by_team[team]
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var cell := Vector2i(x, y)
				if not MapCatalog.in_bounds(cell):
					continue
				var offset := cell - origin
				if offset.length_squared() <= radius * radius:
					team_visibility[cell] = true
		next_visible_by_team[team] = team_visibility
	for team in range(players.size()):
		var next_visible := next_visible_by_team[team]
		_visible_cells_by_team[team] = next_visible
		var explored: Dictionary = _explored_cells_by_team[team]
		for cell in next_visible:
			explored[cell] = true
		_explored_cells_by_team[team] = explored


func _vision_radius(entity_state: Dictionary) -> int:
	if entity_state.get("kind") == &"sentry_tower":
		var occupants := entity_state.get("garrisoned_unit_ids", []) as Array
		if not occupants.is_empty():
			var occupant := entity(int(occupants[0]))
			if not occupant.is_empty():
				return maxi(
					STRUCTURE_VISION_RADIUS,
					ceili(float(occupant.get("range", 0.0)) * GARRISON_RANGE_MULTIPLIER),
				)
	if entity_state.get("category") == &"structure":
		return STRUCTURE_VISION_RADIUS
	if entity_state.get("kind") == &"mystic":
		return MYSTIC_VISION_RADIUS
	return DEFAULT_VISION_RADIUS


func visible_cells_for_team(team: int) -> Dictionary:
	if team < 0 or team >= _visible_cells_by_team.size():
		return {}
	return _visible_cells_by_team[team].duplicate()


func explored_cells_for_team(team: int) -> Dictionary:
	if team < 0 or team >= _explored_cells_by_team.size():
		return {}
	return _explored_cells_by_team[team].duplicate()


func is_cell_visible_to_team(team: int, cell: Vector2i) -> bool:
	return (
		team >= 0
		and team < _visible_cells_by_team.size()
		and _visible_cells_by_team[team].has(cell)
	)


func is_cell_explored_by_team(team: int, cell: Vector2i) -> bool:
	return (
		team >= 0
		and team < _explored_cells_by_team.size()
		and _explored_cells_by_team[team].has(cell)
	)


func is_entity_visible_to_team(team: int, target: Dictionary) -> bool:
	if target.is_empty() or not bool(target.get("alive", false)):
		return false
	if int(target.get("team", TEAM_NEUTRAL)) == team:
		return true
	return is_cell_visible_to_team(team, Vector2i(_entity_center(target).floor()))


func is_entity_explored_by_team(team: int, target: Dictionary) -> bool:
	if target.is_empty() or not bool(target.get("alive", false)):
		return false
	if int(target.get("team", TEAM_NEUTRAL)) == team:
		return true
	return is_cell_explored_by_team(team, Vector2i(_entity_center(target).floor()))


func _formation_cells(center: Vector2i, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if count <= 0:
		return result
	var used: Dictionary = {}
	var maximum_radius := maxi(MapCatalog.SIZE.x, MapCatalog.SIZE.y)
	for radius in range(maximum_radius + 1):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(abs(x), abs(y)) != radius:
					continue
				var candidate := center + Vector2i(x, y)
				if (
					not MapCatalog.in_bounds(candidate)
					or _astar.is_point_solid(candidate)
					or used.has(candidate)
				):
					continue
				result.append(candidate)
				used[candidate] = true
				if result.size() >= count:
					return result
	return result


func _resolve_unit_separation(tick_delta: float = TICK_SECONDS) -> void:
	var unit_ids: Array[int] = []
	for raw_id in entities.keys():
		var entity_state := entity(int(raw_id))
		if (
			bool(entity_state.get("alive", false))
			and entity_state.get("category") in [&"unit", &"wildlife"]
			and int(entity_state.get("garrisoned_in", -1)) < 0
		):
			unit_ids.append(int(raw_id))
	unit_ids.sort()
	var step_delta := tick_delta / float(UNIT_SEPARATION_ITERATIONS)
	for _iteration in range(UNIT_SEPARATION_ITERATIONS):
		var displacements: Dictionary = {}
		for unit_id in unit_ids:
			displacements[unit_id] = Vector2.ZERO
		for first_index in range(unit_ids.size()):
			var first_id := unit_ids[first_index]
			var first := entity(first_id)
			for second_index in range(first_index + 1, unit_ids.size()):
				var second_id := unit_ids[second_index]
				var second := entity(second_id)
				if _moving_friendly_units_can_overlap(first, second) or not _units_should_separate(first, second):
					continue
				var delta := (second["position"] as Vector2) - (first["position"] as Vector2)
				var distance := delta.length()
				if distance >= UNIT_SEPARATION_DISTANCE:
					continue
				var direction: Vector2
				if distance <= 0.0001:
					var angle_degrees := float(posmod(first_id * 97 + second_id * 53, 360))
					direction = Vector2.RIGHT.rotated(deg_to_rad(angle_degrees))
				else:
					direction = delta / distance
				var correction := direction * (UNIT_SEPARATION_DISTANCE - distance) * 0.5
				displacements[first_id] = displacements[first_id] as Vector2 - correction
				displacements[second_id] = displacements[second_id] as Vector2 + correction
		for unit_id in unit_ids:
			var unit := entity(unit_id)
			var displacement := displacements[unit_id] as Vector2
			var velocity := unit.get("separation_velocity", Vector2.ZERO) as Vector2
			if _has_active_path(unit) and displacement.is_zero_approx():
				unit["separation_velocity"] = Vector2.ZERO
				continue
			var profile := _separation_profile(unit)
			velocity += displacement * profile.x * step_delta
			velocity *= exp(-profile.y * step_delta)
			if velocity.length() > profile.z:
				velocity = velocity.normalized() * profile.z
			if displacement.is_zero_approx() and velocity.length() <= UNIT_SEPARATION_STOP_SPEED:
				unit["separation_velocity"] = Vector2.ZERO
				continue
			var proposed := (unit["position"] as Vector2) + velocity * step_delta
			if _is_walkable_unit_position(proposed):
				unit["position"] = proposed
				unit["cell"] = Vector2i(proposed.round())
				unit["separation_velocity"] = velocity
			else:
				unit["separation_velocity"] = Vector2.ZERO


func _separation_profile(entity_state: Dictionary) -> Vector3:
	if entity_state.get("kind") == &"worker":
		return Vector3(
			WORKER_SEPARATION_STIFFNESS,
			WORKER_SEPARATION_DAMPING,
			WORKER_SEPARATION_MAX_SPEED,
		)
	if entity_state.get("category") == &"unit":
		return Vector3(
			COMBAT_SEPARATION_STIFFNESS,
			COMBAT_SEPARATION_DAMPING,
			COMBAT_SEPARATION_MAX_SPEED,
		)
	return Vector3(
		UNIT_SEPARATION_STIFFNESS,
		UNIT_SEPARATION_DAMPING,
		UNIT_SEPARATION_MAX_SPEED,
	)


func _moving_friendly_units_can_overlap(first: Dictionary, second: Dictionary) -> bool:
	var first_team := int(first.get("team", TEAM_NEUTRAL))
	return (
		first_team >= 0
		and first_team == int(second.get("team", TEAM_NEUTRAL))
		and (_has_active_path(first) or _has_active_path(second))
	)


func _has_active_path(entity_state: Dictionary) -> bool:
	var path := entity_state.get("path", []) as Array
	return not path.is_empty() and int(entity_state.get("path_index", 0)) < path.size()


func _units_should_separate(first: Dictionary, second: Dictionary) -> bool:
	return not (
		first.get("category") == &"unit" and _is_harmless_wildlife(second)
		or second.get("category") == &"unit" and _is_harmless_wildlife(first)
	)


func _is_harmless_wildlife(entity_state: Dictionary) -> bool:
	return (
		entity_state.get("category") == &"wildlife"
		and not bool(entity_state.get("retaliates", false))
	)


func _is_walkable_unit_position(position: Vector2) -> bool:
	if (
		position.x < 0.0
		or position.y < 0.0
		or position.x > float(MapCatalog.SIZE.x - 1)
		or position.y > float(MapCatalog.SIZE.y - 1)
	):
		return false
	var cell := Vector2i(position.round())
	return MapCatalog.in_bounds(cell) and not _astar.is_point_solid(cell)


func _cell_occupied_by_static_entity(
	cell: Vector2i,
	placing_team: int = TEAM_NEUTRAL,
	placing_kind: StringName = &"",
	placing_orientation: StringName = &"y",
) -> bool:
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)):
			continue
		if entity_state.get("category") not in [&"structure", &"resource", &"objective"]:
			continue
		for occupied in MapCatalog.footprint_cells(
			entity_state["cell"] as Vector2i,
			entity_state.get("footprint", Vector2i.ONE) as Vector2i,
		):
			if occupied == cell:
				if (
					_wall_can_overlap_gate_corner(
						placing_team,
						placing_kind,
						entity_state,
						cell,
					)
					or _wall_can_overlap_perpendicular_wall(
						placing_team,
						placing_kind,
						placing_orientation,
						entity_state,
						cell,
					)
				):
					break
				return true
	return false


func _wall_can_overlap_gate_corner(
	placing_team: int,
	placing_kind: StringName,
	occupant: Dictionary,
	cell: Vector2i,
) -> bool:
	if (
		placing_kind != &"wall"
		or occupant.get("kind") != &"gate"
		or int(occupant.get("team", TEAM_NEUTRAL)) != placing_team
	):
		return false
	var origin := occupant.get("cell", Vector2i(-1, -1)) as Vector2i
	var footprint := occupant.get("footprint", Vector2i.ONE) as Vector2i
	var offset := cell - origin
	return (
		offset.x in [0, footprint.x - 1]
		and offset.y in [0, footprint.y - 1]
	)


func _wall_can_overlap_perpendicular_wall(
	placing_team: int,
	placing_kind: StringName,
	placing_orientation: StringName,
	occupant: Dictionary,
	cell: Vector2i,
) -> bool:
	if (
		placing_kind != &"wall"
		or occupant.get("kind") != &"wall"
		or int(occupant.get("team", TEAM_NEUTRAL)) != placing_team
		or occupant.get("cell", Vector2i(-1, -1)) != cell
	):
		return false
	var normalized_orientation: StringName = &"x" if placing_orientation == &"x" else &"y"
	return occupant.get("orientation", &"y") != normalized_orientation


func _cell_occupied_by_live_unit(cell: Vector2i) -> bool:
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			not bool(entity_state.get("alive", false))
			or entity_state.get("category") not in [&"unit", &"wildlife"]
			or int(entity_state.get("garrisoned_in", -1)) >= 0
		):
			continue
		if Vector2i((entity_state["position"] as Vector2).round()) == cell:
			return true
	return false


func _can_afford(team: int, stats: Dictionary) -> bool:
	return (
		int(players[team]["jade"]) >= int(stats.get("jade_cost", 0))
		and int(players[team]["lumber"]) >= int(stats.get("lumber_cost", 0))
		and int(players[team]["essence"]) >= int(stats.get("essence_cost", 0))
		and int(players[team]["food"]) >= int(stats.get("food_cost", 0))
	)


func _pay(team: int, stats: Dictionary) -> void:
	players[team]["jade"] = int(players[team]["jade"]) - int(stats.get("jade_cost", 0))
	players[team]["lumber"] = int(players[team]["lumber"]) - int(stats.get("lumber_cost", 0))
	players[team]["essence"] = int(players[team]["essence"]) - int(stats.get("essence_cost", 0))
	players[team]["food"] = int(players[team]["food"]) - int(stats.get("food_cost", 0))


func _has_population_room(team: int, amount: int) -> bool:
	return int(players[team]["population"]) + amount <= int(players[team]["population_cap"])


func _is_commandable_unit(entity_state: Dictionary) -> bool:
	var team := int(entity_state.get("team", TEAM_NEUTRAL))
	return (
		not entity_state.is_empty()
		and bool(entity_state.get("alive", false))
		and entity_state.get("category") == &"unit"
		and int(entity_state.get("garrisoned_in", -1)) < 0
		and team >= 0
		and _is_valid_team(team)
		and not bool(players[team].get("eliminated", false))
	)


func _is_valid_team(team: int) -> bool:
	return team >= 0 and team < players.size()


func _can_issue_command(team: int) -> bool:
	return (
		outcome.is_empty()
		and _is_valid_team(team)
		and not bool(players[team].get("eliminated", false))
	)


func _is_military_unit(entity_state: Dictionary) -> bool:
	return entity_state.get("category") == &"unit" and entity_state.get("kind") in [&"hunter", &"vanguard", &"mystic", &"jadeclaw", &"shenlong"]


func _is_neutral_guardian(entity_state: Dictionary) -> bool:
	return (
		int(entity_state.get("team", TEAM_NEUTRAL)) == TEAM_NEUTRAL
		and (
			entity_state.get("kind") == &"jadeclaw" and int(entity_state.get("home_cave_id", -1)) >= 0
			or entity_state.get("kind") == &"shenlong" and bool(entity_state.get("is_shenlong_guardian", false))
		)
	)


func _is_shenlong_guardian(entity_state: Dictionary) -> bool:
	return (
		int(entity_state.get("team", TEAM_NEUTRAL)) == TEAM_NEUTRAL
		and entity_state.get("kind") == &"shenlong"
		and bool(entity_state.get("is_shenlong_guardian", false))
	)


func _ai_shenlong_lock_active(team: int) -> bool:
	return (
		_is_valid_team(team)
		and bool(players[team].get("is_ai", false))
		and elapsed_time < AI_SHENLONG_UNLOCK_TIME_SECONDS
	)


func _entity_center(entity_state: Dictionary) -> Vector2:
	var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
	return entity_state["position"] as Vector2 + (Vector2(footprint) - Vector2.ONE) * 0.5


func _entity_distance(first: Dictionary, second: Dictionary) -> float:
	return _entity_center(first).distance_to(_entity_center(second))


func _entity_footprint_distance(first: Dictionary, second: Dictionary) -> float:
	var first_min := first["position"] as Vector2
	var first_footprint := first.get("footprint", Vector2i.ONE) as Vector2i
	var first_max := first_min + Vector2(first_footprint) - Vector2.ONE
	var second_min := second["position"] as Vector2
	var second_footprint := second.get("footprint", Vector2i.ONE) as Vector2i
	var second_max := second_min + Vector2(second_footprint) - Vector2.ONE
	var gap_x := maxf(maxf(first_min.x - second_max.x, second_min.x - first_max.x), 0.0)
	var gap_y := maxf(maxf(first_min.y - second_max.y, second_min.y - first_max.y), 0.0)
	return Vector2(gap_x, gap_y).length()


func _combat_distance(first: Dictionary, second: Dictionary) -> float:
	var second_footprint := second.get("footprint", Vector2i.ONE) as Vector2i
	var footprint_reach := float(maxi(second_footprint.x, second_footprint.y) - 1) * 0.9
	return maxf(0.0, _entity_distance(first, second) - footprint_reach)


func _stronghold_for_team(team: int) -> Dictionary:
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			bool(entity_state.get("alive", false))
			and int(entity_state.get("team", TEAM_NEUTRAL)) == team
			and entity_state.get("kind") == &"stronghold"
		):
			return entity_state
	return {}


func are_hostile(first: Dictionary, second: Dictionary) -> bool:
	if first.is_empty() or second.is_empty():
		return false
	if not bool(first.get("alive", false)) or not bool(second.get("alive", false)):
		return false
	if int(second.get("garrisoned_in", -1)) >= 0:
		return false
	if second.get("category") == &"resource" or second.get("kind") == &"yaoguai_den":
		return false
	if second.get("category") == &"wildlife":
		return (
			int(first.get("team", TEAM_NEUTRAL)) >= 0
			and first.get("kind") == &"hunter"
			and FactionCatalog.can_hunt(first.get("faction", &"neutral") as StringName)
		)
	if first.get("category") == &"wildlife":
		return (
			bool(first.get("retaliates", false))
			and int(first.get("target_id", -1)) == int(second.get("id", -2))
		)
	var first_team := int(first.get("team", TEAM_NEUTRAL))
	var second_team := int(second.get("team", TEAM_NEUTRAL))
	if first_team == second_team:
		return false
	if _is_shenlong_guardian(second) and _ai_shenlong_lock_active(first_team):
		return false
	if (
		first_team >= 0 and _is_valid_team(first_team) and bool(players[first_team].get("eliminated", false))
		or second_team >= 0 and _is_valid_team(second_team) and bool(players[second_team].get("eliminated", false))
	):
		return false
	if first_team == TEAM_NEUTRAL:
		return _is_neutral_guardian(first) and second_team >= 0
	if second_team == TEAM_NEUTRAL:
		return _is_neutral_guardian(second)
	return true


func _has_line_of_sight(
	first: Dictionary,
	second: Dictionary,
	additional_ignored_ids: Array = [],
) -> bool:
	var start := Vector2i(_entity_center(first).round())
	var finish := Vector2i(_entity_center(second).round())
	var ignored_ids := {int(first.get("id", -1)): true, int(second.get("id", -1)): true}
	for raw_id in additional_ignored_ids:
		ignored_ids[int(raw_id)] = true
	var difference := finish - start
	var steps := maxi(absi(difference.x), absi(difference.y))
	if steps <= 1:
		return true
	for step in range(1, steps):
		var ratio := float(step) / float(steps)
		var cell := Vector2i(Vector2(start).lerp(Vector2(finish), ratio).round())
		if _cell_blocks_line_of_sight(cell, ignored_ids):
			return false
	return true


func _cell_blocks_line_of_sight(cell: Vector2i, ignored_ids: Dictionary) -> bool:
	if not MapCatalog.in_bounds(cell):
		return true
	if not _line_of_sight_blockers.has(cell):
		return false
	var blocker_id := int(_line_of_sight_blockers[cell])
	return blocker_id < 0 or not ignored_ids.has(blocker_id)


func _nearest_enemy(source: Dictionary, maximum_distance: float, require_line_of_sight: bool = false) -> int:
	var best_id := -1
	var best_distance := maximum_distance
	var source_team := int(source.get("team", TEAM_NEUTRAL))
	for raw_target in entities.values():
		var target := raw_target as Dictionary
		if not are_hostile(source, target):
			continue
		if source_team >= 0 and not is_entity_visible_to_team(source_team, target):
			continue
		var distance := _entity_distance(source, target)
		if distance < best_distance and (not require_line_of_sight or _has_line_of_sight(source, target)):
			best_distance = distance
			best_id = int(target["id"])
	return best_id


func _nearest_hunter_automatic_target(
	hunter: Dictionary,
	maximum_distance: float,
	require_line_of_sight: bool = false,
) -> int:
	var best_id := -1
	var best_distance := maximum_distance
	var hunter_team := int(hunter.get("team", TEAM_NEUTRAL))
	var pasture := _preferred_hunter_pasture(hunter)
	var pasture_id := int(pasture.get("id", -1))
	for raw_target in entities.values():
		var target := raw_target as Dictionary
		if target.get("category") != &"wildlife" or not are_hostile(hunter, target):
			continue
		if pasture_id >= 0 and int(target.get("herd_id", -1)) != pasture_id:
			continue
		if hunter_team >= 0 and not is_entity_visible_to_team(hunter_team, target):
			continue
		var distance := _entity_distance(hunter, target)
		if distance < best_distance and (not require_line_of_sight or _has_line_of_sight(hunter, target)):
			best_distance = distance
			best_id = int(target["id"])
	return best_id


func _nearest_enemy_hunter(
	hunter: Dictionary,
	maximum_distance: float,
	require_line_of_sight: bool = false,
) -> int:
	var best_id := -1
	var best_distance := maximum_distance
	var hunter_team := int(hunter.get("team", TEAM_NEUTRAL))
	for raw_target in entities.values():
		var target := raw_target as Dictionary
		if (
			target.get("category") != &"unit"
			or target.get("kind") != &"hunter"
			or not are_hostile(hunter, target)
		):
			continue
		if hunter_team >= 0 and not is_entity_visible_to_team(hunter_team, target):
			continue
		var distance := _entity_distance(hunter, target)
		if distance < best_distance and (not require_line_of_sight or _has_line_of_sight(hunter, target)):
			best_distance = distance
			best_id = int(target["id"])
	return best_id


func _nearest_hunter_combat_threat(
	hunter: Dictionary,
	maximum_distance: float,
	require_line_of_sight: bool = false,
) -> int:
	var best_id := -1
	var best_distance := maximum_distance
	var hunter_team := int(hunter.get("team", TEAM_NEUTRAL))
	for raw_target in entities.values():
		var target := raw_target as Dictionary
		if target.get("category") != &"unit" or not are_hostile(hunter, target):
			continue
		if hunter_team >= 0 and not is_entity_visible_to_team(hunter_team, target):
			continue
		var distance := _entity_distance(hunter, target)
		if distance < best_distance and (not require_line_of_sight or _has_line_of_sight(hunter, target)):
			best_distance = distance
			best_id = int(target["id"])
	return best_id


func _team_units_of_kind(team: int, kind: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			bool(entity_state.get("alive", false))
			and int(entity_state.get("team", TEAM_NEUTRAL)) == team
			and entity_state.get("kind") == kind
		):
			result.append(entity_state)
	return result


func _team_structures_of_kind(team: int, kind: StringName) -> Array[Dictionary]:
	return _team_units_of_kind(team, kind)


func _team_military(team: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			bool(entity_state.get("alive", false))
			and int(entity_state.get("team", TEAM_NEUTRAL)) == team
			and _is_military_unit(entity_state)
			and int(entity_state.get("garrisoned_in", -1)) < 0
		):
			result.append(entity_state)
	return result


func entity(id: int) -> Dictionary:
	return entities.get(id, {}) as Dictionary


func entity_center(id: int) -> Vector2:
	var value := entity(id)
	return Vector2.ZERO if value.is_empty() else _entity_center(value)


func team_entity_ids(team: int, kinds: Array[StringName] = []) -> Array[int]:
	var result: Array[int] = []
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)) or int(entity_state.get("team", TEAM_NEUTRAL)) != team:
			continue
		if not kinds.is_empty() and entity_state.get("kind") not in kinds:
			continue
		result.append(int(entity_state["id"]))
	return result


func primary_structure_id(team: int, kind: StringName) -> int:
	var structures := _team_structures_of_kind(team, kind)
	return -1 if structures.is_empty() else int(structures[0]["id"])


func shenlong_egg() -> Dictionary:
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if entity_state.get("kind") == &"shenlong_egg":
			return entity_state
	return {}


func shenlong_guardian() -> Dictionary:
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if bool(entity_state.get("alive", false)) and bool(entity_state.get("is_shenlong_guardian", false)):
			return entity_state
	return {}


func cave_ids() -> Array[int]:
	var result: Array[int] = []
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if bool(entity_state.get("alive", false)) and entity_state.get("kind") == &"yaoguai_den":
			result.append(int(entity_state["id"]))
	return result


func wildlife_ids(kind: StringName = &"") -> Array[int]:
	var result: Array[int] = []
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)) or entity_state.get("category") != &"wildlife":
			continue
		if not kind.is_empty() and entity_state.get("kind") != kind:
			continue
		result.append(int(entity_state["id"]))
	return result


func cave_guardian_count(cave_id: int) -> int:
	var cave := entity(cave_id)
	if cave.is_empty() or cave.get("kind") != &"yaoguai_den":
		return 0
	var result := 0
	for raw_guardian_id in cave.get("guardian_ids", []) as Array:
		var guardian := entity(int(raw_guardian_id))
		if bool(guardian.get("alive", false)):
			result += 1
	return result


func captured_cave_count(team: int) -> int:
	return _team_structures_of_kind(team, &"yaoguai_den").size()


func can_afford_kind(team: int, kind: StringName) -> bool:
	if not is_kind_available(team, kind):
		return false
	if kind == &"worker" and can_train_free_worker(team):
		return true
	var faction := players[team]["faction"] as StringName
	return _can_afford(team, FactionCatalog.stats(kind, faction))


func can_train_free_worker(team: int) -> bool:
	if team < 0 or team >= players.size():
		return false
	if not team_entity_ids(team, [&"worker"]).is_empty():
		return false
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			not bool(entity_state.get("alive", false))
			or int(entity_state.get("team", TEAM_NEUTRAL)) != team
			or entity_state.get("category") != &"structure"
		):
			continue
		for raw_item in entity_state.get("queue", []) as Array:
			if (raw_item as Dictionary).get("kind") == &"worker":
				return false
	return true


func is_kind_available(team: int, kind: StringName) -> bool:
	if team < 0 or team >= players.size():
		return false
	var faction := players[team]["faction"] as StringName
	if kind in BUILDABLE_STRUCTURE_KINDS:
		return FactionCatalog.can_build_structure(faction, kind)
	return FactionCatalog.can_train_unit(faction, kind)


func has_population_for(team: int, kind: StringName) -> bool:
	var faction := players[team]["faction"] as StringName
	var stats := FactionCatalog.stats(kind, faction)
	return _has_population_room(team, int(stats.get("population", 0)))


func food_income_per_second(team: int) -> float:
	var result := 0.0
	for structure_kind in FOOD_PRODUCER_KINDS:
		for structure in _team_structures_of_kind(team, structure_kind):
			if float(structure.get("complete", 0.0)) < 1.0:
				continue
			var stats := FactionCatalog.stats(structure_kind, structure["faction"] as StringName)
			var interval := float(stats.get("food_interval", 0.0))
			if interval > 0.0:
				result += float(structure_food_yield(int(structure["id"]))) / interval
	return result


func farm_worker_id(farm_id: int) -> int:
	var farm := entity(farm_id)
	if farm.is_empty() or farm.get("kind") != &"rice_farm":
		return -1
	var worker_id := int(farm.get("farm_worker_id", -1))
	var worker := entity(worker_id)
	if (
		worker.is_empty()
		or not bool(worker.get("alive", false))
		or worker.get("kind") != &"worker"
		or worker.get("order", &"idle") != &"farm"
		or int(worker.get("target_id", -1)) != farm_id
		or int(worker.get("team", TEAM_NEUTRAL)) != int(farm.get("team", TEAM_NEUTRAL))
	):
		farm["farm_worker_id"] = -1
		return -1
	return worker_id


func is_farm_staffed(farm_id: int) -> bool:
	var farm := entity(farm_id)
	var worker := entity(farm_worker_id(farm_id))
	return (
		not farm.is_empty()
		and not worker.is_empty()
		and _entity_footprint_distance(worker, farm) <= WORKER_INTERACTION_RANGE
	)


func structure_food_yield(structure_id: int) -> int:
	var structure := entity(structure_id)
	if (
		structure.is_empty()
		or structure.get("kind") not in FOOD_PRODUCER_KINDS
		or not bool(structure.get("alive", false))
		or float(structure.get("complete", 0.0)) < 1.0
	):
		return 0
	var stats := FactionCatalog.stats(
		structure["kind"] as StringName,
		structure["faction"] as StringName,
	)
	var food_yield := int(stats.get("food_yield", 0))
	if structure.get("kind") == &"rice_farm" and is_farm_staffed(structure_id):
		food_yield *= FARM_WORKER_FOOD_MULTIPLIER
	return food_yield


func drain_events() -> Array[Dictionary]:
	var result := _events.duplicate(true)
	_events.clear()
	return result


func _add_event(
	event_type: StringName,
	position: Vector2,
	color: Color,
	metadata: Dictionary = {},
) -> void:
	var event := {"type": event_type, "position": position, "color": color}
	event.merge(metadata, true)
	_events.append(event)


func _team_color(team: int) -> Color:
	if team == TEAM_NEUTRAL:
		return Color("d5b963")
	return FactionCatalog.definition(players[team]["faction"] as StringName)["accent"] as Color
