class_name RtsSimulation
extends RefCounted

signal match_ended(result: StringName)
signal state_changed

const TEAM_PLAYER := 0
const TEAM_ENEMY := 1
const TEAM_NEUTRAL := -1
const POPULATION_CAP := 24
const TICK_SECONDS := 1.0 / 30.0
const GATHER_CYCLE := 0.8
const CARGO_CAPACITY := 50.0
const GATHER_AMOUNT := 10.0
const UNIT_SEPARATION_DISTANCE := 0.46
const UNIT_SEPARATION_STEP := 0.10
const AI_WAR_CAMP_CELL := Vector2i(15, 3)
const INVALID_CELL := Vector2i(-1, -1)

var players: Array[Dictionary] = []
var entities: Dictionary = {}
var elapsed_time := 0.0
var outcome: StringName = &""

var _next_entity_id := 1
var _accumulator := 0.0
var _astar := AStarGrid2D.new()
var _events: Array[Dictionary] = []
var _ai_strategy_timer := 0.5
var _ai_attack_timer := 14.0
var _ai_training_flip := false
var _ai_enabled := true


func setup(player_faction: StringName, enable_ai: bool = true) -> void:
	var map_errors := MapCatalog.validation_errors()
	if not map_errors.is_empty():
		for message in map_errors:
			push_error("Invalid authored map: %s" % message)
		assert(map_errors.is_empty(), "Authored map validation failed")
		return
	entities.clear()
	_events.clear()
	_next_entity_id = 1
	_accumulator = 0.0
	_ai_strategy_timer = 0.5
	_ai_attack_timer = 14.0
	_ai_training_flip = false
	_ai_enabled = enable_ai
	elapsed_time = 0.0
	outcome = &""
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
	_rebuild_pathfinding()
	if _ai_enabled:
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
	_advance_production(delta)
	_advance_worker_orders(delta)
	_advance_combat_and_movement(delta)
	if _ai_enabled:
		_advance_ai(delta)
	state_changed.emit()


func _player_state(faction: StringName, is_ai: bool) -> Dictionary:
	return {
		"faction": faction,
		"jade": 320,
		"essence": 160,
		"population": 0,
		"population_cap": POPULATION_CAP,
		"is_ai": is_ai,
	}


func _spawn_unit(team: int, kind: StringName, cell: Vector2i) -> int:
	var faction := players[team]["faction"] as StringName
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
		"attack_move": false,
		"attack_move_destination": INVALID_CELL,
		"repath_timer": 0.0,
		"cargo_kind": &"",
		"cargo_amount": 0.0,
		"gather_source_id": -1,
		"gather_timer": 0.0,
		"population": int(stats["population"]),
		"flash_timer": 0.0,
	}
	entities[_next_entity_id] = entity_state
	players[team]["population"] = int(players[team]["population"]) + int(stats["population"])
	_next_entity_id += 1
	return int(entity_state["id"])


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
		"flash_timer": 0.0,
	}
	entities[_next_entity_id] = entity_state
	_next_entity_id += 1
	return int(entity_state["id"])


func _spawn_resource(definition: Dictionary) -> int:
	var kind := definition["kind"] as StringName
	var entity_state := {
		"id": _next_entity_id,
		"team": TEAM_NEUTRAL,
		"faction": &"neutral",
		"kind": &"jade_node" if kind == &"jade" else &"essence_node",
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


func command_move(ids: Array[int], destination: Vector2i, attack_move: bool = false) -> void:
	if not MapCatalog.in_bounds(destination):
		return
	var commandable: Array[Dictionary] = []
	for id in ids:
		var unit := entity(id)
		if _is_commandable_unit(unit):
			commandable.append(unit)
	if commandable.is_empty():
		return
	var formation := _formation_cells(destination, commandable.size())
	for index in range(commandable.size()):
		var unit := commandable[index]
		var formation_cell := formation[index]
		unit["order"] = &"attack_move" if attack_move else &"move"
		unit["target_id"] = -1
		unit["attack_move"] = attack_move
		unit["attack_move_destination"] = formation_cell if attack_move else INVALID_CELL
		_set_path(unit, formation_cell)
	_add_event(&"command", Vector2(destination), Color("8de8c0"))


func command_attack(ids: Array[int], target_id: int) -> void:
	var target := entity(target_id)
	if target.is_empty() or not bool(target.get("alive", false)):
		return
	for id in ids:
		var attacker := entity(id)
		if not _is_commandable_unit(attacker) or int(attacker["team"]) == int(target["team"]):
			continue
		attacker["order"] = &"attack"
		attacker["target_id"] = target_id
		attacker["attack_move"] = false
		attacker["attack_move_destination"] = INVALID_CELL
		attacker["path"] = []
	_add_event(&"command", _entity_center(target), Color("f16a57"))


func command_gather(ids: Array[int], resource_id: int) -> void:
	var resource := entity(resource_id)
	if resource.is_empty() or resource.get("category") != &"resource":
		return
	for id in ids:
		var worker := entity(id)
		if not _is_commandable_unit(worker) or worker.get("kind") != &"worker":
			continue
		worker["order"] = &"gather"
		worker["gather_source_id"] = resource_id
		worker["target_id"] = resource_id
		worker["gather_timer"] = 0.0
		worker["attack_move"] = false
		worker["attack_move_destination"] = INVALID_CELL
		_set_path(worker, resource["cell"] as Vector2i)
	_add_event(&"command", _entity_center(resource), Color("73e6bc"))


func command_stop(ids: Array[int]) -> void:
	for id in ids:
		var unit := entity(id)
		if not _is_commandable_unit(unit):
			continue
		unit["order"] = &"idle"
		unit["target_id"] = -1
		unit["path"] = []
		unit["attack_move"] = false
		unit["attack_move_destination"] = INVALID_CELL


func command_build_war_camp(worker_id: int, cell: Vector2i) -> bool:
	var worker := entity(worker_id)
	if worker.is_empty() or worker.get("kind") != &"worker" or not _is_commandable_unit(worker):
		return false
	var team := int(worker["team"])
	var faction := players[team]["faction"] as StringName
	var stats := FactionCatalog.stats(&"war_camp", faction)
	if not can_place_war_camp(team, cell) or not _can_afford(team, stats):
		return false
	_pay(team, stats)
	var structure_id := _spawn_structure(team, &"war_camp", cell, false)
	worker["order"] = &"build"
	worker["target_id"] = structure_id
	worker["path"] = []
	_rebuild_pathfinding()
	_add_event(&"build", Vector2(cell), FactionCatalog.definition(faction)["accent"] as Color)
	return true


func can_place_war_camp(team: int, cell: Vector2i) -> bool:
	var faction := players[team]["faction"] as StringName
	var stats := FactionCatalog.stats(&"war_camp", faction)
	var footprint := stats.get("footprint", Vector2i.ONE) as Vector2i
	for footprint_cell in MapCatalog.footprint_cells(cell, footprint):
		if not MapCatalog.is_static_walkable(footprint_cell):
			return false
		if _cell_occupied_by_live_entity(footprint_cell):
			return false
	return true


func command_train(structure_id: int, unit_kind: StringName) -> bool:
	var structure := entity(structure_id)
	if structure.is_empty() or not bool(structure.get("alive", false)):
		return false
	if float(structure.get("complete", 0.0)) < 1.0:
		return false
	if unit_kind == &"worker" and structure.get("kind") != &"stronghold":
		return false
	if unit_kind in [&"vanguard", &"mystic"] and structure.get("kind") != &"war_camp":
		return false
	var team := int(structure["team"])
	var faction := players[team]["faction"] as StringName
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
	})
	structure["queue"] = queue
	return true


func set_rally(structure_id: int, cell: Vector2i) -> void:
	var structure := entity(structure_id)
	if structure.is_empty() or structure.get("category") != &"structure" or not MapCatalog.in_bounds(cell):
		return
	structure["rally_cell"] = _nearest_walkable(cell)
	_add_event(&"command", Vector2(structure["rally_cell"]), Color("f0d278"))


func _rebuild_pathfinding() -> void:
	_astar.clear()
	_astar.region = Rect2i(Vector2i.ZERO, MapCatalog.SIZE)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update()
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			_astar.set_point_solid(cell, not MapCatalog.is_static_walkable(cell))
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


func _set_path(entity_state: Dictionary, destination: Vector2i) -> void:
	var start := Vector2i((entity_state["position"] as Vector2).round())
	if not MapCatalog.in_bounds(start):
		return
	if _astar.is_point_solid(start):
		_astar.set_point_solid(start, false)
	var target := _nearest_walkable(destination)
	var cell_path := _astar.get_id_path(start, target, true)
	var path: Array[Vector2] = []
	for cell in cell_path:
		path.append(Vector2(cell))
	if not path.is_empty() and path[0].distance_to(entity_state["position"] as Vector2) < 0.1:
		path.pop_front()
	entity_state["path"] = path
	entity_state["path_index"] = 0


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
			worker["order"] = &"idle"
			continue
		if float(target.get("complete", 1.0)) >= 1.0:
			worker["order"] = &"idle"
			worker["target_id"] = -1
			continue
		if _entity_distance(worker, target) > 1.35:
			if (worker["path"] as Array).is_empty():
				_set_path(worker, target["cell"] as Vector2i)
			continue
		worker["path"] = []
		var progress := minf(1.0, float(target["complete"]) + delta / 8.0)
		target["complete"] = progress
		target["hp"] = maxf(float(target["hp"]), float(target["max_hp"]) * progress)
		if progress >= 1.0:
			target["order"] = &"idle"
			worker["order"] = &"idle"
			worker["target_id"] = -1
			_add_event(&"complete", _entity_center(target), Color("f3d47b"))


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
		command_move([unit_id], structure.get("rally_cell", spawn_cell) as Vector2i)
		_add_event(&"complete", Vector2(spawn_cell), Color("f3d47b"))


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


func _advance_gather(worker: Dictionary, delta: float) -> void:
	var resource := entity(int(worker.get("gather_source_id", -1)))
	if resource.is_empty() or not bool(resource.get("alive", false)) or float(resource.get("amount", 0.0)) <= 0.0:
		if float(worker.get("cargo_amount", 0.0)) > 0.0:
			_start_return(worker)
		else:
			worker["order"] = &"idle"
		return
	if _entity_distance(worker, resource) > 1.25:
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
		CARGO_CAPACITY - float(worker["cargo_amount"]),
	)
	resource["amount"] = float(resource["amount"]) - gathered
	worker["cargo_kind"] = resource["resource_kind"]
	worker["cargo_amount"] = float(worker["cargo_amount"]) + gathered
	_add_event(
		&"gather",
		_entity_center(resource),
		Color("79e3b4") if resource["resource_kind"] == &"jade" else Color("87c9ff"),
	)
	if float(resource["amount"]) <= 0.0:
		resource["alive"] = false
		_rebuild_pathfinding()
	if float(worker["cargo_amount"]) >= CARGO_CAPACITY or not bool(resource["alive"]):
		_start_return(worker)


func _advance_return(worker: Dictionary) -> void:
	var stronghold := _stronghold_for_team(int(worker["team"]))
	if stronghold.is_empty():
		worker["order"] = &"idle"
		return
	if _entity_distance(worker, stronghold) > 1.55:
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
	var source := entity(int(worker.get("gather_source_id", -1)))
	if not source.is_empty() and bool(source.get("alive", false)):
		worker["order"] = &"gather"
		worker["target_id"] = int(source["id"])
		_set_path(worker, source["cell"] as Vector2i)
	else:
		worker["order"] = &"idle"
	_add_event(&"deposit", _entity_center(stronghold), Color("f1d477"))


func _start_return(worker: Dictionary) -> void:
	worker["order"] = &"return"
	worker["target_id"] = -1
	worker["path"] = []


func _deposit(team: int, resource_kind: StringName, amount: float) -> void:
	var faction := players[team]["faction"] as StringName
	var multiplier := 1.0
	if faction == &"celestial" and resource_kind == &"essence":
		multiplier = 1.15
	elif faction == &"human" and resource_kind == &"jade":
		multiplier = 1.10
	var final_amount := int(round(amount * multiplier))
	players[team][String(resource_kind)] = int(players[team][String(resource_kind)]) + final_amount


func _advance_combat_and_movement(delta: float) -> void:
	for raw_id in entities.keys():
		var current := entity(int(raw_id))
		if current.is_empty() or not bool(current.get("alive", false)):
			continue
		current["flash_timer"] = maxf(0.0, float(current.get("flash_timer", 0.0)) - delta)
		if current.get("category") != &"unit":
			continue
		current["attack_cooldown"] = maxf(0.0, float(current.get("attack_cooldown", 0.0)) - delta)
		current["repath_timer"] = maxf(0.0, float(current.get("repath_timer", 0.0)) - delta)
		if current.get("order") in [&"gather", &"return", &"build"]:
			_advance_path(current, delta)
			continue
		if current.get("order") in [&"attack", &"attack_move"]:
			if _advance_attack_order(current, delta):
				continue
		elif current.get("order") == &"idle" and current.get("kind") != &"worker":
			var nearby := _nearest_enemy(current, 3.8)
			if nearby >= 0:
				current["order"] = &"attack"
				current["target_id"] = nearby
				if _advance_attack_order(current, delta):
					continue
		_advance_path(current, delta)
	_apply_unit_separation()


func _advance_attack_order(attacker: Dictionary, delta: float) -> bool:
	var target := entity(int(attacker.get("target_id", -1)))
	if target.is_empty() or not bool(target.get("alive", false)):
		attacker["target_id"] = -1
		if bool(attacker.get("attack_move", false)):
			var acquired := _nearest_enemy(attacker, float(attacker["acquire_range"]))
			if acquired >= 0:
				attacker["target_id"] = acquired
				target = entity(acquired)
			else:
				_resume_attack_move(attacker)
				return false
		else:
			attacker["order"] = &"idle"
			attacker["path"] = []
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


func _resume_attack_move(attacker: Dictionary) -> void:
	var destination := attacker.get("attack_move_destination", INVALID_CELL) as Vector2i
	if not MapCatalog.in_bounds(destination):
		attacker["order"] = &"idle"
		attacker["attack_move"] = false
		attacker["attack_move_destination"] = INVALID_CELL
		attacker["path"] = []
		return
	if (attacker["position"] as Vector2).distance_to(Vector2(destination)) <= 0.025:
		attacker["order"] = &"idle"
		attacker["attack_move"] = false
		attacker["attack_move_destination"] = INVALID_CELL
		attacker["path"] = []
		return
	if (attacker.get("path", []) as Array).is_empty():
		_set_path(attacker, destination)


func _apply_attack(attacker: Dictionary, target: Dictionary) -> void:
	attacker["attack_cooldown"] = float(attacker["attack_period"])
	target["hp"] = float(target["hp"]) - float(attacker["damage"])
	target["flash_timer"] = 0.16
	_events.append({
		"type": &"attack",
		"from": _entity_center(attacker),
		"to": _entity_center(target),
		"color": FactionCatalog.definition(attacker["faction"] as StringName)["accent"],
	})
	if float(target["hp"]) <= 0.0:
		_kill(target, attacker)


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
	elif target.get("category") == &"structure":
		for queued_item in target.get("queue", []) as Array:
			players[int(target["team"])]["population"] = maxi(
				0,
				int(players[int(target["team"])]["population"]) - int(queued_item.get("reserved_population", 0)),
			)
	if int(killer.get("team", TEAM_NEUTRAL)) >= 0 and killer.get("faction") == &"demon":
		killer["hp"] = minf(float(killer["max_hp"]), float(killer["hp"]) + 12.0)
		players[int(killer["team"])]["essence"] = int(players[int(killer["team"])]["essence"]) + 3
	_events.append({"type": &"death", "position": _entity_center(target), "color": Color("ff735d")})
	if target.get("category") in [&"structure", &"resource"]:
		_rebuild_pathfinding()
	if target.get("kind") == &"stronghold":
		outcome = &"victory" if int(target["team"]) == TEAM_ENEMY else &"defeat"
		match_ended.emit(outcome)


func _advance_path(entity_state: Dictionary, delta: float) -> void:
	var path := entity_state.get("path", []) as Array
	var path_index := int(entity_state.get("path_index", 0))
	if path.is_empty() or path_index >= path.size():
		if entity_state.get("order") in [&"move", &"attack_move"] and int(entity_state.get("target_id", -1)) < 0:
			entity_state["order"] = &"idle"
			entity_state["attack_move"] = false
			entity_state["attack_move_destination"] = INVALID_CELL
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
			if entity_state.get("order") in [&"move", &"attack_move"] and int(entity_state.get("target_id", -1)) < 0:
				entity_state["order"] = &"idle"
				entity_state["attack_move"] = false
				entity_state["attack_move_destination"] = INVALID_CELL


func _advance_ai(delta: float) -> void:
	_ai_strategy_timer -= delta
	_ai_attack_timer -= delta
	if _ai_strategy_timer > 0.0:
		return
	_ai_strategy_timer = 1.4
	var camps := _team_structures_of_kind(TEAM_ENEMY, &"war_camp")
	if camps.is_empty() and can_afford_kind(TEAM_ENEMY, &"war_camp") and can_place_war_camp(TEAM_ENEMY, AI_WAR_CAMP_CELL):
		var builders := _team_units_of_kind(TEAM_ENEMY, &"worker")
		if not builders.is_empty():
			command_build_war_camp(int(builders[0]["id"]), AI_WAR_CAMP_CELL)
			camps = _team_structures_of_kind(TEAM_ENEMY, &"war_camp")
	var stronghold := _stronghold_for_team(TEAM_ENEMY)
	if not stronghold.is_empty() and _team_units_of_kind(TEAM_ENEMY, &"worker").size() < 5:
		if (stronghold.get("queue", []) as Array).size() < 1:
			command_train(int(stronghold["id"]), &"worker")
	for camp in camps:
		if (camp.get("queue", []) as Array).size() >= 2:
			continue
		var next_kind: StringName = &"mystic" if _ai_training_flip else &"vanguard"
		if command_train(int(camp["id"]), next_kind):
			_ai_training_flip = not _ai_training_flip
		else:
			var fallback_kind: StringName = &"vanguard" if next_kind == &"mystic" else &"mystic"
			if command_train(int(camp["id"]), fallback_kind):
				_ai_training_flip = fallback_kind == &"vanguard"
	var army := _team_military(TEAM_ENEMY)
	if army.size() >= 4 and (_ai_attack_timer <= 0.0 or army.size() >= 8):
		var player_hold := _stronghold_for_team(TEAM_PLAYER)
		if not player_hold.is_empty():
			var ids: Array[int] = []
			for unit in army:
				ids.append(int(unit["id"]))
			command_attack(ids, int(player_hold["id"]))
			_ai_attack_timer = 22.0
	_auto_assign_idle_worker(TEAM_ENEMY)


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
	var essence_workers := 0
	for teammate in _team_units_of_kind(TEAM_ENEMY, &"worker"):
		if int(teammate.get("id", -1)) == int(worker.get("id", -1)):
			continue
		var source := entity(int(teammate.get("gather_source_id", -1)))
		if bool(source.get("alive", false)) and source.get("resource_kind") == &"essence":
			essence_workers += 1
	var preferred_kind: StringName = &"essence" if essence_workers < 1 else &"jade"
	if not _assign_nearest_resource(worker, preferred_kind):
		_assign_nearest_resource(worker)


func _assign_nearest_resource(worker: Dictionary, resource_kind: StringName = &"") -> bool:
	var best_id := -1
	var best_distance := INF
	for raw_resource in entities.values():
		var resource := raw_resource as Dictionary
		if not bool(resource.get("alive", false)) or resource.get("category") != &"resource":
			continue
		if not resource_kind.is_empty() and resource.get("resource_kind") != resource_kind:
			continue
		var distance := _entity_distance(worker, resource)
		if distance < best_distance:
			best_distance = distance
			best_id = int(resource["id"])
	if best_id >= 0:
		command_gather([int(worker["id"])], best_id)
		return true
	return false


func _formation_cells(center: Vector2i, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if count <= 0:
		return result
	var used := {}
	var max_radius := MapCatalog.SIZE.x + MapCatalog.SIZE.y
	for radius in range(max_radius):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if abs(x) + abs(y) != radius:
					continue
				var candidate := center + Vector2i(x, y)
				if not MapCatalog.in_bounds(candidate) or _astar.is_point_solid(candidate) or used.has(candidate):
					continue
				used[candidate] = true
				result.append(candidate)
				if result.size() >= count:
					return result
	return result


func _cell_occupied_by_live_entity(cell: Vector2i) -> bool:
	for raw_entity in entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)):
			continue
		for occupied in MapCatalog.footprint_cells(
			entity_state["cell"] as Vector2i,
			entity_state.get("footprint", Vector2i.ONE) as Vector2i,
		):
			if occupied == cell:
				return true
	return false


func _apply_unit_separation() -> void:
	var unit_ids := team_entity_ids(TEAM_PLAYER) + team_entity_ids(TEAM_ENEMY)
	unit_ids.sort()
	for first_index in range(unit_ids.size()):
		var first := entity(unit_ids[first_index])
		if first.get("category") != &"unit":
			continue
		for second_index in range(first_index + 1, unit_ids.size()):
			var second := entity(unit_ids[second_index])
			if second.get("category") != &"unit":
				continue
			var first_position := first["position"] as Vector2
			var second_position := second["position"] as Vector2
			var offset := second_position - first_position
			var distance := offset.length()
			if distance >= UNIT_SEPARATION_DISTANCE:
				continue
			var direction := offset / distance if distance > 0.001 else _deterministic_separation_direction(int(first["id"]), int(second["id"]))
			var correction := minf((UNIT_SEPARATION_DISTANCE - distance) * 0.5, UNIT_SEPARATION_STEP)
			_try_move_for_separation(first, first_position - direction * correction)
			_try_move_for_separation(second, second_position + direction * correction)


func _deterministic_separation_direction(first_id: int, second_id: int) -> Vector2:
	var directions: Array[Vector2] = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	return directions[posmod(first_id * 31 + second_id * 17, directions.size())]


func _try_move_for_separation(unit: Dictionary, candidate: Vector2) -> void:
	var cell := Vector2i(candidate.round())
	if not MapCatalog.in_bounds(cell) or _astar.is_point_solid(cell):
		return
	unit["position"] = candidate
	unit["cell"] = cell


func _can_afford(team: int, stats: Dictionary) -> bool:
	return (
		int(players[team]["jade"]) >= int(stats.get("jade_cost", 0))
		and int(players[team]["essence"]) >= int(stats.get("essence_cost", 0))
	)


func _pay(team: int, stats: Dictionary) -> void:
	players[team]["jade"] = int(players[team]["jade"]) - int(stats.get("jade_cost", 0))
	players[team]["essence"] = int(players[team]["essence"]) - int(stats.get("essence_cost", 0))


func _has_population_room(team: int, amount: int) -> bool:
	return int(players[team]["population"]) + amount <= int(players[team]["population_cap"])


func _is_commandable_unit(entity_state: Dictionary) -> bool:
	return (
		not entity_state.is_empty()
		and bool(entity_state.get("alive", false))
		and entity_state.get("category") == &"unit"
		and int(entity_state.get("team", TEAM_NEUTRAL)) >= 0
	)


func _entity_center(entity_state: Dictionary) -> Vector2:
	var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
	return entity_state["position"] as Vector2 + (Vector2(footprint) - Vector2.ONE) * 0.5


func _entity_distance(first: Dictionary, second: Dictionary) -> float:
	return _entity_center(first).distance_to(_entity_center(second))


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


func _nearest_enemy(source: Dictionary, maximum_distance: float) -> int:
	var best_id := -1
	var best_distance := maximum_distance
	for raw_target in entities.values():
		var target := raw_target as Dictionary
		if not bool(target.get("alive", false)) or int(target.get("team", TEAM_NEUTRAL)) < 0:
			continue
		if int(target["team"]) == int(source["team"]):
			continue
		var distance := _entity_distance(source, target)
		if distance < best_distance and _has_line_of_sight(source, target) and _has_reachable_path(source, target):
			best_distance = distance
			best_id = int(target["id"])
	return best_id


func _has_reachable_path(source: Dictionary, target: Dictionary) -> bool:
	var start := Vector2i((source["position"] as Vector2).round())
	if not MapCatalog.in_bounds(start):
		return false
	var destination := _nearest_walkable(target["cell"] as Vector2i)
	if start == destination:
		return true
	return not _astar.get_id_path(start, destination, false).is_empty()


func _has_line_of_sight(source: Dictionary, target: Dictionary) -> bool:
	var start := Vector2i((source["position"] as Vector2).round())
	var finish := Vector2i(_entity_center(target).round())
	var difference := finish - start
	var steps := maxi(absi(difference.x), absi(difference.y))
	if steps <= 1:
		return true
	for step in range(1, steps):
		var ratio := float(step) / float(steps)
		var cell := Vector2i(Vector2(start).lerp(Vector2(finish), ratio).round())
		if not MapCatalog.in_bounds(cell) or MapCatalog.terrain_at(cell) == &"ridge":
			return false
	return true


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
			and entity_state.get("kind") in [&"vanguard", &"mystic"]
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


func can_afford_kind(team: int, kind: StringName) -> bool:
	var faction := players[team]["faction"] as StringName
	return _can_afford(team, FactionCatalog.stats(kind, faction))


func has_population_for(team: int, kind: StringName) -> bool:
	var faction := players[team]["faction"] as StringName
	var stats := FactionCatalog.stats(kind, faction)
	return _has_population_room(team, int(stats.get("population", 0)))


func drain_events() -> Array[Dictionary]:
	var result := _events.duplicate(true)
	_events.clear()
	return result


func _add_event(event_type: StringName, position: Vector2, color: Color) -> void:
	_events.append({"type": event_type, "position": position, "color": color})
