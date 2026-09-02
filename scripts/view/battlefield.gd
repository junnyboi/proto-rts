class_name Battlefield
extends Control

signal selection_changed(ids)
signal feedback(message: String, is_error: bool)

const TERRAIN_TEXTURES := {
	&"meadow": preload("res://assets/runtime/terrain/jade_meadow.webp"),
	&"ridge": preload("res://assets/runtime/terrain/inkstone_ridge.webp"),
	&"water": preload("res://assets/runtime/terrain/celadon_water.webp"),
}
const RESOURCE_TEXTURES := {
	&"jade_node": preload("res://assets/runtime/resources/jade_outcrop.png"),
	&"essence_node": preload("res://assets/runtime/resources/essence_shrine.png"),
}
const PLAYER_COLOR := Color("78dfb7")
const ENEMY_COLOR := Color("f06656")
const GRID_COLOR := Color(0.04, 0.12, 0.12, 0.52)

var simulation: RtsSimulation
var selected_ids: Array[int] = []
var attack_move_armed := false
var placement_worker_id := -1

var camera_scale := 0.62
var camera_offset := Vector2.ZERO
var _camera_initialized := false
var _middle_dragging := false
var _selection_pressed := false
var _selection_dragging := false
var _selection_start := Vector2.ZERO
var _selection_current := Vector2.ZERO
var _mouse_position := Vector2.ZERO
var _texture_cache: Dictionary = {}
var _effects: Array[Dictionary] = []


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
	_texture_cache.clear()
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
	camera_scale = clampf(minf(available.x / bounds.size.x, available.y / bounds.size.y), 0.48, 0.78)
	camera_offset = Vector2(size.x * 0.5, size.y * 0.49) - bounds.get_center() * camera_scale
	_camera_initialized = true
	_clamp_camera()


func center_on_cell(cell: Vector2i) -> void:
	camera_offset = size * 0.5 - IsoProjection.cell_center(cell) * camera_scale
	_clamp_camera()
	queue_redraw()


func center_on_player_stronghold() -> void:
	center_on_cell(MapCatalog.PLAYER_STRONGHOLD)


func _process(delta: float) -> void:
	var camera_direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	if camera_direction.length_squared() > 0.0:
		camera_offset -= camera_direction * 520.0 * delta
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
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		_mouse_position = button.position
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_dragging = button.pressed
			accept_event()
			return
		if button.pressed and button.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_zoom_at(button.position, 1.12 if button.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.12)
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_handle_left_press(button.position)
			else:
				_handle_left_release(button.position)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
			_handle_right_click(button.position)
			accept_event()


func _handle_left_press(position: Vector2) -> void:
	if placement_worker_id >= 0:
		var cell := screen_to_cell(position)
		if simulation.command_build_war_camp(placement_worker_id, cell):
			feedback.emit("War Camp foundation placed.", false)
			placement_worker_id = -1
		else:
			feedback.emit("That site cannot host a War Camp.", true)
		return
	if attack_move_armed:
		var cell := screen_to_cell(position)
		var units := selected_commandable_units()
		if not units.is_empty() and MapCatalog.in_bounds(cell):
			simulation.command_move(units, cell, true)
			feedback.emit("Attack-move order issued.", false)
		attack_move_armed = false
		return
	_selection_pressed = true
	_selection_dragging = false
	_selection_start = position
	_selection_current = position


func _handle_left_release(position: Vector2) -> void:
	if not _selection_pressed:
		return
	_selection_pressed = false
	_selection_current = position
	if _selection_dragging:
		_select_in_rect(Rect2(_selection_start, _selection_current - _selection_start).abs())
	else:
		var hit := entity_at_screen(position, true)
		select_entities([] if hit < 0 else [hit])
	_selection_dragging = false


func _handle_right_click(position: Vector2) -> void:
	cancel_modes()
	if selected_ids.is_empty():
		return
	var target_id := entity_at_screen(position, false)
	if target_id >= 0:
		var target := simulation.entity(target_id)
		if int(target.get("team", RtsSimulation.TEAM_NEUTRAL)) == RtsSimulation.TEAM_ENEMY:
			simulation.command_attack(selected_commandable_units(), target_id)
			feedback.emit("Focus-fire order issued.", false)
			return
		if target.get("category") == &"resource":
			var workers := _selected_of_kind(&"worker")
			if not workers.is_empty():
				simulation.command_gather(workers, target_id)
				feedback.emit("Workers assigned to %s." % _display_name(target), false)
				return
	var selected_structure := primary_selected_structure()
	var cell := screen_to_cell(position)
	if selected_structure >= 0 and selected_commandable_units().is_empty():
		simulation.set_rally(selected_structure, cell)
		feedback.emit("Rally point updated.", false)
	else:
		simulation.command_move(selected_commandable_units(), cell)
		feedback.emit("Move order issued.", false)


func _select_in_rect(rect: Rect2) -> void:
	var ids: Array[int] = []
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if not bool(entity_state.get("alive", false)):
			continue
		if int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL)) != RtsSimulation.TEAM_PLAYER:
			continue
		if entity_state.get("category") != &"unit":
			continue
		if rect.has_point(entity_screen_position(entity_state)):
			ids.append(int(entity_state["id"]))
	select_entities(ids)


func select_entities(ids: Array[int]) -> void:
	selected_ids.clear()
	for id in ids:
		var entity_state := simulation.entity(id)
		if not entity_state.is_empty() and bool(entity_state.get("alive", false)):
			selected_ids.append(id)
	selection_changed.emit(selected_ids.duplicate())
	queue_redraw()


func select_all_workers() -> void:
	select_entities(simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"worker"]))


func select_all_army() -> void:
	select_entities(simulation.team_entity_ids(RtsSimulation.TEAM_PLAYER, [&"vanguard", &"mystic"]))


func select_player_stronghold() -> void:
	var id := simulation.primary_structure_id(RtsSimulation.TEAM_PLAYER, &"stronghold")
	if id >= 0:
		select_entities([id])
		center_on_player_stronghold()


func begin_attack_move() -> void:
	if selected_commandable_units().is_empty():
		feedback.emit("Select units before issuing attack-move.", true)
		return
	placement_worker_id = -1
	attack_move_armed = true
	feedback.emit("Attack-move armed: choose a destination.", false)


func begin_war_camp_placement() -> void:
	var workers := _selected_of_kind(&"worker")
	if workers.is_empty():
		feedback.emit("Select a worker to construct a War Camp.", true)
		return
	attack_move_armed = false
	placement_worker_id = workers[0]
	feedback.emit("Choose a clear meadow tile for the War Camp.", false)


func cancel_modes() -> void:
	attack_move_armed = false
	placement_worker_id = -1


func selected_commandable_units() -> Array[int]:
	var result: Array[int] = []
	for id in selected_ids:
		var entity_state := simulation.entity(id)
		if entity_state.get("category") == &"unit" and int(entity_state.get("team", -1)) == RtsSimulation.TEAM_PLAYER:
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
		if selectable_only and int(entity_state.get("team", -1)) != RtsSimulation.TEAM_PLAYER:
			continue
		var radius := 28.0 * camera_scale
		var priority := 3
		match entity_state.get("category"):
			&"structure":
				radius = 66.0 * camera_scale
				priority = 1
			&"resource":
				radius = 40.0 * camera_scale
				priority = 0
		var distance := entity_screen_position(entity_state).distance_to(screen_position)
		if distance <= maxf(radius, 16.0) and (priority > best_priority or (priority == best_priority and distance < best_distance)):
			best_priority = priority
			best_distance = distance
			best_id = int(entity_state["id"])
	return best_id


func _zoom_at(position: Vector2, factor: float) -> void:
	var world_point := (position - camera_offset) / camera_scale
	camera_scale = clampf(camera_scale * factor, 0.46, 1.05)
	camera_offset = position - world_point * camera_scale
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
			var terrain := MapCatalog.terrain_at(cell)
			var points := IsoProjection.transformed_polygon(cell, camera_scale, camera_offset)
			var texture := TERRAIN_TEXTURES.get(terrain) as Texture2D
			var tint := Color.WHITE
			if terrain == &"ridge":
				tint = Color(0.82, 0.87, 0.85, 1.0)
			elif terrain == &"water":
				tint = Color(0.74, 0.96, 1.0, 0.95)
			else:
				var variation := 0.92 + float(posmod(x * 17 + y * 29, 7)) * 0.018
				tint = Color(variation, variation, variation * 0.98, 1.0)
			var colors := PackedColorArray([tint, tint, tint, tint])
			var uvs := PackedVector2Array([
				Vector2(float(x) * 0.33, float(y) * 0.33),
				Vector2(float(x + 1) * 0.33, float(y) * 0.33),
				Vector2(float(x + 1) * 0.33, float(y + 1) * 0.33),
				Vector2(float(x) * 0.33, float(y + 1) * 0.33),
			])
			draw_polygon(points, colors, uvs, texture)
			var closed := points.duplicate()
			closed.append(points[0])
			draw_polyline(closed, GRID_COLOR, 1.0, true)


func _draw_hover_feedback() -> void:
	var cell := screen_to_cell(_mouse_position)
	if not MapCatalog.in_bounds(cell):
		return
	var points := IsoProjection.transformed_polygon(cell, camera_scale, camera_offset)
	var closed := points.duplicate()
	closed.append(points[0])
	if placement_worker_id >= 0:
		var valid := simulation.can_place_war_camp(RtsSimulation.TEAM_PLAYER, cell)
		var color := PLAYER_COLOR if valid else ENEMY_COLOR
		draw_colored_polygon(points, Color(color, 0.24))
		draw_polyline(closed, color, 2.5, true)
		var faction := simulation.players[RtsSimulation.TEAM_PLAYER]["faction"] as StringName
		var texture := _entity_texture(faction, &"war_camp")
		var center := camera_offset + IsoProjection.cell_center(cell) * camera_scale
		_draw_world_texture(texture, center, Vector2(140.0, 116.0) * camera_scale, Color(1, 1, 1, 0.58 if valid else 0.35))
	elif attack_move_armed:
		draw_colored_polygon(points, Color(ENEMY_COLOR, 0.12))
		draw_polyline(closed, ENEMY_COLOR, 2.0, true)
	else:
		draw_polyline(closed, Color(PLAYER_COLOR, 0.52), 1.4, true)


func _draw_entities() -> void:
	var renderables: Array[Dictionary] = []
	for raw_entity in simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if bool(entity_state.get("alive", false)):
			renderables.append(entity_state)
	renderables.sort_custom(
		func(first: Dictionary, second: Dictionary) -> bool:
			return IsoProjection.depth(first["position"] as Vector2) < IsoProjection.depth(second["position"] as Vector2)
	)
	for entity_state in renderables:
		_draw_entity(entity_state)


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

	if selected:
		var radius_x := 27.0 if category == &"unit" else 54.0
		var radius_y := 13.0 if category == &"unit" else 25.0
		_draw_ellipse(center + Vector2(0.0, 3.0 * camera_scale), radius_x * camera_scale, radius_y * camera_scale, PLAYER_COLOR, 2.4)

	if category == &"resource":
		var texture := RESOURCE_TEXTURES.get(kind) as Texture2D
		_draw_world_texture(texture, center, Vector2(98.0, 88.0) * camera_scale, tint)
		_draw_resource_bar(entity_state, center)
	else:
		var texture := _entity_texture(entity_state["faction"] as StringName, kind)
		var display_size := Vector2(94.0, 104.0) if category == &"unit" else Vector2(182.0, 152.0)
		_draw_world_texture(texture, center, display_size * camera_scale, tint)
		_draw_health_bar(entity_state, center, category)

	if kind == &"worker" and float(entity_state.get("cargo_amount", 0.0)) > 0.0:
		var cargo_color := Color("73dfab") if entity_state.get("cargo_kind") == &"jade" else Color("77c6ff")
		draw_circle(center + Vector2(23.0, -40.0) * camera_scale, maxf(3.0, 5.0 * camera_scale), cargo_color)


func _draw_world_texture(texture: Texture2D, center: Vector2, display_size: Vector2, tint: Color) -> void:
	if texture == null:
		return
	var rect := Rect2(
		Vector2(center.x - display_size.x * 0.5, center.y - display_size.y + 10.0 * camera_scale),
		display_size,
	)
	draw_texture_rect(texture, rect, false, tint)


func _draw_health_bar(entity_state: Dictionary, center: Vector2, category: StringName) -> void:
	var ratio := clampf(float(entity_state["hp"]) / float(entity_state["max_hp"]), 0.0, 1.0)
	if ratio >= 0.999 and not selected_ids.has(int(entity_state["id"])):
		return
	var width := (46.0 if category == &"unit" else 86.0) * camera_scale
	var y_offset := (-77.0 if category == &"unit" else -137.0) * camera_scale
	var rect := Rect2(center + Vector2(-width * 0.5, y_offset), Vector2(width, maxf(4.0, 6.0 * camera_scale)))
	draw_rect(rect, Color(0.02, 0.03, 0.03, 0.9), true)
	var health_color := PLAYER_COLOR if int(entity_state["team"]) == RtsSimulation.TEAM_PLAYER else ENEMY_COLOR
	draw_rect(Rect2(rect.position + Vector2.ONE, Vector2((rect.size.x - 2.0) * ratio, rect.size.y - 2.0)), health_color, true)


func _draw_resource_bar(entity_state: Dictionary, center: Vector2) -> void:
	var ratio := clampf(float(entity_state["amount"]) / float(entity_state["max_amount"]), 0.0, 1.0)
	var width := 52.0 * camera_scale
	var rect := Rect2(center + Vector2(-width * 0.5, -75.0 * camera_scale), Vector2(width, maxf(3.0, 5.0 * camera_scale)))
	draw_rect(rect, Color(0.02, 0.03, 0.03, 0.8), true)
	var resource_color := Color("72e0ac") if entity_state.get("resource_kind") == &"jade" else Color("75c6ff")
	draw_rect(Rect2(rect.position + Vector2.ONE, Vector2((rect.size.x - 2.0) * ratio, maxf(1.0, rect.size.y - 2.0))), resource_color, true)


func _draw_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(33):
		var angle := float(index) / 32.0 * TAU
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_polyline(points, color, width, true)


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
			var position := camera_offset + IsoProjection.position_center(effect["position"] as Vector2) * camera_scale
			draw_circle(position, (14.0 + (1.0 - ratio) * 24.0) * camera_scale, Color(color, 0.08), true)
			draw_arc(position, (14.0 + (1.0 - ratio) * 24.0) * camera_scale, 0.0, TAU, 28, color, 2.0, true)


func _entity_texture(faction: StringName, kind: StringName) -> Texture2D:
	var key := "%s:%s" % [faction, kind]
	if not _texture_cache.has(key):
		_texture_cache[key] = load(FactionCatalog.entity_art_path(faction, kind)) as Texture2D
	return _texture_cache[key] as Texture2D


func _display_name(entity_state: Dictionary) -> String:
	if entity_state.get("category") == &"resource":
		return "Jade outcrop" if entity_state.get("resource_kind") == &"jade" else "Essence shrine"
	return String(FactionCatalog.stats(entity_state["kind"] as StringName, entity_state["faction"] as StringName)["name"])
