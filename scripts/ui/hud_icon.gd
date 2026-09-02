class_name HudIcon
extends Control

var glyph: StringName = &"objective"
var glyph_color := Color("d9b45e")


func _init() -> void:
	custom_minimum_size = Vector2(28.0, 28.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func configure(value: StringName, color: Color) -> HudIcon:
	glyph = value
	glyph_color = color
	queue_redraw()
	return self


func _draw() -> void:
	var scale := minf(size.x, size.y) / 32.0
	var offset := (size - Vector2.ONE * 32.0 * scale) * 0.5
	var c := glyph_color
	var dark := c.darkened(0.42)
	var light := c.lightened(0.26)
	match glyph:
		&"jade":
			_poly([Vector2(16, 2), Vector2(25, 10), Vector2(21, 27), Vector2(11, 27), Vector2(7, 10)], c, scale, offset)
			_line(Vector2(16, 3), Vector2(16, 27), dark, 1.5, scale, offset)
			_line(Vector2(7, 10), Vector2(16, 15), light, 1.2, scale, offset)
			_line(Vector2(25, 10), Vector2(16, 15), dark, 1.2, scale, offset)
		&"lumber":
			_line(Vector2(7, 21), Vector2(23, 8), c, 6.2, scale, offset)
			_line(Vector2(10, 26), Vector2(27, 13), light, 5.2, scale, offset)
			_circle(Vector2(7, 21), 3.2, dark, scale, offset)
			_circle(Vector2(10, 26), 2.7, dark, scale, offset)
		&"essence":
			_poly([Vector2(17, 2), Vector2(22, 10), Vector2(19, 13), Vector2(25, 16), Vector2(23, 25), Vector2(16, 30), Vector2(8, 25), Vector2(7, 17), Vector2(13, 10)], c, scale, offset)
			_poly([Vector2(17, 11), Vector2(20, 18), Vector2(17, 25), Vector2(12, 22), Vector2(13, 16)], light, scale, offset)
		&"food":
			_arc(Vector2(16, 12), 9.0, PI, TAU, c, 2.0, scale, offset)
			_poly([Vector2(5, 14), Vector2(27, 14), Vector2(23, 24), Vector2(9, 24)], c, scale, offset)
			_line(Vector2(9, 27), Vector2(23, 27), light, 2.2, scale, offset)
			_circle(Vector2(12, 10), 1.4, light, scale, offset)
			_circle(Vector2(17, 8), 1.4, light, scale, offset)
			_circle(Vector2(21, 11), 1.4, light, scale, offset)
		&"population":
			_circle(Vector2(16, 8), 4.0, c, scale, offset)
			_circle(Vector2(7, 12), 3.0, dark, scale, offset)
			_circle(Vector2(25, 12), 3.0, dark, scale, offset)
			_poly([Vector2(10, 27), Vector2(11, 16), Vector2(16, 13), Vector2(21, 16), Vector2(22, 27)], c, scale, offset)
			_poly([Vector2(2, 27), Vector2(3, 18), Vector2(7, 16), Vector2(10, 18), Vector2(9, 27)], dark, scale, offset)
			_poly([Vector2(23, 27), Vector2(22, 18), Vector2(25, 16), Vector2(29, 18), Vector2(30, 27)], dark, scale, offset)
		&"den":
			_poly([Vector2(4, 27), Vector2(5, 14), Vector2(10, 6), Vector2(16, 3), Vector2(23, 7), Vector2(28, 16), Vector2(28, 27)], c, scale, offset)
			_arc(Vector2(16, 25), 8.0, PI, TAU, dark, 5.5, scale, offset)
		&"clock":
			_arc(Vector2(16, 16), 12.0, 0.0, TAU, c, 2.0, scale, offset)
			_line(Vector2(16, 16), Vector2(16, 8), c, 2.0, scale, offset)
			_line(Vector2(16, 16), Vector2(22, 19), light, 2.0, scale, offset)
		&"move":
			_line(Vector2(5, 24), Vector2(23, 8), c, 3.0, scale, offset)
			_poly([Vector2(18, 5), Vector2(28, 4), Vector2(27, 14)], c, scale, offset)
			_line(Vector2(4, 28), Vector2(13, 28), dark, 2.0, scale, offset)
		&"attack_move":
			_line(Vector2(5, 26), Vector2(24, 7), c, 3.0, scale, offset)
			_poly([Vector2(19, 4), Vector2(29, 3), Vector2(28, 13)], c, scale, offset)
			_line(Vector2(6, 7), Vector2(23, 24), light, 2.2, scale, offset)
			_line(Vector2(5, 12), Vector2(11, 6), light, 2.2, scale, offset)
		&"patrol":
			_arc(Vector2(16, 16), 10.0, -2.6, 0.35, c, 2.5, scale, offset)
			_arc(Vector2(16, 16), 10.0, 0.55, 3.45, light, 2.5, scale, offset)
			_poly([Vector2(24, 6), Vector2(29, 12), Vector2(21, 13)], c, scale, offset)
			_poly([Vector2(8, 26), Vector2(3, 20), Vector2(11, 19)], light, scale, offset)
		&"repair":
			_line(Vector2(8, 26), Vector2(22, 12), c, 5.0, scale, offset)
			_poly([Vector2(17, 4), Vector2(27, 4), Vector2(28, 10), Vector2(21, 15), Vector2(16, 10)], light, scale, offset)
			_circle(Vector2(7, 27), 3.0, dark, scale, offset)
		&"stop":
			_poly([Vector2(10, 3), Vector2(22, 3), Vector2(29, 10), Vector2(29, 22), Vector2(22, 29), Vector2(10, 29), Vector2(3, 22), Vector2(3, 10)], c, scale, offset)
			_poly([Vector2(12, 9), Vector2(20, 9), Vector2(23, 12), Vector2(23, 22), Vector2(9, 22), Vector2(9, 12)], dark, scale, offset)
		&"rally":
			_line(Vector2(8, 3), Vector2(8, 29), c, 2.5, scale, offset)
			_poly([Vector2(9, 5), Vector2(27, 8), Vector2(22, 16), Vector2(9, 14)], c, scale, offset)
		&"cancel":
			_arc(Vector2(16, 16), 12.0, 0.0, TAU, c, 2.0, scale, offset)
			_line(Vector2(10, 10), Vector2(22, 22), c, 2.8, scale, offset)
			_line(Vector2(22, 10), Vector2(10, 22), c, 2.8, scale, offset)
		&"fog":
			_poly([Vector2(3, 16), Vector2(9, 10), Vector2(16, 7), Vector2(23, 10), Vector2(29, 16), Vector2(23, 22), Vector2(16, 25), Vector2(9, 22)], c, scale, offset)
			_circle(Vector2(16, 16), 6.0, dark, scale, offset)
			_circle(Vector2(16, 16), 2.4, light, scale, offset)
		&"ping":
			_arc(Vector2(16, 14), 9.0, 0.0, TAU, c, 2.0, scale, offset)
			_circle(Vector2(16, 14), 3.0, c, scale, offset)
			_poly([Vector2(10, 20), Vector2(22, 20), Vector2(16, 30)], c, scale, offset)
		&"zoom":
			_arc(Vector2(13, 13), 8.0, 0.0, TAU, c, 2.2, scale, offset)
			_line(Vector2(19, 19), Vector2(28, 28), c, 3.0, scale, offset)
			_line(Vector2(9, 13), Vector2(17, 13), light, 1.8, scale, offset)
			_line(Vector2(13, 9), Vector2(13, 17), light, 1.8, scale, offset)
		&"health":
			_poly([Vector2(16, 28), Vector2(5, 17), Vector2(5, 10), Vector2(9, 6), Vector2(14, 7), Vector2(16, 10), Vector2(18, 7), Vector2(23, 6), Vector2(27, 10), Vector2(27, 17)], c, scale, offset)
		&"cargo":
			_poly([Vector2(5, 11), Vector2(16, 5), Vector2(27, 11), Vector2(27, 24), Vector2(16, 29), Vector2(5, 24)], c, scale, offset)
			_line(Vector2(5, 11), Vector2(16, 17), dark, 1.4, scale, offset)
			_line(Vector2(27, 11), Vector2(16, 17), dark, 1.4, scale, offset)
			_line(Vector2(16, 17), Vector2(16, 29), dark, 1.4, scale, offset)
		&"queue":
			for index in range(3):
				var y := 8.0 + float(index) * 8.0
				_line(Vector2(5, y), Vector2(27, y), c if index == 0 else dark, 3.0, scale, offset)
		&"order":
			_arc(Vector2(16, 16), 11.0, 0.0, TAU, dark, 2.0, scale, offset)
			_line(Vector2(7, 24), Vector2(23, 8), c, 3.0, scale, offset)
			_poly([Vector2(18, 5), Vector2(28, 4), Vector2(27, 14)], c, scale, offset)
		&"objective":
			_poly([Vector2(16, 2), Vector2(30, 16), Vector2(16, 30), Vector2(2, 16)], c, scale, offset)
			_poly([Vector2(16, 8), Vector2(24, 16), Vector2(16, 24), Vector2(8, 16)], dark, scale, offset)
		_:
			_circle(Vector2(16, 16), 8.0, c, scale, offset)


func _v(point: Vector2, scale: float, offset: Vector2) -> Vector2:
	return offset + point * scale


func _poly(points: Array[Vector2], color: Color, scale: float, offset: Vector2) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(_v(point, scale, offset))
	draw_colored_polygon(transformed, color)


func _line(from: Vector2, to: Vector2, color: Color, width: float, scale: float, offset: Vector2) -> void:
	draw_line(_v(from, scale, offset), _v(to, scale, offset), color, width * scale, true)


func _circle(center: Vector2, radius: float, color: Color, scale: float, offset: Vector2) -> void:
	draw_circle(_v(center, scale, offset), radius * scale, color)


func _arc(center: Vector2, radius: float, start: float, end: float, color: Color, width: float, scale: float, offset: Vector2) -> void:
	draw_arc(_v(center, scale, offset), radius * scale, start, end, 24, color, width * scale, true)
