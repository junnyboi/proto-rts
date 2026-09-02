class_name HudCommandButton
extends Button

var command_title := "COMMAND"
var cost_markup := ""
var hotkey_text := ""
var art_texture: Texture2D
var glyph: StringName = &"objective"
var glyph_color := Color("d9b45e")

var _title_label: Label
var _cost_label: RichTextLabel
var _badge: Label
var _art_host: Control


func _init() -> void:
	text = ""
	clip_contents = true
	custom_minimum_size = Vector2(92.0, 66.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	_build_content()


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
		_badge.text = value
		_badge.visible = not value.is_empty()


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
	_refresh_content()


func _refresh_content() -> void:
	_title_label.text = command_title
	_cost_label.text = cost_markup
	_cost_label.visible = not cost_markup.is_empty()
	_badge.text = hotkey_text
	_badge.visible = not hotkey_text.is_empty()
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
