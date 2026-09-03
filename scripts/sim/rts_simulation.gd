class_name RtsSimulation
extends RefCounted

signal match_ended(result: StringName)
signal state_changed
signal battle_notice(message: String, team: int)

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const TEAM_NEUTRAL := -1
const POPULATION_CAP := 24
const TICK_SECONDS := 1.0 / 30.0
const GATHER_CYCLE := 0.8
const CARGO_CAPACITY := 50.0
const GATHER_AMOUNT := 10.0
const WORKER_INTERACTION_RANGE := 1.25
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
const WILDLIFE_FLEE_DISTANCE := 4.5
const WILDLIFE_RETALIATION_LEASH_BONUS := 3.0
const HUNTER_WILDLIFE_DAMAGE_MULTIPLIER := 3.0
const HERD_SPAWN_OFFSETS: Array[Vector2i] = [
	Vector2i.ZERO,
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]
const BUILDABLE_STRUCTURE_KINDS: Array[StringName] = [&"war_camp", &"rice_farm", &"hunters_lodge"]
const FOOD_PRODUCER_KINDS: Array[StringName] = [&"rice_farm", &"hunters_lodge"]
const MONSTER_BOUNTY := {
	"jade": 45,
	"lumber": 30,
	"essence": 25,
}

var players: Array[Dictionary] = []
var entities: Dictionary = {}
var elapsed_time := 0.0
var outcome: StringName = &""

var _next_entity_id := 1
var _accumulator := 0.0
var _astar := AStarGrid2D.new()
var _wander_rng := RandomNumberGenerator.new()
var _wildlife_rng := RandomNumberGenerator.new()
var _events: Array[Dictionary] = []
var _ai_strategy_timer := 0.5
var _ai_attack_timer := 14.0
var _ai_cave_timer := 3.0
var _ai_hunt_timer := 4.0
var _ai_training_flip := false
var _ai_enabled := true
var _line_of_sight_blockers: Dictionary = {}
var _visible_cells_by_team: Array[Dictionary] = []
var _explored_cells_by_team: Array[Dictionary] = []


func setup(player_faction: StringName, enable_ai: bool = true) -> void:
	var map_errors := MapCatalog.validation_errors()
	assert(map_errors.is_empty(), "Invalid authored map: %s" % "; ".join(map_errors))
	entities.clear()
	_events.clear()
	_next_entity_id = 1
	elapsed_time = 0.0
	outcome = &""
	_accumulator = 0.0
	_ai_enabled = enable_ai
	_ai_strategy_timer = 0.5
	_ai_attack_timer = 14.0
	_ai_cave_timer = 3.0
	_ai_hunt_timer = 4.0
	_ai_training_flip = false
	_wander_rng.seed = GUARDIAN_WANDER_SEED
	_wildlife_rng.seed = WILDLIFE_WANDER_SEED
	players = [
		_player_state(player_faction, false),
		_player_state(FactionCatalog.opposing_faction(player_faction), true),
	]
	_rebuild_pathfinding()
	_spawn_structure(TEAM_PLAYER, &"stronghold", MapCatalog.PLAYER_STRONGHOLD, true)
	_spawn_structure(TEAM_ENEMY, &"stronghold", MapCatalog.ENEMY_STRONGHOLD, true)
	for cell in MapCatalog.PLAYER_WORKERS:
		_spawn_unit(TEAM_PLAYER, &"worker", cell)
	for cell in MapCatalog.ENEMY_WORKERS:
		_spawn_unit(TEAM_ENEMY, &"worker", cell)
	for resource in MapCatalog.RESOURCES:
		_spawn_resource(resource)
	for tree in MapCatalog.tree_definitions():
		_spawn_resource(tree)
	for cave in MapCatalog.CAVES:
		_spawn_cave(cave)
	_rebuild_pathfinding()
	for herd_index in range(MapCatalog.WILDLIFE_HERDS.size()):
		_spawn_wildlife_herd(herd_index, MapCatalog.WILDLIFE_HERDS[herd_index])
	_reset_visibility()
	_refresh_visibility()
	_auto_assign_workers(TEAM_ENEMY)
	state_changed.emit()


func advance(delta: float) -> void:
	if not outcome.is_empty():
		return
	_accumulator += minf(delta, 0.25)
	while _accumulator >= TICK_SECONDS:
		_tick(TICK_SECONDS)
		_accumulator -= TICK_SECONDS


func _tick(delta: float) -> void:
	elapsed_time += delta
	_advance_construction(delta)
	_advance_food_production(delta)
	_advance_production(delta)
	_advance_worker_orders(delta)
	_advance_combat_and_movement(delta)
	_resolve_unit_separation(delta)
	_refresh_visibility()
	_advance_cave_capture(delta)
	if _ai_enabled:
		_advance_ai(delta)
	state_changed.emit()


func _player_state(faction: StringName, is_ai: bool) -> Dictionary:
	return {
		"faction": faction,
		"jade": 320,
		"lumber": 30,
		"essence": 160,
		"food": 160,
		"population": 0,
		"population_cap": POPULATION_CAP,
		"is_ai": is_ai,
	}


func _spawn_unit(team: int, kind: StringName, cell: Vector2i, home_cave_id: int = -1) -> int:
	var faction := &"neutral" if team == TEAM_NEUTRAL else players[team]["faction"] as StringName
	var stats := FactionCatalog.stats(kind, faction)
	var entity_state := {
		"id": _next_entity_id,
		"team": team,
		"faction": faction,
		"kind": kind,
		"category": &"unit",
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
		"acquire_range": float(stats["acquire_range"]),
		"order": &"idle",
		"target_id": -1,
		"path": [],
		"path_index": 0,
		"separation_velocity": Vector2.ZERO,
		"command_queue": [],
		"attack_move": false,
		"attack_move_destination": Vector2i(-1, -1),
		"patrol_origin": Vector2i(-1, -1),
		"patrol_destination": Vector2i(-1, -1),
		"patrol_target": Vector2i(-1, -1),
		"repath_timer": 0.0,
		"cargo_kind": &"",
		"cargo_amount": 0.0,
		"gather_source_id": -1,
		"gather_timer": 0.0,
		"repair_timer": 0.0,
		"repair_notice_cooldown": 0.0,
		"return_resume_gather": true,
		"population": int(stats["population"]),
		"flash_timer": 0.0,
		"home_cave_id": home_cave_id,
		"leash_origin": Vector2(cell),
		"leash_radius": GUARDIAN_LEASH_RADIUS,
		"wander_timer": 0.0,
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


func _spawn_structure(team: int, kind: StringName, cell: Vector2i, completed: bool) -> int:
	var faction := players[team]["faction"] as StringName
	var stats := FactionCatalog.stats(kind, faction)
	var completion := 1.0 if completed else 0.06
	var entity_state := {
		"id": _next_entity_id,
		"team": team,
		"faction": faction,
		"kind": kind,
		"category": &"structure",
		"position": Vector2(cell),
		"cell": cell,
		"footprint": stats.get("footprint", Vector2i.ONE),
		"hp": float(stats["max_hp"]) * completion,
		"max_hp": float(stats["max_hp"]),
		"alive": true,
		"complete": completion,
		"order": &"idle" if completed else &"constructing",
		"queue": [],
		"rally_cell": cell + Vector2i(2, 1),
		"food_timer": 0.0,
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


func _spawn_wildlife(
	kind: StringName,
	cell: Vector2i,
	herd_id: int,
	herd_origin: Vector2i,
	herd_radius: float,
) -> int:
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
	_next_entity_id += 1
	return int(entity_state["id"])


func command_move(
	issuer_team: int,
	ids: Array[int],
	destination: Vector2i,
	attack_move: bool = false,
	append: bool = false,
) -> bool:
	if not _is_valid_team(issuer_team) or not MapCatalog.in_bounds(destination):
		return false
	var units: Array[Dictionary] = []
	for id in ids:
		var unit := entity(id)
		if _is_commandable_unit(unit) and int(unit["team"]) == issuer_team:
			units.append(unit)
	var formation := _formation_cells(destination, units.size())
	var issued := false
	for index in range(mini(units.size(), formation.size())):
		issued = _issue_unit_order(
			units[index],
			{
				"type": &"attack_move" if attack_move else &"move",
				"destination": formation[index],
			},
			append,
		) or issued
	if issued:
		_add_event(&"command", Vector2(destination), Color("8de8c0"))
	return issued


func command_attack(issuer_team: int, ids: Array[int], target_id: int, append: bool = false) -> bool:
	if not _is_valid_team(issuer_team):
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
	if not _is_valid_team(issuer_team):
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
			or not is_entity_explored_by_team(int(worker["team"]), resource)
		):
			continue
		issued = _issue_unit_order(worker, {"type": &"gather", "target_id": resource_id}, append) or issued
	if issued:
		_add_event(&"command", _entity_center(resource), Color("73e6bc"))
	return issued


func command_deposit(issuer_team: int, ids: Array[int], stronghold_id: int, append: bool = false) -> int:
	if not _is_valid_team(issuer_team):
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
	if not _is_valid_team(issuer_team):
		return false
	var issued := false
	for id in ids:
		var unit := entity(id)
		if not _is_commandable_unit(unit) or int(unit["team"]) != issuer_team:
			continue
		_cancel_all_unit_orders(unit)
		issued = true
	return issued


func command_repair(issuer_team: int, ids: Array[int], target_id: int, append: bool = false) -> bool:
	if not _is_valid_team(issuer_team):
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


func command_patrol(issuer_team: int, ids: Array[int], destination: Vector2i, append: bool = false) -> bool:
	if not _is_valid_team(issuer_team) or not MapCatalog.in_bounds(destination):
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
	unit["order"] = &"idle"
	unit["target_id"] = -1
	unit["path"] = []
	unit["path_index"] = 0
	unit["repair_timer"] = 0.0
	unit["return_resume_gather"] = true
	_clear_attack_move(unit)
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


func command_build(issuer_team: int, worker_id: int, structure_kind: StringName, cell: Vector2i) -> bool:
	if not _is_valid_team(issuer_team) or structure_kind not in BUILDABLE_STRUCTURE_KINDS:
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
	if not can_place_structure(team, structure_kind, cell) or not _can_afford(team, stats):
		return false
	_pay(team, stats)
	var structure_id := _spawn_structure(team, structure_kind, cell, false)
	_cancel_all_unit_orders(worker)
	worker["order"] = &"build"
	worker["target_id"] = structure_id
	worker["path"] = []
	_clear_attack_move(worker)
	_rebuild_pathfinding()
	_add_event(
		&"build",
		Vector2(cell),
		FactionCatalog.definition(faction)["accent"] as Color,
		{"team": team, "category": &"structure", "kind": structure_kind},
	)
	return true


func command_build_war_camp(issuer_team: int, worker_id: int, cell: Vector2i) -> bool:
	return command_build(issuer_team, worker_id, &"war_camp", cell)


func can_place_structure(team: int, structure_kind: StringName, cell: Vector2i) -> bool:
	if team < 0 or team >= players.size() or structure_kind not in BUILDABLE_STRUCTURE_KINDS:
		return false
	var faction := players[team]["faction"] as StringName
	if not FactionCatalog.can_build_structure(faction, structure_kind):
		return false
	var stats := FactionCatalog.stats(structure_kind, faction)
	var footprint := stats.get("footprint", Vector2i.ONE) as Vector2i
	for footprint_cell in MapCatalog.footprint_cells(cell, footprint):
		if not MapCatalog.is_buildable(footprint_cell):
			return false
		if _cell_occupied_by_static_entity(footprint_cell):
			return false
		if _cell_occupied_by_live_unit(footprint_cell):
			return false
	return true


func can_place_war_camp(team: int, cell: Vector2i) -> bool:
	return can_place_structure(team, &"war_camp", cell)


func command_train(issuer_team: int, structure_id: int, unit_kind: StringName) -> bool:
	if not _is_valid_team(issuer_team):
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
	if not _can_afford(team, stats) or not _has_population_room(team, int(stats["population"])):
		return false
	_pay(team, stats)
	players[team]["population"] = int(players[team]["population"]) + int(stats["population"])
	var queue := structure["queue"] as Array
	queue.append({
		"kind": unit_kind,
		"remaining": float(stats["train_time"]),
		"total": float(stats["train_time"]),
		"reserved_population": int(stats["population"]),
		"costs": {
			"jade": int(stats.get("jade_cost", 0)),
			"lumber": int(stats.get("lumber_cost", 0)),
			"essence": int(stats.get("essence_cost", 0)),
			"food": int(stats.get("food_cost", 0)),
		},
	})
	structure["queue"] = queue
	return true


func command_cancel_training(requesting_team: int, structure_id: int) -> Dictionary:
	if not _is_valid_team(requesting_team):
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
	var cancelled := queue.pop_back() as Dictionary
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
	if not _is_valid_team(issuer_team) or not MapCatalog.in_bounds(cell):
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
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
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


func _set_path(entity_state: Dictionary, destination: Vector2i) -> void:
	var start := Vector2i((entity_state["position"] as Vector2).round())
	if not MapCatalog.in_bounds(start):
		return
	var team := int(entity_state.get("team", TEAM_NEUTRAL))
	_set_friendly_structures_solid(team, false)
	var start_was_solid := _astar.is_point_solid(start)
	if start_was_solid:
		_astar.set_point_solid(start, false)
	var target := _nearest_walkable(destination)
	var cell_path := _astar.get_id_path(start, target, true)
	if start_was_solid:
		_astar.set_point_solid(start, true)
	_set_friendly_structures_solid(team, true)
	var path: Array[Vector2] = []
	for cell in cell_path:
		path.append(Vector2(cell))
	if not path.is_empty() and Vector2i(path[0]) == start:
		path.pop_front()
	entity_state["path"] = path
	entity_state["path_index"] = 0


func _set_friendly_structures_solid(team: int, solid: bool) -> void:
	if team < 0:
		return
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
				_astar.set_point_solid(cell, solid)


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
		var progress := minf(1.0, float(target["complete"]) + delta / 8.0)
		target["complete"] = progress
		target["hp"] = maxf(float(target["hp"]), float(target["max_hp"]) * progress)
		if progress >= 1.0:
			target["order"] = &"idle"
			_finish_unit_order(worker)
			_add_event(
				&"complete",
				_entity_center(target),
				Color("f3d47b"),
				{
					"team": int(target["team"]),
					"category": &"structure",
					"kind": target["kind"],
				},
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
		command_move(int(structure["team"]), [unit_id], structure.get("rally_cell", spawn_cell) as Vector2i)
		_add_event(
			&"complete",
			Vector2(spawn_cell),
			Color("f3d47b"),
			{
				"team": int(structure["team"]),
				"category": &"unit",
				"kind": item["kind"],
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
		var food_yield := int(stats.get("food_yield", 0))
		if interval <= 0.0 or food_yield <= 0:
			continue
		structure["food_timer"] = float(structure.get("food_timer", 0.0)) + delta
		while float(structure["food_timer"]) >= interval:
			structure["food_timer"] = float(structure["food_timer"]) - interval
			players[team]["food"] = int(players[team]["food"]) + food_yield
			_add_event(
				&"food",
				_entity_center(structure),
				Color("f2c85b"),
				{"team": team, "category": &"structure", "kind": structure["kind"]},
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
		for team in [TEAM_PLAYER, TEAM_ENEMY]:
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
	_add_event(
		&"capture",
		_entity_center(cave),
		_team_color(team),
		{"team": team, "category": &"structure", "kind": &"yaoguai_den"},
	)
	if team == TEAM_PLAYER:
		battle_notice.emit("Yaoguai Den captured. Jadeclaw production unlocked.", team)
	else:
		battle_notice.emit("The rival has captured a Yaoguai Den.", team)


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
			&"return":
				_advance_return(worker)
			&"repair":
				_advance_repair(worker, delta)


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
	_deposit(
		int(worker["team"]),
		worker.get("cargo_kind", &"") as StringName,
		float(worker.get("cargo_amount", 0.0)),
	)
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
		{"team": int(worker["team"]), "category": &"structure", "kind": &"stronghold"},
	)


func _start_return(worker: Dictionary, resume_gather: bool = true) -> void:
	worker["order"] = &"return"
	worker["target_id"] = -1
	worker["path"] = []
	worker["return_resume_gather"] = resume_gather
	_clear_attack_move(worker)


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
			battle_notice.emit("Repairs paused: gather more Lumber.", team)
			worker["repair_notice_cooldown"] = REPAIR_NOTICE_SECONDS
		return
	players[team]["lumber"] = int(players[team]["lumber"]) - REPAIR_LUMBER_COST
	var restored := minf(REPAIR_AMOUNT, float(target["max_hp"]) - float(target["hp"]))
	target["hp"] = float(target["hp"]) + restored
	_add_event(
		&"repair",
		_entity_center(target),
		Color("e4c66d"),
		{"team": team, "category": &"structure", "kind": target["kind"]},
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
	players[team][String(resource_kind)] = int(players[team][String(resource_kind)]) + final_amount


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
		if _is_neutral_guardian(current):
			_advance_guardian_wander(current, delta)
		if current.get("order") in [&"gather", &"return", &"build", &"repair"]:
			_advance_path(current, delta)
			continue
		if current.get("order") in [&"attack", &"attack_move", &"patrol"]:
			if _advance_attack_order(current, delta):
				continue
		elif current.get("order") in [&"idle", &"wander"] and current.get("kind") != &"worker":
			var nearby := _nearest_enemy(current, float(current.get("acquire_range", 3.8)), true)
			if nearby >= 0:
				current["order"] = &"attack"
				current["target_id"] = nearby
				_clear_attack_move(current)
				if _advance_attack_order(current, delta):
					continue
		_advance_path(current, delta)


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
	if target.is_empty() or not bool(target.get("alive", false)) or not target_is_visible:
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
		attacker["path"] = []
		if float(attacker["attack_cooldown"]) <= 0.0:
			_apply_attack(attacker, target)
		return true
	if float(attacker["repath_timer"]) <= 0.0 or (attacker["path"] as Array).is_empty():
		_set_path(attacker, target["cell"] as Vector2i)
		attacker["repath_timer"] = 0.55
	_advance_path(attacker, delta)
	return true


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
		"attacker_kind": attacker.get("kind", &""),
		"attacker_category": attacker.get("category", &"unit"),
		"target_kind": target.get("kind", &""),
		"target_category": target.get("category", &""),
	})
	if float(target["hp"]) <= 0.0:
		_kill(target, attacker)
	elif target.get("category") == &"wildlife":
		_react_to_hunt(target, attacker)


func _kill(target: Dictionary, killer: Dictionary) -> void:
	if not bool(target.get("alive", false)):
		return
	target["alive"] = false
	target["hp"] = 0.0
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
		_award_guardian_bounty(int(killer.get("team", TEAM_NEUTRAL)), target)
	if target.get("category") == &"wildlife" and killer.get("kind") == &"hunter":
		_award_wildlife_bounty(int(killer.get("team", TEAM_NEUTRAL)), target)
	if int(killer.get("team", TEAM_NEUTRAL)) >= 0 and killer.get("faction") == &"demon":
		killer["hp"] = minf(float(killer["max_hp"]), float(killer["hp"]) + 12.0)
		players[int(killer["team"])]["essence"] = int(players[int(killer["team"])]["essence"]) + 3
	_events.append({
		"type": &"death",
		"position": _entity_center(target),
		"color": Color("ff735d"),
		"team": int(target.get("team", TEAM_NEUTRAL)),
		"category": target.get("category", &""),
		"kind": target.get("kind", &""),
		"killer_team": int(killer.get("team", TEAM_NEUTRAL)),
		"killer_kind": killer.get("kind", &""),
	})
	if target.get("category") in [&"structure", &"resource"]:
		_rebuild_pathfinding()
	if target.get("kind") == &"stronghold":
		outcome = &"victory" if int(target["team"]) == TEAM_ENEMY else &"defeat"
		match_ended.emit(outcome)


func _award_guardian_bounty(team: int, guardian: Dictionary) -> void:
	if team < 0:
		return
	for resource_kind in MONSTER_BOUNTY:
		players[team][resource_kind] = int(players[team][resource_kind]) + int(MONSTER_BOUNTY[resource_kind])
	_add_event(&"bounty", _entity_center(guardian), Color("e4c66d"), {"team": team, "kind": &"jadeclaw"})
	battle_notice.emit("Jadeclaw hunted: +45 Jade · +30 Lumber · +25 Essence.", team)
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
	battle_notice.emit("Yaoguai Den cleared. Hold its ring for 6 seconds to capture it.", team)


func _award_wildlife_bounty(team: int, wildlife: Dictionary) -> void:
	if team < 0:
		return
	var faction := players[team]["faction"] as StringName
	if not FactionCatalog.can_hunt(faction):
		return
	var bounty := int(wildlife.get("food_bounty", 0))
	players[team]["food"] = int(players[team]["food"]) + bounty
	_add_event(
		&"bounty",
		_entity_center(wildlife),
		Color("f1c96b"),
		{"team": team, "category": &"wildlife", "kind": wildlife["kind"]},
	)
	var stats := FactionCatalog.stats(wildlife["kind"] as StringName, &"neutral")
	battle_notice.emit("%s hunted: +%d Food." % [String(stats["name"]), bounty], team)


func _advance_path(entity_state: Dictionary, delta: float) -> void:
	var path := entity_state.get("path", []) as Array
	var path_index := int(entity_state.get("path_index", 0))
	if path.is_empty() or path_index >= path.size():
		if entity_state.get("order") == &"move":
			_finish_unit_order(entity_state)
		elif entity_state.get("order") in [&"wander", &"flee", &"return_home"]:
			entity_state["order"] = &"idle"
		elif entity_state.get("order") == &"attack_move" and int(entity_state.get("target_id", -1)) < 0:
			_finish_unit_order(entity_state)
		elif entity_state.get("order") == &"patrol" and int(entity_state.get("target_id", -1)) < 0:
			_advance_patrol_leg(entity_state)
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
			if entity_state.get("order") == &"move":
				_finish_unit_order(entity_state)
			elif entity_state.get("order") in [&"wander", &"flee", &"return_home"]:
				entity_state["order"] = &"idle"
			elif entity_state.get("order") == &"attack_move" and int(entity_state.get("target_id", -1)) < 0:
				_finish_unit_order(entity_state)
			elif entity_state.get("order") == &"patrol" and int(entity_state.get("target_id", -1)) < 0:
				_advance_patrol_leg(entity_state)


func _advance_ai(delta: float) -> void:
	_ai_strategy_timer -= delta
	_ai_attack_timer -= delta
	_ai_cave_timer -= delta
	_ai_hunt_timer -= delta
	if _ai_strategy_timer > 0.0:
		return
	_ai_strategy_timer = 1.4
	var stronghold := _stronghold_for_team(TEAM_ENEMY)
	if not stronghold.is_empty() and _team_units_of_kind(TEAM_ENEMY, &"worker").size() < 5:
		if (stronghold.get("queue", []) as Array).size() < 1:
			command_train(TEAM_ENEMY, int(stronghold["id"]), &"worker")
	_try_rebuild_ai_war_camp()
	_try_expand_ai_food_economy()
	_try_train_ai_hunters()
	if _ai_hunt_timer <= 0.0:
		_ai_hunt_timer = 5.0
		_issue_ai_hunt_orders()
	for camp in _team_structures_of_kind(TEAM_ENEMY, &"war_camp"):
		if (camp.get("queue", []) as Array).size() >= 2:
			continue
		var next_kind: StringName = &"mystic" if _ai_training_flip else &"vanguard"
		if command_train(TEAM_ENEMY, int(camp["id"]), next_kind):
			_ai_training_flip = not _ai_training_flip
		else:
			var fallback_kind: StringName = &"vanguard" if next_kind == &"mystic" else &"mystic"
			if command_train(TEAM_ENEMY, int(camp["id"]), fallback_kind):
				_ai_training_flip = fallback_kind == &"vanguard"
	for cave in _team_structures_of_kind(TEAM_ENEMY, &"yaoguai_den"):
		if (cave.get("queue", []) as Array).size() < 2:
			command_train(TEAM_ENEMY, int(cave["id"]), &"jadeclaw")
	var army := _team_military(TEAM_ENEMY)
	var needs_cave := captured_cave_count(TEAM_ENEMY) == 0
	if needs_cave and army.size() >= 3:
		if _ai_cave_timer <= 0.0:
			_ai_cave_timer = 6.0
			_issue_ai_cave_order(army)
	elif army.size() >= 4 and (_ai_attack_timer <= 0.0 or army.size() >= 8):
		var player_hold := _stronghold_for_team(TEAM_PLAYER)
		if not player_hold.is_empty():
			var ids: Array[int] = []
			for unit in army:
				ids.append(int(unit["id"]))
				if is_entity_visible_to_team(TEAM_ENEMY, player_hold):
					command_attack(TEAM_ENEMY, ids, int(player_hold["id"]))
				else:
					command_move(TEAM_ENEMY, ids, player_hold["cell"] as Vector2i, true)
			_ai_attack_timer = 22.0
	_auto_assign_idle_worker(TEAM_ENEMY)


func _issue_ai_cave_order(army: Array[Dictionary]) -> void:
	var stronghold := _stronghold_for_team(TEAM_ENEMY)
	if stronghold.is_empty():
		return
	var best_cave: Dictionary = {}
	var best_distance := INF
	for cave_id in cave_ids():
		var cave := entity(cave_id)
		if int(cave.get("team", TEAM_NEUTRAL)) == TEAM_ENEMY:
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
		is_entity_explored_by_team(TEAM_ENEMY, best_cave)
		and cave_guardian_count(int(best_cave["id"])) > 0
	):
		var target_id := -1
		var target_distance := INF
		for raw_guardian_id in best_cave.get("guardian_ids", []) as Array:
			var guardian := entity(int(raw_guardian_id))
			if (
				not bool(guardian.get("alive", false))
				or not is_entity_visible_to_team(TEAM_ENEMY, guardian)
			):
				continue
			var distance := _entity_distance(stronghold, guardian)
			if distance < target_distance:
				target_distance = distance
				target_id = int(guardian["id"])
			if target_id >= 0:
				command_attack(TEAM_ENEMY, ids, target_id)
				return
	command_move(TEAM_ENEMY, ids, best_cave["cell"] as Vector2i, true)


func _try_rebuild_ai_war_camp() -> void:
	if not _team_structures_of_kind(TEAM_ENEMY, &"war_camp").is_empty():
		return
	var builder := _available_builder(TEAM_ENEMY)
	if builder.is_empty() or not can_afford_kind(TEAM_ENEMY, &"war_camp"):
		return
	var sites: Array[Vector2i] = [
		MapCatalog.ENEMY_WAR_CAMP,
		MapCatalog.ENEMY_WAR_CAMP + Vector2i(-1, 0),
		MapCatalog.ENEMY_WAR_CAMP + Vector2i(0, 1),
		MapCatalog.ENEMY_WAR_CAMP + Vector2i(-1, 1),
	]
	for site in sites:
		if can_place_war_camp(TEAM_ENEMY, site):
			command_build_war_camp(TEAM_ENEMY, int(builder["id"]), site)
			return


func _try_expand_ai_food_economy() -> void:
	var farms := _team_structures_of_kind(TEAM_ENEMY, &"rice_farm")
	var lodges := _team_structures_of_kind(TEAM_ENEMY, &"hunters_lodge")
	var faction := players[TEAM_ENEMY]["faction"] as StringName
	var structure_kind := &"" as StringName
	if FactionCatalog.can_farm(faction) and farms.is_empty():
		structure_kind = &"rice_farm"
	elif (
		FactionCatalog.can_hunt(faction)
		and lodges.is_empty()
		and (not FactionCatalog.can_farm(faction) or int(players[TEAM_ENEMY]["food"]) < 100)
	):
		structure_kind = &"hunters_lodge"
	if structure_kind.is_empty() or not can_afford_kind(TEAM_ENEMY, structure_kind):
		return
	var builder := _available_builder(TEAM_ENEMY)
	var stronghold := _stronghold_for_team(TEAM_ENEMY)
	if builder.is_empty() or stronghold.is_empty():
		return
	var site := _find_build_site(TEAM_ENEMY, structure_kind, stronghold["cell"] as Vector2i)
	if site.x >= 0:
		command_build(TEAM_ENEMY, int(builder["id"]), structure_kind, site)


func _try_train_ai_hunters() -> void:
	var faction := players[TEAM_ENEMY]["faction"] as StringName
	if not FactionCatalog.can_hunt(faction):
		return
	var hunter_total := _team_units_of_kind(TEAM_ENEMY, &"hunter").size()
	for lodge in _team_structures_of_kind(TEAM_ENEMY, &"hunters_lodge"):
		if float(lodge.get("complete", 0.0)) < 1.0:
			continue
		for raw_item in lodge.get("queue", []) as Array:
			if (raw_item as Dictionary).get("kind") == &"hunter":
				hunter_total += 1
		if hunter_total >= 2:
			return
		if command_train(TEAM_ENEMY, int(lodge["id"]), &"hunter"):
			hunter_total += 1


func _issue_ai_hunt_orders() -> void:
	var wildlife := wildlife_ids()
	if wildlife.is_empty():
		return
	for hunter in _team_units_of_kind(TEAM_ENEMY, &"hunter"):
		if hunter.get("order") != &"idle":
			continue
		var target: Dictionary = {}
		var best_distance := INF
		for wildlife_id in wildlife:
			var candidate := entity(wildlife_id)
			if not is_entity_visible_to_team(TEAM_ENEMY, candidate):
				continue
			var distance := _entity_distance(hunter, candidate)
			if distance < best_distance:
				best_distance = distance
				target = candidate
		if (
			not target.is_empty()
			and command_attack(TEAM_ENEMY, [int(hunter["id"])], int(target["id"]))
		):
			continue
		var scout_cell := _nearest_wildlife_herd_center(hunter["position"] as Vector2)
		if MapCatalog.in_bounds(scout_cell):
			command_move(TEAM_ENEMY, [int(hunter["id"])], scout_cell, true)


func _nearest_wildlife_herd_center(origin: Vector2) -> Vector2i:
	var best_cell := Vector2i(-1, -1)
	var best_distance := INF
	for definition in MapCatalog.WILDLIFE_HERDS:
		var center := definition["center"] as Vector2i
		if is_cell_explored_by_team(TEAM_ENEMY, center):
			continue
		var distance := origin.distance_to(Vector2(center))
		if distance < best_distance:
			best_distance = distance
			best_cell = center
	if MapCatalog.in_bounds(best_cell):
		return best_cell
	for definition in MapCatalog.WILDLIFE_HERDS:
		var center := definition["center"] as Vector2i
		var distance := origin.distance_to(Vector2(center))
		if distance < best_distance:
			best_distance = distance
			best_cell = center
	return best_cell


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
		if team == TEAM_ENEMY:
			_assign_ai_resource(worker)
		else:
			_assign_nearest_resource(worker)


func _auto_assign_idle_worker(team: int) -> void:
	for worker in _team_units_of_kind(team, &"worker"):
		if worker.get("order") == &"idle":
			if team == TEAM_ENEMY:
				_assign_ai_resource(worker)
			else:
				_assign_nearest_resource(worker)
			return


func _assign_ai_resource(worker: Dictionary) -> void:
	var assigned := {&"jade": 0, &"lumber": 0, &"essence": 0}
	for teammate in _team_units_of_kind(TEAM_ENEMY, &"worker"):
		if int(teammate.get("id", -1)) == int(worker.get("id", -1)):
			continue
		var source := entity(int(teammate.get("gather_source_id", -1)))
		var kind := source.get("resource_kind", &"") as StringName
		if bool(source.get("alive", false)) and assigned.has(kind):
			assigned[kind] = int(assigned[kind]) + 1
	var preferred_kind: StringName = &"jade"
	if int(players[TEAM_ENEMY]["lumber"]) < 160 and int(assigned[&"lumber"]) < 1:
		preferred_kind = &"lumber"
	elif int(assigned[&"essence"]) < 1:
		preferred_kind = &"essence"
	if not _assign_nearest_resource(worker, preferred_kind):
		_assign_nearest_resource(worker)


func _assign_nearest_resource(worker: Dictionary, resource_kind: StringName = &"") -> bool:
	var resource := _nearest_resource(worker, resource_kind)
	if not resource.is_empty():
		command_gather(int(worker["team"]), [int(worker["id"])], int(resource["id"]))
		return true
	return false


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
				if _moving_friendly_units_can_overlap(first, second):
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


func _cell_occupied_by_static_entity(cell: Vector2i) -> bool:
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)):
			continue
		if entity_state.get("category") not in [&"structure", &"resource"]:
			continue
		for occupied in MapCatalog.footprint_cells(
			entity_state["cell"] as Vector2i,
			entity_state.get("footprint", Vector2i.ONE) as Vector2i,
		):
			if occupied == cell:
				return true
	return false


func _cell_occupied_by_live_unit(cell: Vector2i) -> bool:
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			not bool(entity_state.get("alive", false))
			or entity_state.get("category") not in [&"unit", &"wildlife"]
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
	return (
		not entity_state.is_empty()
		and bool(entity_state.get("alive", false))
		and entity_state.get("category") == &"unit"
		and int(entity_state.get("team", TEAM_NEUTRAL)) >= 0
	)


func _is_valid_team(team: int) -> bool:
	return team >= 0 and team < players.size()


func _is_military_unit(entity_state: Dictionary) -> bool:
	return entity_state.get("category") == &"unit" and entity_state.get("kind") in [&"hunter", &"vanguard", &"mystic", &"jadeclaw"]


func _is_neutral_guardian(entity_state: Dictionary) -> bool:
	return (
		entity_state.get("kind") == &"jadeclaw"
		and int(entity_state.get("team", TEAM_NEUTRAL)) == TEAM_NEUTRAL
		and int(entity_state.get("home_cave_id", -1)) >= 0
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
	if first_team == TEAM_NEUTRAL:
		return _is_neutral_guardian(first) and second_team >= 0
	if second_team == TEAM_NEUTRAL:
		return _is_neutral_guardian(second)
	return true


func _has_line_of_sight(first: Dictionary, second: Dictionary) -> bool:
	var start := Vector2i(_entity_center(first).round())
	var finish := Vector2i(_entity_center(second).round())
	var ignored_ids := {int(first.get("id", -1)): true, int(second.get("id", -1)): true}
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
	var faction := players[team]["faction"] as StringName
	return _can_afford(team, FactionCatalog.stats(kind, faction))


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
				result += float(stats.get("food_yield", 0)) / interval
	return result


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
