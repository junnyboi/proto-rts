extends "res://scripts/sim/rts_simulation.gd"

# Frozen pre-optimization algorithms used only by focused runtime equivalence tests.
# Keep these independent of the optimized broad phase and visibility signatures.

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
