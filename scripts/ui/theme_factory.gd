class_name ThemeFactory
extends RefCounted

const INK := Color("0b1719")
const INK_DEEP := Color("071012")
const INK_SOFT := Color("14282a")
const PANEL := Color(0.035, 0.075, 0.078, 0.95)
const PANEL_LIGHT := Color(0.07, 0.14, 0.145, 0.96)
const PARCHMENT := Color("f3e4bf")
const IVORY := Color("f0e2c0")
const MUTED := Color("a9b8ae")
const MUTED_SAGE := Color("9aada4")
const GOLD := Color("deb961")
const JADE := Color("6fd2aa")
const DANGER := Color("e85d4f")
const ESSENCE := Color("a974e6")
const LUMBER := Color("d0a25c")
const FOOD := Color("e8c56a")


static func create() -> Theme:
	var theme := Theme.new()
	theme.set_default_font_size(17)
	theme.set_color(&"font_color", &"Label", PARCHMENT)
	theme.set_color(&"font_shadow_color", &"Label", Color(0.0, 0.0, 0.0, 0.7))
	theme.set_constant(&"shadow_offset_x", &"Label", 1)
	theme.set_constant(&"shadow_offset_y", &"Label", 2)
	theme.set_font_size(&"font_size", &"Label", 17)
	theme.set_font_size(&"font_size", &"Button", 16)
	theme.set_color(&"font_color", &"Button", PARCHMENT)
	theme.set_color(&"font_hover_color", &"Button", Color.WHITE)
	theme.set_color(&"font_pressed_color", &"Button", INK)
	theme.set_color(&"font_disabled_color", &"Button", Color(MUTED, 0.7))
	theme.set_color(&"font_focus_color", &"Button", Color.WHITE)
	theme.set_stylebox(&"normal", &"Button", button_style(INK_SOFT, Color("3d6761"), 1))
	theme.set_stylebox(&"hover", &"Button", button_style(Color("214942"), JADE, 2))
	theme.set_stylebox(&"pressed", &"Button", button_style(GOLD, Color("ffe8a0"), 2))
	theme.set_stylebox(&"focus", &"Button", button_style(Color(0.0, 0.0, 0.0, 0.0), GOLD, 2))
	theme.set_stylebox(&"disabled", &"Button", button_style(Color("101d1f"), Color("40504e"), 1))
	theme.set_stylebox(&"panel", &"PanelContainer", panel_style())
	theme.set_stylebox(&"panel", &"Panel", panel_style())
	theme.set_color(&"font_color", &"RichTextLabel", PARCHMENT)
	theme.set_color(&"default_color", &"RichTextLabel", PARCHMENT)
	theme.set_stylebox(&"background", &"ProgressBar", progress_background_style())
	theme.set_stylebox(&"fill", &"ProgressBar", progress_fill_style())
	theme.set_color(&"font_color", &"ProgressBar", IVORY)
	theme.set_font_size(&"font_size", &"ProgressBar", 11)
	return theme


static func panel_style(
	background: Color = PANEL,
	border: Color = Color("31514e"),
	width: int = 1,
	corner: int = 10,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(corner)
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	return style


static func button_style(
	background: Color,
	border: Color,
	width: int,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14.0
	style.content_margin_top = 9.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 9.0
	return style


static func hud_deck_style(accent: Color = JADE) -> StyleBoxFlat:
	var style := panel_style(Color("081414f7"), Color(accent, 0.72), 2, 3)
	style.content_margin_left = 8.0
	style.content_margin_top = 7.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 7.0
	return style


static func hud_inset_style(border: Color = Color("4d6e67")) -> StyleBoxFlat:
	var style := panel_style(Color("061011f2"), Color(border, 0.82), 1, 2)
	style.content_margin_left = 8.0
	style.content_margin_top = 6.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 6.0
	return style


static func economy_chip_style(color: Color) -> StyleBoxFlat:
	var style := panel_style(Color("0a1718f2"), Color(color, 0.48), 1, 2)
	style.content_margin_left = 8.0
	style.content_margin_top = 4.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 4.0
	return style


static func objective_style(active: bool = false) -> StyleBoxFlat:
	var border := GOLD if active else Color("49625d")
	var style := panel_style(Color("071112eb"), Color(border, 0.78), 1 if not active else 2, 3)
	style.content_margin_left = 9.0
	style.content_margin_top = 6.0
	style.content_margin_right = 9.0
	style.content_margin_bottom = 6.0
	return style


static func toast_style(color: Color = JADE) -> StyleBoxFlat:
	var style := panel_style(Color("071313f7"), color, 2, 4)
	style.content_margin_left = 14.0
	style.content_margin_top = 7.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 7.0
	return style


static func command_button_style(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := button_style(background, border, width)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style


static func portrait_style(accent: Color = GOLD) -> StyleBoxFlat:
	var style := panel_style(Color("061011"), Color(accent, 0.9), 2, 4)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style


static func queue_tile_style(accent: Color = Color("49625d")) -> StyleBoxFlat:
	var style := panel_style(Color("0b1919f2"), Color(accent, 0.78), 1, 3)
	style.content_margin_left = 4.0
	style.content_margin_top = 3.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 3.0
	return style


static func badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101d1ff2")
	style.border_color = Color(GOLD, 0.84)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


static func progress_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("020808e6")
	style.border_color = Color("334b47")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


static func progress_fill_style(color: Color = JADE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style


static func label(text: String, size: int = 17, color: Color = PARCHMENT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override(&"font_size", size)
	result.add_theme_color_override(&"font_color", color)
	return result


static func button(text: String, tooltip: String = "") -> Button:
	var result := Button.new()
	result.text = text
	result.tooltip_text = tooltip
	result.focus_mode = Control.FOCUS_ALL
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return result
