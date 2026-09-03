extends RefCounted

## Builds a presentation-only fog texture in logical map space. Visibility and
## exploration remain authoritative dictionaries supplied by RtsSimulation.

const DEFAULT_PIXELS_PER_CELL := 3
const PADDING_CELLS := 1
const WARP_STRENGTH_CELLS := 0.28
const VISIBILITY_FEATHER_START := 0.12
const VISIBILITY_FEATHER_END := 0.76
const EXPLORATION_FEATHER_START := 0.18
const EXPLORATION_FEATHER_END := 0.82

var map_size: Vector2i
var pixels_per_cell: int
var explored_color: Color
var unexplored_color: Color
var _texture_size: Vector2i
var _sample_positions := PackedVector2Array()


func _init(
	value_map_size: Vector2i,
	value_pixels_per_cell: int = DEFAULT_PIXELS_PER_CELL,
	value_explored_color: Color = Color(0.015, 0.055, 0.06, 0.58),
	value_unexplored_color: Color = Color(0.005, 0.018, 0.022, 0.97),
) -> void:
	map_size = value_map_size
	pixels_per_cell = maxi(1, value_pixels_per_cell)
	explored_color = value_explored_color
	unexplored_color = value_unexplored_color
	_texture_size = (map_size + Vector2i.ONE * PADDING_CELLS * 2) * pixels_per_cell
	_cache_sample_positions()


func texture_size() -> Vector2i:
	return _texture_size


func map_uv_rect() -> Rect2:
	var texture_extent := Vector2(_texture_size)
	var start := Vector2.ONE * float(PADDING_CELLS * pixels_per_cell) / texture_extent
	var end := (
		Vector2(map_size + Vector2i.ONE * PADDING_CELLS)
		* float(pixels_per_cell)
		/ texture_extent
	)
	return Rect2(start, end - start)


func build_image(visible_cells: Dictionary, explored_cells: Dictionary) -> Image:
	var image := Image.create(
		_texture_size.x,
		_texture_size.y,
		false,
		Image.FORMAT_RGBA8,
	)
	for pixel_y in range(_texture_size.y):
		for pixel_x in range(_texture_size.x):
			var index := pixel_y * _texture_size.x + pixel_x
			var sample_position := _sample_positions[index]
			var visible_amount := _smoothstep(
				VISIBILITY_FEATHER_START,
				VISIBILITY_FEATHER_END,
				_sample_cell_field(visible_cells, sample_position),
			)
			var explored_amount := _smoothstep(
				EXPLORATION_FEATHER_START,
				EXPLORATION_FEATHER_END,
				_sample_cell_field(explored_cells, sample_position),
			)
			var color := unexplored_color.lerp(explored_color, explored_amount)
			color.a *= 1.0 - visible_amount
			image.set_pixel(pixel_x, pixel_y, color)
	return image


func _cache_sample_positions() -> void:
	_sample_positions.resize(_texture_size.x * _texture_size.y)
	for pixel_y in range(_texture_size.y):
		for pixel_x in range(_texture_size.x):
			var map_position := Vector2(
				(float(pixel_x) + 0.5) / float(pixels_per_cell),
				(float(pixel_y) + 0.5) / float(pixels_per_cell),
			) - Vector2.ONE * float(PADDING_CELLS)
			var broad_warp := Vector2(
				_value_noise(map_position * 0.22, 0) - 0.5,
				_value_noise(map_position * 0.22, 1) - 0.5,
			)
			var fine_warp := Vector2(
				_value_noise(map_position * 0.61, 2) - 0.5,
				_value_noise(map_position * 0.61, 3) - 0.5,
			)
			var offset := (broad_warp * 0.78 + fine_warp * 0.22) * WARP_STRENGTH_CELLS * 2.0
			_sample_positions[pixel_y * _texture_size.x + pixel_x] = map_position + offset


func _sample_cell_field(cells: Dictionary, map_position: Vector2) -> float:
	# Cell values live at cell centers. Sampling this field bilinearly turns the
	# hard simulation grid into a continuous visual field without altering truth.
	var centered := map_position - Vector2(0.5, 0.5)
	var origin := Vector2i(floori(centered.x), floori(centered.y))
	var fraction := centered - Vector2(origin)
	var top := lerpf(
		_cell_value(cells, origin),
		_cell_value(cells, origin + Vector2i.RIGHT),
		fraction.x,
	)
	var bottom := lerpf(
		_cell_value(cells, origin + Vector2i.DOWN),
		_cell_value(cells, origin + Vector2i.ONE),
		fraction.x,
	)
	return lerpf(top, bottom, fraction.y)


func _cell_value(cells: Dictionary, cell: Vector2i) -> float:
	if cell.x < 0 or cell.y < 0 or cell.x >= map_size.x or cell.y >= map_size.y:
		return 0.0
	return 1.0 if cells.has(cell) else 0.0


func _value_noise(position: Vector2, channel: int) -> float:
	var origin := Vector2i(floori(position.x), floori(position.y))
	var fraction := position - Vector2(origin)
	var blend := fraction * fraction * (Vector2(3.0, 3.0) - fraction * 2.0)
	var top := lerpf(
		_hash01(origin, channel),
		_hash01(origin + Vector2i.RIGHT, channel),
		blend.x,
	)
	var bottom := lerpf(
		_hash01(origin + Vector2i.DOWN, channel),
		_hash01(origin + Vector2i.ONE, channel),
		blend.x,
	)
	return lerpf(top, bottom, blend.y)


func _hash01(point: Vector2i, channel: int) -> float:
	var value := sin(
		float(point.x) * 12.9898
		+ float(point.y) * 78.233
		+ float(channel) * 37.719,
	) * 43758.5453
	return value - floorf(value)


func _smoothstep(edge_start: float, edge_end: float, value: float) -> float:
	var amount := clampf((value - edge_start) / (edge_end - edge_start), 0.0, 1.0)
	return amount * amount * (3.0 - 2.0 * amount)
