class_name BattlefieldMinimap
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
var _terrain_texture: ImageTexture
var _entity_image: Image
var _entity_texture: ImageTexture
var _fog_image: Image
var _fog_texture: ImageTexture


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "Click or drag to move the battlefield camera."
	_ensure_image_caches()
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


func _ensure_image_caches() -> void:
	if _terrain_texture != null:
		return
	var terrain_image := Image.create(MapCatalog.SIZE.x, MapCatalog.SIZE.y, false, Image.FORMAT_RGBA8)
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			terrain_image.set_pixelv(cell, TERRAIN_COLORS.get(MapCatalog.terrain_at(cell), Color("315d4c")))
	_terrain_texture = ImageTexture.create_from_image(terrain_image)
	_entity_image = Image.create(MapCatalog.SIZE.x, MapCatalog.SIZE.y, false, Image.FORMAT_RGBA8)
	_entity_image.fill(Color.TRANSPARENT)
	_entity_texture = ImageTexture.create_from_image(_entity_image)
	_fog_image = Image.create(MapCatalog.SIZE.x, MapCatalog.SIZE.y, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color.TRANSPARENT)
	_fog_texture = ImageTexture.create_from_image(_fog_image)


func _draw() -> void:
	_ensure_image_caches()
	draw_rect(Rect2(Vector2.ZERO, size), Color("071416"), true)
	var map_rect := _map_rect()
	draw_texture_rect(_terrain_texture, map_rect, false)
	if battlefield == null or battlefield.simulation == null:
		return
	_draw_entities(map_rect)
	_draw_fog(map_rect)
	_draw_camera_view(map_rect)
	draw_rect(map_rect, Color("527b72"), false, 1.0)


func _draw_entities(map_rect: Rect2) -> void:
	_entity_image.fill(Color.TRANSPARENT)
	for raw_entity in battlefield.simulation.entities.values():
		var entity_state := raw_entity as Dictionary
		if not battlefield.should_render_entity(entity_state):
			continue
		var footprint := entity_state.get("footprint", Vector2i.ONE) as Vector2i
		var cell := Vector2i((entity_state["position"] as Vector2).floor())
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
		if category == &"structure":
			for footprint_cell in MapCatalog.footprint_cells(cell, footprint):
				_set_overlay_pixel(_entity_image, footprint_cell, color)
		elif category == &"unit":
			_paint_marker(_entity_image, cell, color, 1)
		else:
			_set_overlay_pixel(_entity_image, cell, color)
	_entity_texture.update(_entity_image)
	draw_texture_rect(_entity_texture, map_rect, false)


func _draw_fog(map_rect: Rect2) -> void:
	if not battlefield.fog_enabled:
		return
	_fog_image.fill(Color.TRANSPARENT)
	for y in range(MapCatalog.SIZE.y):
		for x in range(MapCatalog.SIZE.x):
			var cell := Vector2i(x, y)
			if battlefield.is_cell_visible(cell):
				continue
			var color := Color(0.015, 0.045, 0.05, 0.55)
			if not battlefield.is_cell_explored(cell):
				color = Color(0.0, 0.012, 0.016, 0.94)
			_fog_image.set_pixelv(cell, color)
	_fog_texture.update(_fog_image)
	draw_texture_rect(_fog_texture, map_rect, false)


func _set_overlay_pixel(image: Image, cell: Vector2i, color: Color) -> void:
	if MapCatalog.in_bounds(cell):
		image.set_pixelv(cell, color)


func _paint_marker(image: Image, cell: Vector2i, color: Color, radius: int) -> void:
	for y in range(cell.y - radius, cell.y + radius + 1):
		for x in range(cell.x - radius, cell.x + radius + 1):
			_set_overlay_pixel(image, Vector2i(x, y), color)


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
