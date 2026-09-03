class_name Battlefield
extends Control

signal selection_changed(ids)
signal feedback(message: String, is_error: bool)
signal fog_visibility_changed
signal audio_cue(cue: StringName)
signal simulation_event(event: Dictionary)

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
const CARGO_ICON_TEXTURES := {
	&"jade": preload("res://assets/runtime/ui/resource_icons/jade.png"),
	&"lumber": preload("res://assets/runtime/ui/resource_icons/lumber.png"),
	&"essence": preload("res://assets/runtime/ui/resource_icons/essence.png"),
	&"food": preload("res://assets/runtime/ui/resource_icons/food.png"),
}
const FARM_WORKER_ICON_TEXTURE := preload("res://assets/runtime/ui/resource_icons/food.png")
const IDLE_WORKER_ALERT_TEXTURE := preload("res://assets/runtime/ui/idle_worker_alert.png")
const FOG_MASK_BUILDER_SCRIPT := preload("res://scripts/view/fog_mask_builder.gd")
const MAP_EDGE_CONTOUR_SCRIPT := preload("res://scripts/view/map_edge_contour.gd")
const EFFECT_CATALOG_SCRIPT := preload("res://scripts/view/effects/effect_catalog.gd")
const EFFECT_DIRECTOR_SCRIPT := preload("res://scripts/view/effects/effect_director.gd")
const PRESENTATION_STATE_SCRIPT := preload("res://scripts/view/effects/presentation_state.gd")
const BATTLEFIELD_BACKGROUND_COLOR := Color("071416")
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
const FOG_MASK_PIXELS_PER_CELL := 1
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
const IDLE_WOBBLE_MIN_WAIT_SECONDS := 6.0
const IDLE_WOBBLE_MAX_WAIT_SECONDS := 12.0
const IDLE_WOBBLE_DURATION := 0.52
const IDLE_WOBBLE_ANGLE := 0.0436332313
const IDLE_WOBBLE_OSCILLATIONS := 2.0
const SHENLONG_WAVE_MIN_SCALE := 0.28
const SHENLONG_MESH_COLUMNS := 12
const SHENLONG_MESH_ROWS := 9
const SHENLONG_AURA_WISP_COUNT := 5
const STRONGHOLD_AURA_BASE_RADIUS := Vector2(72.0, 29.0)
const STRONGHOLD_LEVEL_2_PARTICLE_COUNT := 9
const STRONGHOLD_LEVEL_3_PARTICLE_COUNT := 18
const MAX_VISIBLE_COMMAND_PATHS := 10
const COMMAND_PATH_DOT_SPACING := 16.0
const COMMAND_PATH_DOT_RADIUS := 2.4
const COMMAND_PATH_POINT_EPSILON_SQUARED := 0.0001
const COMMAND_INTERACTION_ROTATION_SPEED := 1.75
const SPRITE_PICK_ALPHA_THRESHOLD := 0.125
const SPRITE_PICK_SAMPLE_RADIUS := 3.0
const SPRITE_PICK_SAMPLE_OFFSETS := [
	Vector2.ZERO,
	Vector2(-SPRITE_PICK_SAMPLE_RADIUS, 0.0),
	Vector2(SPRITE_PICK_SAMPLE_RADIUS, 0.0),
	Vector2(0.0, -SPRITE_PICK_SAMPLE_RADIUS),
	Vector2(0.0, SPRITE_PICK_SAMPLE_RADIUS),
	Vector2(-SPRITE_PICK_SAMPLE_RADIUS, -SPRITE_PICK_SAMPLE_RADIUS),
	Vector2(SPRITE_PICK_SAMPLE_RADIUS, -SPRITE_PICK_SAMPLE_RADIUS),
	Vector2(-SPRITE_PICK_SAMPLE_RADIUS, SPRITE_PICK_SAMPLE_RADIUS),
	Vector2(SPRITE_PICK_SAMPLE_RADIUS, SPRITE_PICK_SAMPLE_RADIUS),
]
const AMBIENT_REDRAW_SECONDS := 1.0 / 30.0
const AMBIENT_EFFECT_SECONDS := 0.24
const WALL_SPRITE_SCALE := 1.10
const GATE_SPRITE_SCALE := 1.10
const GATE_SPRITE_SCALE_OVERRIDES := {
	"beast_gate.png": 1.30,
	"celestial_gate.png": 1.20,
	"demon_gate.png": 1.30,
	"human_gate.png": 1.00,
}
const GATE_SPRITE_ANCHOR_RATIO := 0.25
const GATE_SPRITE_ANCHOR_RATIO_OVERRIDES := {
	"beast_gate.png": 0.20,
	"demon_gate.png": 0.20,
}
const WALL_CORNER_DIRECTION_ORDER: Array[StringName] = [
	&"top_left",
	&"top_right",
	&"bottom_left",
	&"bottom_right",
]
const WALL_CORNER_NEIGHBOR_OFFSETS := {
	&"top_left": Vector2i(-1, 0),
	&"top_right": Vector2i(0, -1),
	&"bottom_left": Vector2i(0, 1),
	&"bottom_right": Vector2i(1, 0),
}
const TOWER_OCCUPANT_DISPLAY_SIZE := Vector2(58.0, 68.0)
const TOWER_ROOFTOP_SOURCE_Y := 106.0
const TOWER_ROOFTOP_SOURCE_CENTER_X := 152.0
const TOWER_ROOFTOP_SOURCE_SPAN_X := 64.0
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
	"neutral:shenlong": true,
}
const WHEEL_ZOOM_STEP := 1.12
const INITIAL_CAMERA_ZOOM_FACTOR := 1.5
const MIN_CAMERA_SCALE := 0.14
const MAX_CAMERA_SCALE := 1.30
const CAMERA_PAN_SPEED := 1000.0
const CAMERA_PAN_RESPONSE := 10.0
const CAMERA_PAN_STOP_EPSILON := 0.5
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
var placement_orientation: StringName = &"y"
var fog_enabled := true
var control_groups: Dictionary = {}

var camera_scale := 0.93
var camera_offset := Vector2.ZERO
var _camera_initialized := false
var _camera_pan_velocity := Vector2.ZERO
var _middle_dragging := false
var _selection_pressed := false
var _selection_dragging := false
var _selection_start := Vector2.ZERO
var _selection_current := Vector2.ZERO
var _selection_additive := false
var _placement_pressed := false
var _placement_start_cell := Vector2i(-1, -1)
var _placement_current_cell := Vector2i(-1, -1)
var _armed_append := false
var _last_control_group := -1
var _last_control_group_recall_ms := -1000
var _mouse_position := Vector2.ZERO
var _cursor_state: StringName = &""
var _texture_cache: Dictionary = {}
var _texture_bottom_margin_cache: Dictionary = {}
var _texture_content_rect_cache: Dictionary = {}
var _texture_ground_profile_cache: Dictionary = {}
var _texture_ground_slope_cache: Dictionary = {}
var _texture_pick_mask_cache: Dictionary = {}
var _wall_render_lookup: Dictionary = {}
var _gate_bottom_corner_render_lookup: Dictionary = {}
var _effect_director = EFFECT_DIRECTOR_SCRIPT.new()
var _presentation = PRESENTATION_STATE_SCRIPT.new()
var _visible_cells: Dictionary = {}
var _explored_cells: Dictionary = {}
var _visibility_timer := 0.0
var _fog_mask_builder
var _fog_mask_texture: ImageTexture
var _fog_mask_dirty := true
var _map_edge_projected_bands: Array[Dictionary] = []
var _water_animation_time := 0.0
var _wind_animation_time := 0.0
var _walk_animation_time := 0.0
var _command_indicator_time := 0.0
var _ambient_redraw_timer := 0.0
var _ambient_effect_timer := 0.0
var _ambient_effect_cursor := 0
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
	_effect_director.clear()
	_presentation.clear()
	_visible_cells.clear()
	_explored_cells.clear()
	_fog_mask_dirty = true
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
	camera_scale = clampf(overview_scale * 2.376, 0.504, 0.864) * INITIAL_CAMERA_ZOOM_FACTOR
	var focus := MapCatalog.PLAYER_STRONGHOLD if simulation != null else MapCatalog.SIZE / 2
	camera_offset = Vector2(size.x * 0.5, size.y * 0.46) - IsoProjection.cell_center(focus) * camera_scale
	_camera_pan_velocity = Vector2.ZERO
	_camera_initialized = true
	_clamp_camera()


func center_on_cell(cell: Vector2i) -> void:
	camera_offset = size * 0.5 - IsoProjection.cell_center(cell) * camera_scale
	_camera_pan_velocity = Vector2.ZERO
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
	if fog_enabled:
		_fog_mask_dirty = true
	fog_visibility_changed.emit()
	queue_redraw()


func configure_effects(
	intensity: StringName = &"full",
	reduced_motion: bool = false,
	damage_numbers: StringName = &"contextual",
	camera_impulse: StringName = &"major",
) -> void:
	_effect_director.configure(intensity, reduced_motion, damage_numbers, camera_impulse)
	_presentation.configure(reduced_motion)
	queue_redraw()


func effect_diagnostics() -> Dictionary:
	return _effect_director.diagnostics()


func preview_effect(event: Dictionary) -> void:
	var snapshot := event.duplicate(true)
	if snapshot.get("type") == &"attack":
		snapshot["attack_family"] = EFFECT_CATALOG_SCRIPT.attack_family(
			snapshot.get("attacker_kind", &"") as StringName,
			snapshot.get("attacker_faction", &"neutral") as StringName,
		)
	_effect_director.consume_event(snapshot)
	_presentation.consume_event(snapshot)
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
	if team >= 0 and team != RtsSimulation.TEAM_PLAYER:
		return is_cell_visible(cell)
	if entity_state.get("kind") == &"shenlong_egg" and int(entity_state.get("carried_by", -1)) >= 0:
		return is_cell_visible(cell)
	if entity_state.get("category") in [&"unit", &"wildlife"]:
		return is_cell_visible(cell)
	return is_cell_explored(cell)


func _process(delta: float) -> void:
	_prune_selected_ids()
	_presentation.synchronize(simulation.entities if simulation != null else {})
	var hover_id := command_target_at_screen(_mouse_position, false) if simulation != null else -1
	if hover_id < 0 and simulation != null:
		hover_id = entity_at_screen(_mouse_position, false)
	_presentation.set_hover(hover_id)
	_presentation.advance(delta)
	_water_animation_time += delta
	_wind_animation_time = fmod(_wind_animation_time + delta, TAU * 1000.0)
	_walk_animation_time = fmod(_walk_animation_time + delta, TAU * 1000.0)
	_command_indicator_time = fmod(_command_indicator_time + delta, TAU * 1000.0)
	_update_movement_visuals(delta)
	_visibility_timer -= delta
	if simulation != null and _visibility_timer <= 0.0:
		_visibility_timer = VISIBILITY_REFRESH_SECONDS
		_refresh_visibility()
	_update_camera_pan(delta)
	for event in simulation.drain_events() if simulation != null else []:
		var effect := (event as Dictionary).duplicate(true)
		if effect.get("type") == &"attack":
			effect["attack_family"] = EFFECT_CATALOG_SCRIPT.attack_family(
				effect.get("attacker_kind", &"") as StringName,
				effect.get("attacker_faction", &"neutral") as StringName,
			)
		if _event_is_presentable(effect):
			_effect_director.consume_event(effect)
			_presentation.consume_event(effect)
		if _event_is_audible(effect):
			simulation_event.emit(effect.duplicate(true))
	if _presentation.has_active_wildlife_fades():
		queue_redraw()
	_effect_director.advance(delta)
	_ambient_effect_timer -= delta
	if _ambient_effect_timer <= 0.0:
		_ambient_effect_timer = AMBIENT_EFFECT_SECONDS
		_emit_ambient_juice()
	_refresh_cursor()
	_ambient_redraw_timer -= delta
	if _ambient_redraw_timer <= 0.0:
		_ambient_redraw_timer = AMBIENT_REDRAW_SECONDS
		queue_redraw()


func _prune_selected_ids() -> void:
	var next_ids: Array[int] = []
	for id in selected_ids:
		var entity_state := simulation.entity(id) if simulation != null else {}
		if (
			not entity_state.is_empty()
			and bool(entity_state.get("alive", false))
			and int(entity_state.get("garrisoned_in", -1)) < 0
		):
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
		_fog_mask_dirty = true
		fog_visibility_changed.emit()
		queue_redraw()


func _entity_center_cell(entity_state: Dictionary) -> Vector2i:
	var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
	var center := (entity_state["position"] as Vector2) + (Vector2(footprint) - Vector2.ONE) * 0.5
	return Vector2i(center.floor())


func _event_is_audible(event: Dictionary) -> bool:
	if int(event.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER:
		return true
	if not fog_enabled:
		return true
	var position := Vector2(-9999.0, -9999.0)
	if event.has("position"):
		position = event["position"] as Vector2
	elif event.has("to"):
		position = event["to"] as Vector2
	elif event.has("from"):
		position = event["from"] as Vector2
	return is_cell_visible(Vector2i(position.floor()))


func _event_is_presentable(event: Dictionary) -> bool:
	if int(event.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER:
		return true
	if not fog_enabled:
		return true
	var position := event.get("position", event.get("to", event.get("from", Vector2(-9999.0, -9999.0)))) as Vector2
	return is_cell_visible(Vector2i(position.floor()))


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
		elif _placement_pressed:
			_placement_current_cell = screen_to_cell(motion.position)
			if placement_kind in [&"wall", &"gate"] and _placement_current_cell != _placement_start_cell:
				placement_orientation = _automatic_drag_orientation(
					_placement_start_cell,
					_placement_current_cell,
				)
			_refresh_cursor()
			queue_redraw()
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
			if button.pressed:
				_camera_pan_velocity = Vector2.ZERO
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
		_placement_pressed = true
		_placement_start_cell = screen_to_cell(screen_position)
		_placement_current_cell = _placement_start_cell
		return
	if move_armed:
		var move_cell := screen_to_cell(screen_position)
		var move_units := selected_commandable_units()
		if not move_units.is_empty() and MapCatalog.in_bounds(move_cell):
			simulation.command_move(RtsSimulation.TEAM_PLAYER, move_units, move_cell, false, append or _armed_append)
			_effect_director.emit_click(Vector2(move_cell), &"queued" if append or _armed_append else &"move", PLAYER_COLOR, append or _armed_append)
			feedback.emit("Move queued." if append or _armed_append else "Move order issued.", false)
			audio_cue.emit(&"order_move")
		else:
			_effect_director.emit_invalid(screen_to_map_position(screen_position))
			feedback.emit("Choose a valid move destination.", true)
		return
	if rally_armed:
		var rally_cell := screen_to_cell(screen_position)
		var rally_structure := primary_selected_structure()
		if rally_structure >= 0 and MapCatalog.in_bounds(rally_cell):
			simulation.set_rally(RtsSimulation.TEAM_PLAYER, rally_structure, rally_cell)
			_effect_director.emit_click(Vector2(rally_cell), &"rally", Color("f0d278"))
			feedback.emit("Rally point updated.", false)
			audio_cue.emit(&"order_move")
		else:
			_effect_director.emit_invalid(screen_to_map_position(screen_position))
			feedback.emit("Choose a valid rally destination.", true)
		return
	if repair_armed:
		var repair_target_id := command_target_at_screen(screen_position, false)
		var workers := _selected_of_kind(&"worker")
		if repair_target_id >= 0 and simulation.command_repair(
			RtsSimulation.TEAM_PLAYER,
			workers,
			repair_target_id,
			append or _armed_append,
		):
			_effect_director.emit_click(screen_to_map_position(screen_position), &"queued" if append or _armed_append else &"repair", Color("e4c66d"), append or _armed_append)
			feedback.emit("Repair order queued." if append or _armed_append else "Repair order issued.", false)
			audio_cue.emit(&"order_work")
		else:
			_effect_director.emit_invalid(screen_to_map_position(screen_position))
			feedback.emit("Choose a damaged allied structure to repair.", true)
		return
	if attack_move_armed:
		var cell := screen_to_cell(screen_position)
		var units := selected_commandable_units()
		if not units.is_empty() and MapCatalog.in_bounds(cell):
			simulation.command_move(RtsSimulation.TEAM_PLAYER, units, cell, true, append or _armed_append)
			_effect_director.emit_click(Vector2(cell), &"queued" if append or _armed_append else &"attack", ENEMY_COLOR, append or _armed_append)
			feedback.emit("Attack-move queued." if append or _armed_append else "Attack-move order issued.", false)
			audio_cue.emit(&"order_attack")
		return
	if patrol_armed:
		var patrol_cell := screen_to_cell(screen_position)
		if simulation.command_patrol(
			RtsSimulation.TEAM_PLAYER,
			selected_military_units(),
			patrol_cell,
			append or _armed_append,
		):
			_effect_director.emit_click(Vector2(patrol_cell), &"queued" if append or _armed_append else &"patrol", Color("79c9ee"), append or _armed_append)
			feedback.emit("Patrol queued." if append or _armed_append else "Patrol route established.", false)
			audio_cue.emit(&"order_move")
		else:
			_effect_director.emit_invalid(screen_to_map_position(screen_position))
			feedback.emit("Choose a valid patrol destination.", true)
		return
	_selection_pressed = true
	_selection_dragging = false
	_selection_additive = append
	_selection_start = screen_position
	_selection_current = screen_position


func _handle_left_release(screen_position: Vector2) -> void:
	if _placement_pressed:
		_placement_pressed = false
		_placement_current_cell = screen_to_cell(screen_position)
		if placement_kind in [&"wall", &"gate"] and _placement_current_cell != _placement_start_cell:
			placement_orientation = _automatic_drag_orientation(
				_placement_start_cell,
				_placement_current_cell,
			)
		_commit_structure_placement()
		return
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
		if hit >= 0:
			_effect_director.emit_click(_entity_world_center(simulation.entity(hit)), &"select", _team_color(int(simulation.entity(hit).get("team", RtsSimulation.TEAM_NEUTRAL))))
		else:
			_effect_director.emit_click(screen_to_map_position(screen_position), &"select", Color(PLAYER_COLOR, 0.72))
		select_entities(hit_ids)
	_selection_dragging = false
	_selection_additive = false


func _commit_structure_placement() -> void:
	var faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
	var stats := FactionCatalog.stats(placement_kind, faction)
	var structure_name := String(stats.get("name", "Structure"))
	if placement_kind == &"wall":
		var wall_ids := simulation.command_build_wall_line(
			RtsSimulation.TEAM_PLAYER,
			placement_worker_id,
			_placement_start_cell,
			_placement_current_cell,
			placement_orientation,
		)
		if wall_ids.is_empty():
			_effect_director.emit_invalid(Vector2(_placement_start_cell))
			feedback.emit("That snapped wall line is blocked or unaffordable.", true)
		else:
			_effect_director.emit_click(Vector2(_placement_start_cell), &"build", PLAYER_COLOR)
			feedback.emit("%d Wood Wall foundations placed." % wall_ids.size(), false)
			audio_cue.emit(&"order_work")
		return
	if simulation.command_build(
		RtsSimulation.TEAM_PLAYER,
		placement_worker_id,
		placement_kind,
		_placement_start_cell,
		placement_orientation,
	):
		_effect_director.emit_click(Vector2(_placement_start_cell), &"build", PLAYER_COLOR)
		feedback.emit("%s foundation placed." % structure_name, false)
		audio_cue.emit(&"order_work")
	else:
		_effect_director.emit_invalid(Vector2(_placement_start_cell))
		feedback.emit("That site cannot host a %s." % structure_name, true)


func _handle_right_click(screen_position: Vector2, append: bool = false) -> void:
	if selected_ids.is_empty():
		return
	var commandable_units := selected_commandable_units()
	var selected_structure := primary_selected_structure()
	if commandable_units.is_empty() and selected_structure < 0:
		return
	var click_cell := screen_to_cell(screen_position)
	if MapCatalog.in_bounds(click_cell):
		var context := cursor_context_at(screen_position)
		var cue_kind := &"attack" if context.get("state") == CursorSystem.ATTACK else &"queued" if append else &"order"
		var cue_color := ENEMY_COLOR if cue_kind == &"attack" else PLAYER_COLOR
		_effect_director.emit_click(screen_to_map_position(screen_position), cue_kind, cue_color, append)
	var target_id := command_target_at_screen(screen_position, false)
	if target_id >= 0:
		var target := simulation.entity(target_id)
		if (
			target.get("kind") == &"sentry_tower"
			and int(target.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and float(target.get("complete", 0.0)) >= 1.0
		):
			var ranged_units := _selected_garrison_units()
			if ranged_units.is_empty():
				feedback.emit("Select a Hunter or Mystic to garrison this tower.", true)
			elif simulation.command_garrison(
				RtsSimulation.TEAM_PLAYER,
				ranged_units,
				target_id,
				append,
			):
				feedback.emit("Tower garrison queued." if append else "Unit sent to the Sentry Tower.", false)
				audio_cue.emit(&"order_move")
			else:
				feedback.emit("This tower is already occupied.", true)
			return
		if target.get("kind") == &"shenlong_egg":
			var egg_workers := _selected_of_kind(&"worker")
			if egg_workers.is_empty():
				feedback.emit("Select an empty-handed Worker to claim the Dragon Egg.", true)
			elif simulation.command_claim_egg(RtsSimulation.TEAM_PLAYER, egg_workers, target_id, append):
				feedback.emit("Dragon Egg claim queued." if append else "Worker sent to claim the Dragon Egg.", false)
				audio_cue.emit(&"order_work")
			else:
				feedback.emit("The Dragon Egg is locked, carried, or the Worker has cargo.", true)
			return
		if target.get("category") == &"wildlife":
			var hunters := _selected_of_kind(&"hunter")
			if hunters.is_empty():
				feedback.emit("Only Hunters can hunt wildlife.", true)
			else:
				simulation.command_attack(RtsSimulation.TEAM_PLAYER, hunters, target_id, append)
				feedback.emit("Hunt queued." if append else "Hunters pursuing %s." % _display_name(target), false)
				audio_cue.emit(&"order_attack")
			return
		if target.get("kind") == &"yaoguai_den" and not commandable_units.is_empty():
			simulation.command_move(RtsSimulation.TEAM_PLAYER, commandable_units, target["cell"] as Vector2i, true, append)
			feedback.emit("Den hunt queued." if append else "Hunt the guardians, then hold the Den's capture ring.", false)
			audio_cue.emit(&"order_attack")
			return
		if not commandable_units.is_empty() and simulation.are_hostile(simulation.entity(commandable_units[0]), target):
			simulation.command_attack(RtsSimulation.TEAM_PLAYER, commandable_units, target_id, append)
			feedback.emit("Focus-fire queued." if append else "Focus-fire order issued.", false)
			audio_cue.emit(&"order_attack")
			return
		var construction_workers := _selected_of_kind(&"worker")
		if (
			not construction_workers.is_empty()
			and target.get("category") == &"structure"
			and int(target.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and float(target.get("complete", 1.0)) < 1.0
			and simulation.command_construct(
				RtsSimulation.TEAM_PLAYER,
				construction_workers,
				target_id,
				append,
			)
		):
			feedback.emit("Construction queued." if append else "Workers assigned to construction.", false)
			return
		var farm_workers := _selected_of_kind(&"worker")
		if (
			not farm_workers.is_empty()
			and target.get("kind") == &"rice_farm"
			and int(target.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and float(target.get("complete", 0.0)) >= 1.0
			and float(target.get("hp", 0.0)) >= float(target.get("max_hp", 0.0))
		):
			if simulation.command_assign_farm_worker(
				RtsSimulation.TEAM_PLAYER,
				farm_workers,
				target_id,
				append,
			):
				feedback.emit("Farm work queued." if append else "Worker assigned to the Rice Farm.", false)
				audio_cue.emit(&"order_work")
			elif simulation.farm_worker_id(target_id) >= 0:
				feedback.emit("This Rice Farm already has its maximum of one Worker.", true)
			else:
				feedback.emit("Assign an empty-handed Worker to this Rice Farm.", true)
			return
		if target.get("kind") == &"stronghold":
			var workers := _selected_of_kind(&"worker")
			var egg_carriers: Array[int] = []
			for worker_id in workers:
				if bool(simulation.entity(worker_id).get("carrying_egg", false)):
					egg_carriers.append(worker_id)
			if not egg_carriers.is_empty() and simulation.command_return_egg(RtsSimulation.TEAM_PLAYER, egg_carriers, target_id, append):
				feedback.emit("Dragon Egg return queued." if append else "Dragon Egg carrier returning to the Stronghold.", false)
				audio_cue.emit(&"order_work")
				return
			var carrying_workers: Array[int] = []
			for worker_id in workers:
				if float(simulation.entity(worker_id).get("cargo_amount", 0.0)) > 0.0:
					carrying_workers.append(worker_id)
			if not carrying_workers.is_empty():
				var deposited_workers := simulation.command_deposit(RtsSimulation.TEAM_PLAYER, carrying_workers, target_id, append)
				audio_cue.emit(&"order_work")
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
			audio_cue.emit(&"order_work")
			return
		if target.get("category") == &"resource":
			var workers := _selected_of_kind(&"worker")
			if not workers.is_empty():
				simulation.command_gather(RtsSimulation.TEAM_PLAYER, workers, target_id, append)
				audio_cue.emit(&"order_work")
				feedback.emit(
					"%s gathering queued." % _display_name(target) if append
					else "Workers assigned to %s." % _display_name(target),
					false,
				)
				return
	var cell := screen_to_cell(screen_position)
	if not MapCatalog.in_bounds(cell):
		_effect_director.emit_invalid(screen_to_map_position(screen_position))
		feedback.emit("That destination is beyond the map boundary.", true)
		return
	if selected_structure >= 0 and selected_commandable_units().is_empty():
		if simulation.set_rally(RtsSimulation.TEAM_PLAYER, selected_structure, cell):
			feedback.emit("Rally point updated.", false)
			audio_cue.emit(&"order_move")
	else:
		if simulation.command_move(RtsSimulation.TEAM_PLAYER, selected_commandable_units(), cell, false, append):
			feedback.emit("Move queued." if append else "Move order issued.", false)
			audio_cue.emit(&"order_move")


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
		if int(entity_state.get("garrisoned_in", -1)) >= 0:
			continue
		if rect.has_point(entity_screen_position(entity_state)) and not ids.has(int(entity_state["id"])):
			ids.append(int(entity_state["id"]))
	select_entities(ids)


func select_entities(ids: Array[int]) -> void:
	var previous := selected_ids.duplicate()
	selected_ids.clear()
	for id in ids:
		var entity_state := simulation.entity(id)
		if (
			not entity_state.is_empty()
			and bool(entity_state.get("alive", false))
			and int(entity_state.get("garrisoned_in", -1)) < 0
			and not selected_ids.has(id)
		):
			selected_ids.append(id)
	if not selected_ids.is_empty() and selected_ids != previous:
		audio_cue.emit(&"unit_select")
		_presentation.note_selection(selected_ids)
	selection_changed.emit(selected_ids.duplicate())
	_refresh_cursor()
	queue_redraw()


func select_all_workers() -> void:
	select_entities(simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"]))


func select_all_idle_workers() -> void:
	var idle_worker_ids: Array[int] = []
	for id in simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"]):
		if simulation.entity(id).get("order", &"idle") == &"idle":
			idle_worker_ids.append(id)
	select_entities(idle_worker_ids)


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
	audio_cue.emit(&"ui_confirm")
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
	if attack_move_armed:
		cancel_modes()
		audio_cue.emit(&"ui_cancel")
		feedback.emit("Attack-move cancelled.", false)
		return
	if selected_commandable_units().is_empty():
		feedback.emit("Select units before issuing attack-move.", true)
		return
	cancel_modes()
	attack_move_armed = true
	_armed_append = append
	_refresh_cursor()
	audio_cue.emit(&"ui_confirm")
	feedback.emit("Queued attack-move: choose a destination." if append else "Attack-move armed: choose a destination.", false)


func begin_move(append: bool = false) -> void:
	if move_armed:
		cancel_modes()
		audio_cue.emit(&"ui_cancel")
		feedback.emit("Move command cancelled.", false)
		return
	if selected_commandable_units().is_empty():
		feedback.emit("Select units before issuing a move.", true)
		return
	cancel_modes()
	move_armed = true
	_armed_append = append
	audio_cue.emit(&"ui_confirm")
	feedback.emit("Queued move: choose a destination." if append else "Move armed: choose a destination.", false)


func begin_patrol(append: bool = false) -> void:
	if patrol_armed:
		cancel_modes()
		audio_cue.emit(&"ui_cancel")
		feedback.emit("Patrol cancelled.", false)
		return
	if selected_military_units().is_empty():
		feedback.emit("Select military units before setting a patrol.", true)
		return
	cancel_modes()
	patrol_armed = true
	_armed_append = append
	_refresh_cursor()
	audio_cue.emit(&"ui_confirm")
	feedback.emit("Queued patrol: choose a destination." if append else "Patrol armed: choose a destination.", false)


func begin_repair(append: bool = false) -> void:
	if repair_armed:
		cancel_modes()
		audio_cue.emit(&"ui_cancel")
		feedback.emit("Repair command cancelled.", false)
		return
	if _selected_of_kind(&"worker").is_empty():
		feedback.emit("Select workers before issuing a repair order.", true)
		return
	cancel_modes()
	repair_armed = true
	_armed_append = append
	_refresh_cursor()
	audio_cue.emit(&"ui_confirm")
	feedback.emit("Queued repair: choose a structure." if append else "Repair armed: choose a damaged allied structure.", false)


func begin_rally() -> void:
	if rally_armed:
		cancel_modes()
		audio_cue.emit(&"ui_cancel")
		feedback.emit("Rally command cancelled.", false)
		return
	if primary_selected_structure() < 0:
		feedback.emit("Select an allied production structure before setting a rally point.", true)
		return
	cancel_modes()
	rally_armed = true
	audio_cue.emit(&"ui_confirm")
	feedback.emit("Rally point armed: choose a destination.", false)


func begin_war_camp_placement() -> void:
	begin_structure_placement(&"war_camp")


func begin_structure_placement(structure_kind: StringName) -> void:
	if placement_worker_id >= 0 and placement_kind == structure_kind:
		cancel_modes()
		audio_cue.emit(&"ui_cancel")
		feedback.emit("%s placement cancelled." % String(structure_kind).replace("_", " ").capitalize(), false)
		return
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
	placement_orientation = &"y"
	_refresh_cursor()
	audio_cue.emit(&"ui_confirm")
	var faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
	var structure_name := String(FactionCatalog.stats(structure_kind, faction)["name"])
	var placement_instruction := (
		"Drag a straight snapped line for the %s." % structure_name
		if structure_kind == &"wall"
		else "Drag to orient and place the %s." % structure_name
		if structure_kind == &"gate"
		else "Choose a clear walkable-land footprint for the %s." % structure_name
		if structure_kind in RtsSimulation.FORTIFICATION_STRUCTURE_KINDS
		else "Choose a clear meadow footprint for the %s." % structure_name
	)
	feedback.emit("%s Press R to rotate 90 degrees." % placement_instruction, false)


func rotate_structure_placement() -> bool:
	if placement_worker_id < 0 or placement_kind.is_empty():
		return false
	placement_orientation = &"x" if placement_orientation == &"y" else &"y"
	_refresh_cursor()
	queue_redraw()
	var faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
	var structure_name := String(FactionCatalog.stats(placement_kind, faction)["name"])
	feedback.emit("%s rotated 90 degrees." % structure_name, false)
	audio_cue.emit(&"ui_confirm")
	return true


func _automatic_drag_orientation(start: Vector2i, finish: Vector2i) -> StringName:
	# Wall art needs the opposite facing assignment from its original import.
	# Read the actual snapped line so diagonal ties cannot disagree with its axis.
	if placement_kind == &"wall":
		var snapped_cells := simulation.wall_line_cells(start, finish)
		var follows_map_x := (
			snapped_cells.size() < 2
			or snapped_cells[1].x != snapped_cells[0].x
		)
		return &"x" if follows_map_x else &"y"
	return simulation.gate_orientation(start, finish)


func cancel_modes() -> void:
	move_armed = false
	attack_move_armed = false
	patrol_armed = false
	repair_armed = false
	rally_armed = false
	placement_worker_id = -1
	placement_kind = &""
	placement_orientation = &"y"
	_placement_pressed = false
	_placement_start_cell = Vector2i(-1, -1)
	_placement_current_cell = Vector2i(-1, -1)
	_armed_append = false
	_refresh_cursor()


func selected_commandable_units() -> Array[int]:
	var result: Array[int] = []
	for id in selected_ids:
		var entity_state := simulation.entity(id)
		if (
			entity_state.get("category") == &"unit"
			and int(entity_state.get("team", -1)) == RtsSimulation.TEAM_PLAYER
			and int(entity_state.get("garrisoned_in", -1)) < 0
		):
			result.append(id)
	return result


func selected_military_units() -> Array[int]:
	var result: Array[int] = []
	for id in selected_ids:
		var entity_state := simulation.entity(id)
		if (
			entity_state.get("kind") in [&"hunter", &"vanguard", &"mystic", &"jadeclaw"]
			and int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and int(entity_state.get("garrisoned_in", -1)) < 0
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
		if (
			entity_state.get("kind") == kind
			and int(entity_state.get("team", -1)) == RtsSimulation.TEAM_PLAYER
			and int(entity_state.get("garrisoned_in", -1)) < 0
		):
			result.append(id)
	return result


func _selected_garrison_units() -> Array[int]:
	var result: Array[int] = []
	for id in selected_ids:
		var unit := simulation.entity(id)
		if (
			unit.get("kind") in RtsSimulation.GARRISON_UNIT_KINDS
			and int(unit.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and int(unit.get("garrisoned_in", -1)) < 0
		):
			result.append(id)
	return result


func screen_to_cell(screen_position: Vector2) -> Vector2i:
	return IsoProjection.cell_at((screen_position - camera_offset) / camera_scale)


func entity_screen_position(entity_state: Dictionary) -> Vector2:
	var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
	var center := entity_state["position"] as Vector2 + (Vector2(footprint) - Vector2.ONE) * 0.5
	return camera_offset + IsoProjection.position_center(center) * camera_scale


func entity_at_screen(screen_position: Vector2, selectable_only: bool) -> int:
	return _tile_entity_at_screen(screen_position, selectable_only)


func command_target_at_screen(screen_position: Vector2, selectable_only: bool) -> int:
	var sprite_hits: Array[Dictionary] = []
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if not _is_entity_pickable(entity_state, selectable_only):
			continue
		if _entity_sprite_contains_screen_point(entity_state, screen_position):
			sprite_hits.append(entity_state)
	if sprite_hits.size() == 1:
		return int(sprite_hits[0]["id"])
	if sprite_hits.size() > 1:
		# Sprite silhouettes make large art targetable, but an overlap is visually
		# ambiguous. Preserve the established tile-anchor rules for that case.
		return _tile_entity_at_screen(screen_position, selectable_only)
	return -1


func _tile_entity_at_screen(screen_position: Vector2, selectable_only: bool) -> int:
	var best_id := -1
	var best_distance := INF
	var best_priority := -1
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if not _is_entity_pickable(entity_state, selectable_only):
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
			&"objective":
				radius = 54.0 * camera_scale
				priority = 2
		var distance := entity_screen_position(entity_state).distance_to(screen_position)
		if distance <= maxf(radius, 16.0) and (priority > best_priority or (priority == best_priority and distance < best_distance)):
			best_priority = priority
			best_distance = distance
			best_id = int(entity_state["id"])
	return best_id


func _is_entity_pickable(entity_state: Dictionary, selectable_only: bool) -> bool:
	if (
		not bool(entity_state.get("alive", false))
		or int(entity_state.get("garrisoned_in", -1)) >= 0
		or not should_render_entity(entity_state)
	):
		return false
	if (
		camera_scale < TREE_ENTITY_MIN_SCALE
		and entity_state.get("resource_kind") == &"lumber"
	):
		var tree_cell := entity_state.get("cell", Vector2i(-1, -1)) as Vector2i
		if (
			posmod(tree_cell.x, MapCatalog.CELL_SCALE) != 0
			or posmod(tree_cell.y, MapCatalog.CELL_SCALE) != 0
		):
			return false
	return (
		not selectable_only
		or entity_state.get("category") in [
			&"unit",
			&"structure",
			&"resource",
			&"wildlife",
			&"objective",
		]
	)


func _entity_sprite_contains_screen_point(
	entity_state: Dictionary,
	screen_position: Vector2,
) -> bool:
	for geometry in _entity_sprite_pick_geometries(entity_state):
		if _sprite_geometry_contains_screen_point(geometry, screen_position):
			return true
	return false


func _entity_sprite_pick_geometries(entity_state: Dictionary) -> Array[Dictionary]:
	var geometries: Array[Dictionary] = []
	var category := entity_state.get("category", &"") as StringName
	var kind := entity_state.get("kind", &"") as StringName
	var texture: Texture2D
	if category == &"resource":
		texture = RESOURCE_TEXTURES.get(kind) as Texture2D
	else:
		texture = _entity_texture(
			entity_state.get("faction", &"neutral") as StringName,
			kind,
		)
	if texture == null:
		return geometries

	var display_size := _entity_sprite_display_size(entity_state, texture) * camera_scale
	var sprite_center := _grounded_sprite_screen_position(entity_state)
	if category == &"resource":
		if (
			entity_state.get("resource_kind") == &"lumber"
			and camera_scale >= TREE_SWAY_MIN_SCALE
		):
			var phase := _tree_wind_phase(entity_state)
			sprite_center += _tree_sway_offset(0.18, phase, display_size) * 0.22
		geometries.append(_sprite_pick_geometry(texture, sprite_center, display_size))
		return geometries

	var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
	var is_movable := category in [&"unit", &"wildlife"]
	var flip_h := false
	var rotation := 0.0
	if is_movable:
		var presentation_transform := _presentation.visual_transform(
			int(entity_state.get("id", -1))
		)
		sprite_center += (
			IsoProjection.project(presentation_transform["offset"] as Vector2)
			* camera_scale
		)
		sprite_center.y += _movement_bounce_offset(entity_state)
		flip_h = _movement_sprite_flipped(entity_state)
		rotation = (
			_idle_wobble_rotation(entity_state)
			+ _movement_lean_rotation(entity_state)
			+ float(presentation_transform["rotation"])
		)
		display_size *= (
			(presentation_transform["scale"] as Vector2)
			* _movement_squash_scale(entity_state)
		)

	var fits_footprint := kind in RtsSimulation.FORTIFICATION_STRUCTURE_KINDS
	var bottom_margin := (
		_character_art_bottom_margin(texture)
		if is_movable or fits_footprint
		else -1.0
	)
	var content_center_x := _texture_content_center_x(texture) if fits_footprint else -1.0
	if kind == &"wall":
		for orientation in _wall_render_orientations(entity_state):
			var wall_flip := _structure_sprite_flipped(
				kind,
				orientation,
				footprint,
				texture,
			)
			var wall_skew := _structure_sprite_axis_skew(
				kind,
				orientation,
				footprint,
				texture,
				display_size,
				wall_flip,
			)
			geometries.append(_sprite_pick_geometry(
				texture,
				sprite_center + _wall_sprite_axis_anchor_offset(orientation, camera_scale),
				display_size,
				wall_flip,
				0.0,
				bottom_margin,
				content_center_x,
				wall_skew,
			))
		return geometries

	if not is_movable and category == &"structure":
		flip_h = _structure_sprite_flipped(
			kind,
			entity_state.get("orientation", &"y") as StringName,
			footprint,
			texture,
		)
	var texture_center := sprite_center
	if kind == &"gate":
		texture_center += _gate_sprite_axis_anchor_offset(
			entity_state.get("orientation", &"y") as StringName,
			texture,
			display_size,
		)
	var axis_skew := 0.0
	if fits_footprint:
		axis_skew = _structure_sprite_axis_skew(
			kind,
			entity_state.get("orientation", &"y") as StringName,
			footprint,
			texture,
			display_size,
			flip_h,
		)
	geometries.append(_sprite_pick_geometry(
		texture,
		texture_center,
		display_size,
		flip_h,
		rotation,
		bottom_margin,
		content_center_x,
		axis_skew,
		kind == &"shenlong",
		int(entity_state.get("id", -1)),
	))
	return geometries


func _sprite_pick_geometry(
	texture: Texture2D,
	center: Vector2,
	display_size: Vector2,
	flip_h: bool = false,
	rotation: float = 0.0,
	content_bottom_margin_pixels: float = -1.0,
	content_center_x_pixels: float = -1.0,
	axis_skew: float = 0.0,
	waves: bool = false,
	entity_id: int = -1,
) -> Dictionary:
	var rect := _world_texture_rect(
		texture,
		display_size,
		content_bottom_margin_pixels,
		content_center_x_pixels,
	)
	var transform_center := center
	if content_bottom_margin_pixels >= 0.0 and not is_zero_approx(axis_skew):
		transform_center.y -= _skewed_texture_bottom_overhang(
			texture,
			display_size,
			content_center_x_pixels,
			axis_skew,
		)
	var horizontal_scale := -1.0 if flip_h else 1.0
	return {
		"texture": texture,
		"rect": rect,
		"transform": Transform2D(
			Vector2(horizontal_scale, axis_skew).rotated(rotation),
			Vector2(0.0, 1.0).rotated(rotation),
			transform_center,
		),
		"waves": waves,
		"entity_id": entity_id,
	}


func _sprite_geometry_contains_screen_point(
	geometry: Dictionary,
	screen_position: Vector2,
) -> bool:
	var texture := geometry.get("texture") as Texture2D
	if texture == null:
		return false
	var rect := geometry.get("rect", Rect2()) as Rect2
	if not rect.has_area():
		return false
	var transform := geometry.get("transform", Transform2D.IDENTITY) as Transform2D
	var inverse := transform.affine_inverse()
	var local_center: Vector2 = inverse * screen_position
	var broad_phase_margin := SPRITE_PICK_SAMPLE_RADIUS * 2.0
	if bool(geometry.get("waves", false)):
		broad_phase_margin += maxf(rect.size.x, rect.size.y) * 0.04
	if not rect.grow(broad_phase_margin).has_point(local_center):
		return false
	var mask := _texture_pick_mask(texture)
	var mask_size := mask.get_size()
	if mask_size.x <= 0 or mask_size.y <= 0:
		return false
	for offset in SPRITE_PICK_SAMPLE_OFFSETS:
		var local_point: Vector2 = inverse * (screen_position + offset)
		var uv: Vector2 = (local_point - rect.position) / rect.size
		if bool(geometry.get("waves", false)):
			for _iteration in range(2):
				var wave_offset: Vector2 = _shenlong_wave_offset(
					uv,
					rect.size,
					int(geometry.get("entity_id", -1)),
				)
				uv = (local_point - wave_offset - rect.position) / rect.size
		if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
			continue
		var pixel := Vector2i(
			mini(int(floor(uv.x * float(mask_size.x))), mask_size.x - 1),
			mini(int(floor(uv.y * float(mask_size.y))), mask_size.y - 1),
		)
		if mask.get_bitv(pixel):
			return true
	return false


func _texture_pick_mask(texture: Texture2D) -> BitMap:
	var cache_key := texture.resource_path
	if cache_key.is_empty():
		cache_key = str(texture.get_instance_id())
	if _texture_pick_mask_cache.has(cache_key):
		return _texture_pick_mask_cache[cache_key] as BitMap
	var mask := BitMap.new()
	var image := texture.get_image()
	if image != null and not image.is_empty():
		mask.create_from_image_alpha(image, SPRITE_PICK_ALPHA_THRESHOLD)
	_texture_pick_mask_cache[cache_key] = mask
	return mask


func cursor_context_at(screen_position: Vector2) -> Dictionary:
	if simulation == null or not simulation.outcome.is_empty():
		return _cursor_context(CursorSystem.SELECT)
	if _middle_dragging:
		return _cursor_context(CursorSystem.PAN)
	if _selection_pressed and _selection_dragging:
		return _cursor_context(CursorSystem.BOX_SELECT)

	var cell := screen_to_cell(screen_position)
	var target_id := command_target_at_screen(screen_position, false)
	if placement_worker_id >= 0:
		var start_cell := _placement_start_cell if _placement_pressed else cell
		var can_build := false
		if placement_kind == &"wall":
			can_build = simulation.can_place_wall_line(
				RtsSimulation.TEAM_PLAYER,
				start_cell,
				cell,
				placement_orientation,
			)
		else:
			can_build = (
				MapCatalog.in_bounds(cell)
				and simulation.can_place_structure(
					RtsSimulation.TEAM_PLAYER,
					placement_kind,
					start_cell,
					placement_orientation,
				)
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
		if (
			target.get("kind") == &"sentry_tower"
			and int(target.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
			and not _selected_garrison_units().is_empty()
		):
			var has_space: bool = (target.get("garrisoned_unit_ids", []) as Array).size() < int(target.get("garrison_capacity", 0))
			return _cursor_context(CursorSystem.MOVE if has_space else CursorSystem.FORBIDDEN, target_id, has_space)
		if target.get("kind") == &"shenlong_egg" and not _selected_of_kind(&"worker").is_empty():
			var can_claim := bool(target.get("claimable", false)) and int(target.get("carried_by", -1)) < 0
			return _cursor_context(CursorSystem.GATHER_ESSENCE if can_claim else CursorSystem.FORBIDDEN, target_id, can_claim)
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
		if not workers.is_empty() and _cursor_can_construct_target(target_id):
			return _cursor_context(CursorSystem.BUILD, target_id)
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


func _cursor_can_construct_target(target_id: int) -> bool:
	if target_id < 0:
		return false
	var target := simulation.entity(target_id)
	return (
		not target.is_empty()
		and bool(target.get("alive", false))
		and target.get("category") == &"structure"
		and int(target.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
		and float(target.get("complete", 1.0)) < 1.0
	)


func _any_worker_carrying(workers: Array[int]) -> bool:
	for worker_id in workers:
		var worker := simulation.entity(worker_id)
		if float(worker.get("cargo_amount", 0.0)) > 0.0 or bool(worker.get("carrying_egg", false)):
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


func _update_camera_pan(delta: float) -> void:
	if delta <= 0.0:
		return
	var direction := Input.get_vector(
		&"camera_left",
		&"camera_right",
		&"camera_up",
		&"camera_down",
	)
	var target_velocity := direction * CAMERA_PAN_SPEED
	if target_velocity.is_zero_approx() and _camera_pan_velocity.length() <= CAMERA_PAN_STOP_EPSILON:
		_camera_pan_velocity = Vector2.ZERO
		return

	# Integrate exponential velocity smoothing exactly so uneven browser frame
	# times do not change the distance or feel of keyboard camera movement.
	var previous_velocity := _camera_pan_velocity
	var velocity_difference := previous_velocity - target_velocity
	var decay := exp(-CAMERA_PAN_RESPONSE * delta)
	_camera_pan_velocity = target_velocity + velocity_difference * decay
	var displacement := (
		target_velocity * delta
		+ velocity_difference * ((1.0 - decay) / CAMERA_PAN_RESPONSE)
	)
	var unclamped_offset := camera_offset - displacement
	camera_offset = unclamped_offset
	_clamp_camera()
	if not displacement.is_zero_approx():
		queue_redraw()
	if not is_equal_approx(camera_offset.x, unclamped_offset.x):
		_camera_pan_velocity.x = 0.0
	if not is_equal_approx(camera_offset.y, unclamped_offset.y):
		_camera_pan_velocity.y = 0.0


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
	var considered_entities := 0
	for entity_id in selected_ids:
		var entity_state := simulation.entity(entity_id)
		if (
			entity_state.is_empty()
			or not bool(entity_state.get("alive", false))
			or int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) != RtsSimulation.TEAM_PLAYER
		):
			continue
		if considered_entities >= MAX_VISIBLE_COMMAND_PATHS:
			break
		var record: Dictionary = {}
		match entity_state.get("category") as StringName:
			&"unit":
				record = _command_visualization_record(entity_state)
			&"structure":
				record = _rally_visualization_record(entity_state)
			_:
				continue
		considered_entities += 1
		if record.is_empty():
			continue
		var dedupe_key := _command_visualization_dedupe_key(record)
		if seen.has(dedupe_key):
			continue
		seen[dedupe_key] = true
		records.append(record)
	return records


func _rally_visualization_record(structure: Dictionary) -> Dictionary:
	if not structure.has("rally_cell"):
		return {}
	var rally_cell := structure.get("rally_cell", Vector2i(-1, -1)) as Vector2i
	if not MapCatalog.in_bounds(rally_cell):
		return {}
	var origin := _entity_world_center(structure)
	var endpoint := Vector2(rally_cell)
	var points: Array[Vector2] = []
	_append_command_route_point(points, origin)
	_append_command_route_point(points, endpoint)
	return {
		"entity_id": int(structure.get("id", -1)),
		"kind": &"flag",
		"target_id": -1,
		"endpoint": endpoint,
		"points": points,
	}


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
	elif order in [&"gather", &"claim_egg", &"build", &"repair"] and has_live_target:
		indicator_kind = &"interact"
		endpoint = _entity_world_center(target)
	elif order in [&"return", &"return_egg"]:
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
	var logical_camera_offset := camera_offset
	camera_offset += _effect_director.current_camera_offset()
	draw_rect(Rect2(Vector2.ZERO, size), BATTLEFIELD_BACKGROUND_COLOR)
	_draw_terrain()
	_draw_environment_sheen()
	_draw_map_edge_fade()
	_draw_effect_underlay()
	_draw_hover_feedback()
	_draw_entities()
	_draw_death_snapshots()
	_draw_hover_overlay()
	_draw_effects()
	_draw_fog_of_war()
	_draw_command_visualizations(_command_visualization_records())
	if _selection_pressed and _selection_dragging:
		var rect := Rect2(_selection_start, _selection_current - _selection_start).abs()
		draw_rect(rect, Color(0.32, 0.93, 0.72, 0.12), true)
		draw_rect(rect, PLAYER_COLOR, false, 1.5)
	camera_offset = logical_camera_offset


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


func _transformed_map_polygon() -> PackedVector2Array:
	var map_size := Vector2(MapCatalog.SIZE)
	return PackedVector2Array([
		camera_offset,
		IsoProjection.project(Vector2(map_size.x, 0.0)) * camera_scale + camera_offset,
		IsoProjection.project(map_size) * camera_scale + camera_offset,
		IsoProjection.project(Vector2(0.0, map_size.y)) * camera_scale + camera_offset,
	])


func _draw_map_edge_fade() -> void:
	_ensure_map_edge_bands()
	draw_set_transform(camera_offset, 0.0, Vector2.ONE * camera_scale)
	for band in _map_edge_projected_bands:
		var color := band["color"] as Color
		for polygon in band["polygons"] as Array[PackedVector2Array]:
			draw_colored_polygon(polygon, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ensure_map_edge_bands() -> void:
	if not _map_edge_projected_bands.is_empty():
		return
	var contour = MAP_EDGE_CONTOUR_SCRIPT.new(MapCatalog.SIZE)
	var definitions: Array[Dictionary] = [
		{"depth": 2.40, "alpha": 0.12},
		{"depth": 1.35, "alpha": 0.30},
		{"depth": 0.42, "alpha": 0.94},
	]
	for definition in definitions:
		var projected_polygons: Array[PackedVector2Array] = []
		for map_polygon in contour.band_polygons(float(definition["depth"])):
			var projected := PackedVector2Array()
			for map_point in map_polygon:
				projected.append(IsoProjection.project(map_point))
			projected_polygons.append(projected)
		_map_edge_projected_bands.append({
			"color": Color(BATTLEFIELD_BACKGROUND_COLOR, float(definition["alpha"])),
			"polygons": projected_polygons,
		})


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
	var hovered_id := int(_presentation.hovered_entity_id)
	if hovered_id >= 0:
		var hovered := simulation.entity(hovered_id)
		if not hovered.is_empty() and should_render_entity(hovered):
			var hover_center := _selection_ring_screen_position(hovered)
			var hover_strength := _presentation.hover_strength(hovered_id)
			var hover_color := _team_color(int(hovered.get("team", RtsSimulation.TEAM_NEUTRAL)))
			var hover_radius := _entity_ring_radius(hovered)
			_draw_ellipse(
				hover_center,
				hover_radius.x * camera_scale * (1.04 + hover_strength * 0.04),
				hover_radius.y * camera_scale * (1.04 + hover_strength * 0.04),
				Color(hover_color, 0.32 + hover_strength * 0.22),
				maxf(1.2, 1.8 * camera_scale),
			)
	if placement_worker_id >= 0:
		var faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
		var texture := _entity_texture(faction, placement_kind)
		var start_cell := _placement_start_cell if _placement_pressed else cell
		var preview_cells: Array[Vector2i] = [start_cell]
		if placement_kind == &"wall":
			preview_cells = simulation.wall_line_cells(start_cell, cell)
		var orientation := placement_orientation
		var valid := (
			simulation.can_place_wall_line(
				RtsSimulation.TEAM_PLAYER,
				start_cell,
				cell,
				placement_orientation,
			)
			if placement_kind == &"wall"
			else simulation.can_place_structure(
				RtsSimulation.TEAM_PLAYER,
				placement_kind,
				start_cell,
				orientation,
			) and simulation.can_afford_kind(RtsSimulation.TEAM_PLAYER, placement_kind)
		)
		var color := PLAYER_COLOR if valid else ENEMY_COLOR
		for preview_cell in preview_cells:
			var footprint := simulation.structure_footprint(
				RtsSimulation.TEAM_PLAYER,
				placement_kind,
				orientation,
			)
			for footprint_cell in MapCatalog.footprint_cells(preview_cell, footprint):
				var footprint_points := IsoProjection.transformed_polygon(footprint_cell, camera_scale, camera_offset)
				var footprint_closed := footprint_points.duplicate()
				footprint_closed.append(footprint_points[0])
				draw_colored_polygon(footprint_points, Color(color, 0.24))
				draw_polyline(footprint_closed, color, 2.5, true)
			var center_position := Vector2(preview_cell) + (Vector2(footprint) - Vector2.ONE) * 0.5
			var ghost_center := camera_offset + IsoProjection.position_center(center_position) * camera_scale
			var fits_footprint := placement_kind in RtsSimulation.FORTIFICATION_STRUCTURE_KINDS
			var ghost_size := _structure_display_size(placement_kind, footprint, texture) * camera_scale
			if not fits_footprint:
				ghost_size *= 0.78
			var sprite_flip := _structure_sprite_flipped(
				placement_kind,
				orientation,
				footprint,
				texture,
			)
			var axis_skew := _structure_sprite_axis_skew(
				placement_kind,
				orientation,
				footprint,
				texture,
				ghost_size,
				sprite_flip,
			)
			var structure_axis_offset := (
				_gate_sprite_axis_anchor_offset(orientation, texture, ghost_size)
				if placement_kind == &"gate"
				else _wall_sprite_axis_anchor_offset(orientation, camera_scale)
				if placement_kind == &"wall"
				else Vector2.ZERO
			)
			_draw_world_texture(
				texture,
				ghost_center + _footprint_ground_offset(footprint) + structure_axis_offset,
				ghost_size,
				Color(1, 1, 1, 0.58 if valid else 0.35),
				sprite_flip,
				0.0,
				_character_art_bottom_margin(texture) if fits_footprint else -1.0,
				_texture_content_center_x(texture) if fits_footprint else -1.0,
				axis_skew,
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
	_rebuild_wall_render_lookup()
	var renderables: Array[Dictionary] = []
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if int(entity_state.get("garrisoned_in", -1)) >= 0:
			continue
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
	var first_depth := _entity_draw_depth(first)
	var second_depth := _entity_draw_depth(second)
	if first_depth != second_depth:
		return first_depth < second_depth
	if first_position.x != second_position.x:
		return first_position.x < second_position.x
	if first_position.y != second_position.y:
		return first_position.y < second_position.y
	return int(first.get("id", -1)) < int(second.get("id", -1))


func _entity_draw_depth(entity_state: Dictionary) -> float:
	var position := entity_state["position"] as Vector2
	var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
	var footprint_depth := float(footprint.x + footprint.y)
	if entity_state.get("category") in [&"unit", &"wildlife"]:
		# Moving sprites touch the ground at their projected tile center.
		footprint_depth *= 0.5
	# Static art is bottom-anchored at the southeast edge of its footprint. Sorting
	# on that same edge keeps units behind walls, gates, and buildings underneath
	# them while entities farther south/east are still painted later.
	return IsoProjection.depth(position) + footprint_depth


func _draw_entity(entity_state: Dictionary) -> void:
	var center := entity_screen_position(entity_state)
	var entity_id := int(entity_state.get("id", -1))
	var category := entity_state.get("category") as StringName
	var kind := entity_state.get("kind") as StringName
	var selected := selected_ids.has(int(entity_state["id"]))
	var tint := Color.WHITE
	if int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) > RtsSimulation.TEAM_PLAYER:
		tint = Color(1.0, 0.9, 0.88, 1.0)
	var hit_strength := _presentation.hit_flash(entity_id)
	if hit_strength > 0.0:
		tint = tint.lerp(Color(1.0, 0.52, 0.38, 1.0), hit_strength * 0.9)
	var hover_strength := _presentation.hover_strength(entity_id)
	if hover_strength > 0.0:
		tint = tint.lerp(Color(1.1, 1.1, 0.96, tint.a), hover_strength * 0.18)
	if float(entity_state.get("complete", 1.0)) < 1.0:
		tint.a = 0.55 + float(entity_state["complete"]) * 0.45
	if category == &"wildlife":
		tint.a *= _presentation.wildlife_opacity(entity_id)
	if kind == &"stronghold":
		_draw_stronghold_aura(entity_state, center)
	if kind in [&"jadeclaw", &"shenlong", &"shenlong_egg", &"yaoguai_den", &"rice_farm", &"hunters_lodge"]:
		var allegiance := _team_color(int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)))
		var allegiance_radius_x := 58.0 if kind == &"shenlong" else 35.0 if kind == &"jadeclaw" else 42.0 if kind == &"shenlong_egg" else (78.0 if kind in [&"yaoguai_den", &"rice_farm"] else 58.0)
		var allegiance_radius_y := 25.0 if kind == &"shenlong" else 16.0 if kind == &"jadeclaw" else 18.0 if kind == &"shenlong_egg" else (34.0 if kind in [&"yaoguai_den", &"rice_farm"] else 26.0)
		_draw_ellipse(
			center + Vector2(0.0, 4.0 * camera_scale),
			allegiance_radius_x * camera_scale,
			allegiance_radius_y * camera_scale,
			Color(allegiance, 0.78),
			2.2,
		)

	if selected:
		var selection_radius := _entity_ring_radius(entity_state)
		var radius_x := selection_radius.x
		var radius_y := selection_radius.y
		_draw_ellipse(_selection_ring_screen_position(entity_state), radius_x * camera_scale, radius_y * camera_scale, Color("fff0a0"), 2.4)
		var selection_strength := _presentation.selection_strength(entity_id)
		_draw_ellipse_arc(
			_selection_ring_screen_position(entity_state),
			radius_x * camera_scale * (1.12 + selection_strength * 0.06),
			radius_y * camera_scale * (1.12 + selection_strength * 0.06),
			_command_indicator_time * 0.55 + float(entity_id) * 0.19,
			PI * 1.38,
			Color(1.0, 0.94, 0.62, 0.42),
			maxf(1.0, 1.5 * camera_scale),
		)

	if category == &"resource":
		var texture := RESOURCE_TEXTURES.get(kind) as Texture2D
		var is_tree: bool = entity_state.get("resource_kind") == &"lumber"
		var resource_size := _entity_sprite_display_size(entity_state, texture)
		var sprite_center := _grounded_sprite_screen_position(entity_state)
		if is_tree:
			_draw_tree_texture(texture, sprite_center, resource_size * camera_scale, tint, entity_state)
		else:
			_draw_world_texture(texture, sprite_center, resource_size * camera_scale, tint)
		_draw_resource_bar(entity_state, sprite_center)
	else:
		var texture := _entity_texture(entity_state["faction"] as StringName, kind)
		var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
		var display_size := _entity_sprite_display_size(entity_state, texture)
		var is_movable := category in [&"unit", &"wildlife"]
		var sprite_center := _grounded_sprite_screen_position(entity_state)
		var flip_h := false
		var rotation := 0.0
		var axis_skew := 0.0
		var presentation_scale := Vector2.ONE
		if is_movable:
			var presentation_transform := _presentation.visual_transform(entity_id)
			sprite_center += IsoProjection.project(presentation_transform["offset"] as Vector2) * camera_scale
			sprite_center.y += _movement_bounce_offset(entity_state)
			flip_h = _movement_sprite_flipped(entity_state)
			rotation = (
				_idle_wobble_rotation(entity_state)
				+ _movement_lean_rotation(entity_state)
				+ float(presentation_transform["rotation"])
			)
			presentation_scale = (presentation_transform["scale"] as Vector2) * _movement_squash_scale(entity_state)
		elif category == &"structure":
			flip_h = _structure_sprite_flipped(
				kind,
				entity_state.get("orientation", &"y") as StringName,
				footprint,
				texture,
			)
		var scaled_display_size := display_size * camera_scale * presentation_scale
		var texture_center := sprite_center
		if kind == &"gate":
			texture_center += _gate_sprite_axis_anchor_offset(
				entity_state.get("orientation", &"y") as StringName,
				texture,
				scaled_display_size,
			)
		elif kind == &"wall":
			texture_center += _wall_sprite_axis_anchor_offset(
				entity_state.get("orientation", &"y") as StringName,
				camera_scale,
			)
		var fits_footprint := kind in RtsSimulation.FORTIFICATION_STRUCTURE_KINDS
		if fits_footprint:
			axis_skew = _structure_sprite_axis_skew(
				kind,
				entity_state.get("orientation", &"y") as StringName,
				footprint,
				texture,
				scaled_display_size,
				flip_h,
			)
		var bottom_margin := _character_art_bottom_margin(texture) if is_movable or fits_footprint else -1.0
		var content_center_x := _texture_content_center_x(texture) if fits_footprint else -1.0
		var wall_render_orientations: Array[StringName] = []
		if kind == &"wall":
			wall_render_orientations = _wall_render_orientations(entity_state)
		if kind == &"wall":
			_draw_wall_joint_segments(
				texture,
				sprite_center,
				scaled_display_size,
				tint,
				wall_render_orientations,
			)
		elif kind == &"shenlong":
			_draw_shenlong_texture(
				texture,
				sprite_center,
				scaled_display_size,
				tint,
				entity_state,
				flip_h,
				rotation,
				bottom_margin,
			)
		else:
			_draw_world_texture(
				texture,
				texture_center,
				scaled_display_size,
				tint,
				flip_h,
				rotation,
				bottom_margin,
				content_center_x,
				axis_skew,
			)
		if kind == &"stronghold":
			_draw_stronghold_particles(entity_state, center, scaled_display_size)
		if kind == &"yaoguai_den":
			_draw_cave_status(entity_state, sprite_center)
		elif kind != &"shenlong_egg":
			_draw_health_bar(entity_state, sprite_center, category)
		if kind == &"sentry_tower":
			_draw_tower_occupants(entity_state, sprite_center)
		if kind in RtsSimulation.FOOD_PRODUCER_KINDS and float(entity_state.get("complete", 0.0)) >= 1.0:
			_draw_food_progress(entity_state, sprite_center)

	if kind == &"worker":
		if float(entity_state.get("cargo_amount", 0.0)) > 0.0:
			_draw_worker_cargo_icon(entity_state, center)
		elif _worker_has_farm_assignment(entity_state):
			_draw_farm_worker_icon(center)


func _draw_tower_occupants(tower: Dictionary, tower_sprite_center: Vector2) -> void:
	for draw_data in _tower_occupant_draw_data(tower, tower_sprite_center):
		var unit := draw_data["unit"] as Dictionary
		var texture := _entity_texture(unit["faction"] as StringName, unit["kind"] as StringName)
		_draw_world_texture(
			texture,
			draw_data["center"] as Vector2,
			TOWER_OCCUPANT_DISPLAY_SIZE * camera_scale,
			Color.WHITE,
			false,
			0.0,
			_character_art_bottom_margin(texture),
		)


func _tower_occupant_draw_data(
	tower: Dictionary,
	tower_sprite_center: Vector2,
) -> Array[Dictionary]:
	var occupants := tower.get("garrisoned_unit_ids", []) as Array
	if occupants.is_empty():
		return []
	var live_occupants: Array[Dictionary] = []
	for raw_id in occupants:
		var unit := simulation.entity(int(raw_id))
		if not unit.is_empty() and bool(unit.get("alive", false)):
			live_occupants.append(unit)
	if live_occupants.is_empty():
		return []
	var tower_texture := _entity_texture(
		tower["faction"] as StringName,
		tower["kind"] as StringName,
	)
	var result: Array[Dictionary] = []
	for index in range(live_occupants.size()):
		result.append({
			"unit": live_occupants[index],
			"center": _tower_rooftop_screen_position(
				tower,
				tower_sprite_center,
				tower_texture,
				_tower_rooftop_source_slot(index, live_occupants.size()),
			),
		})
	return result


func _tower_rooftop_source_slot(index: int, occupant_count: int) -> Vector2:
	if occupant_count <= 1:
		return Vector2(TOWER_ROOFTOP_SOURCE_CENTER_X, TOWER_ROOFTOP_SOURCE_Y)
	var weight := float(index) / float(occupant_count - 1)
	return Vector2(
		TOWER_ROOFTOP_SOURCE_CENTER_X
			+ lerpf(-TOWER_ROOFTOP_SOURCE_SPAN_X * 0.5, TOWER_ROOFTOP_SOURCE_SPAN_X * 0.5, weight),
		TOWER_ROOFTOP_SOURCE_Y,
	)


func _tower_rooftop_screen_position(
	tower: Dictionary,
	tower_sprite_center: Vector2,
	tower_texture: Texture2D,
	source_position: Vector2,
) -> Vector2:
	if tower_texture == null:
		return tower_sprite_center
	var footprint := tower.get("footprint", Vector2i.ONE) as Vector2i
	var display_size := _structure_display_size(&"sentry_tower", footprint, tower_texture) * camera_scale
	var bottom_margin := _character_art_bottom_margin(tower_texture)
	var content_center_x := _texture_content_center_x(tower_texture)
	var texture_rect := _world_texture_rect(
		tower_texture,
		display_size,
		bottom_margin,
		content_center_x,
	)
	var flip_h := _structure_sprite_flipped(
		&"sentry_tower",
		tower.get("orientation", &"y") as StringName,
		footprint,
		tower_texture,
	)
	var axis_skew := _structure_sprite_axis_skew(
		&"sentry_tower",
		tower.get("orientation", &"y") as StringName,
		footprint,
		tower_texture,
		display_size,
		flip_h,
	)
	var transform_center := tower_sprite_center
	if not is_zero_approx(axis_skew):
		transform_center.y -= _skewed_texture_bottom_overhang(
			tower_texture,
			display_size,
			content_center_x,
			axis_skew,
		)
	var local_position := texture_rect.position + Vector2(
		source_position.x * display_size.x / maxf(float(tower_texture.get_width()), 1.0),
		source_position.y * display_size.y / maxf(float(tower_texture.get_height()), 1.0),
	)
	var horizontal_scale := -1.0 if flip_h else 1.0
	return transform_center + Vector2(
		local_position.x * horizontal_scale,
		local_position.y + local_position.x * axis_skew,
	)


func _draw_worker_cargo_icon(worker: Dictionary, center: Vector2) -> void:
	var cargo_kind := worker.get("cargo_kind", &"") as StringName
	var texture := _cargo_icon_texture(cargo_kind)
	if texture == null:
		return
	var icon_size := clampf(23.0 * camera_scale, 12.0, 26.0)
	var icon_center := center + Vector2(24.0, -48.0) * camera_scale
	var cargo_color := _resource_color(cargo_kind)
	var plate_radius := icon_size * 0.57
	draw_circle(icon_center, plate_radius, Color(0.015, 0.035, 0.035, 0.9))
	draw_arc(
		icon_center,
		plate_radius,
		0.0,
		TAU,
		24,
		Color(cargo_color, 0.9),
		maxf(1.0, 1.35 * camera_scale),
		true,
	)
	var rect := Rect2(icon_center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
	draw_texture_rect(texture, rect, false)


func _cargo_icon_texture(cargo_kind: StringName) -> Texture2D:
	return CARGO_ICON_TEXTURES.get(cargo_kind) as Texture2D


func _worker_has_farm_assignment(worker: Dictionary) -> bool:
	if worker.get("order", &"idle") != &"farm":
		return false
	var farm := simulation.entity(int(worker.get("target_id", -1)))
	return (
		not farm.is_empty()
		and bool(farm.get("alive", false))
		and farm.get("kind") == &"rice_farm"
		and int(farm.get("farm_worker_id", -1)) == int(worker.get("id", -1))
	)


func _draw_farm_worker_icon(center: Vector2) -> void:
	var icon_size := clampf(23.0 * camera_scale, 12.0, 26.0)
	var icon_center := center + Vector2(24.0, -48.0) * camera_scale
	var plate_radius := icon_size * 0.57
	draw_circle(icon_center, plate_radius, Color(0.015, 0.035, 0.035, 0.9))
	draw_arc(
		icon_center,
		plate_radius,
		0.0,
		TAU,
		24,
		Color(FOOD_RESOURCE_COLOR, 0.95),
		maxf(1.0, 1.35 * camera_scale),
		true,
	)
	var rect := Rect2(icon_center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size)
	draw_texture_rect(FARM_WORKER_ICON_TEXTURE, rect, false)


func _draw_world_texture(
	texture: Texture2D,
	center: Vector2,
	display_size: Vector2,
	tint: Color,
	flip_h: bool = false,
	rotation: float = 0.0,
	content_bottom_margin_pixels: float = -1.0,
	content_center_x_pixels: float = -1.0,
	axis_skew: float = 0.0,
) -> void:
	if texture == null:
		return
	var rect := _world_texture_rect(
		texture,
		display_size,
		content_bottom_margin_pixels,
		content_center_x_pixels,
	)
	var transform_center := center
	if content_bottom_margin_pixels >= 0.0 and not is_zero_approx(axis_skew):
		transform_center.y -= _skewed_texture_bottom_overhang(
			texture,
			display_size,
			content_center_x_pixels,
			axis_skew,
		)
	var horizontal_scale := -1.0 if flip_h else 1.0
	var x_axis := Vector2(horizontal_scale, axis_skew).rotated(rotation)
	var y_axis := Vector2(0.0, 1.0).rotated(rotation)
	draw_set_transform_matrix(Transform2D(x_axis, y_axis, transform_center))
	draw_texture_rect(texture, rect, false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shenlong_texture(
	texture: Texture2D,
	center: Vector2,
	display_size: Vector2,
	tint: Color,
	entity_state: Dictionary,
	flip_h: bool,
	rotation: float,
	content_bottom_margin_pixels: float,
) -> void:
	if texture == null:
		return
	_draw_shenlong_aura(center, display_size, entity_state, flip_h, rotation)
	if camera_scale < SHENLONG_WAVE_MIN_SCALE:
		_draw_world_texture(
			texture,
			center,
			display_size,
			tint,
			flip_h,
			rotation,
			content_bottom_margin_pixels,
		)
		return
	var rect := _world_texture_rect(texture, display_size, content_bottom_margin_pixels)
	var entity_id := int(entity_state.get("id", 0))
	var colors := PackedColorArray([tint, tint, tint, tint])
	draw_set_transform(center, rotation, Vector2(-1.0 if flip_h else 1.0, 1.0))
	for row in range(SHENLONG_MESH_ROWS):
		var v0 := float(row) / float(SHENLONG_MESH_ROWS)
		var v1 := float(row + 1) / float(SHENLONG_MESH_ROWS)
		for column in range(SHENLONG_MESH_COLUMNS):
			var u0 := float(column) / float(SHENLONG_MESH_COLUMNS)
			var u1 := float(column + 1) / float(SHENLONG_MESH_COLUMNS)
			var uv_top_left := Vector2(u0, v0)
			var uv_top_right := Vector2(u1, v0)
			var uv_bottom_right := Vector2(u1, v1)
			var uv_bottom_left := Vector2(u0, v1)
			var points := PackedVector2Array([
				_shenlong_mesh_point(rect, uv_top_left, display_size, entity_id),
				_shenlong_mesh_point(rect, uv_top_right, display_size, entity_id),
				_shenlong_mesh_point(rect, uv_bottom_right, display_size, entity_id),
				_shenlong_mesh_point(rect, uv_bottom_left, display_size, entity_id),
			])
			var uvs := PackedVector2Array([
				uv_top_left,
				uv_top_right,
				uv_bottom_right,
				uv_bottom_left,
			])
			draw_polygon(points, colors, uvs, texture)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _shenlong_mesh_point(
	rect: Rect2,
	uv: Vector2,
	display_size: Vector2,
	entity_id: int,
) -> Vector2:
	return rect.position + rect.size * uv + _shenlong_wave_offset(uv, display_size, entity_id)


func _shenlong_wave_offset(uv: Vector2, display_size: Vector2, entity_id: int) -> Vector2:
	# The lower silhouette stays planted while overlapping waves travel through
	# the coiled body. Edge-weighted harmonics give the mane, whiskers, and tail
	# a quicker flutter without turning the heavier torso rubbery.
	var ground_flex := pow(clampf((0.92 - uv.y) / 0.82, 0.0, 1.0), 1.25)
	if ground_flex <= 0.0:
		return Vector2.ZERO
	var seed := deg_to_rad(float(posmod(entity_id * 97, 360)))
	var silhouette_weight := 0.45 + sin(uv.x * PI) * 0.55
	var edge_weight := pow(absf(uv.x - 0.5) * 2.0, 1.4)
	var body_phase := _wind_animation_time * 1.35 + uv.y * TAU * 1.30 + seed
	var hair_phase := (
		_wind_animation_time * 2.45
		- uv.x * TAU * 1.65
		+ uv.y * TAU * 1.10
		+ seed * 0.7
	)
	var horizontal := sin(body_phase) * display_size.x * 0.022 * silhouette_weight
	horizontal += sin(hair_phase) * display_size.x * 0.012 * (0.25 + edge_weight * 0.75)
	var vertical := cos(body_phase * 0.82 + uv.x * PI) * display_size.y * 0.011
	vertical += sin(hair_phase * 0.74) * display_size.y * 0.006 * edge_weight
	return Vector2(horizontal, vertical) * ground_flex


func _draw_shenlong_aura(
	center: Vector2,
	display_size: Vector2,
	entity_state: Dictionary,
	flip_h: bool,
	rotation: float,
) -> void:
	if camera_scale < SHENLONG_WAVE_MIN_SCALE:
		return
	var entity_id := int(entity_state.get("id", 0))
	var seed := deg_to_rad(float(posmod(entity_id * 71, 360)))
	var aura_color := _team_color(int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)))
	var pulse := 1.0 + sin(_wind_animation_time * 1.7 + seed) * 0.045
	draw_set_transform(center, rotation, Vector2(-1.0 if flip_h else 1.0, 1.0))
	_draw_ellipse(
		Vector2(0.0, -display_size.y * 0.43),
		display_size.x * 0.39 * pulse,
		display_size.y * 0.29 * pulse,
		Color(aura_color, 0.16),
		maxf(1.0, 2.2 * camera_scale),
	)
	for wisp_index in range(SHENLONG_AURA_WISP_COUNT):
		var side := -1.0 if wisp_index % 2 == 0 else 1.0
		var wisp_phase := (
			_wind_animation_time * (0.82 + float(wisp_index) * 0.09)
			+ seed
			+ float(wisp_index) * 1.37
		)
		var origin := Vector2(
			side * display_size.x * (0.22 + float(wisp_index % 3) * 0.055),
			-display_size.y * (0.27 + float(wisp_index % 2) * 0.16),
		)
		var points := PackedVector2Array()
		for point_index in range(12):
			var progress := float(point_index) / 11.0
			var curl := wisp_phase + progress * TAU * 0.72
			points.append(origin + Vector2(
				side * progress * display_size.x * 0.17
				+ sin(curl) * display_size.x * 0.027,
				-progress * display_size.y * 0.28
				+ cos(curl * 1.18) * display_size.y * 0.018,
			))
		draw_polyline(
			points,
			Color(aura_color.lerp(Color.WHITE, 0.38), 0.18),
			maxf(1.0, (1.2 + float(wisp_index % 2) * 0.7) * camera_scale),
			true,
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _stronghold_effect_profile(stronghold: Dictionary) -> Dictionary:
	var level := int(stronghold.get("stronghold_level", RtsSimulation.STRONGHOLD_INITIAL_LEVEL))
	if level <= RtsSimulation.STRONGHOLD_INITIAL_LEVEL:
		return {
			"aura_alpha": 0.0,
			"aura_layers": 0,
			"aura_radius_scale": 0.0,
			"particle_alpha": 0.0,
			"particle_count": 0,
			"particle_size": 0.0,
		}
	if level >= RtsSimulation.STRONGHOLD_MAX_LEVEL:
		return {
			"aura_alpha": 0.6,
			"aura_layers": 3,
			"aura_radius_scale": 1.22,
			"particle_alpha": 1.0,
			"particle_count": STRONGHOLD_LEVEL_3_PARTICLE_COUNT,
			"particle_size": 2.8,
		}
	return {
		"aura_alpha": 0.34,
		"aura_layers": 2,
		"aura_radius_scale": 1.0,
		"particle_alpha": 0.68,
		"particle_count": STRONGHOLD_LEVEL_2_PARTICLE_COUNT,
		"particle_size": 2.0,
	}


func _draw_stronghold_aura(stronghold: Dictionary, center: Vector2) -> void:
	var profile := _stronghold_effect_profile(stronghold)
	var aura_alpha := float(profile["aura_alpha"])
	if aura_alpha <= 0.0:
		return
	var entity_id := int(stronghold.get("id", 0))
	var seed := deg_to_rad(float(posmod(entity_id * 67, 360)))
	var pulse := 1.0 + sin(_wind_animation_time * 1.45 + seed) * 0.055
	var radius := (
		STRONGHOLD_AURA_BASE_RADIUS
		* camera_scale
		* float(profile["aura_radius_scale"])
		* pulse
	)
	var aura_center := center + Vector2(0.0, 4.0 * camera_scale)
	var aura_color := _team_color(
		int(stronghold.get("team", RtsSimulation.TEAM_NEUTRAL))
	).lerp(Color("8cfff1"), 0.34)
	var fill_points := PackedVector2Array()
	for point_index in range(32):
		var angle := float(point_index) / 32.0 * TAU
		fill_points.append(
			aura_center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		)
	draw_colored_polygon(fill_points, Color(aura_color, aura_alpha * 0.24))
	var inner_fill_points := PackedVector2Array()
	for point_index in range(32):
		var angle := float(point_index) / 32.0 * TAU
		inner_fill_points.append(
			aura_center
			+ Vector2(cos(angle) * radius.x * 0.72, sin(angle) * radius.y * 0.72)
		)
	draw_colored_polygon(inner_fill_points, Color(aura_color, aura_alpha * 0.17))
	var layers := int(profile["aura_layers"])
	for layer_index in range(layers):
		var layer_progress := float(layer_index) / float(maxi(layers - 1, 1))
		var layer_radius := radius * (1.0 - layer_progress * 0.2)
		var layer_color := aura_color.lerp(Color("ffe8aa"), 0.16 + layer_progress * 0.2)
		_draw_ellipse(
			aura_center,
			layer_radius.x,
			layer_radius.y,
			Color(layer_color, aura_alpha * (0.46 + layer_progress * 0.22)),
			maxf(1.0, (1.8 + layer_progress * 0.9) * camera_scale),
		)


func _draw_stronghold_particles(
	stronghold: Dictionary,
	ground_center: Vector2,
	display_size: Vector2,
) -> void:
	var profile := _stronghold_effect_profile(stronghold)
	var particle_count := int(profile["particle_count"])
	if particle_count <= 0:
		return
	var entity_id := int(stronghold.get("id", 0))
	var team_color := _team_color(int(stronghold.get("team", RtsSimulation.TEAM_NEUTRAL)))
	var orbit_radius := STRONGHOLD_AURA_BASE_RADIUS * camera_scale
	for particle_index in range(particle_count):
		var highlight := Color("ffe5a0") if particle_index % 3 == 0 else Color("b4fff2")
		var particle_color := team_color.lerp(highlight, 0.48)
		var seed := (
			float(posmod(entity_id * 83 + particle_index * 137, 997)) / 997.0
		)
		var speed := 0.17 + seed * 0.08
		var progress := fposmod(
			_wind_animation_time * speed + seed + float(particle_index) * 0.071,
			1.0,
		)
		var angle := seed * TAU + sin(
			_wind_animation_time * 0.46 + float(particle_index) * 1.31
		) * 0.34
		var spread := 0.48 + fposmod(seed * 7.13, 1.0) * 0.52
		var origin := ground_center + Vector2(
			cos(angle) * orbit_radius.x * spread,
			sin(angle) * orbit_radius.y * spread + 3.0 * camera_scale,
		)
		var drift := Vector2(
			sin(angle * 1.7 + progress * TAU) * 9.0 * camera_scale,
			-progress * display_size.y * (0.68 + seed * 0.2),
		)
		var particle_position := origin + drift
		var fade := sin(progress * PI)
		var alpha := float(profile["particle_alpha"]) * fade
		var radius := maxf(
			0.65,
			float(profile["particle_size"]) * camera_scale * (0.78 + seed * 0.42),
		)
		draw_line(
			particle_position + Vector2(0.0, radius * 3.0),
			particle_position,
			Color(particle_color, alpha * 0.46),
			maxf(1.0, radius * 0.65),
			true,
		)
		draw_circle(
			particle_position,
			radius * 2.4,
			Color(particle_color, alpha * 0.18),
		)
		draw_circle(
			particle_position,
			radius * 0.62,
			Color(particle_color.lerp(Color.WHITE, 0.62), alpha),
		)


func _world_texture_rect(
	texture: Texture2D,
	display_size: Vector2,
	content_bottom_margin_pixels: float = -1.0,
	content_center_x_pixels: float = -1.0,
) -> Rect2:
	var bottom_offset := 10.0 * camera_scale
	if content_bottom_margin_pixels >= 0.0:
		bottom_offset = (
			display_size.y
			* content_bottom_margin_pixels
			/ maxf(float(texture.get_height()), 1.0)
		)
	var left_offset := display_size.x * 0.5
	if content_center_x_pixels >= 0.0:
		left_offset = (
			display_size.x
			* content_center_x_pixels
			/ maxf(float(texture.get_width()), 1.0)
		)
	return Rect2(Vector2(-left_offset, -display_size.y + bottom_offset), display_size)


func _selection_ring_screen_position(entity_state: Dictionary) -> Vector2:
	return entity_screen_position(entity_state)


func _grounded_sprite_screen_position(entity_state: Dictionary) -> Vector2:
	if entity_state.get("category") in [&"unit", &"wildlife"]:
		# Movable art and selection rings share the projected tile center as their
		# ground contact, so standing feet cannot drift toward a diamond edge.
		return _selection_ring_screen_position(entity_state)
	var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
	return entity_screen_position(entity_state) + _footprint_ground_offset(footprint)


func _character_art_bottom_margin(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	# Runtime derivatives may use different transparent bottom margins. Measure
	# each texture once so its visible ground contact, rather than its canvas,
	# lands on the shared tile/ring center.
	var cache_key := texture.resource_path
	if cache_key.is_empty():
		cache_key = str(texture.get_instance_id())
	if _texture_bottom_margin_cache.has(cache_key):
		return float(_texture_bottom_margin_cache[cache_key])
	var content_rect := _texture_content_rect(texture)
	var bottom_margin := maxf(float(texture.get_height() - content_rect.end.y), 0.0)
	_texture_bottom_margin_cache[cache_key] = bottom_margin
	return bottom_margin


func _texture_content_center_x(texture: Texture2D) -> float:
	var content_rect := _texture_content_rect(texture)
	return float(content_rect.position.x) + float(content_rect.size.x) * 0.5


func _texture_content_rect(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i()
	var cache_key := texture.resource_path
	if cache_key.is_empty():
		cache_key = str(texture.get_instance_id())
	if _texture_content_rect_cache.has(cache_key):
		return _texture_content_rect_cache[cache_key] as Rect2i
	var content_rect := Rect2i(
		Vector2i.ZERO,
		Vector2i(texture.get_width(), texture.get_height()),
	)
	var image := texture.get_image()
	if image != null and not image.is_empty():
		var used_rect := image.get_used_rect()
		if used_rect.has_area():
			content_rect = used_rect
	_texture_content_rect_cache[cache_key] = content_rect
	return content_rect


func _texture_ground_profile(texture: Texture2D) -> PackedVector2Array:
	if texture == null:
		return PackedVector2Array()
	var cache_key := texture.resource_path
	if cache_key.is_empty():
		cache_key = str(texture.get_instance_id())
	if _texture_ground_profile_cache.has(cache_key):
		return _texture_ground_profile_cache[cache_key] as PackedVector2Array
	var profile := PackedVector2Array()
	var image := texture.get_image()
	var content_rect := _texture_content_rect(texture)
	if image != null and not image.is_empty() and content_rect.has_area():
		for x in range(content_rect.position.x, content_rect.end.x):
			for y in range(content_rect.end.y - 1, content_rect.position.y - 1, -1):
				if image.get_pixel(x, y).a > 0.125:
					profile.append(Vector2(float(x) + 0.5, float(y) + 1.0))
					break
	_texture_ground_profile_cache[cache_key] = profile
	return profile


func _texture_ground_axis_slope(texture: Texture2D) -> float:
	if texture == null:
		return 0.0
	var cache_key := texture.resource_path
	if cache_key.is_empty():
		cache_key = str(texture.get_instance_id())
	if _texture_ground_slope_cache.has(cache_key):
		return float(_texture_ground_slope_cache[cache_key])
	var profile := _texture_ground_profile(texture)
	if profile.size() < 2:
		return 0.0
	# Trim decorative endcaps before fitting the opaque lower contour. This yields
	# the authored ground axis without mistaking roofs or banners for footprint edges.
	var trim := profile.size() / 10
	var first := trim
	var last := profile.size() - trim
	if last - first < 2:
		first = 0
		last = profile.size()
	var mean := Vector2.ZERO
	for index in range(first, last):
		mean += profile[index]
	mean /= float(last - first)
	var covariance := 0.0
	var variance_x := 0.0
	for index in range(first, last):
		var offset := profile[index] - mean
		covariance += offset.x * offset.y
		variance_x += offset.x * offset.x
	var slope := covariance / maxf(variance_x, 0.0001)
	_texture_ground_slope_cache[cache_key] = slope
	return slope


func _skewed_texture_bottom_overhang(
	texture: Texture2D,
	display_size: Vector2,
	content_center_x_pixels: float,
	axis_skew: float,
) -> float:
	var profile := _texture_ground_profile(texture)
	if profile.is_empty():
		return 0.0
	var content_rect := _texture_content_rect(texture)
	var content_center_x := content_center_x_pixels
	if content_center_x < 0.0:
		content_center_x = float(content_rect.position.x) + float(content_rect.size.x) * 0.5
	var scale_x := display_size.x / maxf(float(texture.get_width()), 1.0)
	var scale_y := display_size.y / maxf(float(texture.get_height()), 1.0)
	var overhang := 0.0
	for point in profile:
		var local_x := (point.x - content_center_x) * scale_x
		var local_y := (point.y - float(content_rect.end.y)) * scale_y
		overhang = maxf(overhang, local_y + axis_skew * local_x)
	return overhang


func _footprint_ground_offset(footprint: Vector2i) -> Vector2:
	# Bottom-anchored world art places its ground contact at the
	# lowest edge of its projected footprint, horizontally centered on that edge.
	var half_footprint_height := (
		float(footprint.x + footprint.y) * IsoProjection.TILE_HEIGHT * 0.25
	)
	return Vector2(0.0, half_footprint_height * camera_scale)


func _gate_sprite_flipped_for_footprint(footprint: Vector2i) -> bool:
	# A horizontal mirror is a 90-degree turn between the two upright isometric
	# axes. Gate masters face map X, so their map-Y footprint is the mirrored view.
	return footprint.y > footprint.x


func _gate_sprite_axis_anchor_offset(
	orientation: StringName,
	texture: Texture2D,
	display_size: Vector2,
) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var content_width := (
		float(_texture_content_rect(texture).size.x)
		* display_size.x
		/ maxf(float(texture.get_width()), 1.0)
	)
	# The grounded structure anchor is horizontally halfway between the footprint
	# center and its lowest vertex. The texture-calibrated span fraction seats the
	# gate on the front long edge while retaining a slight screen-NW/NE overlap bias.
	var anchor_ratio := _gate_sprite_anchor_ratio(texture)
	return Vector2(
		-content_width * anchor_ratio
		if orientation == &"x"
		else content_width * anchor_ratio,
		0.0,
	)


func _gate_sprite_scale(texture: Texture2D) -> float:
	if texture == null:
		return GATE_SPRITE_SCALE
	return float(GATE_SPRITE_SCALE_OVERRIDES.get(
		texture.resource_path.get_file(),
		GATE_SPRITE_SCALE,
	))


func _gate_sprite_anchor_ratio(texture: Texture2D) -> float:
	if texture == null:
		return GATE_SPRITE_ANCHOR_RATIO
	return float(GATE_SPRITE_ANCHOR_RATIO_OVERRIDES.get(
		texture.resource_path.get_file(),
		GATE_SPRITE_ANCHOR_RATIO,
	))


func _wall_sprite_axis_anchor_offset(
	orientation: StringName,
	projection_scale: float = 1.0,
) -> Vector2:
	# Bottom-profile grounding already supplies the vertical component of the
	# sloped edge. Move the wall center to the nominal edge midpoint: screen-NW
	# for 0°/map X and screen-NE for 90°/map Y. The offset deliberately ignores
	# the 10% art enlargement so its extra length overlaps both ends evenly.
	return Vector2(
		-IsoProjection.TILE_WIDTH * 0.25 if orientation == &"x" else IsoProjection.TILE_WIDTH * 0.25,
		0.0,
	) * projection_scale


func _wall_lookup_key(team: int, cell: Vector2i) -> Vector3i:
	return Vector3i(team, cell.x, cell.y)


func _rebuild_wall_render_lookup() -> void:
	_wall_render_lookup.clear()
	_gate_bottom_corner_render_lookup.clear()
	if simulation == null:
		return
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			not bool(entity_state.get("alive", false))
			or float(entity_state.get("complete", 0.0)) < 1.0
		):
			continue
		var kind := entity_state.get("kind", &"") as StringName
		var cell := entity_state.get("cell", Vector2i(-1, -1)) as Vector2i
		var team := int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL))
		var lookup_key := _wall_lookup_key(team, cell)
		if kind == &"gate":
			var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
			var bottom_corner := cell + footprint - Vector2i.ONE
			_gate_bottom_corner_render_lookup[
				_wall_lookup_key(team, bottom_corner)
			] = entity_state
			continue
		if kind != &"wall":
			continue
		var orientations := _wall_render_lookup.get(lookup_key, {}) as Dictionary
		orientations[entity_state.get("orientation", &"y") as StringName] = entity_state
		_wall_render_lookup[lookup_key] = orientations


func _wall_corner_direction_orientation(direction: StringName) -> StringName:
	return &"x" if direction in [&"top_left", &"bottom_right"] else &"y"


func _wall_gate_bottom_corner_orientation(wall: Dictionary) -> StringName:
	if (
		wall.get("kind") != &"wall"
		or not bool(wall.get("alive", false))
		or float(wall.get("complete", 0.0)) < 1.0
	):
		return &""
	var cell := wall.get("cell", Vector2i(-1, -1)) as Vector2i
	var team := int(wall.get("team", RtsSimulation.TEAM_NEUTRAL))
	var gate := _gate_bottom_corner_render_lookup.get(
		_wall_lookup_key(team, cell),
		{},
	) as Dictionary
	if gate.is_empty():
		return &""
	return gate.get("orientation", &"y") as StringName


func _wall_render_orientations(wall: Dictionary) -> Array[StringName]:
	var orientations: Array[StringName] = []
	var primary_orientation := wall.get("orientation", &"y") as StringName
	orientations.append(primary_orientation)
	if (
		wall.get("kind") != &"wall"
		or not bool(wall.get("alive", false))
		or float(wall.get("complete", 0.0)) < 1.0
	):
		return orientations
	var cell := wall.get("cell", Vector2i(-1, -1)) as Vector2i
	var team := int(wall.get("team", RtsSimulation.TEAM_NEUTRAL))
	var co_located_walls := _wall_render_lookup.get(
		_wall_lookup_key(team, cell),
		{},
	) as Dictionary
	# Perpendicular walls intentionally sharing a cell each own their authored
	# segment. Do not derive replacement arms for both entities at the same joint.
	if co_located_walls.has(&"x") and co_located_walls.has(&"y"):
		return orientations
	var gate_orientation := _wall_gate_bottom_corner_orientation(wall)
	if not gate_orientation.is_empty() and not orientations.has(gate_orientation):
		orientations.append(gate_orientation)
		return orientations
	var corner_directions := _wall_corner_directions(wall)
	if corner_directions.is_empty():
		return orientations
	# Neighbor sprites on +X/+Y already begin at this tile's shared endpoint.
	# Only -X/-Y runs stop one edge short and need a segment owned by this tile.
	# Replacing (rather than supplementing) the primary sprite prevents top and
	# right turns from growing an unused wall arm beyond the polygon boundary.
	orientations.clear()
	if corner_directions.has(&"top_left"):
		orientations.append(&"x")
	if corner_directions.has(&"top_right"):
		orientations.append(&"y")
	return orientations


func _wall_corner_directions(wall: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	if (
		wall.get("kind") != &"wall"
		or not bool(wall.get("alive", false))
		or float(wall.get("complete", 0.0)) < 1.0
	):
		return result
	var cell := wall.get("cell", Vector2i(-1, -1)) as Vector2i
	var team := int(wall.get("team", RtsSimulation.TEAM_NEUTRAL))
	for direction in WALL_CORNER_DIRECTION_ORDER:
		var neighbor_offset := WALL_CORNER_NEIGHBOR_OFFSETS[direction] as Vector2i
		var neighbor_cell: Vector2i = cell + neighbor_offset
		var neighbor_orientation := _wall_corner_direction_orientation(direction)
		var neighbor_walls := _wall_render_lookup.get(
			_wall_lookup_key(team, neighbor_cell),
			{},
		) as Dictionary
		var neighbor := neighbor_walls.get(neighbor_orientation, {}) as Dictionary
		if (
			not neighbor.is_empty()
			and neighbor.get("orientation", &"y") == neighbor_orientation
		):
			result.append(direction)
	var has_x_axis := result.has(&"top_left") or result.has(&"bottom_right")
	var has_y_axis := result.has(&"top_right") or result.has(&"bottom_left")
	# Opposing arms are a straight run. Only perpendicular axes form a corner;
	# T-junctions and crossings retain every connected arm.
	if has_x_axis and has_y_axis:
		return result
	result.clear()
	return result


func _wall_corner_direction_anchor_offset(
	direction: StringName,
	projection_scale: float = 1.0,
) -> Vector2:
	# The normal 0° and 90° sprites sit on the two lower diamond edges. Their
	# opposite-edge variants move one half-tile upward while crossing to the
	# other side, so the measured opaque ground axis stays flush to the diamond.
	if direction == &"bottom_left":
		return -IsoProjection.project(Vector2(1.0, 0.0)) * projection_scale
	if direction == &"bottom_right":
		return -IsoProjection.project(Vector2(0.0, 1.0)) * projection_scale
	return Vector2.ZERO


func _draw_wall_joint_segments(
	texture: Texture2D,
	sprite_center: Vector2,
	display_size: Vector2,
	tint: Color,
	orientations: Array[StringName],
) -> void:
	var footprint := Vector2i.ONE
	var bottom_margin := _character_art_bottom_margin(texture)
	var content_center_x := _texture_content_center_x(texture)
	for orientation in [&"x", &"y"]:
		if not orientations.has(orientation):
			continue
		var flip_h := _structure_sprite_flipped(
			&"wall",
			orientation,
			footprint,
			texture,
		)
		var axis_skew := _structure_sprite_axis_skew(
			&"wall",
			orientation,
			footprint,
			texture,
			display_size,
			flip_h,
		)
		var texture_center := (
			sprite_center
			+ _wall_sprite_axis_anchor_offset(orientation, camera_scale)
		)
		_draw_world_texture(
			texture,
			texture_center,
			display_size,
			tint,
			flip_h,
			0.0,
			bottom_margin,
			content_center_x,
			axis_skew,
		)


func _fortification_target_axis_slope(
	structure_kind: StringName,
	orientation: StringName,
	_footprint: Vector2i,
) -> float:
	var tile_slope := IsoProjection.TILE_HEIGHT / IsoProjection.TILE_WIDTH
	if structure_kind in [&"wall", &"gate"]:
		# Walls and gates sit on one of the two actual isometric tile axes. A
		# rectangular gate footprint changes the length of that axis, not its angle.
		return tile_slope if orientation == &"x" else -tile_slope
	return 0.0


func _structure_sprite_flipped(
	structure_kind: StringName,
	orientation: StringName,
	footprint: Vector2i,
	texture: Texture2D = null,
) -> bool:
	if structure_kind in RtsSimulation.FORTIFICATION_STRUCTURE_KINDS and texture != null:
		var source_slope := _texture_ground_axis_slope(texture)
		var target_slope := _fortification_target_axis_slope(
			structure_kind,
			orientation,
			footprint,
		)
		if not is_zero_approx(source_slope) and not is_zero_approx(target_slope):
			return source_slope * target_slope < 0.0
	if structure_kind == &"gate":
		return _gate_sprite_flipped_for_footprint(footprint)
	return orientation == &"x"


func _structure_sprite_axis_skew(
	structure_kind: StringName,
	orientation: StringName,
	footprint: Vector2i,
	texture: Texture2D,
	display_size: Vector2,
	flip_h: bool,
) -> float:
	if structure_kind not in RtsSimulation.FORTIFICATION_STRUCTURE_KINDS or texture == null:
		return 0.0
	var source_scale_x := display_size.x / maxf(float(texture.get_width()), 1.0)
	var source_scale_y := display_size.y / maxf(float(texture.get_height()), 1.0)
	var source_slope := _texture_ground_axis_slope(texture) * source_scale_y / maxf(source_scale_x, 0.0001)
	var target_slope := _fortification_target_axis_slope(
		structure_kind,
		orientation,
		footprint,
	)
	var horizontal_scale := -1.0 if flip_h else 1.0
	return horizontal_scale * target_slope - source_slope


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
				"idle_wait_remaining": _idle_wobble_wait(entity_id, 0),
				"idle_wobble_elapsed": 0.0,
					"idle_turn_count": 0,
					"was_idle_player_unit": false,
					"last_foot_cycle": -1,
					"motion_blend": 0.0,
					"start_impulse": 0.0,
					"settle_impulse": 0.0,
					"was_moving": false,
				}
		var visual := _movement_visuals[entity_id] as Dictionary
		var previous_position := visual.get("position", position) as Vector2
		var movement := position - previous_position
		if movement.length_squared() > WALK_MOTION_EPSILON_SQUARED:
			var projected_movement := IsoProjection.project(movement)
			if absf(projected_movement.x) > WALK_FACING_EPSILON:
				visual["faces_left"] = projected_movement.x < 0.0
			visual["moving_for"] = WALK_MOTION_MEMORY_SECONDS
			if not bool(visual.get("was_moving", false)):
				visual["start_impulse"] = 1.0
			visual["was_moving"] = true
			var foot_phase := _walk_animation_time * WALK_BOUNCE_SPEED + float(entity_id) * 1.61803398875
			var foot_cycle := int(floor(foot_phase / PI))
			if (
				foot_cycle != int(visual.get("last_foot_cycle", -1))
				and camera_scale > 0.45
				and should_render_entity(entity_state)
			):
				_effect_director.emit_foot_dust(position, _ground_contact_color(position))
			visual["last_foot_cycle"] = foot_cycle
		else:
			var previous_moving_for := float(visual.get("moving_for", 0.0))
			visual["moving_for"] = maxf(0.0, previous_moving_for - delta)
			if previous_moving_for > 0.0 and float(visual["moving_for"]) <= 0.0 and bool(visual.get("was_moving", false)):
				visual["settle_impulse"] = 1.0
				visual["was_moving"] = false
		var motion_target := 1.0 if float(visual.get("moving_for", 0.0)) > 0.0 else 0.0
		visual["motion_blend"] = lerpf(float(visual.get("motion_blend", 0.0)), motion_target, clampf(delta * 10.0, 0.0, 1.0))
		visual["start_impulse"] = maxf(0.0, float(visual.get("start_impulse", 0.0)) - delta * 7.0)
		visual["settle_impulse"] = maxf(0.0, float(visual.get("settle_impulse", 0.0)) - delta * 6.0)
		var is_idle_player_unit := (
			_is_idle_player_unit_visual(entity_state)
			and float(visual.get("moving_for", 0.0)) <= 0.0
		)
		if is_idle_player_unit:
			visual["was_idle_player_unit"] = true
			_update_idle_unit_visual(visual, entity_id, delta)
		else:
			if bool(visual.get("was_idle_player_unit", false)):
				var turn_count := int(visual.get("idle_turn_count", 0))
				visual["idle_wait_remaining"] = _idle_wobble_wait(entity_id, turn_count)
			visual["idle_wobble_elapsed"] = 0.0
			visual["was_idle_player_unit"] = false
		visual["position"] = position
		_movement_visuals[entity_id] = visual
	for raw_id in _movement_visuals.keys():
		var entity_id := int(raw_id)
		if not live_ids.has(entity_id):
			_movement_visuals.erase(entity_id)


func _is_movable_visual(entity_state: Dictionary) -> bool:
	return entity_state.get("category") in [&"unit", &"wildlife"]


func _is_idle_player_unit_visual(entity_state: Dictionary) -> bool:
	return (
		entity_state.get("category") == &"unit"
		and int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_PLAYER
		and entity_state.get("order", &"idle") == &"idle"
	)


func _update_idle_unit_visual(visual: Dictionary, entity_id: int, delta: float) -> void:
	var wobble_elapsed := float(visual.get("idle_wobble_elapsed", 0.0))
	if wobble_elapsed > 0.0:
		wobble_elapsed += delta
		if wobble_elapsed < IDLE_WOBBLE_DURATION:
			visual["idle_wobble_elapsed"] = wobble_elapsed
			return
		_finish_idle_wobble(visual, entity_id)
		return

	var wait_remaining := float(
		visual.get(
			"idle_wait_remaining",
			_idle_wobble_wait(entity_id, int(visual.get("idle_turn_count", 0))),
		)
	)
	if delta < wait_remaining:
		visual["idle_wait_remaining"] = wait_remaining - delta
		return
	var elapsed_after_wait := maxf(delta - wait_remaining, 0.000001)
	if elapsed_after_wait < IDLE_WOBBLE_DURATION:
		visual["idle_wait_remaining"] = 0.0
		visual["idle_wobble_elapsed"] = elapsed_after_wait
		return
	_finish_idle_wobble(visual, entity_id)


func _finish_idle_wobble(visual: Dictionary, entity_id: int) -> void:
	visual["faces_left"] = not bool(visual.get("faces_left", false))
	var turn_count := int(visual.get("idle_turn_count", 0)) + 1
	visual["idle_turn_count"] = turn_count
	visual["idle_wobble_elapsed"] = 0.0
	visual["idle_wait_remaining"] = _idle_wobble_wait(entity_id, turn_count)


func _idle_wobble_wait(entity_id: int, turn_count: int) -> float:
	# Stable per-unit variation keeps crowds from wobbling in sync while leaving
	# gameplay RNG and deterministic simulation state untouched.
	var hash_value := absi(entity_id * 1103515245 + (turn_count + 1) * 12345)
	var variation := float(hash_value % 10000) / 9999.0
	return lerpf(IDLE_WOBBLE_MIN_WAIT_SECONDS, IDLE_WOBBLE_MAX_WAIT_SECONDS, variation)


func _idle_wobble_rotation(entity_state: Dictionary) -> float:
	if not _is_idle_player_unit_visual(entity_state):
		return 0.0
	var visual := _movement_visuals.get(int(entity_state.get("id", -1)), {}) as Dictionary
	var elapsed := float(visual.get("idle_wobble_elapsed", 0.0))
	if elapsed <= 0.0:
		return 0.0
	var progress := clampf(elapsed / IDLE_WOBBLE_DURATION, 0.0, 1.0)
	var envelope := sin(progress * PI)
	return sin(progress * TAU * IDLE_WOBBLE_OSCILLATIONS) * envelope * IDLE_WOBBLE_ANGLE


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


func _movement_lean_rotation(entity_state: Dictionary) -> float:
	if _effect_director.reduced_motion:
		return 0.0
	var visual := _movement_visuals.get(int(entity_state.get("id", -1)), {}) as Dictionary
	var blend := float(visual.get("motion_blend", 0.0))
	var direction := -1.0 if bool(visual.get("faces_left", false)) else 1.0
	return direction * blend * 0.035


func _movement_squash_scale(entity_state: Dictionary) -> Vector2:
	if _effect_director.reduced_motion:
		return Vector2.ONE
	var entity_id := int(entity_state.get("id", -1))
	var visual := _movement_visuals.get(entity_id, {}) as Dictionary
	var blend := float(visual.get("motion_blend", 0.0))
	var phase := _walk_animation_time * WALK_BOUNCE_SPEED + float(entity_id) * 1.61803398875
	var foot_plant := pow(1.0 - absf(sin(phase)), 4.0) * blend
	var start_impulse := float(visual.get("start_impulse", 0.0))
	var settle_impulse := float(visual.get("settle_impulse", 0.0))
	var squash := foot_plant * 0.045 + settle_impulse * 0.035
	var stretch := start_impulse * 0.035
	return Vector2(1.0 + squash - stretch * 0.35, 1.0 - squash + stretch)


func _ground_contact_color(position: Vector2) -> Color:
	var cell := Vector2i(position.floor())
	match MapCatalog.terrain_at(cell):
		&"road", &"bridge":
			return Color(0.84, 0.68, 0.42, 0.48)
		&"forest":
			return Color(0.43, 0.65, 0.32, 0.48)
		&"ridge":
			return Color(0.58, 0.62, 0.58, 0.46)
		_:
			return Color(0.72, 0.73, 0.48, 0.42)


func _entity_sprite_display_size(
	entity_state: Dictionary,
	texture: Texture2D = null,
) -> Vector2:
	var category := entity_state.get("category", &"") as StringName
	var kind := entity_state.get("kind", &"") as StringName
	if category == &"resource":
		return (
			Vector2(136.0, 164.0)
			if entity_state.get("resource_kind") == &"lumber"
			else Vector2(98.0, 88.0)
		)
	if kind == &"jadeclaw":
		return Vector2(124.0, 112.0)
	if kind == &"shenlong":
		return Vector2(448.0, 362.0)
	if kind == &"shenlong_egg":
		return (
			Vector2(58.0, 58.0)
			if int(entity_state.get("carried_by", -1)) >= 0
			else Vector2(118.0, 118.0)
		)
	if kind == &"yaoguai_den":
		return Vector2(250.0, 212.0)
	if category == &"unit":
		return Vector2(94.0, 104.0)
	if category == &"wildlife":
		return _wildlife_display_size(kind)
	return _structure_display_size(
		kind,
		entity_state.get("footprint", Vector2i.ONE) as Vector2i,
		texture,
	)


func _structure_display_size(
	kind: StringName,
	footprint: Vector2i = Vector2i.ONE,
	texture: Texture2D = null,
) -> Vector2:
	if kind in RtsSimulation.FORTIFICATION_STRUCTURE_KINDS and texture != null:
		var content_rect := _texture_content_rect(texture)
		var footprint_bounds_width := (
			float(footprint.x + footprint.y)
			* IsoProjection.TILE_WIDTH
			* 0.5
		)
		# Walls and gates follow one sloped footprint edge, whose horizontal span
		# depends only on that edge's length. Scaling either to the full diamond
		# bounds would spill the sprite past its supporting tile axis.
		var target_content_width := (
			IsoProjection.TILE_WIDTH * 0.5 * WALL_SPRITE_SCALE
			if kind == &"wall"
			else (
				float(maxi(footprint.x, footprint.y))
				* IsoProjection.TILE_WIDTH
				* 0.5
				* _gate_sprite_scale(texture)
			)
			if kind == &"gate"
			else footprint_bounds_width
		)
		var content_scale := target_content_width / maxf(float(content_rect.size.x), 1.0)
		return Vector2(texture.get_width(), texture.get_height()) * content_scale
	match kind:
		&"wall":
			return Vector2(114.0, 94.0)
		&"gate":
			return Vector2(292.0, 198.0)
		&"sentry_tower":
			return Vector2(220.0, 208.0)
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
	var max_hp := maxf(float(entity_state["max_hp"]), 1.0)
	var ratio := clampf(float(entity_state["hp"]) / max_hp, 0.0, 1.0)
	var display_ratio := clampf(
		_presentation.display_hp(int(entity_state.get("id", -1)), float(entity_state["hp"])) / max_hp,
		0.0,
		1.0,
	)
	if ratio >= 0.999 and not selected_ids.has(int(entity_state["id"])):
		return
	var width := (52.0 if category == &"wildlife" else 46.0 if category == &"unit" else 86.0) * camera_scale
	var y_offset := (-67.0 if category == &"wildlife" else -77.0 if category == &"unit" else -137.0) * camera_scale
	var rect := Rect2(center + Vector2(-width * 0.5, y_offset), Vector2(width, maxf(4.0, 6.0 * camera_scale)))
	draw_rect(rect, Color(0.02, 0.03, 0.03, 0.9), true)
	var health_color := _team_color(int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)))
	if display_ratio > ratio:
		draw_rect(
			Rect2(rect.position + Vector2.ONE, Vector2((rect.size.x - 2.0) * display_ratio, rect.size.y - 2.0)),
			Color("f6b45f"),
			true,
		)
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


func _draw_ellipse_arc(
	center: Vector2,
	radius_x: float,
	radius_y: float,
	start_angle: float,
	arc_length: float,
	color: Color,
	width: float,
) -> void:
	var points := PackedVector2Array()
	for index in range(19):
		var angle := start_angle + float(index) / 18.0 * arc_length
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)


func _entity_ring_radius(entity_state: Dictionary) -> Vector2:
	var kind := entity_state.get("kind", &"") as StringName
	var category := entity_state.get("category", &"") as StringName
	if kind == &"jadeclaw":
		return Vector2(34.0, 16.0)
	if category == &"wildlife":
		return Vector2(32.0, 15.0)
	if category == &"unit":
		return Vector2(27.0, 13.0)
	if kind == &"yaoguai_den":
		return Vector2(76.0, 34.0)
	return Vector2(54.0, 25.0)


func _draw_hover_overlay() -> void:
	var entity_id := int(_presentation.hovered_entity_id)
	if entity_id < 0:
		return
	var entity_state := simulation.entity(entity_id)
	if entity_state.is_empty() or not should_render_entity(entity_state):
		return
	var center := _selection_ring_screen_position(entity_state)
	var radius := _entity_ring_radius(entity_state) * camera_scale
	var color := _team_color(int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)))
	var strength := _presentation.hover_strength(entity_id)
	_draw_ellipse_arc(
		center,
		radius.x * 1.08,
		radius.y * 1.08,
		-_command_indicator_time * 0.7,
		PI * 0.66,
		Color(color, 0.55 + strength * 0.25),
		maxf(1.2, 1.8 * camera_scale),
	)
	_draw_ellipse_arc(
		center,
		radius.x * 1.08,
		radius.y * 1.08,
		PI - _command_indicator_time * 0.7,
		PI * 0.66,
		Color(color, 0.28 + strength * 0.18),
		maxf(1.0, 1.4 * camera_scale),
	)


func _draw_environment_sheen() -> void:
	if camera_scale < 0.28:
		return
	for macro_y in range(MapCatalog.AUTHORED_SIZE.y):
		for macro_x in range(MapCatalog.AUTHORED_SIZE.x):
			var cell := Vector2i(macro_x, macro_y) * MapCatalog.CELL_SCALE
			if MapCatalog.terrain_at(cell) != &"water" or not _is_block_on_screen(cell, MapCatalog.CELL_SCALE):
				continue
			var phase := _water_animation_time * 1.3 + float(macro_x * 7 + macro_y * 11)
			var local := Vector2(0.5 + sin(phase * 0.47) * 0.18, 0.5 + cos(phase * 0.31) * 0.16)
			var map_position := Vector2(cell) + local * float(MapCatalog.CELL_SCALE)
			var center := camera_offset + IsoProjection.position_center(map_position) * camera_scale
			var half_length := clampf(18.0 * camera_scale, 5.0, 20.0)
			var alpha := 0.10 + (sin(phase) * 0.5 + 0.5) * 0.12
			draw_line(
				center - Vector2(half_length, half_length * 0.24),
				center + Vector2(half_length, half_length * 0.24),
				Color(0.72, 1.0, 0.96, alpha),
				maxf(1.0, 1.4 * camera_scale),
				true,
			)


func _emit_ambient_juice() -> void:
	if simulation == null or camera_scale < 0.28:
		return
	var candidate: Dictionary = {}
	var wrap_candidate: Dictionary = {}
	var candidate_id := 2147483647
	var wrap_id := 2147483647
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if (
			not bool(entity_state.get("alive", false))
			or entity_state.get("resource_kind") != &"lumber"
			or not should_render_entity(entity_state)
		):
			continue
		var entity_id := int(entity_state.get("id", -1))
		if entity_id > _ambient_effect_cursor and entity_id < candidate_id:
			candidate = entity_state
			candidate_id = entity_id
		if entity_id < wrap_id:
			wrap_candidate = entity_state
			wrap_id = entity_id
	if candidate.is_empty():
		candidate = wrap_candidate
		candidate_id = wrap_id
	if candidate.is_empty():
		return
	_ambient_effect_cursor = candidate_id
	var phase := float(candidate_id) * 1.618 + _wind_animation_time * 0.16
	var position := _entity_world_center(candidate) + Vector2(sin(phase), cos(phase * 0.73)) * 0.18
	_effect_director.emit_ambient(position, Color(0.55, 0.84, 0.42, 0.72), &"leaf")


func _draw_fog_of_war() -> void:
	if not fog_enabled:
		return
	_ensure_fog_mask_texture()
	if _fog_mask_texture == null:
		return
	var uv_rect: Rect2 = _fog_mask_builder.map_uv_rect()
	var uvs := PackedVector2Array([
		uv_rect.position,
		Vector2(uv_rect.end.x, uv_rect.position.y),
		uv_rect.end,
		Vector2(uv_rect.position.x, uv_rect.end.y),
	])
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE])
	draw_polygon(_transformed_map_polygon(), colors, uvs, _fog_mask_texture)


func _ensure_fog_mask_texture() -> void:
	if not _fog_mask_dirty and _fog_mask_texture != null:
		return
	if _fog_mask_builder == null:
		_fog_mask_builder = FOG_MASK_BUILDER_SCRIPT.new(
			MapCatalog.SIZE,
			FOG_MASK_PIXELS_PER_CELL,
			EXPLORED_FOG_COLOR,
			UNEXPLORED_FOG_COLOR,
		)
	var image: Image = _fog_mask_builder.build_image(_visible_cells, _explored_cells)
	if _fog_mask_texture == null:
		_fog_mask_texture = ImageTexture.create_from_image(image)
	else:
		_fog_mask_texture.update(image)
	_fog_mask_dirty = false


func _draw_effect_underlay() -> void:
	for trace in _effect_director.traces:
		var elapsed := float(trace.get("elapsed", 0.0))
		if elapsed < 0.0:
			continue
		var duration := maxf(float(trace.get("duration", 0.001)), 0.001)
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		var position := _effect_screen_position(trace.get("position", Vector2.ZERO) as Vector2)
		var color := trace.get("color", Color.WHITE) as Color
		color.a *= (1.0 - progress) * 0.48
		var kind := trace.get("kind", &"residue") as StringName
		var radius := (22.0 if kind == &"residue" else 46.0 if kind == &"rubble" else 34.0) * camera_scale
		if kind == &"rubble":
			for index in range(5):
				var angle := float(index) / 5.0 * TAU + float(trace.get("seed", 0)) * 0.001
				var shard := position + Vector2.from_angle(angle) * radius * (0.38 + float(index % 2) * 0.24)
				draw_line(shard - Vector2(5.0, 2.0) * camera_scale, shard + Vector2(5.0, 2.0) * camera_scale, color, maxf(1.0, 2.0 * camera_scale), true)
		else:
			_draw_ellipse(position, radius, radius * 0.42, color, maxf(1.0, 2.0 * camera_scale))
	for pulse in _effect_director.pulses:
		_draw_effect_pulse(pulse)


func _draw_effects() -> void:
	for trail in _effect_director.trails:
		_draw_effect_trail(trail)
	for impact in _effect_director.impacts:
		_draw_effect_impact(impact)
	for particle in _effect_director.particles:
		_draw_effect_particle(particle)
	for value in _effect_director.values:
		_draw_effect_value(value)


func _draw_death_snapshots() -> void:
	for snapshot in _effect_director.deaths:
		var elapsed := float(snapshot.get("elapsed", 0.0))
		if elapsed < 0.0:
			continue
		var duration := maxf(float(snapshot.get("duration", 0.001)), 0.001)
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		var category := snapshot.get("category", &"unit") as StringName
		var kind := snapshot.get("kind", &"") as StringName
		var faction := snapshot.get("faction", &"neutral") as StringName
		var texture := _entity_texture(faction, kind)
		if texture == null:
			continue
		var footprint := snapshot.get("footprint", Vector2i.ONE) as Vector2i
		var display_size := Vector2(94.0, 104.0)
		if category == &"wildlife":
			display_size = _wildlife_display_size(kind)
		elif category == &"structure":
			display_size = _structure_display_size(kind, footprint, texture)
		if kind == &"jadeclaw":
			display_size = Vector2(124.0, 112.0)
		elif kind == &"shenlong":
			display_size = Vector2(448.0, 362.0)
		var hold_progress := clampf((progress - 0.12) / 0.88, 0.0, 1.0)
		var center := _effect_screen_position(snapshot.get("position", Vector2.ZERO) as Vector2)
		if category == &"structure":
			center += _footprint_ground_offset(footprint)
		var seed_sign := -1.0 if int(snapshot.get("seed", 0)) % 2 == 0 else 1.0
		var rotation := 0.0
		var collapse_scale := Vector2.ONE
		if not _effect_director.reduced_motion:
			if category == &"structure":
				collapse_scale = Vector2(1.0 + hold_progress * 0.08, 1.0 - hold_progress * 0.34)
				center.y += hold_progress * 16.0 * camera_scale
			else:
				rotation = seed_sign * hold_progress * 0.72
				center.y += hold_progress * 12.0 * camera_scale
		var tint := Color(1.0, 0.72, 0.62, pow(1.0 - hold_progress, 1.4) * 0.82)
		_draw_world_texture(
			texture,
			center,
			display_size * camera_scale * collapse_scale,
			tint,
			false,
			rotation,
			_character_art_bottom_margin(texture),
		)


func _effect_screen_position(world_position: Vector2) -> Vector2:
	return camera_offset + IsoProjection.position_center(world_position) * camera_scale


func _draw_effect_pulse(pulse: Dictionary) -> void:
	var elapsed := float(pulse.get("elapsed", 0.0))
	if elapsed < 0.0:
		return
	var duration := maxf(float(pulse.get("duration", 0.001)), 0.001)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var center := _effect_screen_position(pulse.get("position", Vector2.ZERO) as Vector2)
	var color := pulse.get("color", Color.WHITE) as Color
	var alpha := sin(progress * PI) * 0.88
	color.a *= alpha
	var radius := lerpf(9.0, 42.0, 1.0 - pow(1.0 - progress, 2.0)) * camera_scale
	var kind := pulse.get("kind", &"select") as StringName
	if kind == &"invalid":
		var pinch := lerpf(22.0, 8.0, progress) * camera_scale
		draw_line(center + Vector2(-pinch, -pinch * 0.5), center + Vector2(-pinch * 0.25, -pinch * 0.12), color, maxf(1.6, 2.6 * camera_scale), true)
		draw_line(center + Vector2(pinch, pinch * 0.5), center + Vector2(pinch * 0.25, pinch * 0.12), color, maxf(1.6, 2.6 * camera_scale), true)
		draw_line(center + Vector2(-5.0, -5.0) * camera_scale, center + Vector2(5.0, 5.0) * camera_scale, color, maxf(1.4, 2.2 * camera_scale), true)
		draw_line(center + Vector2(5.0, -5.0) * camera_scale, center + Vector2(-5.0, 5.0) * camera_scale, color, maxf(1.4, 2.2 * camera_scale), true)
		return
	if kind in [&"attack", &"death"]:
		var triangle := PackedVector2Array()
		for index in range(4):
			var angle := -PI * 0.5 + float(index) / 3.0 * TAU
			triangle.append(center + Vector2.from_angle(angle) * radius)
		draw_polyline(triangle, color, maxf(1.5, 2.5 * camera_scale), true)
	elif kind in [&"move", &"order", &"queued", &"rally", &"build", &"complete", &"upgrade"]:
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -radius * 0.55),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius * 0.55),
			center + Vector2(-radius, 0.0),
			center + Vector2(0.0, -radius * 0.55),
		])
		draw_polyline(diamond, color, maxf(1.2, 2.2 * camera_scale), true)
		if bool(pulse.get("queued", false)):
			var inner := radius * 0.68
			draw_arc(center, inner, 0.15, PI * 1.25, 18, Color(color, color.a * 0.65), maxf(1.0, 1.5 * camera_scale), true)
	elif kind == &"repair":
		draw_arc(center, radius, 0.0, TAU, 24, color, maxf(1.3, 2.2 * camera_scale), true)
		draw_line(center + Vector2(-radius * 0.42, 0.0), center + Vector2(radius * 0.42, 0.0), color, maxf(1.2, 2.0 * camera_scale), true)
		draw_line(center + Vector2(0.0, -radius * 0.42), center + Vector2(0.0, radius * 0.42), color, maxf(1.2, 2.0 * camera_scale), true)
	else:
		_draw_ellipse(center, radius, radius * 0.46, color, maxf(1.2, 2.2 * camera_scale))


func _draw_effect_trail(trail: Dictionary) -> void:
	var elapsed := float(trail.get("elapsed", 0.0))
	if elapsed < 0.0:
		return
	var duration := maxf(float(trail.get("duration", 0.001)), 0.001)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var from := _effect_screen_position(trail.get("from", Vector2.ZERO) as Vector2) + Vector2(0.0, -30.0 * camera_scale)
	var to := _effect_screen_position(trail.get("to", Vector2.ZERO) as Vector2) + Vector2(0.0, -24.0 * camera_scale)
	var head := from.lerp(to, 1.0 - pow(1.0 - progress, 2.0))
	var tail := from.lerp(to, maxf(0.0, progress - 0.34))
	var color := trail.get("color", Color.WHITE) as Color
	color.a *= sin(progress * PI)
	var family := trail.get("family", &"melee") as StringName
	if family in [&"melee", &"beast"]:
		var direction := (to - from).normalized()
		var normal := Vector2(-direction.y, direction.x)
		var swing_center := to - direction * 13.0 * camera_scale
		var swing_radius := (18.0 if family == &"melee" else 26.0) * camera_scale
		draw_arc(swing_center, swing_radius, direction.angle() - 1.0, direction.angle() + 0.9, 16, color, maxf(2.0, 4.0 * camera_scale), true)
		draw_circle(to + normal * sin(progress * PI) * 2.0, maxf(2.0, 4.5 * camera_scale), Color(color, color.a * 0.72))
		return
	if family == &"dragon":
		var points := PackedVector2Array()
		var direction := head - tail
		var normal := Vector2(-direction.y, direction.x).normalized()
		for index in range(9):
			var weight := float(index) / 8.0
			points.append(tail.lerp(head, weight) + normal * sin(weight * TAU * 1.5 + progress * TAU) * 4.0 * camera_scale)
		draw_polyline(points, Color(color, color.a * 0.38), maxf(3.0, 7.0 * camera_scale), true)
		draw_polyline(points, color, maxf(1.2, 2.6 * camera_scale), true)
	else:
		draw_line(tail, head, Color(color, color.a * 0.28), maxf(3.0, 7.0 * camera_scale), true)
		draw_line(tail, head, color, maxf(1.2, 2.5 * camera_scale), true)
		draw_circle(head, maxf(2.2, (5.5 if family == &"mystic" else 3.5) * camera_scale), color)
		if family == &"mystic":
			draw_circle(head, maxf(5.0, 10.0 * camera_scale), Color(color, color.a * 0.16))


func _draw_effect_impact(impact: Dictionary) -> void:
	var elapsed := float(impact.get("elapsed", 0.0))
	if elapsed < 0.0:
		return
	var duration := maxf(float(impact.get("duration", 0.001)), 0.001)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var center := _effect_screen_position(impact.get("position", Vector2.ZERO) as Vector2) + Vector2(0.0, -22.0 * camera_scale)
	var color := impact.get("color", Color.WHITE) as Color
	var flash := clampf(1.0 - progress / 0.43, 0.0, 1.0)
	var radius := lerpf(4.0, 28.0, sqrt(progress)) * camera_scale
	draw_circle(center, radius * 0.42, Color(color, flash * 0.44))
	var faction := impact.get("faction", &"neutral") as StringName
	var shape := EFFECT_CATALOG_SCRIPT.faction_shape(faction)
	var edge_color := Color(color, (1.0 - progress) * 0.9)
	if shape == &"triangle":
		var points := PackedVector2Array()
		for index in range(4):
			points.append(center + Vector2.from_angle(-PI * 0.5 + float(index) / 3.0 * TAU) * radius)
		draw_polyline(points, edge_color, maxf(1.3, 2.5 * camera_scale), true)
	elif shape == &"diamond":
		draw_polyline(PackedVector2Array([
			center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius),
		]), edge_color, maxf(1.3, 2.5 * camera_scale), true)
	elif shape == &"claw":
		for offset in [-0.35, 0.0, 0.35]:
			draw_arc(center + Vector2(offset * radius, 0.0), radius * 0.72, -2.4, -0.4, 12, edge_color, maxf(1.2, 2.3 * camera_scale), true)
	else:
		draw_arc(center, radius, 0.0, TAU, 24, edge_color, maxf(1.3, 2.5 * camera_scale), true)


func _draw_effect_particle(particle: Dictionary) -> void:
	var elapsed := float(particle.get("elapsed", 0.0))
	if elapsed < 0.0:
		return
	var duration := maxf(float(particle.get("duration", 0.001)), 0.001)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var velocity := particle.get("velocity", Vector2.ZERO) as Vector2
	var shape := particle.get("shape", &"spark") as StringName
	var offset := velocity * elapsed
	if shape == &"inward":
		offset = velocity * (duration - elapsed)
	elif shape in [&"dust", &"debris", &"fleck", &"leaf"]:
		offset.y += 42.0 * elapsed * elapsed
	var center := _effect_screen_position(particle.get("position", Vector2.ZERO) as Vector2) + offset * camera_scale + Vector2(0.0, -18.0 * camera_scale)
	var color := particle.get("color", Color.WHITE) as Color
	color.a *= (1.0 - progress)
	var radius := maxf(1.2, (3.2 - progress * 1.4) * camera_scale)
	if shape in [&"triangle", &"debris", &"ray"]:
		var direction := velocity.normalized()
		var normal := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([
			center + direction * radius * 2.2,
			center - direction * radius + normal * radius,
			center - direction * radius - normal * radius,
		]), color)
	elif shape in [&"diamond", &"fleck", &"leaf"]:
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0, -radius * 1.8), center + Vector2(radius, 0), center + Vector2(0, radius * 1.8), center + Vector2(-radius, 0),
		]), color)
	elif shape == &"claw":
		draw_arc(center, radius * 2.0, -2.5, -0.3, 8, color, maxf(1.0, radius * 0.8), true)
	else:
		draw_circle(center, radius, color)


func _draw_effect_value(value: Dictionary) -> void:
	var elapsed := float(value.get("elapsed", 0.0))
	if elapsed < 0.0:
		return
	var duration := maxf(float(value.get("duration", 0.001)), 0.001)
	var progress := clampf(elapsed / duration, 0.0, 1.0)
	var center := _effect_screen_position(value.get("position", Vector2.ZERO) as Vector2)
	center += Vector2(0.0, lerpf(-38.0, -68.0, progress) * camera_scale)
	var amount := int(round(float(value.get("amount", 0.0))))
	var prefix := "+" if bool(value.get("positive", false)) else "−"
	var label := "%s%d" % [prefix, absi(amount)]
	var color := value.get("color", Color.WHITE) as Color
	color.a *= sin(progress * PI)
	var font := ThemeDB.fallback_font
	var font_size := maxi(11, int(15.0 * camera_scale))
	draw_string(font, center + Vector2(1.0, 1.0), label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, Color(0.0, 0.0, 0.0, color.a * 0.72))
	draw_string(font, center, label, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size, color)


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
	if team == RtsSimulation.TEAM_RIVAL_TWO:
		return Color("69a9ff")
	if team == RtsSimulation.TEAM_RIVAL_THREE:
		return Color("cf83ef")
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
