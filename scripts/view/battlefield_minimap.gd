extends Control

const PLAYER_COLOR := Color("78dfb7")
const ENEMY_COLOR := Color("f06656")
const RESOURCE_COLOR := Color("deb961")
const TREE_COLOR := Color("7cab62")
const CAVE_COLOR := Color("d7bd6c")
const MONSTER_COLOR := Color("c79855")
const CAMERA_COLOR := Color(0.96, 0.9, 0.64, 0.9)
const REDRAW_SECONDS := 0.1
const TERRAIN_COLORS := {
	&"meadow": Color("315d4c"),
	&"ridge": Color("3a4546"),
	&"water": Color("236170"),
	&"forest": Color("173f2d"),
	&"road": Color("c19b57"),
	&"bridge": Color("d0d0b2"),
}

var battlefield: Battlefield
var _dragging := false
var _redraw_timer := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click or drag to move the battlefield camera."
	set_process(true)


func set_battlefield(value: Battlefield) -> void:
	battlefield = value
	queue_redraw()


func _process(delta: float) -> void:
	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = REDRAW_SECONDS
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if battlefield == null:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button.pressed
			if button.pressed:
				_center_battlefield(button.position)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_center_battlefield((event as InputEventMouseMotion).position)
		accept_event()


func _center_battlefield(local_position: Vector2) -> void:
	var map_rect := _map_rect()
	var normalized := (local_position - map_rect.position) / map_rect.size
	normalized.x = clampf(normalized.x, 0.0, 0.999)
	normalized.y = clampf(normalized.y, 0.0, 0.999)
	var cell := Vector2i(
		floori(normalized.x * MapCatalog.SIZE.x),
		floori(normalized.y * MapCatalog.SIZE.y),
	)
	battlefield.center_on_cell(cell)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("071416"), true)
	var map_rect := _map_rect()
	var cell_size := map_rect.size / Vector2(MapCatalog.SIZE)
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			var rect := Rect2(map_rect.position + Vector2(cell) * cell_size, cell_size + Vector2(0.5, 0.5))
			draw_rect(rect, TERRAIN_COLORS.get(MapCatalog.terrain_at(cell), Color("315d4c")), true)
	if battlefield == null or battlefield.simulation == null:
		return
	_draw_entities(map_rect, cell_size)
	_draw_fog(map_rect, cell_size)
	_draw_camera_view(map_rect)
	draw_rect(map_rect, Color("527b72"), false, 1.0)


func _draw_entities(map_rect: Rect2, cell_size: Vector2) -> void:
	for raw_entity in battlefield.simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if not battlefield.should_render_entity(entity_state):
			continue
		var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
		var map_position := (entity_state["position"] as Vector2) + Vector2(footprint) * 0.5
		var center := map_rect.position + map_position / Vector2(MapCatalog.SIZE) * map_rect.size
		var category := entity_state.get("category") as StringName
		var team := int(entity_state.get("team", RtsSimulation.TEAM_NEUTRAL))
		var color := TREE_COLOR if entity_state.get("resource_kind") == &"lumber" else RESOURCE_COLOR
		if entity_state.get("kind") == &"yaoguai_den":
			color = CAVE_COLOR
		elif entity_state.get("kind") == &"jadeclaw" and team == RtsSimulation.TEAM_NEUTRAL:
			color = MONSTER_COLOR
		if team == RtsSimulation.TEAM_PLAYER:
			color = PLAYER_COLOR
		elif team == RtsSimulation.TEAM_ENEMY:
			color = ENEMY_COLOR
		var radius := 2.0
		if category == &"structure":
			var marker_size := Vector2(footprint) * cell_size
			draw_rect(Rect2(center - marker_size * 0.5, marker_size).grow(0.5), color, true)
		else:
			radius = 2.8 if category == &"unit" else 2.2
			draw_circle(center, radius, color)


func _draw_fog(map_rect: Rect2, cell_size: Vector2) -> void:
	if not battlefield.fog_enabled:
		return
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			if battlefield.is_cell_visible(cell):
				continue
			var color := Color(0.015, 0.045, 0.05, 0.55)
			if not battlefield.is_cell_explored(cell):
				color = Color(0.0, 0.012, 0.016, 0.94)
			var rect := Rect2(map_rect.position + Vector2(cell) * cell_size, cell_size + Vector2(0.5, 0.5))
			draw_rect(rect, color, true)


func _draw_camera_view(map_rect: Rect2) -> void:
	var corners := PackedVector2Array([
		Vector2.ZERO,
		Vector2(battlefield.size.x, 0.0),
		battlefield.size,
		Vector2(0.0, battlefield.size.y),
	])
	var points := PackedVector2Array()
	for corner in corners:
		var map_position := battlefield.screen_to_map_position(corner)
		points.append(map_rect.position + map_position / Vector2(MapCatalog.SIZE) * map_rect.size)
	points.append(points[0])
	draw_polyline(points, CAMERA_COLOR, 1.5, true)


func _map_rect() -> Rect2:
	return Rect2(Vector2(4.0, 4.0), size - Vector2(8.0, 8.0))
