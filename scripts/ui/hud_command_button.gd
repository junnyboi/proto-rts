class_name HudCommandButton
extends Button

var command_title := ""
var cost_markup := ""
var hotkey_text := ""
var art_texture: Texture2D
var glyph: StringName = &"objective"
var glyph_color := Color("d9b45e")

var _title_label: Label
var _cost_label: RichTextLabel
var _badge: Label
var _art_host: Control
var _art_visual: Control
var _animation_time := 0.0
var _hover_strength := 0.0
var _press_depth := 0.0
var _release_glint := 0.0
var _disabled_nudge := 0.0
var _reduced_motion := false


func _init() -> void:
	text = ""
	clip_contents = true
	custom_minimum_size = Vector2(92.0, 66.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	_build_content()
	set_process(true)
	pressed.connect(_on_visual_activated)
	button_down.connect(func() -> void: queue_redraw())
	button_up.connect(_on_visual_release)
	mouse_entered.connect(func() -> void: queue_redraw())
	mouse_exited.connect(func() -> void: queue_redraw())
	gui_input.connect(_on_visual_gui_input)


func _process(delta: float) -> void:
	_animation_time = fmod(_animation_time + delta, TAU * 1000.0)
	var hover_target := 1.0 if is_hovered() and not disabled else 0.0
	var press_target := 2.0 if is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not disabled else 0.0
	if _reduced_motion:
		_hover_strength = hover_target
		_press_depth = press_target
	else:
		_hover_strength = lerpf(_hover_strength, hover_target, clampf(delta * 14.0, 0.0, 1.0))
		_press_depth = lerpf(_press_depth, press_target, clampf(delta * 24.0, 0.0, 1.0))
	_release_glint = maxf(0.0, _release_glint - delta * (7.0 if _reduced_motion else 4.5))
	_disabled_nudge = maxf(0.0, _disabled_nudge - delta * 5.0)
	if _art_visual != null:
		var nudge := sin(_disabled_nudge * PI * 4.0) * 2.0 if _disabled_nudge > 0.0 and not _reduced_motion else 0.0
		_art_visual.offset_left = nudge
		_art_visual.offset_right = nudge
		_art_visual.offset_top = _press_depth
		_art_visual.offset_bottom = _press_depth
	queue_redraw()


func _draw() -> void:
	var inset := 2.0
	var rect := Rect2(Vector2.ONE * inset, size - Vector2.ONE * inset * 2.0)
	if _hover_strength > 0.01:
		var hover_color := Color(glyph_color, (0.18 + sin(_animation_time * 3.0) * 0.05) * _hover_strength)
		draw_rect(rect, hover_color, false, 1.0 + _hover_strength, true)
	if button_pressed:
		var armed_color := Color(glyph_color, 0.34 + sin(_animation_time * 3.4) * 0.16)
		draw_arc(size * 0.5, minf(size.x, size.y) * 0.43, _animation_time * 0.7, _animation_time * 0.7 + PI * 1.45, 28, armed_color, 1.6, true)
	if _release_glint > 0.0:
		var progress := 1.0 - _release_glint
		var x := lerpf(4.0, size.x - 4.0, progress)
		draw_line(Vector2(x - 9.0, 3.0), Vector2(x + 9.0, 3.0), Color(1.0, 0.93, 0.62, _release_glint * 0.85), 2.0, true)


func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	queue_redraw()


func animation_diagnostics() -> Dictionary:
	return {
		"hover": _hover_strength,
		"press_depth": _press_depth,
		"release_glint": _release_glint,
		"reduced_motion": _reduced_motion,
	}


func configure(
	title: String,
	cost: String = "",
	hotkey: String = "",
	texture: Texture2D = null,
	icon_glyph: StringName = &"objective",
	color: Color = Color("d9b45e"),
) -> HudCommandButton:
	command_title = title
	cost_markup = cost
	hotkey_text = hotkey
	art_texture = texture
	glyph = icon_glyph
	glyph_color = color
	if is_node_ready():
		_refresh_content()
	return self


func set_cost_markup(value: String) -> void:
	cost_markup = value
	if _cost_label != null:
		_cost_label.text = value
		_cost_label.visible = not value.is_empty()


func set_command_title(value: String) -> void:
	command_title = value
	if _title_label != null:
		_title_label.text = value


func set_hotkey(value: String) -> void:
	hotkey_text = value
	if _badge != null:
		_badge.text = _badge_label()
		_badge.visible = not value.is_empty()
		_layout_badge()


func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 4)
	margin.add_theme_constant_override(&"margin_top", 4)
	margin.add_theme_constant_override(&"margin_right", 4)
	margin.add_theme_constant_override(&"margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	_art_host = Control.new()
	_art_host.custom_minimum_size = Vector2(32.0, 44.0)
	_art_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_art_host)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override(&"separation", 1)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(copy)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override(&"font_size", 10)
	_title_label.add_theme_color_override(&"font_color", Color("f0e2c0"))
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(_title_label)

	_cost_label = RichTextLabel.new()
	_cost_label.bbcode_enabled = true
	_cost_label.fit_content = true
	_cost_label.scroll_active = false
	_cost_label.custom_minimum_size.y = 17.0
	_cost_label.add_theme_font_size_override(&"normal_font_size", 9)
	_cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(_cost_label)

	_badge = Label.new()
	_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_badge.position = Vector2(-22.0, 3.0)
	_badge.size = Vector2(18.0, 18.0)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override(&"font_size", 10)
	_badge.add_theme_color_override(&"font_color", Color("f0e2c0"))
	_badge.add_theme_stylebox_override(&"normal", ThemeFactory.badge_style())
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)
	_layout_badge()
	_refresh_content()


func _layout_badge() -> void:
	if _badge == null:
		return
	var badge_width := maxf(18.0, 8.0 + float(_badge_label().length()) * 6.0)
	_badge.offset_left = -badge_width - 4.0
	_badge.offset_top = 3.0
	_badge.offset_right = -4.0
	_badge.offset_bottom = 21.0


func _badge_label() -> String:
	return I18n.t(&"ui.hotkey.space_short") if hotkey_text == I18n.t(&"ui.hotkey.space") else hotkey_text


func _refresh_content() -> void:
	_title_label.text = command_title
	_cost_label.text = cost_markup
	_cost_label.visible = not cost_markup.is_empty()
	_badge.text = _badge_label()
	_badge.visible = not hotkey_text.is_empty()
	_layout_badge()
	for child in _art_host.get_children():
		child.queue_free()
	var art: Control
	if art_texture != null:
		var texture_rect := TextureRect.new()
		texture_rect.texture = art_texture
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art = texture_rect
	else:
		art = HudIcon.new().configure(glyph, glyph_color)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_host.add_child(art)
	_art_visual = art


func _on_visual_activated() -> void:
	_release_glint = 1.0
	queue_redraw()


func _on_visual_release() -> void:
	if not disabled:
		_release_glint = 1.0
	queue_redraw()


func _on_visual_gui_input(event: InputEvent) -> void:
	if disabled and event is InputEventMouseButton and event.pressed:
		_disabled_nudge = 1.0
		queue_redraw()
