class_name ResponsiveLayout
extends RefCounted

const PORTRAIT_ASPECT_THRESHOLD := 0.92
const MIN_SAFE_MARGIN := 8.0
const MIN_TOUCH_TARGET := 48.0


static func is_portrait(viewport_size: Vector2) -> bool:
	return viewport_size.y > 0.0 and viewport_size.x / viewport_size.y < PORTRAIT_ASPECT_THRESHOLD


static func safe_rect(viewport_size: Vector2, platform_safe_area: Rect2i = Rect2i()) -> Rect2:
	var full := Rect2(Vector2.ZERO, viewport_size)
	if platform_safe_area.size.x <= 0 or platform_safe_area.size.y <= 0:
		return full.grow(-MIN_SAFE_MARGIN)
	var safe := Rect2(platform_safe_area)
	# Native safe areas are screen-space. Ignore unrelated monitor coordinates or
	# dimensions that cannot describe this viewport.
	if safe.position.x < 0.0 or safe.position.y < 0.0 or safe.end.x > viewport_size.x or safe.end.y > viewport_size.y:
		return full.grow(-MIN_SAFE_MARGIN)
	return safe.grow(-MIN_SAFE_MARGIN)


static func clamped_panel_size(preferred: Vector2, safe: Rect2, minimum: Vector2) -> Vector2:
	return Vector2(
		clampf(preferred.x, minimum.x, safe.size.x),
		clampf(preferred.y, minimum.y, safe.size.y),
	)


## Grid columns share their widest item; measure the same geometry as GridContainer.
static func grid_content_size(items: Array[Vector2], columns: int, spacing: Vector2) -> Vector2:
	if items.is_empty():
		return Vector2.ZERO
	columns = maxi(1, mini(columns, items.size()))
	var rows := ceili(float(items.size()) / float(columns))
	var widths: Array[float] = []
	var heights: Array[float] = []
	widths.resize(columns)
	heights.resize(rows)
	widths.fill(0.0)
	heights.fill(0.0)
	for index: int in range(items.size()):
		var column := index % columns
		var row := index / columns
		widths[column] = maxf(widths[column], items[index].x)
		heights[row] = maxf(heights[row], items[index].y)
	var result := Vector2(spacing.x * (columns - 1), spacing.y * (rows - 1))
	for width: float in widths:
		result.x += width
	for height: float in heights:
		result.y += height
	return result


static func fitting_grid_columns(items: Array[Vector2], width: float, separation: float, maximum: int) -> int:
	for columns: int in range(maxi(1, mini(maximum, items.size())), 0, -1):
		if grid_content_size(items, columns, Vector2(separation, 0.0)).x <= width:
			return columns
	return 1
