class_name Battlefield
extends Control

signal selection_changed(ids)
signal feedback(message: String, is_error: bool)
signal fog_visibility_changed

const TERRAIN_TEXTURES := {
	&"meadow": preload("res://assets/runtime/terrain/jade_meadow.webp"),
	&"ridge": preload("res://assets/runtime/terrain/inkstone_ridge.webp"),
	&"water": preload("res://assets/runtime/terrain/celadon_water.webp"),
	&"forest": preload("res://assets/runtime/terrain/jade_forest.webp"),
	&"road": preload("res://assets/runtime/terrain/meridian_road.webp"),
	&"bridge": preload("res://assets/runtime/terrain/moon_bridge.webp"),
}
const RESOURCE_TEXTURES := {
	&"jade_node": preload("res://assets/runtime/resources/jade_outcrop.png"),
	&"essence_node": preload("res://assets/runtime/resources/essence_shrine.png"),
	&"lumber_pine": preload("res://assets/runtime/resources/lumber_pine.png"),
	&"lumber_cedar": preload("res://assets/runtime/resources/lumber_cedar.png"),
	&"lumber_fir": preload("res://assets/runtime/resources/lumber_fir.png"),
	&"lumber_juniper": preload("res://assets/runtime/resources/lumber_juniper.png"),
}
const IDLE_WORKER_ALERT_TEXTURE := preload("res://assets/runtime/ui/idle_worker_alert.png")
const PLAYER_COLOR := Color("78dfb7")
const ENEMY_COLOR := Color("f06656")
const NEUTRAL_COLOR := Color("d7bd6c")
const GRID_COLOR := Color(0.06, 0.16, 0.15, 0.24)
const GRID_LINE_WIDTH := 0.65
const JADE_RESOURCE_COLOR := Color("73dfab")
const LUMBER_RESOURCE_COLOR := Color("d5a85d")
const ESSENCE_RESOURCE_COLOR := Color("77c6ff")
const FOOD_RESOURCE_COLOR := Color("f2c85b")
const EXPLORED_FOG_COLOR := Color(0.015, 0.055, 0.06, 0.58)
const UNEXPLORED_FOG_COLOR := Color(0.005, 0.018, 0.022, 0.97)
const VISIBILITY_REFRESH_SECONDS := 0.1
const WATER_UV_SCALE := 0.33
const WATER_FLOW_SPEED := Vector2(-0.045, -0.045)
const TREE_SWAY_BANDS := 12
const TREE_SWAY_ANCHOR := 0.72
const TREE_SWAY_STRENGTH := 0.052
const TREE_SWAY_MIN_SCALE := 0.28
const WHEEL_ZOOM_STEP := 1.12
const MIN_CAMERA_SCALE := 0.14
const MAX_CAMERA_SCALE := 1.05
const CONTROL_GROUP_DOUBLE_TAP_MS := 450

var simulation: RtsSimulation
var selected_ids: Array[int] = []
var attack_move_armed := false
var patrol_armed := false
var repair_armed := false
var placement_worker_id := -1
var placement_kind: StringName = &""
var fog_enabled := true
var control_groups: Dictionary = {}

var camera_scale := 0.62
var camera_offset := Vector2.ZERO
var _camera_initialized := false
var _middle_dragging := false
var _selection_pressed := false
var _selection_dragging := false
var _selection_start := Vector2.ZERO
var _selection_current := Vector2.ZERO
var _selection_additive := false
var _armed_append := false
var _last_control_group := -1
var _last_control_group_recall_ms := -1000
var _mouse_position := Vector2.ZERO
var _texture_cache: Dictionary = {}
var _effects: Array[Dictionary] = []
var _visible_cells: Dictionary = {}
var _explored_cells: Dictionary = {}
var _visibility_timer := 0.0
var _water_animation_time := 0.0
var _wind_animation_time := 0.0


func _ready() -> void:
	set_process(true)
	set_process_unhandled_key_input(true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	resized.connect(_on_resized)
	call_deferred("_fit_camera")


func set_simulation(value: RtsSimulation) -> void:
	simulation = value
	selected_ids.clear()
	control_groups.clear()
	cancel_modes()
	_last_control_group = -1
	_last_control_group_recall_ms = -1000
	_texture_cache.clear()
	_visible_cells.clear()
	_explored_cells.clear()
	_refresh_visibility()
	_fit_camera()
	queue_redraw()


func _on_resized() -> void:
	if not _camera_initialized:
		_fit_camera()
	else:
		_clamp_camera()
	queue_redraw()


func _fit_camera() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var bounds := IsoProjection.map_bounds(MapCatalog.SIZE)
	var available := Vector2(size.x - 56.0, size.y - 176.0)
	var overview_scale := minf(available.x / bounds.size.x, available.y / bounds.size.y)
	camera_scale = clampf(overview_scale * 2.376, 0.504, 0.864)
	var focus := MapCatalog.PLAYER_STRONGHOLD if simulation != null else MapCatalog.SIZE / 2
	camera_offset = Vector2(size.x * 0.5, size.y * 0.46) - IsoProjection.cell_center(focus) * camera_scale
	_camera_initialized = true
	_clamp_camera()


func center_on_cell(cell: Vector2i) -> void:
	camera_offset = size * 0.5 - IsoProjection.cell_center(cell) * camera_scale
	_clamp_camera()
	queue_redraw()


func center_on_player_stronghold() -> void:
	center_on_cell(MapCatalog.PLAYER_STRONGHOLD)


func screen_to_map_position(screen_position: Vector2) -> Vector2:
	return IsoProjection.unproject((screen_position - camera_offset) / camera_scale)


func set_fog_enabled(value: bool) -> void:
	if fog_enabled == value:
		return
	fog_enabled = value
	fog_visibility_changed.emit()
	queue_redraw()


func is_cell_visible(cell: Vector2i) -> bool:
	return not fog_enabled or _visible_cells.has(cell)


func is_cell_explored(cell: Vector2i) -> bool:
	return not fog_enabled or _explored_cells.has(cell)


func should_render_entity(entity_state: Dictionary) -> bool:
	if not bool(entity_state.get("alive", false)):
		return false
	var team := int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL))
	if team == RtsSimulation.TEAM_PLAYER or not fog_enabled:
		return true
	var cell := _entity_center_cell(entity_state)
	if team == RtsSimulation.TEAM_ENEMY:
		return is_cell_visible(cell)
	if entity_state.get("category") in [&"unit", &"wildlife"]:
		return is_cell_visible(cell)
	return is_cell_explored(cell)


func _process(delta: float) -> void:
	_water_animation_time += delta
	_wind_animation_time = fmod(_wind_animation_time + delta, TAU * 1000.0)
	_visibility_timer -= delta
	if simulation != null and _visibility_timer <= 0.0:
		_visibility_timer = VISIBILITY_REFRESH_SECONDS
		_refresh_visibility()
	var camera_direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if camera_direction.length_squared() > 0.0:
		camera_offset -= camera_direction * 1000.0 * delta
		_clamp_camera()
	for event in simulation.drain_events() if simulation != null else []:
		var effect := (event as Dictionary).duplicate(true)
		effect["remaining"] = 0.45 if effect.get("type") == &"attack" else 0.7
		effect["duration"] = effect["remaining"]
		_effects.append(effect)
	for index in range(_effects.size() - 1, -1, -1):
		_effects[index]["remaining"] = float(_effects[index]["remaining"]) - delta
		if float(_effects[index]["remaining"]) <= 0.0:
			_effects.remove_at(index)
	queue_redraw()


func _refresh_visibility() -> void:
	if simulation == null:
		return
	var next_visible := simulation.visible_cells_for_team(RtsSimulation.TEAM_PLAYER)
	var next_explored := simulation.explored_cells_for_team(RtsSimulation.TEAM_PLAYER)
	var changed := next_visible != _visible_cells or next_explored != _explored_cells
	_visible_cells = next_visible
	_explored_cells = next_explored
	if changed:
		fog_visibility_changed.emit()


func _entity_center_cell(entity_state: Dictionary) -> Vector2i:
	var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
	var center := (entity_state["position"] as Vector2) + (Vector2(footprint) - Vector2.ONE) * 0.5
	return Vector2i(center.floor())


func _gui_input(event: InputEvent) -> void:
	if simulation == null or not simulation.outcome.is_empty():
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_mouse_position = motion.position
		if _middle_dragging:
			camera_offset += motion.relative
			_clamp_camera()
			accept_event()
			return
		if _selection_pressed:
			_selection_current = motion.position
			_selection_dragging = _selection_current.distance_to(_selection_start) >= 6.0
			accept_event()
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		_mouse_position = magnify.position
		_zoom_at(magnify.position, clampf(magnify.factor, 0.5, 2.0))
		accept_event()
		return
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		_mouse_position = button.position
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_dragging = button.pressed
			accept_event()
			return
		if (
			button.pressed
			and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
			and (button.meta_pressed or button.ctrl_pressed)
		):
			var scroll_amount := button.factor if button.factor > 0.0 else 1.0
			var zoom_factor := pow(WHEEL_ZOOM_STEP, clampf(scroll_amount, 0.25, 4.0))
			_zoom_at(button.position, zoom_factor if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / zoom_factor)
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_handle_left_press(button.position, button.shift_pressed)
			else:
				_handle_left_release(button.position)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			_handle_right_click(button.position, button.shift_pressed)
			accept_event()


func _handle_left_press(screen_position: Vector2, append: bool = false) -> void:
	if placement_worker_id >= 0:
		var cell := screen_to_cell(screen_position)
		var stats := FactionCatalog.stats(
			placement_kind,
			simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName,
		)
		var structure_name := String(stats.get("name", "Structure"))
		if simulation.command_build(placement_worker_id, placement_kind, cell):
			feedback.emit("%s foundation placed." % structure_name, false)
			placement_worker_id = -1
			placement_kind = &""
		else:
			feedback.emit("That site cannot host a %s." % structure_name, true)
		return
	if repair_armed:
		var repair_target_id := entity_at_screen(screen_position, false)
		var workers := _selected_of_kind(&"worker")
		if repair_target_id >= 0 and simulation.command_repair(
			workers,
			repair_target_id,
			append or _armed_append,
		):
			feedback.emit("Repair order queued." if append or _armed_append else "Repair order issued.", false)
		else:
			feedback.emit("Choose a damaged allied structure to repair.", true)
		repair_armed = false
		_armed_append = false
		return
	if attack_move_armed:
		var cell := screen_to_cell(screen_position)
		var units := selected_commandable_units()
		if not units.is_empty() and MapCatalog.in_bounds(cell):
			simulation.command_move(units, cell, true, append or _armed_append)
			feedback.emit("Attack-move queued." if append or _armed_append else "Attack-move order issued.", false)
		attack_move_armed = false
		_armed_append = false
		return
	if patrol_armed:
		var patrol_cell := screen_to_cell(screen_position)
		if simulation.command_patrol(
			selected_military_units(),
			patrol_cell,
			append or _armed_append,
		):
			feedback.emit("Patrol queued." if append or _armed_append else "Patrol route established.", false)
		else:
			feedback.emit("Choose a valid patrol destination.", true)
		patrol_armed = false
		_armed_append = false
		return
	_selection_pressed = true
	_selection_dragging = false
	_selection_additive = append
	_selection_start = screen_position
	_selection_current = screen_position


func _handle_left_release(screen_position: Vector2) -> void:
	if not _selection_pressed:
		return
	_selection_pressed = false
	_selection_current = screen_position
	if _selection_dragging:
		_select_in_rect(
			Rect2(_selection_start, _selection_current - _selection_start).abs(),
			_selection_additive,
		)
	else:
		var hit := entity_at_screen(screen_position, true)
		var hit_ids: Array[int] = []
		if _selection_additive:
			hit_ids.assign(selected_ids)
		if hit >= 0 and _selection_additive and hit_ids.has(hit):
			hit_ids.erase(hit)
		elif hit >= 0:
			hit_ids.append(hit)
		select_entities(hit_ids)
	_selection_dragging = false
	_selection_additive = false


func _handle_right_click(screen_position: Vector2, append: bool = false) -> void:
	cancel_modes()
	if selected_ids.is_empty():
		return
	var target_id := entity_at_screen(screen_position, false)
	if target_id >= 0:
		var target := simulation.entity(target_id)
		var commandable_units := selected_commandable_units()
		if target.get("category") == &"wildlife":
			var hunters := _selected_of_kind(&"hunter")
			if hunters.is_empty():
				feedback.emit("Only Hunters can hunt wildlife.", true)
			else:
				simulation.command_attack(hunters, target_id, append)
				feedback.emit("Hunt queued." if append else "Hunters pursuing %s." % _display_name(target), false)
			return
		if target.get("kind") == &"yaoguai_den" and not commandable_units.is_empty():
			simulation.command_move(commandable_units, target["cell"] as Vector2i, true, append)
			feedback.emit("Den hunt queued." if append else "Hunt the guardians, then hold the Den's capture ring.", false)
			return
		if not commandable_units.is_empty() and simulation.are_hostile(simulation.entity(commandable_units[0]), target):
			simulation.command_attack(commandable_units, target_id, append)
			feedback.emit("Focus-fire queued." if append else "Focus-fire order issued.", false)
			return
		if target.get("kind") == &"stronghold":
			var workers := _selected_of_kind(&"worker")
			var carrying_workers: Array[int] = []
			for worker_id in workers:
				if float(simulation.entity(worker_id).get("cargo_amount", 0.0)) > 0.0:
					carrying_workers.append(worker_id)
			if not carrying_workers.is_empty():
				var deposited_workers := simulation.command_deposit(carrying_workers, target_id, append)
				if append:
					feedback.emit("Resource return queued.", false)
					return
				if deposited_workers == carrying_workers.size():
					feedback.emit("Workers deposited all carried resources.", false)
				elif deposited_workers > 0:
					feedback.emit("Nearby workers deposited; the rest are returning cargo.", false)
				else:
					feedback.emit("Workers returning cargo to the Stronghold.", false)
				return
		var repair_workers := _selected_of_kind(&"worker")
		if (
			not repair_workers.is_empty()
			and target.get("category") == &"structure"
			and int(target.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and float(target.get("hp", 0.0)) < float(target.get("max_hp", 0.0))
			and simulation.command_repair(repair_workers, target_id, append)
		):
			feedback.emit("Repair queued." if append else "Workers assigned to repairs.", false)
			return
		if target.get("category") == &"resource":
			var workers := _selected_of_kind(&"worker")
			if not workers.is_empty():
				simulation.command_gather(workers, target_id, append)
				feedback.emit(
					"%s gathering queued." % _display_name(target) if append
					else "Workers assigned to %s." % _display_name(target),
					false,
				)
				return
	var selected_structure := primary_selected_structure()
	var cell := screen_to_cell(screen_position)
	if selected_structure >= 0 and selected_commandable_units().is_empty():
		simulation.set_rally(selected_structure, cell)
		feedback.emit("Rally point updated.", false)
	else:
		simulation.command_move(selected_commandable_units(), cell, false, append)
		feedback.emit("Move queued." if append else "Move order issued.", false)


func _select_in_rect(rect: Rect2, additive: bool = false) -> void:
	var ids: Array[int] = selected_ids.duplicate() if additive else []
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)):
			continue
		if int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) != RtsSimulation.TEAM_PLAYER:
			continue
		if entity_state.get("category") != &"unit":
			continue
		if rect.has_point(entity_screen_position(entity_state)) and not ids.has(int(entity_state["id"])):
			ids.append(int(entity_state["id"]))
	select_entities(ids)


func select_entities(ids: Array[int]) -> void:
	selected_ids.clear()
	for id in ids:
		var entity_state := simulation.entity(id)
		if (
			not entity_state.is_empty()
			and bool(entity_state.get("alive", false))
			and not selected_ids.has(id)
		):
			selected_ids.append(id)
	selection_changed.emit(selected_ids.duplicate())
	queue_redraw()


func select_all_workers() -> void:
	select_entities(simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"]))


func select_all_army() -> void:
	select_entities(simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"vanguard", &"mystic", &"jadeclaw"]))


func select_player_stronghold() -> void:
	var id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	if id >= 0:
		select_entities([id])
		center_on_player_stronghold()


func assign_control_group(index: int, append: bool = false) -> void:
	if index < 0 or index > 9:
		return
	var members := _valid_control_group_members(control_groups.get(index, []) as Array)
	if not append:
		members.clear()
	for id in selected_ids:
		var entity_state := simulation.entity(id)
		if (
			bool(entity_state.get("alive", false))
			and int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and entity_state.get("category") in [&"unit", &"structure"]
			and not members.has(id)
		):
			members.append(id)
	control_groups[index] = members
	feedback.emit(
		"Group %d updated · %d selected." % [index, members.size()]
		if append
		else "Group %d assigned · %d selected." % [index, members.size()],
		false,
	)


func recall_control_group(index: int, additive: bool = false) -> void:
	if index < 0 or index > 9:
		return
	var members := _valid_control_group_members(control_groups.get(index, []) as Array)
	control_groups[index] = members
	if members.is_empty():
		if not additive:
			select_entities([])
		feedback.emit("Control group %d is empty." % index, true)
		return
	var next_selection: Array[int] = []
	if additive:
		next_selection.assign(selected_ids)
	for id in members:
		if not next_selection.has(id):
			next_selection.append(id)
	var now := Time.get_ticks_msec()
	var should_center := (
		not additive
		and _last_control_group == index
		and now - _last_control_group_recall_ms <= CONTROL_GROUP_DOUBLE_TAP_MS
	)
	select_entities(next_selection)
	if should_center:
		center_on_selection()
	_last_control_group = index
	_last_control_group_recall_ms = now


func center_on_selection() -> void:
	if selected_ids.is_empty():
		return
	var center := Vector2.ZERO
	var count := 0
	for id in selected_ids:
		var entity_state := simulation.entity(id)
		if not entity_state.is_empty() and bool(entity_state.get("alive", false)):
			center += simulation.entity_center(id)
			count += 1
	if count > 0:
		center_on_cell(Vector2i((center / float(count)).round()))


func _valid_control_group_members(raw_members: Array) -> Array[int]:
	var result: Array[int] = []
	for raw_id in raw_members:
		var id := int(raw_id)
		var entity_state := simulation.entity(id)
		if (
			bool(entity_state.get("alive", false))
			and int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and entity_state.get("category") in [&"unit", &"structure"]
			and not result.has(id)
		):
			result.append(id)
	return result


func begin_attack_move(append: bool = false) -> void:
	if selected_commandable_units().is_empty():
		feedback.emit("Select units before issuing attack-move.", true)
		return
	cancel_modes()
	attack_move_armed = true
	_armed_append = append
	feedback.emit("Queued attack-move: choose a destination." if append else "Attack-move armed: choose a destination.", false)


func begin_patrol(append: bool = false) -> void:
	if selected_military_units().is_empty():
		feedback.emit("Select military units before setting a patrol.", true)
		return
	cancel_modes()
	patrol_armed = true
	_armed_append = append
	feedback.emit("Queued patrol: choose a destination." if append else "Patrol armed: choose a destination.", false)


func begin_repair(append: bool = false) -> void:
	if _selected_of_kind(&"worker").is_empty():
		feedback.emit("Select workers before issuing a repair order.", true)
		return
	cancel_modes()
	repair_armed = true
	_armed_append = append
	feedback.emit("Queued repair: choose a structure." if append else "Repair armed: choose a damaged allied structure.", false)


func begin_war_camp_placement() -> void:
	begin_structure_placement(&"war_camp")


func begin_structure_placement(structure_kind: StringName) -> void:
	var workers := _selected_of_kind(&"worker")
	if workers.is_empty():
		feedback.emit("Select a worker before choosing a build command.", true)
		return
	if structure_kind not in RtsSimulation.BUILDABLE_STRUCTURE_KINDS:
		feedback.emit("That structure is not available for construction.", true)
		return
	if not simulation.is_kind_available(RtsSimulation.TEAM_PLAYER, structure_kind):
		feedback.emit("Your faction cannot construct that food building.", true)
		return
	cancel_modes()
	placement_worker_id = workers[0]
	placement_kind = structure_kind
	var faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
	var structure_name := String(FactionCatalog.stats(structure_kind, faction)["name"])
	feedback.emit("Choose a clear meadow footprint for the %s." % structure_name, false)


func cancel_modes() -> void:
	attack_move_armed = false
	patrol_armed = false
	repair_armed = false
	placement_worker_id = -1
	placement_kind = &""
	_armed_append = false


func selected_commandable_units() -> Array[int]:
	var result: Array[int] = []
	for id in selected_ids:
		var entity_state := simulation.entity(id)
		if entity_state.get("category") == &"unit" and int(entity_state.get("team", -1)) == RtsSimulation.TEAM_PLAYER:
			result.append(id)
	return result


func selected_military_units() -> Array[int]:
	var result: Array[int] = []
	for id in selected_ids:
		var entity_state := simulation.entity(id)
		if (
			entity_state.get("kind") in [&"vanguard", &"mystic", &"jadeclaw"]
			and int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
		):
			result.append(id)
	return result


func primary_selected_structure() -> int:
	for id in selected_ids:
		var entity_state := simulation.entity(id)
		if entity_state.get("category") == &"structure" and int(entity_state.get("team", -1)) == RtsSimulation.TEAM_PLAYER:
			return id
	return -1


func _selected_of_kind(kind: StringName) -> Array[int]:
	var result: Array[int] = []
	for id in selected_ids:
		var entity_state := simulation.entity(id)
		if entity_state.get("kind") == kind and int(entity_state.get("team", -1)) == RtsSimulation.TEAM_PLAYER:
			result.append(id)
	return result


func screen_to_cell(screen_position: Vector2) -> Vector2i:
	return IsoProjection.cell_at((screen_position - camera_offset) / camera_scale)


func entity_screen_position(entity_state: Dictionary) -> Vector2:
	var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
	var center := entity_state["position"] as Vector2 + (Vector2(footprint) - Vector2.ONE) * 0.5
	return camera_offset + IsoProjection.position_center(center) * camera_scale


func entity_at_screen(screen_position: Vector2, selectable_only: bool) -> int:
	var best_id := -1
	var best_distance := INF
	var best_priority := -1
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)):
			continue
		if not should_render_entity(entity_state):
			continue
		if (
			selectable_only
			and int(entity_state.get("team", -1)) != RtsSimulation.TEAM_PLAYER
			and entity_state.get("kind") != &"yaoguai_den"
			and entity_state.get("category") != &"wildlife"
		):
			continue
		var radius := 28.0 * camera_scale
		var priority := 3
		match entity_state.get("category"):
			&"structure":
				radius = (88.0 if entity_state.get("kind") == &"yaoguai_den" else 66.0) * camera_scale
				priority = 1
			&"resource":
				radius = 40.0 * camera_scale
				priority = 0
			&"wildlife":
				radius = 38.0 * camera_scale
				priority = 2
		var distance := entity_screen_position(entity_state).distance_to(screen_position)
		if distance <= maxf(radius, 16.0) and (priority > best_priority or (priority == best_priority and distance < best_distance)):
			best_priority = priority
			best_distance = distance
			best_id = int(entity_state["id"])
	return best_id


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var world_point := (screen_position - camera_offset) / camera_scale
	camera_scale = clampf(camera_scale * factor, MIN_CAMERA_SCALE, MAX_CAMERA_SCALE)
	camera_offset = screen_position - world_point * camera_scale
	_clamp_camera()


func _clamp_camera() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var bounds := IsoProjection.map_bounds(MapCatalog.SIZE)
	var scaled := Rect2(camera_offset + bounds.position * camera_scale, bounds.size * camera_scale)
	var margin := Vector2(150.0, 120.0)
	if scaled.end.x < margin.x:
		camera_offset.x += margin.x - scaled.end.x
	if scaled.position.x > size.x - margin.x:
		camera_offset.x -= scaled.position.x - (size.x - margin.x)
	if scaled.end.y < margin.y:
		camera_offset.y += margin.y - scaled.end.y
	if scaled.position.y > size.y - margin.y:
		camera_offset.y -= scaled.position.y - (size.y - margin.y)


func _draw() -> void:
	if simulation == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("071416"))
	_draw_terrain()
	_draw_hover_feedback()
	_draw_entities()
	_draw_effects()
	_draw_fog_of_war()
	if _selection_pressed and _selection_dragging:
		var rect := Rect2(_selection_start, _selection_current - _selection_start).abs()
		draw_rect(rect, Color(0.32, 0.93, 0.72, 0.12), true)
		draw_rect(rect, PLAYER_COLOR, false, 1.5)


func _draw_terrain() -> void:
	for depth in range(MapCatalog.SIZE.x + MapCatalog.SIZE.y - 1):
		for y in range(MapCatalog.SIZE.y):
			var x := depth - y
			if x < 0 or x >= MapCatalog.SIZE.x:
				continue
			var cell := Vector2i(x, y)
			if not _is_cell_on_screen(cell):
				continue
			var terrain := MapCatalog.terrain_at(cell)
			var points := IsoProjection.transformed_polygon(cell, camera_scale, camera_offset)
			var texture := TERRAIN_TEXTURES.get(terrain) as Texture2D
			var tint := Color.WHITE
			if terrain == &"ridge":
				tint = Color(0.82, 0.87, 0.85, 1.0)
			elif terrain == &"water":
				var current := sin(float(x + y) * 0.72 - _water_animation_time * 2.0)
				var brightness := 0.96 + current * 0.035
				tint = Color(0.74 * brightness, 0.96 * brightness, brightness, 0.95)
			elif terrain == &"forest":
				tint = Color(0.82, 0.94, 0.83, 1.0)
			elif terrain == &"road":
				tint = Color(1.0, 0.97, 0.86, 1.0)
			elif terrain == &"bridge":
				tint = Color(0.95, 1.0, 0.96, 1.0)
			else:
				var variation := 0.92 + float(posmod(x * 17 + y * 29, 7)) * 0.018
				tint = Color(variation, variation, variation * 0.98, 1.0)
			var colors := PackedColorArray([tint, tint, tint, tint])
			var uv_offset := WATER_FLOW_SPEED * _water_animation_time if terrain == &"water" else Vector2.ZERO
			var uvs := _terrain_uvs(cell, uv_offset)
			draw_polygon(points, colors, uvs, texture)
			var closed := points.duplicate()
			closed.append(points[0])
			draw_polyline(closed, GRID_COLOR, GRID_LINE_WIDTH, true)


func _terrain_uvs(cell: Vector2i, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var origin := Vector2(cell) * WATER_UV_SCALE + offset
	var extent := Vector2.ONE * WATER_UV_SCALE
	return PackedVector2Array([
		origin,
		origin + Vector2(extent.x, 0.0),
		origin + extent,
		origin + Vector2(0.0, extent.y),
	])

func _is_cell_on_screen(cell: Vector2i) -> bool:
	var center := camera_offset + IsoProjection.cell_center(cell) * camera_scale
	var half_size := Vector2(IsoProjection.TILE_WIDTH, IsoProjection.TILE_HEIGHT) * camera_scale * 0.5
	return (
		center.x + half_size.x >= 0.0
		and center.x - half_size.x <= size.x
		and center.y + half_size.y >= 0.0
		and center.y - half_size.y <= size.y
	)


func _draw_hover_feedback() -> void:
	var cell := screen_to_cell(_mouse_position)
	if not MapCatalog.in_bounds(cell):
		return
	var points := IsoProjection.transformed_polygon(cell, camera_scale, camera_offset)
	var closed := points.duplicate()
	closed.append(points[0])
	if placement_worker_id >= 0:
		var valid := simulation.can_place_structure(RtsSimulation.TEAM_PLAYER, placement_kind, cell)
		var color := PLAYER_COLOR if valid else ENEMY_COLOR
		var faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
		var stats := FactionCatalog.stats(placement_kind, faction)
		var footprint := stats.get("footprint", Vector2i.ONE) as Vector2i
		for footprint_cell in MapCatalog.footprint_cells(cell, footprint):
			var footprint_points := IsoProjection.transformed_polygon(footprint_cell, camera_scale, camera_offset)
			var footprint_closed := footprint_points.duplicate()
			footprint_closed.append(footprint_points[0])
			draw_colored_polygon(footprint_points, Color(color, 0.24))
			draw_polyline(footprint_closed, color, 2.5, true)
		var texture := _entity_texture(faction, placement_kind)
		var center_position := Vector2(cell) + (Vector2(footprint) - Vector2.ONE) * 0.5
		var center := camera_offset + IsoProjection.position_center(center_position) * camera_scale
		_draw_world_texture(
			texture,
			center,
			_structure_display_size(placement_kind) * 0.78 * camera_scale,
			Color(1, 1, 1, 0.58 if valid else 0.35),
		)
	elif repair_armed:
		draw_colored_polygon(points, Color(Color("e4c66d"), 0.14))
		draw_polyline(closed, Color("e4c66d"), 2.0, true)
	elif patrol_armed:
		draw_colored_polygon(points, Color(Color("79c9ee"), 0.12))
		draw_polyline(closed, Color("79c9ee"), 2.0, true)
	elif attack_move_armed:
		draw_colored_polygon(points, Color(ENEMY_COLOR, 0.12))
		draw_polyline(closed, ENEMY_COLOR, 2.0, true)
	else:
		draw_polyline(closed, Color(PLAYER_COLOR, 0.52), 1.4, true)


func _draw_entities() -> void:
	var renderables: Array[Dictionary] = []
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if should_render_entity(entity_state) and _is_entity_on_screen(entity_state):
			renderables.append(entity_state)
	renderables.sort_custom(
		_entity_draws_before
	)
	for entity_state in renderables:
		_draw_entity(entity_state)
	for entity_state in renderables:
		if entity_state.get("kind") == &"worker" and entity_state.get("order", &"idle") == &"idle":
			_draw_idle_worker_marker(entity_screen_position(entity_state))


func _is_entity_on_screen(entity_state: Dictionary) -> bool:
	var center := entity_screen_position(entity_state)
	var margin := 280.0 * camera_scale + 24.0
	return Rect2(
		Vector2(-margin, -margin),
		size + Vector2.ONE * margin * 2.0,
	).has_point(center)


func _entity_draws_before(first: Dictionary, second: Dictionary) -> bool:
	var first_position := first["position"] as Vector2
	var second_position := second["position"] as Vector2
	var first_depth := IsoProjection.depth(first_position)
	var second_depth := IsoProjection.depth(second_position)
	if first_depth != second_depth:
		return first_depth < second_depth
	if first_position.x != second_position.x:
		return first_position.x < second_position.x
	if first_position.y != second_position.y:
		return first_position.y < second_position.y
	return int(first.get("id", -1)) < int(second.get("id", -1))


func _draw_entity(entity_state: Dictionary) -> void:
	var center := entity_screen_position(entity_state)
	var category := entity_state.get("category") as StringName
	var kind := entity_state.get("kind") as StringName
	var selected := selected_ids.has(int(entity_state["id"]))
	var tint := Color.WHITE
	if int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_ENEMY:
		tint = Color(1.0, 0.9, 0.88, 1.0)
	if float(entity_state.get("flash_timer", 0.0)) > 0.0:
		tint = Color(1.0, 0.42, 0.32, 1.0)
	if float(entity_state.get("complete", 1.0)) < 1.0:
		tint.a = 0.55 + float(entity_state["complete"]) * 0.45
	if kind in [&"jadeclaw", &"yaoguai_den", &"rice_farm", &"hunters_lodge"]:
		var allegiance := _team_color(int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)))
		var allegiance_radius_x := 35.0 if kind == &"jadeclaw" else (78.0 if kind in [&"yaoguai_den", &"rice_farm"] else 58.0)
		var allegiance_radius_y := 16.0 if kind == &"jadeclaw" else (34.0 if kind in [&"yaoguai_den", &"rice_farm"] else 26.0)
		_draw_ellipse(
			center + Vector2(0.0, 4.0 * camera_scale),
			allegiance_radius_x * camera_scale,
			allegiance_radius_y * camera_scale,
			Color(allegiance, 0.78),
			2.2,
		)

	if selected:
		var radius_x := 34.0 if kind == &"jadeclaw" else (32.0 if category == &"wildlife" else 27.0 if category == &"unit" else 76.0 if kind == &"yaoguai_den" else 54.0)
		var radius_y := 16.0 if kind == &"jadeclaw" else (15.0 if category == &"wildlife" else 13.0 if category == &"unit" else 34.0 if kind == &"yaoguai_den" else 25.0)
		_draw_ellipse(center + Vector2(0.0, 3.0 * camera_scale), radius_x * camera_scale, radius_y * camera_scale, Color("fff0a0"), 2.4)

	if category == &"resource":
		var texture := RESOURCE_TEXTURES.get(kind) as Texture2D
		var is_tree: bool = entity_state.get("resource_kind") == &"lumber"
		var resource_size := Vector2(136.0, 164.0) if is_tree else Vector2(98.0, 88.0)
		if is_tree:
			_draw_tree_texture(texture, center, resource_size * camera_scale, tint, entity_state)
		else:
			_draw_world_texture(texture, center, resource_size * camera_scale, tint)
		_draw_resource_bar(entity_state, center)
	else:
		var texture := _entity_texture(entity_state["faction"] as StringName, kind)
		var display_size := Vector2(94.0, 104.0) if category == &"unit" else (_wildlife_display_size(kind) if category == &"wildlife" else _structure_display_size(kind))
		if kind == &"jadeclaw":
			display_size = Vector2(124.0, 112.0)
		elif kind == &"yaoguai_den":
			display_size = Vector2(250.0, 212.0)
		_draw_world_texture(texture, center, display_size * camera_scale, tint)
		if kind == &"yaoguai_den":
			_draw_cave_status(entity_state, center)
		else:
			_draw_health_bar(entity_state, center, category)
			if kind in RtsSimulation.FOOD_PRODUCER_KINDS and float(entity_state.get("complete", 0.0)) >= 1.0:
				_draw_food_progress(entity_state, center)

	if kind == &"worker" and float(entity_state.get("cargo_amount", 0.0)) > 0.0:
		var cargo_color := _resource_color(entity_state.get("cargo_kind", &"") as StringName)
		draw_circle(center + Vector2(23.0, -40.0) * camera_scale, maxf(3.0, 5.0 * camera_scale), cargo_color)


func _draw_world_texture(texture: Texture2D, center: Vector2, display_size: Vector2, tint: Color) -> void:
	if texture == null:
		return
	var rect := Rect2(
		Vector2(center.x - display_size.x * 0.5, center.y - display_size.y + 10.0 * camera_scale),
		display_size,
	)
	draw_texture_rect(texture, rect, false, tint)


func _structure_display_size(kind: StringName) -> Vector2:
	match kind:
		&"rice_farm":
			return Vector2(236.0, 188.0)
		&"hunters_lodge":
			return Vector2(190.0, 164.0)
		_:
			return Vector2(182.0, 152.0)


func _wildlife_display_size(kind: StringName) -> Vector2:
	match kind:
		&"chicken":
			return Vector2(48.0, 48.0)
		&"deer":
			return Vector2(90.0, 76.0)
		&"bison":
			return Vector2(120.0, 92.0)
		&"boar":
			return Vector2(92.0, 70.0)
		_:
			return Vector2(116.0, 92.0)


func _draw_tree_texture(
	texture: Texture2D,
	center: Vector2,
	display_size: Vector2,
	tint: Color,
	entity_state: Dictionary,
) -> void:
	if texture == null:
		return
	if camera_scale < TREE_SWAY_MIN_SCALE:
		_draw_world_texture(texture, center, display_size, tint)
		return
	var top_left := Vector2(center.x - display_size.x * 0.5, center.y - display_size.y + 10.0 * camera_scale)
	var phase := _tree_wind_phase(entity_state)
	var colors := PackedColorArray([tint, tint, tint, tint])
	for band in range(TREE_SWAY_BANDS):
		var top_ratio := float(band) / float(TREE_SWAY_BANDS)
		var bottom_ratio := float(band + 1) / float(TREE_SWAY_BANDS)
		var top_offset := _tree_sway_offset(top_ratio, phase, display_size)
		var bottom_offset := _tree_sway_offset(bottom_ratio, phase, display_size)
		var points := PackedVector2Array([
			top_left + Vector2(0.0, display_size.y * top_ratio) + top_offset,
			top_left + Vector2(display_size.x, display_size.y * top_ratio) + top_offset,
			top_left + Vector2(display_size.x, display_size.y * bottom_ratio) + bottom_offset,
			top_left + Vector2(0.0, display_size.y * bottom_ratio) + bottom_offset,
		])
		var uvs := PackedVector2Array([
			Vector2(0.0, top_ratio),
			Vector2(1.0, top_ratio),
			Vector2(1.0, bottom_ratio),
			Vector2(0.0, bottom_ratio),
		])
		draw_polygon(points, colors, uvs, texture)


func _tree_wind_phase(entity_state: Dictionary) -> float:
	var position := entity_state.get("position", Vector2.ZERO) as Vector2
	var seed := float(int(entity_state.get("id", 0))) * 0.6180339 + position.x * 1.731 + position.y * 2.417
	return fposmod(seed, TAU)


func _tree_sway_offset(height_ratio: float, phase: float, display_size: Vector2) -> Vector2:
	var flex := clampf((TREE_SWAY_ANCHOR - height_ratio) / TREE_SWAY_ANCHOR, 0.0, 1.0)
	if flex <= 0.0:
		return Vector2.ZERO
	flex = pow(flex, 1.55)
	var shared_breeze := sin(_wind_animation_time * 0.92) * 0.68
	shared_breeze += sin(_wind_animation_time * 1.73 + 1.2) * 0.20
	var local_rustle := sin(_wind_animation_time * 2.35 + phase + height_ratio * 5.0) * 0.12
	var gust := 0.82 + sin(_wind_animation_time * 0.27 + 0.45) * 0.18
	var sway := (shared_breeze * gust + local_rustle) * flex
	return Vector2(
		sway * display_size.x * TREE_SWAY_STRENGTH,
		-absf(sway) * display_size.y * TREE_SWAY_STRENGTH * 0.08,
	)


func _draw_idle_worker_marker(center: Vector2) -> void:
	var display_size := Vector2(40.0, 44.0) * camera_scale
	var position := Vector2(center.x - display_size.x * 0.5, center.y - 142.0 * camera_scale)
	draw_texture_rect(IDLE_WORKER_ALERT_TEXTURE, Rect2(position, display_size), false)


func _draw_health_bar(entity_state: Dictionary, center: Vector2, category: StringName) -> void:
	var ratio := clampf(float(entity_state["hp"]) / float(entity_state["max_hp"]), 0.0, 1.0)
	if ratio >= 0.999 and not selected_ids.has(int(entity_state["id"])):
		return
	var width := (52.0 if category == &"wildlife" else 46.0 if category == &"unit" else 86.0) * camera_scale
	var y_offset := (-67.0 if category == &"wildlife" else -77.0 if category == &"unit" else -137.0) * camera_scale
	var rect := Rect2(center + Vector2(-width * 0.5, y_offset), Vector2(width, maxf(4.0, 6.0 * camera_scale)))
	draw_rect(rect, Color(0.02, 0.03, 0.03, 0.9), true)
	var health_color := _team_color(int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)))
	draw_rect(Rect2(rect.position + Vector2.ONE, Vector2((rect.size.x - 2.0) * ratio, rect.size.y - 2.0)), health_color, true)


func _draw_cave_status(cave: Dictionary, center: Vector2) -> void:
	var guardian_count := simulation.cave_guardian_count(int(cave["id"]))
	if guardian_count > 0:
		var pip_y := center.y - 176.0 * camera_scale
		for index in range(guardian_count):
			draw_circle(
				Vector2(center.x + (float(index) - float(guardian_count - 1) * 0.5) * 13.0 * camera_scale, pip_y),
				maxf(2.5, 4.5 * camera_scale),
				NEUTRAL_COLOR,
			)
		return
	var progress := float(cave.get("capture_progress", 0.0))
	if progress <= 0.0:
		return
	var width := 92.0 * camera_scale
	var rect := Rect2(center + Vector2(-width * 0.5, -171.0 * camera_scale), Vector2(width, maxf(5.0, 7.0 * camera_scale)))
	draw_rect(rect, Color(0.02, 0.03, 0.03, 0.9), true)
	var progress_color := _team_color(int(cave.get("capture_team", RtsSimulation.TEAM_NEUTRAL)))
	if bool(cave.get("capture_contested", false)):
		progress_color = Color("fff0a0")
	var ratio := clampf(progress / RtsSimulation.CAVE_CAPTURE_SECONDS, 0.0, 1.0)
	draw_rect(Rect2(rect.position + Vector2.ONE, Vector2((rect.size.x - 2.0) * ratio, rect.size.y - 2.0)), progress_color, true)


func _draw_resource_bar(entity_state: Dictionary, center: Vector2) -> void:
	var ratio := clampf(float(entity_state["amount"]) / float(entity_state["max_amount"]), 0.0, 1.0)
	var is_tree: bool = entity_state.get("resource_kind") == &"lumber"
	if is_tree and ratio >= 0.999:
		return
	var width := 52.0 * camera_scale
	var y_offset := -145.0 if is_tree else -75.0
	var rect := Rect2(center + Vector2(-width * 0.5, y_offset * camera_scale), Vector2(width, maxf(3.0, 5.0 * camera_scale)))
	draw_rect(rect, Color(0.02, 0.03, 0.03, 0.8), true)
	var resource_color := _resource_color(entity_state.get("resource_kind", &"") as StringName)
	draw_rect(Rect2(rect.position + Vector2.ONE, Vector2((rect.size.x - 2.0) * ratio, maxf(1.0, rect.size.y - 2.0))), resource_color, true)


func _draw_food_progress(structure: Dictionary, center: Vector2) -> void:
	var stats := FactionCatalog.stats(structure["kind"] as StringName, structure["faction"] as StringName)
	var interval := float(stats.get("food_interval", 1.0))
	var ratio := clampf(float(structure.get("food_timer", 0.0)) / interval, 0.0, 1.0)
	var width := (96.0 if structure.get("kind") == &"rice_farm" else 76.0) * camera_scale
	var rect := Rect2(center + Vector2(-width * 0.5, -123.0 * camera_scale), Vector2(width, maxf(3.0, 5.0 * camera_scale)))
	draw_rect(rect, Color(0.02, 0.03, 0.03, 0.82), true)
	draw_rect(Rect2(rect.position + Vector2.ONE, Vector2((rect.size.x - 2.0) * ratio, maxf(1.0, rect.size.y - 2.0))), FOOD_RESOURCE_COLOR, true)


func _resource_color(resource_kind: StringName) -> Color:
	match resource_kind:
		&"jade":
			return JADE_RESOURCE_COLOR
		&"lumber":
			return LUMBER_RESOURCE_COLOR
		&"food":
			return FOOD_RESOURCE_COLOR
		_:
			return ESSENCE_RESOURCE_COLOR


func _draw_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(33):
		var angle := float(index) / 32.0 * TAU
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)


func _draw_fog_of_war() -> void:
	if not fog_enabled:
		return
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			if not _is_cell_on_screen(cell):
				continue
			if _visible_cells.has(cell):
				continue
			var color := EXPLORED_FOG_COLOR if _explored_cells.has(cell) else UNEXPLORED_FOG_COLOR
			var points := IsoProjection.transformed_polygon(cell, camera_scale, camera_offset)
			draw_colored_polygon(points, color)


func _draw_effects() -> void:
	for effect in _effects:
		var ratio := clampf(float(effect["remaining"]) / float(effect["duration"]), 0.0, 1.0)
		var color := effect.get("color", Color.WHITE) as Color
		color.a = ratio
		if effect.get("type") == &"attack":
			var from := camera_offset + IsoProjection.position_center(effect["from"] as Vector2) * camera_scale
			var to := camera_offset + IsoProjection.position_center(effect["to"] as Vector2) * camera_scale
			draw_line(from + Vector2(0, -30) * camera_scale, to + Vector2(0, -24) * camera_scale, color, maxf(1.5, 3.0 * camera_scale), true)
		else:
			var effect_position := camera_offset + IsoProjection.position_center(effect["position"] as Vector2) * camera_scale
			draw_circle(effect_position, (14.0 + (1.0 - ratio) * 24.0) * camera_scale, Color(color, 0.08), true)
			draw_arc(effect_position, (14.0 + (1.0 - ratio) * 24.0) * camera_scale, 0.0, TAU, 28, color, 2.0, true)


func _entity_texture(faction: StringName, kind: StringName) -> Texture2D:
	var key := "%s:%s" % [faction, kind]
	if not _texture_cache.has(key):
		_texture_cache[key] = load(FactionCatalog.entity_art_path(faction, kind)) as Texture2D
	return _texture_cache[key] as Texture2D


func _team_color(team: int) -> Color:
	if team == RtsSimulation.TEAM_PLAYER:
		return PLAYER_COLOR
	if team == RtsSimulation.TEAM_ENEMY:
		return ENEMY_COLOR
	return NEUTRAL_COLOR


func _display_name(entity_state: Dictionary) -> String:
	if entity_state.get("category") == &"resource":
		match entity_state.get("resource_kind"):
			&"jade":
				return "Jade outcrop"
			&"lumber":
				return "Lumber tree"
			_:
				return "Essence shrine"
	return String(FactionCatalog.stats(entity_state["kind"] as StringName, entity_state["faction"] as StringName)["name"])
