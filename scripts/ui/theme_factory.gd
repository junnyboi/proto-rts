class_name ThemeFactory
extends RefCounted

const INK := Color("0b1719")
const INK_SOFT := Color("14282a")
const PANEL := Color(0.035, 0.075, 0.078, 0.95)
const PANEL_LIGHT := Color(0.07, 0.14, 0.145, 0.96)
const PARCHMENT := Color("f3e4bf")
const MUTED := Color("a9b8ae")
const GOLD := Color("deb961")
const JADE := Color("6fd2aa")
const DANGER := Color("e85d4f")


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
	theme.set_color(&"font_disabled_color", &"Button", Color(MUTED, 0.45))
	theme.set_color(&"font_focus_color", &"Button", Color.WHITE)
	theme.set_stylebox(&"normal", &"Button", button_style(INK_SOFT, Color("3d6761"), 1))
	theme.set_stylebox(&"hover", &"Button", button_style(Color("214942"), JADE, 2))
	theme.set_stylebox(&"pressed", &"Button", button_style(GOLD, Color("ffe8a0"), 2))
	theme.set_stylebox(&"focus", &"Button", button_style(Color(0.0, 0.0, 0.0, 0.0), GOLD, 2))
	theme.set_stylebox(&"disabled", &"Button", button_style(Color("101d1f"), Color("263638"), 1))
	theme.set_stylebox(&"panel", &"PanelContainer", panel_style())
	theme.set_stylebox(&"panel", &"Panel", panel_style())
	theme.set_color(&"font_color", &"RichTextLabel", PARCHMENT)
	theme.set_color(&"default_color", &"RichTextLabel", PARCHMENT)
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
	return result
