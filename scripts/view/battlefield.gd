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
const COMMAND_INDICATOR_TEXTURES := {
	&"flag": preload("res://assets/runtime/command_indicators/destination_flag.png"),
	&"interact": preload("res://assets/runtime/command_indicators/interaction_ring.png"),
	&"attack": preload("res://assets/runtime/command_indicators/attack_swords.png"),
}
const IDLE_WORKER_ALERT_TEXTURE := preload("res://assets/runtime/ui/idle_worker_alert.png")
const PLAYER_COLOR := Color("78dfb7")
const ENEMY_COLOR := Color("f06656")
const NEUTRAL_COLOR := Color("d7bd6c")
const GRID_COLOR := Color(0.06, 0.16, 0.15, 0.24)
const GRID_LINE_WIDTH := 0.65
const GRID_MIN_SCALE := 0.25
const JADE_RESOURCE_COLOR := Color("73dfab")
const LUMBER_RESOURCE_COLOR := Color("d5a85d")
const ESSENCE_RESOURCE_COLOR := Color("77c6ff")
const FOOD_RESOURCE_COLOR := Color("f2c85b")
const EXPLORED_FOG_COLOR := Color(0.015, 0.055, 0.06, 0.58)
const UNEXPLORED_FOG_COLOR := Color(0.005, 0.018, 0.022, 0.97)
const VISIBILITY_REFRESH_SECONDS := 0.1
const WATER_UV_SCALE := 0.33
const WATER_FLOW_SPEED := Vector2(-0.045, -0.045)
const TREE_SWAY_ANCHOR := 0.72
const TREE_SWAY_STRENGTH := 0.052
const TREE_SWAY_MIN_SCALE := 0.28
const TREE_ENTITY_MIN_SCALE := 0.25
const WALK_BOUNCE_HEIGHT := 4.5
const WALK_BOUNCE_SPEED := 8.5
const WALK_MOTION_MEMORY_SECONDS := 0.16
const WALK_MOTION_EPSILON_SQUARED := 0.000001
const WALK_FACING_EPSILON := 0.01
const MAX_VISIBLE_COMMAND_PATHS := 10
const COMMAND_PATH_DOT_SPACING := 16.0
const COMMAND_PATH_DOT_RADIUS := 2.4
const COMMAND_PATH_POINT_EPSILON_SQUARED := 0.0001
const COMMAND_INTERACTION_ROTATION_SPEED := 1.75
const AMBIENT_REDRAW_SECONDS := 1.0 / 30.0
# Static source art is not uniformly oriented, so flipping has to account for
# each sprite's authored direction instead of assuming every image faces right.
const NATIVE_RIGHT_FACING_ART := {
	"beast:hunter": true,
	"beast:mystic": true,
	"beast:worker": true,
	"celestial:mystic": true,
	"celestial:vanguard": true,
	"celestial:worker": true,
	"demon:hunter": true,
	"demon:vanguard": true,
	"human:hunter": true,
	"human:mystic": true,
	"neutral:bear": true,
	"neutral:bison": true,
	"neutral:boar": true,
	"neutral:chicken": true,
	"neutral:deer": true,
}
const WHEEL_ZOOM_STEP := 1.12
const MIN_CAMERA_SCALE := 0.14
const MAX_CAMERA_SCALE := 1.05
const CONTROL_GROUP_DOUBLE_TAP_MS := 450

var simulation: RtsSimulation
var selected_ids: Array[int] = []
var move_armed := false
var attack_move_armed := false
var patrol_armed := false
var repair_armed := false
var rally_armed := false
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
var _cursor_state: StringName = &""
var _texture_cache: Dictionary = {}
var _effects: Array[Dictionary] = []
var _visible_cells: Dictionary = {}
var _explored_cells: Dictionary = {}
var _visibility_timer := 0.0
var _water_animation_time := 0.0
var _wind_animation_time := 0.0
var _walk_animation_time := 0.0
var _command_indicator_time := 0.0
var _ambient_redraw_timer := 0.0
var _movement_visuals: Dictionary = {}


func _ready() -> void:
	CursorSystem.install()
	CursorSystem.apply(self, CursorSystem.SELECT)
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
	_movement_visuals.clear()
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
	var available := Vector2(size.x - 56.0, size.y - 278.0)
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


func zoom_by(factor: float) -> void:
	_zoom_at(size * 0.5, factor)


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
	_prune_selected_ids()
	_water_animation_time += delta
	_wind_animation_time = fmod(_wind_animation_time + delta, TAU * 1000.0)
	_walk_animation_time = fmod(_walk_animation_time + delta, TAU * 1000.0)
	_command_indicator_time = fmod(_command_indicator_time + delta, TAU * 1000.0)
	_update_movement_visuals(delta)
	_visibility_timer -= delta
	if simulation != null and _visibility_timer <= 0.0:
		_visibility_timer = VISIBILITY_REFRESH_SECONDS
		_refresh_visibility()
	var camera_direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if camera_direction.length_squared() > 0.0:
		camera_offset -= camera_direction * 1000.0 * delta
		_clamp_camera()
		queue_redraw()
	for event in simulation.drain_events() if simulation != null else []:
		var effect := (event as Dictionary).duplicate(true)
		effect["remaining"] = 0.45 if effect.get("type") == &"attack" else 0.7
		effect["duration"] = effect["remaining"]
		_effects.append(effect)
	for index in range(_effects.size() - 1, -1, -1):
		_effects[index]["remaining"] = float(_effects[index]["remaining"]) - delta
		if float(_effects[index]["remaining"]) <= 0.0:
			_effects.remove_at(index)
	_refresh_cursor()
	_ambient_redraw_timer -= delta
	if _ambient_redraw_timer <= 0.0:
		_ambient_redraw_timer = AMBIENT_REDRAW_SECONDS
		queue_redraw()


func _prune_selected_ids() -> void:
	var next_ids: Array[int] = []
	for id in selected_ids:
		var entity_state := simulation.entity(id) if simulation != null else {}
		if not entity_state.is_empty() and bool(entity_state.get("alive", false)):
			next_ids.append(id)
	if next_ids == selected_ids:
		return
	selected_ids = next_ids
	selection_changed.emit(selected_ids.duplicate())
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
			_refresh_cursor()
			accept_event()
			return
		if _selection_pressed:
			_selection_current = motion.position
			_selection_dragging = _selection_current.distance_to(_selection_start) >= 6.0
			_refresh_cursor()
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
			_refresh_cursor()
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
			_refresh_cursor()
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			_handle_right_click(button.position, button.shift_pressed)
			_refresh_cursor()
			accept_event()


func _handle_left_press(screen_position: Vector2, append: bool = false) -> void:
	if placement_worker_id >= 0:
		var cell := screen_to_cell(screen_position)
		var stats := FactionCatalog.stats(
			placement_kind,
			simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName,
		)
		var structure_name := String(stats.get("name", "Structure"))
		if simulation.command_build(RtsSimulation.TEAM_PLAYER, placement_worker_id, placement_kind, cell):
			feedback.emit("%s foundation placed." % structure_name, false)
			placement_worker_id = -1
			placement_kind = &""
		else:
			feedback.emit("That site cannot host a %s." % structure_name, true)
		return
	if move_armed:
		var move_cell := screen_to_cell(screen_position)
		var move_units := selected_commandable_units()
		if not move_units.is_empty() and MapCatalog.in_bounds(move_cell):
			simulation.command_move(RtsSimulation.TEAM_PLAYER, move_units, move_cell, false, append or _armed_append)
			feedback.emit("Move queued." if append or _armed_append else "Move order issued.", false)
		else:
			feedback.emit("Choose a valid move destination.", true)
		move_armed = false
		_armed_append = false
		return
	if rally_armed:
		var rally_cell := screen_to_cell(screen_position)
		var rally_structure := primary_selected_structure()
		if rally_structure >= 0 and MapCatalog.in_bounds(rally_cell):
			simulation.set_rally(RtsSimulation.TEAM_PLAYER, rally_structure, rally_cell)
			feedback.emit("Rally point updated.", false)
		else:
			feedback.emit("Choose a valid rally destination.", true)
		rally_armed = false
		_armed_append = false
		return
	if repair_armed:
		var repair_target_id := entity_at_screen(screen_position, false)
		var workers := _selected_of_kind(&"worker")
		if repair_target_id >= 0 and simulation.command_repair(
			RtsSimulation.TEAM_PLAYER,
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
			simulation.command_move(RtsSimulation.TEAM_PLAYER, units, cell, true, append or _armed_append)
			feedback.emit("Attack-move queued." if append or _armed_append else "Attack-move order issued.", false)
		attack_move_armed = false
		_armed_append = false
		return
	if patrol_armed:
		var patrol_cell := screen_to_cell(screen_position)
		if simulation.command_patrol(
			RtsSimulation.TEAM_PLAYER,
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
				simulation.command_attack(RtsSimulation.TEAM_PLAYER, hunters, target_id, append)
				feedback.emit("Hunt queued." if append else "Hunters pursuing %s." % _display_name(target), false)
			return
		if target.get("kind") == &"yaoguai_den" and not commandable_units.is_empty():
			simulation.command_move(RtsSimulation.TEAM_PLAYER, commandable_units, target["cell"] as Vector2i, true, append)
			feedback.emit("Den hunt queued." if append else "Hunt the guardians, then hold the Den's capture ring.", false)
			return
		if not commandable_units.is_empty() and simulation.are_hostile(simulation.entity(commandable_units[0]), target):
			simulation.command_attack(RtsSimulation.TEAM_PLAYER, commandable_units, target_id, append)
			feedback.emit("Focus-fire queued." if append else "Focus-fire order issued.", false)
			return
		if target.get("kind") == &"stronghold":
			var workers := _selected_of_kind(&"worker")
			var carrying_workers: Array[int] = []
			for worker_id in workers:
				if float(simulation.entity(worker_id).get("cargo_amount", 0.0)) > 0.0:
					carrying_workers.append(worker_id)
			if not carrying_workers.is_empty():
				var deposited_workers := simulation.command_deposit(RtsSimulation.TEAM_PLAYER, carrying_workers, target_id, append)
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
			and simulation.command_repair(RtsSimulation.TEAM_PLAYER, repair_workers, target_id, append)
		):
			feedback.emit("Repair queued." if append else "Workers assigned to repairs.", false)
			return
		if target.get("category") == &"resource":
			var workers := _selected_of_kind(&"worker")
			if not workers.is_empty():
				simulation.command_gather(RtsSimulation.TEAM_PLAYER, workers, target_id, append)
				feedback.emit(
					"%s gathering queued." % _display_name(target) if append
					else "Workers assigned to %s." % _display_name(target),
					false,
				)
				return
	var selected_structure := primary_selected_structure()
	var cell := screen_to_cell(screen_position)
	if not MapCatalog.in_bounds(cell):
		feedback.emit("That destination is beyond the map boundary.", true)
		return
	if selected_structure >= 0 and selected_commandable_units().is_empty():
		if simulation.set_rally(RtsSimulation.TEAM_PLAYER, selected_structure, cell):
			feedback.emit("Rally point updated.", false)
	else:
		if simulation.command_move(RtsSimulation.TEAM_PLAYER, selected_commandable_units(), cell, false, append):
			feedback.emit("Move queued." if append else "Move order issued.", false)


func _select_in_rect(rect: Rect2, additive: bool = false) -> void:
	var ids: Array[int] = []
	if additive:
		ids.assign(selected_ids)
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
	_refresh_cursor()
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
	_refresh_cursor()
	feedback.emit("Queued attack-move: choose a destination." if append else "Attack-move armed: choose a destination.", false)


func begin_move(append: bool = false) -> void:
	if selected_commandable_units().is_empty():
		feedback.emit("Select units before issuing a move.", true)
		return
	cancel_modes()
	move_armed = true
	_armed_append = append
	feedback.emit("Queued move: choose a destination." if append else "Move armed: choose a destination.", false)


func begin_patrol(append: bool = false) -> void:
	if selected_military_units().is_empty():
		feedback.emit("Select military units before setting a patrol.", true)
		return
	cancel_modes()
	patrol_armed = true
	_armed_append = append
	_refresh_cursor()
	feedback.emit("Queued patrol: choose a destination." if append else "Patrol armed: choose a destination.", false)


func begin_repair(append: bool = false) -> void:
	if _selected_of_kind(&"worker").is_empty():
		feedback.emit("Select workers before issuing a repair order.", true)
		return
	cancel_modes()
	repair_armed = true
	_armed_append = append
	_refresh_cursor()
	feedback.emit("Queued repair: choose a structure." if append else "Repair armed: choose a damaged allied structure.", false)


func begin_rally() -> void:
	if primary_selected_structure() < 0:
		feedback.emit("Select an allied production structure before setting a rally point.", true)
		return
	cancel_modes()
	rally_armed = true
	feedback.emit("Rally point armed: choose a destination.", false)


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
	_refresh_cursor()
	var faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
	var structure_name := String(FactionCatalog.stats(structure_kind, faction)["name"])
	feedback.emit("Choose a clear meadow footprint for the %s." % structure_name, false)


func cancel_modes() -> void:
	move_armed = false
	attack_move_armed = false
	patrol_armed = false
	repair_armed = false
	rally_armed = false
	placement_worker_id = -1
	placement_kind = &""
	_armed_append = false
	_refresh_cursor()


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
			entity_state.get("kind") in [&"hunter", &"vanguard", &"mystic", &"jadeclaw"]
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
		if selectable_only and not should_render_entity(entity_state):
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


func cursor_context_at(screen_position: Vector2) -> Dictionary:
	if simulation == null or not simulation.outcome.is_empty():
		return _cursor_context(CursorSystem.SELECT)
	if _middle_dragging:
		return _cursor_context(CursorSystem.PAN)
	if _selection_pressed and _selection_dragging:
		return _cursor_context(CursorSystem.BOX_SELECT)

	var cell := screen_to_cell(screen_position)
	var target_id := entity_at_screen(screen_position, false)
	if placement_worker_id >= 0:
		var can_build := (
			MapCatalog.in_bounds(cell)
			and simulation.can_place_structure(RtsSimulation.TEAM_PLAYER, placement_kind, cell)
			and simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, placement_kind)
		)
		return _cursor_context(
			CursorSystem.BUILD if can_build else CursorSystem.FORBIDDEN,
			target_id,
			can_build,
		)
	if repair_armed:
		var can_repair := _cursor_can_repair_target(target_id)
		return _cursor_context(
			CursorSystem.REPAIR if can_repair else CursorSystem.FORBIDDEN,
			target_id,
			can_repair,
		)
	if attack_move_armed:
		var can_attack_move := MapCatalog.in_bounds(cell) and not selected_commandable_units().is_empty()
		return _cursor_context(
			CursorSystem.ATTACK_MOVE if can_attack_move else CursorSystem.FORBIDDEN,
			target_id,
			can_attack_move,
		)
	if patrol_armed:
		var can_patrol := MapCatalog.in_bounds(cell) and not selected_military_units().is_empty()
		return _cursor_context(
			CursorSystem.PATROL if can_patrol else CursorSystem.FORBIDDEN,
			target_id,
			can_patrol,
		)

	var commandable_units := selected_commandable_units()
	var selected_structure := primary_selected_structure()
	if not MapCatalog.in_bounds(cell) and (not commandable_units.is_empty() or selected_structure >= 0):
		return _cursor_context(CursorSystem.FORBIDDEN, target_id, false)
	if target_id >= 0:
		var target := simulation.entity(target_id)
		if target.get("kind") == &"yaoguai_den" and not commandable_units.is_empty():
			return _cursor_context(CursorSystem.HUNT, target_id)
		if (
			not commandable_units.is_empty()
			and simulation.are_hostile(simulation.entity(commandable_units[0]), target)
		):
			return _cursor_context(
				CursorSystem.HUNT if target.get("category") == &"wildlife" else CursorSystem.ATTACK,
				target_id,
			)
		var workers := _selected_of_kind(&"worker")
		if target.get("kind") == &"stronghold" and _any_worker_carrying(workers):
			return _cursor_context(CursorSystem.DEPOSIT, target_id)
		if not workers.is_empty() and _cursor_can_repair_target(target_id):
			return _cursor_context(CursorSystem.REPAIR, target_id)
		if target.get("category") == &"resource" and not workers.is_empty():
			return _cursor_context(_resource_cursor_state(target), target_id)
	if selected_structure >= 0 and commandable_units.is_empty():
		return _cursor_context(CursorSystem.RALLY, target_id)
	if not commandable_units.is_empty():
		return _cursor_context(CursorSystem.MOVE, target_id)
	return _cursor_context(CursorSystem.SELECT, target_id)


func _cursor_context(
	state_name: StringName,
	target_id: int = -1,
	valid: bool = true,
) -> Dictionary:
	return {
		"state": state_name,
		"label": CursorSystem.label_for(state_name),
		"target_id": target_id,
		"valid": valid,
	}


func _refresh_cursor() -> void:
	var next_state := cursor_context_at(_mouse_position).get("state", CursorSystem.SELECT) as StringName
	if next_state == _cursor_state:
		return
	_cursor_state = next_state
	CursorSystem.apply(self, _cursor_state)


func _cursor_can_repair_target(target_id: int) -> bool:
	if target_id < 0:
		return false
	var target := simulation.entity(target_id)
	if (
		target.is_empty()
		or not bool(target.get("alive", false))
		or target.get("category") != &"structure"
		or int(target.get("team", RtsSimulation.TEAM_NEUTRAL)) != RtsSimulation.TEAM_PLAYER
		or float(target.get("complete", 0.0)) < 1.0
		or float(target.get("hp", 0.0)) >= float(target.get("max_hp", 0.0))
	):
		return false
	return not _selected_of_kind(&"worker").is_empty()


func _any_worker_carrying(workers: Array[int]) -> bool:
	for worker_id in workers:
		if float(simulation.entity(worker_id).get("cargo_amount", 0.0)) > 0.0:
			return true
	return false


func _resource_cursor_state(resource: Dictionary) -> StringName:
	match resource.get("resource_kind"):
		&"jade":
			return CursorSystem.GATHER_JADE
		&"lumber":
			return CursorSystem.GATHER_LUMBER
		_:
			return CursorSystem.GATHER_ESSENCE


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


func _command_visualization_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if simulation == null or selected_ids.is_empty():
		return records
	var seen: Dictionary = {}
	var considered_units := 0
	for unit_id in selected_ids:
		var unit := simulation.entity(unit_id)
		if (
			unit.is_empty()
			or not bool(unit.get("alive", false))
			or unit.get("category") != &"unit"
			or int(unit.get("team", RtsSimulation.TEAM_NEUTRAL)) != RtsSimulation.TEAM_PLAYER
		):
			continue
		if considered_units >= MAX_VISIBLE_COMMAND_PATHS:
			break
		considered_units += 1
		var record := _command_visualization_record(unit)
		if record.is_empty():
			continue
		var dedupe_key := _command_visualization_dedupe_key(record)
		if seen.has(dedupe_key):
			continue
		seen[dedupe_key] = true
		records.append(record)
	return records


func _command_visualization_record(unit: Dictionary) -> Dictionary:
	var order := unit.get("order", &"idle") as StringName
	var indicator_kind: StringName = &""
	var target_id := int(unit.get("target_id", -1))
	var endpoint := Vector2.ZERO
	var target := simulation.entity(target_id)
	var has_live_target := not target.is_empty() and bool(target.get("alive", false))

	if (
		order in [&"attack", &"attack_move", &"patrol"]
		and has_live_target
		and simulation.are_hostile(unit, target)
		and should_render_entity(target)
	):
		indicator_kind = &"attack"
		endpoint = _entity_world_center(target)
	elif order in [&"gather", &"build", &"repair"] and has_live_target:
		indicator_kind = &"interact"
		endpoint = _entity_world_center(target)
	elif order == &"return":
		if not has_live_target:
			target_id = simulation.primary_structure_id(
				int(unit.get("team", RtsSimulation.TEAM_NEUTRAL)),
				&"stronghold",
			)
			target = simulation.entity(target_id)
			has_live_target = not target.is_empty() and bool(target.get("alive", false))
		if not has_live_target:
			return {}
		indicator_kind = &"interact"
		endpoint = _entity_world_center(target)
	else:
		match order:
			&"move":
				var path := unit.get("path", []) as Array
				if path.is_empty():
					return {}
				indicator_kind = &"flag"
				endpoint = path.back() as Vector2
			&"attack_move":
				var attack_move_destination := unit.get(
					"attack_move_destination",
					Vector2i(-1, -1),
				) as Vector2i
				if not MapCatalog.in_bounds(attack_move_destination):
					return {}
				indicator_kind = &"flag"
				endpoint = Vector2(attack_move_destination)
			&"patrol":
				var patrol_target := unit.get("patrol_target", Vector2i(-1, -1)) as Vector2i
				if not MapCatalog.in_bounds(patrol_target):
					return {}
				indicator_kind = &"flag"
				endpoint = Vector2(patrol_target)
			_:
				return {}

	return {
		"unit_id": int(unit.get("id", -1)),
		"kind": indicator_kind,
		"target_id": target_id if indicator_kind != &"flag" else -1,
		"endpoint": endpoint,
		"points": _command_route_points(unit, endpoint),
	}


func _command_route_points(unit: Dictionary, endpoint: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	_append_command_route_point(points, _entity_world_center(unit))
	var path := unit.get("path", []) as Array
	var path_index := clampi(int(unit.get("path_index", 0)), 0, path.size())
	for index in range(path_index, path.size()):
		_append_command_route_point(points, path[index] as Vector2)
	_append_command_route_point(points, endpoint)
	return points


func _append_command_route_point(points: Array[Vector2], point: Vector2) -> void:
	if points.is_empty() or points.back().distance_squared_to(point) > COMMAND_PATH_POINT_EPSILON_SQUARED:
		points.append(point)


func _entity_world_center(entity_state: Dictionary) -> Vector2:
	var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
	return (
		entity_state.get("position", Vector2.ZERO) as Vector2
		+ (Vector2(footprint) - Vector2.ONE) * 0.5
	)


func _command_visualization_dedupe_key(record: Dictionary) -> String:
	var parts := PackedStringArray([
		String(record.get("kind", &"")),
		str(int(record.get("target_id", -1))),
	])
	for raw_point in record.get("points", []) as Array:
		var point := raw_point as Vector2
		var quantized := Vector2i(roundi(point.x * 100.0), roundi(point.y * 100.0))
		parts.append("%d,%d" % [quantized.x, quantized.y])
	return "|".join(parts)


func _draw_command_visualizations(records: Array[Dictionary]) -> void:
	for record in records:
		_draw_command_path(record)
	for record in records:
		_draw_command_indicator(record)


func _draw_command_path(record: Dictionary) -> void:
	var raw_points := record.get("points", []) as Array
	if raw_points.size() < 2:
		return
	var points: Array[Vector2] = []
	for raw_point in raw_points:
		points.append(
			camera_offset
			+ IsoProjection.position_center(raw_point as Vector2) * camera_scale
		)
	var color := _command_visualization_color(record.get("kind", &"flag") as StringName)
	var next_dot_distance := COMMAND_PATH_DOT_SPACING * 0.5
	for index in range(points.size() - 1):
		var start := points[index]
		var segment := points[index + 1] - start
		var segment_length := segment.length()
		if segment_length <= 0.001:
			continue
		while next_dot_distance <= segment_length:
			var dot := start + segment * (next_dot_distance / segment_length)
			draw_circle(dot, COMMAND_PATH_DOT_RADIUS + 1.6, Color(0.01, 0.04, 0.045, 0.82))
			draw_circle(dot, COMMAND_PATH_DOT_RADIUS, color)
			next_dot_distance += COMMAND_PATH_DOT_SPACING
		next_dot_distance -= segment_length


func _draw_command_indicator(record: Dictionary) -> void:
	var indicator_kind := record.get("kind", &"flag") as StringName
	var texture := COMMAND_INDICATOR_TEXTURES.get(indicator_kind) as Texture2D
	if texture == null:
		return
	var endpoint := record.get("endpoint", Vector2.ZERO) as Vector2
	var anchor := camera_offset + IsoProjection.position_center(endpoint) * camera_scale
	var scale_factor := clampf(0.72 + camera_scale * 0.42, 0.78, 1.12)
	var icon_size := Vector2.ONE * 52.0 * scale_factor
	var rotation := 0.0
	var rect := Rect2(-icon_size * 0.5, icon_size)
	var tint := Color.WHITE
	match indicator_kind:
		&"flag":
			var pulse := 1.0 + sin(_command_indicator_time * 2.6) * 0.035
			icon_size = Vector2.ONE * 50.0 * scale_factor * pulse
			rect = Rect2(Vector2(-icon_size.x * 0.5, -icon_size.y + 4.0), icon_size)
		&"interact":
			icon_size = Vector2.ONE * 62.0 * scale_factor
			rotation = _command_indicator_time * COMMAND_INTERACTION_ROTATION_SPEED
			rect = Rect2(-icon_size * 0.5, icon_size)
			tint.a = 0.94
		&"attack":
			var pulse := 1.0 + sin(_command_indicator_time * 4.5) * 0.06
			icon_size = Vector2.ONE * 54.0 * scale_factor * pulse
			var hover := clampf(42.0 * camera_scale, 18.0, 44.0)
			var icon_anchor := anchor + Vector2(0.0, -hover)
			draw_line(anchor, icon_anchor + Vector2(0.0, icon_size.y * 0.34), Color(0.96, 0.34, 0.25, 0.72), 1.5, true)
			anchor = icon_anchor
			rect = Rect2(-icon_size * 0.5, icon_size)
	draw_set_transform(anchor, rotation, Vector2.ONE)
	draw_texture_rect(texture, rect, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _command_visualization_color(indicator_kind: StringName) -> Color:
	match indicator_kind:
		&"interact":
			return Color(0.94, 0.79, 0.35, 0.92)
		&"attack":
			return Color(0.96, 0.34, 0.25, 0.94)
		_:
			return Color(0.47, 0.92, 0.73, 0.92)


func _draw() -> void:
	if simulation == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("071416"))
	_draw_terrain()
	_draw_hover_feedback()
	_draw_entities()
	_draw_effects()
	_draw_fog_of_war()
	_draw_command_visualizations(_command_visualization_records())
	if _selection_pressed and _selection_dragging:
		var rect := Rect2(_selection_start, _selection_current - _selection_start).abs()
		draw_rect(rect, Color(0.32, 0.93, 0.72, 0.12), true)
		draw_rect(rect, PLAYER_COLOR, false, 1.5)


func _draw_terrain() -> void:
	for depth in range(MapCatalog.AUTHORED_SIZE.x + MapCatalog.AUTHORED_SIZE.y - 1):
		for macro_y in range(MapCatalog.AUTHORED_SIZE.y):
			var macro_x := depth - macro_y
			if macro_x < 0 or macro_x >= MapCatalog.AUTHORED_SIZE.x:
				continue
			var cell := Vector2i(macro_x, macro_y) * MapCatalog.CELL_SCALE
			if not _is_block_on_screen(cell, MapCatalog.CELL_SCALE):
				continue
			var terrain := MapCatalog.terrain_at(cell)
			var points := _transformed_block_polygon(cell, MapCatalog.CELL_SCALE)
			var texture := TERRAIN_TEXTURES.get(terrain) as Texture2D
			var tint := Color.WHITE
			if terrain == &"ridge":
				tint = Color(0.82, 0.87, 0.85, 1.0)
			elif terrain == &"water":
				var current := sin(float(cell.x + cell.y) * 0.72 - _water_animation_time * 2.0)
				var brightness := 0.96 + current * 0.035
				tint = Color(0.74 * brightness, 0.96 * brightness, brightness, 0.95)
			elif terrain == &"forest":
				tint = Color(0.82, 0.94, 0.83, 1.0)
			elif terrain == &"road":
				tint = Color(1.0, 0.97, 0.86, 1.0)
			elif terrain == &"bridge":
				tint = Color(0.95, 1.0, 0.96, 1.0)
			else:
				var variation := 0.92 + float(posmod(macro_x * 17 + macro_y * 29, 7)) * 0.018
				tint = Color(variation, variation, variation * 0.98, 1.0)
			var colors := PackedColorArray([tint, tint, tint, tint])
			var uv_offset := WATER_FLOW_SPEED * _water_animation_time if terrain == &"water" else Vector2.ZERO
			var uvs := _terrain_uvs(cell, uv_offset, MapCatalog.CELL_SCALE)
			draw_polygon(points, colors, uvs, texture)
			if camera_scale >= GRID_MIN_SCALE:
				var closed := points.duplicate()
				closed.append(points[0])
				draw_polyline(closed, GRID_COLOR, GRID_LINE_WIDTH, true)


func _terrain_uvs(cell: Vector2i, offset: Vector2 = Vector2.ZERO, extent_cells: int = 1) -> PackedVector2Array:
	var origin := Vector2(cell) * WATER_UV_SCALE + offset
	var extent := Vector2.ONE * WATER_UV_SCALE * float(extent_cells)
	return PackedVector2Array([
		origin,
		origin + Vector2(extent.x, 0.0),
		origin + extent,
		origin + Vector2(0.0, extent.y),
	])


func _transformed_block_polygon(cell: Vector2i, extent_cells: int) -> PackedVector2Array:
	var origin := Vector2(cell)
	var extent := float(extent_cells)
	return PackedVector2Array([
		IsoProjection.project(origin) * camera_scale + camera_offset,
		IsoProjection.project(origin + Vector2(extent, 0.0)) * camera_scale + camera_offset,
		IsoProjection.project(origin + Vector2(extent, extent)) * camera_scale + camera_offset,
		IsoProjection.project(origin + Vector2(0.0, extent)) * camera_scale + camera_offset,
	])


func _is_block_on_screen(cell: Vector2i, extent_cells: int) -> bool:
	var center := camera_offset + IsoProjection.position_center(
		Vector2(cell) + Vector2.ONE * (float(extent_cells) - 1.0) * 0.5
	) * camera_scale
	var half_size := Vector2(IsoProjection.TILE_WIDTH, IsoProjection.TILE_HEIGHT) * camera_scale * float(extent_cells) * 0.5
	return (
		center.x + half_size.x >= 0.0
		and center.x - half_size.x <= size.x
		and center.y + half_size.y >= 0.0
		and center.y - half_size.y <= size.y
	)

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
	elif move_armed:
		draw_colored_polygon(points, Color(PLAYER_COLOR, 0.12))
		draw_polyline(closed, PLAYER_COLOR, 2.0, true)
	elif rally_armed:
		draw_colored_polygon(points, Color(Color("f0d278"), 0.14))
		draw_polyline(closed, Color("f0d278"), 2.0, true)
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
		if (
			camera_scale < TREE_ENTITY_MIN_SCALE
			and entity_state.get("resource_kind") == &"lumber"
		):
			var tree_cell := entity_state.get("cell", Vector2i(-1, -1)) as Vector2i
			if posmod(tree_cell.x, MapCatalog.CELL_SCALE) != 0 or posmod(tree_cell.y, MapCatalog.CELL_SCALE) != 0:
				continue
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
		var is_movable := category in [&"unit", &"wildlife"]
		var sprite_center := center
		var flip_h := false
		if is_movable:
			sprite_center.y += _movement_bounce_offset(entity_state)
			flip_h = _movement_sprite_flipped(entity_state)
		_draw_world_texture(texture, sprite_center, display_size * camera_scale, tint, flip_h)
		if kind == &"yaoguai_den":
			_draw_cave_status(entity_state, center)
		else:
			_draw_health_bar(entity_state, center, category)
			if kind in RtsSimulation.FOOD_PRODUCER_KINDS and float(entity_state.get("complete", 0.0)) >= 1.0:
				_draw_food_progress(entity_state, center)

	if kind == &"worker" and float(entity_state.get("cargo_amount", 0.0)) > 0.0:
		var cargo_color := _resource_color(entity_state.get("cargo_kind", &"") as StringName)
		draw_circle(center + Vector2(23.0, -40.0) * camera_scale, maxf(3.0, 5.0 * camera_scale), cargo_color)


func _draw_world_texture(
	texture: Texture2D,
	center: Vector2,
	display_size: Vector2,
	tint: Color,
	flip_h: bool = false,
) -> void:
	if texture == null:
		return
	var rect := Rect2(
		Vector2(-display_size.x * 0.5, -display_size.y + 10.0 * camera_scale),
		display_size,
	)
	draw_set_transform(center, 0.0, Vector2(-1.0 if flip_h else 1.0, 1.0))
	draw_texture_rect(texture, rect, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _update_movement_visuals(delta: float) -> void:
	if simulation == null:
		_movement_visuals.clear()
		return
	var live_ids: Dictionary = {}
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)) or not _is_movable_visual(entity_state):
			continue
		var entity_id := int(entity_state.get("id", -1))
		var position := entity_state.get("position", Vector2.ZERO) as Vector2
		live_ids[entity_id] = true
		if not _movement_visuals.has(entity_id):
			_movement_visuals[entity_id] = {
				"position": position,
				"faces_left": not _native_art_faces_right(entity_state),
				"moving_for": 0.0,
			}
			continue
		var visual := _movement_visuals[entity_id] as Dictionary
		var previous_position := visual.get("position", position) as Vector2
		var movement := position - previous_position
		if movement.length_squared() > WALK_MOTION_EPSILON_SQUARED:
			var projected_movement := IsoProjection.project(movement)
			if absf(projected_movement.x) > WALK_FACING_EPSILON:
				visual["faces_left"] = projected_movement.x < 0.0
			visual["moving_for"] = WALK_MOTION_MEMORY_SECONDS
		else:
			visual["moving_for"] = maxf(0.0, float(visual.get("moving_for", 0.0)) - delta)
		visual["position"] = position
		_movement_visuals[entity_id] = visual
	for raw_id in _movement_visuals.keys():
		var entity_id := int(raw_id)
		if not live_ids.has(entity_id):
			_movement_visuals.erase(entity_id)


func _is_movable_visual(entity_state: Dictionary) -> bool:
	return entity_state.get("category") in [&"unit", &"wildlife"]


func _native_art_faces_right(entity_state: Dictionary) -> bool:
	if entity_state.get("kind") == &"jadeclaw":
		return false
	var art_key := "%s:%s" % [
		String(entity_state.get("faction", &"neutral")),
		String(entity_state.get("kind", &"")),
	]
	return bool(NATIVE_RIGHT_FACING_ART.get(art_key, false))


func _movement_sprite_flipped(entity_state: Dictionary) -> bool:
	return _movement_faces_left(entity_state) == _native_art_faces_right(entity_state)


func _movement_faces_left(entity_state: Dictionary) -> bool:
	var visual := _movement_visuals.get(int(entity_state.get("id", -1)), {}) as Dictionary
	return bool(visual.get("faces_left", not _native_art_faces_right(entity_state)))


func _movement_bounce_offset(entity_state: Dictionary) -> float:
	var entity_id := int(entity_state.get("id", -1))
	var visual := _movement_visuals.get(entity_id, {}) as Dictionary
	var moving_for := float(visual.get("moving_for", 0.0))
	if moving_for <= 0.0:
		return 0.0
	var fade := clampf(moving_for / (WALK_MOTION_MEMORY_SECONDS * 0.5), 0.0, 1.0)
	var phase := _walk_animation_time * WALK_BOUNCE_SPEED + float(entity_id) * 1.61803398875
	return -absf(sin(phase)) * WALK_BOUNCE_HEIGHT * camera_scale * fade


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
	var phase := _tree_wind_phase(entity_state)
	var crown_offset := _tree_sway_offset(0.18, phase, display_size) * 0.22
	_draw_world_texture(texture, center + crown_offset, display_size, tint)


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
	if is_tree and not selected_ids.has(int(entity_state["id"])):
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
	for macro_y in range(MapCatalog.AUTHORED_SIZE.y):
		for macro_x in range(MapCatalog.AUTHORED_SIZE.x):
			var origin := Vector2i(macro_x, macro_y) * MapCatalog.CELL_SCALE
			if not _is_block_on_screen(origin, MapCatalog.CELL_SCALE):
				continue
			var hidden_cells: Array[Vector2i] = []
			var explored_hidden := 0
			for local_y in range(MapCatalog.CELL_SCALE):
				for local_x in range(MapCatalog.CELL_SCALE):
					var cell := origin + Vector2i(local_x, local_y)
					if _visible_cells.has(cell):
						continue
					hidden_cells.append(cell)
					if _explored_cells.has(cell):
						explored_hidden += 1
			if hidden_cells.is_empty():
				continue
			if hidden_cells.size() == MapCatalog.CELL_SCALE * MapCatalog.CELL_SCALE and explored_hidden in [0, hidden_cells.size()]:
				var block_color := EXPLORED_FOG_COLOR if explored_hidden > 0 else UNEXPLORED_FOG_COLOR
				draw_colored_polygon(_transformed_block_polygon(origin, MapCatalog.CELL_SCALE), block_color)
				continue
			for cell in hidden_cells:
				var color := EXPLORED_FOG_COLOR if _explored_cells.has(cell) else UNEXPLORED_FOG_COLOR
				draw_colored_polygon(IsoProjection.transformed_polygon(cell, camera_scale, camera_offset), color)


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
