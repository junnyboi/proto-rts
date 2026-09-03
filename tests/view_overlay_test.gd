extends SceneTree

const FOG_MASK_BUILDER_SCRIPT := preload("res://scripts/view/fog_mask_builder.gd")
const MAP_EDGE_CONTOUR_SCRIPT := preload("res://scripts/view/map_edge_contour.gd")
const MAP_SIZE := Vector2i(12, 8)
const PIXELS_PER_CELL := 3


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var failures: Array[String] = []
	_test_fog_mask(failures)
	_test_map_edge_contour(failures)
	if failures.is_empty():
		print("PASS view_overlay_test: deterministic feathered fog field and continuous organic map-edge bands")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_fog_mask(failures: Array[String]) -> void:
	var explored_color := Color(0.015, 0.055, 0.06, 0.58)
	var unexplored_color := Color(0.005, 0.018, 0.022, 0.97)
	var builder = FOG_MASK_BUILDER_SCRIPT.new(
		MAP_SIZE,
		PIXELS_PER_CELL,
		explored_color,
		unexplored_color,
	)
	var visible_cells: Dictionary = {}
	var explored_cells: Dictionary = {}
	for y in range(1, 7):
		for x in range(1, 8):
			explored_cells[Vector2i(x, y)] = true
	for y in range(2, 5):
		for x in range(2, 5):
			var cell := Vector2i(x, y)
			visible_cells[cell] = true
			explored_cells[cell] = true
	var image: Image = builder.build_image(visible_cells, explored_cells)
	var repeated: Image = builder.build_image(visible_cells, explored_cells)
	_expect(
		image.get_size() == (MAP_SIZE + Vector2i.ONE * 2) * PIXELS_PER_CELL,
		"fog mask dimensions did not include the map-scaled field and safe padding",
		failures,
	)
	_expect(
		image.get_data() == repeated.get_data(),
		"fog mask noise was not deterministic",
		failures,
	)
	var uv_rect: Rect2 = builder.map_uv_rect()
	var expected_uv_start := Vector2(
		1.0 / float(MAP_SIZE.x + 2),
		1.0 / float(MAP_SIZE.y + 2),
	)
	var expected_uv_size := Vector2(MAP_SIZE) / Vector2(MAP_SIZE + Vector2i.ONE * 2)
	_expect(
		uv_rect.position.is_equal_approx(expected_uv_start)
		and uv_rect.size.is_equal_approx(expected_uv_size),
		"fog map UVs did not isolate the padded field from texture wrapping",
		failures,
	)
	var visible_alpha := image.get_pixelv(_cell_center_pixel(Vector2i(3, 3))).a
	var explored_alpha := image.get_pixelv(_cell_center_pixel(Vector2i(6, 3))).a
	var unexplored_alpha := image.get_pixelv(_cell_center_pixel(Vector2i(10, 6))).a
	_expect(visible_alpha <= 0.02, "fully visible cell retained an opaque fog core", failures)
	_expect(
		explored_alpha >= 0.54 and explored_alpha <= 0.62,
		"explored fog did not preserve its intended plateau opacity",
		failures,
	)
	_expect(unexplored_alpha >= 0.93, "unexplored fog did not preserve its opaque core", failures)
	var found_feathered_pixel := false
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.04 and alpha < explored_color.a - 0.04:
				found_feathered_pixel = true
				break
		if found_feathered_pixel:
			break
	_expect(found_feathered_pixel, "fog mask did not contain a soft visible-to-hidden transition", failures)


func _test_map_edge_contour(failures: Array[String]) -> void:
	var contour = MAP_EDGE_CONTOUR_SCRIPT.new(MAP_SIZE)
	var polygons: Array[PackedVector2Array] = contour.band_polygons(2.4)
	_expect(polygons.size() == 4, "map edge did not produce one continuous strip per side", failures)
	for polygon in polygons:
		_expect(polygon.size() > 4, "map edge strip did not contain an organic inner contour", failures)
		for point in polygon:
			_expect(
				point.x >= 0.0 and point.y >= 0.0 and point.x <= MAP_SIZE.x and point.y <= MAP_SIZE.y,
				"map edge contour escaped the logical map bounds",
				failures,
			)


func _cell_center_pixel(cell: Vector2i) -> Vector2i:
	return (
		(cell + Vector2i.ONE) * PIXELS_PER_CELL
		+ Vector2i.ONE * (PIXELS_PER_CELL / 2)
	)
