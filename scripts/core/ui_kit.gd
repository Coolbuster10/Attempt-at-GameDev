class_name UIKit
## Shared UI theme + small helpers so every menu looks consistent.

const CREAM := Color("f4e6c4")
const GOLD := Color("f2c14e")
const DARK := Color("1a1210")
const BROWN := Color("3a2a20")
const RED := Color("c8423b")
const MUTED := Color("8b8b93")


static func _box(bg: Color, border: Color, width := 2, margin := 6.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = false
	return sb


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.1, 0.07, 0.06, 0.92), GOLD, 2, 10))
	t.set_stylebox("panel", "Panel", _box(Color(0.1, 0.07, 0.06, 0.92), GOLD, 2, 10))

	t.set_stylebox("normal", "Button", _box(BROWN, Color("5c3a22"), 2, 5))
	t.set_stylebox("hover", "Button", _box(Color("5c3a22"), GOLD, 2, 5))
	t.set_stylebox("pressed", "Button", _box(Color("8a5a36"), GOLD, 2, 5))
	t.set_stylebox("disabled", "Button", _box(Color(0.15, 0.12, 0.1, 0.8), Color("3a2a20"), 2, 5))
	var focus := _box(Color("5c3a22"), GOLD, 2, 5)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_focus_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("6e6e6e"))

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", DARK)
	t.set_constant("outline_size", "Label", 4)

	t.set_stylebox("background", "ProgressBar", _box(DARK, Color("5c3a22"), 1, 0))
	t.set_stylebox("fill", "ProgressBar", _box(GOLD, GOLD, 0, 0))
	t.set_color("font_color", "CheckButton", CREAM)
	t.set_color("font_hover_color", "CheckButton", GOLD)
	t.set_color("font_focus_color", "CheckButton", GOLD)
	t.set_stylebox("focus", "CheckButton", focus)
	t.set_constant("separation", "VBoxContainer", 6)
	t.set_constant("separation", "HBoxContainer", 6)
	return t


static func label(text: String, size := 12, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, min_width := 140.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 22)
	b.pressed.connect(callback)
	return b


## A full-screen Control root (put it inside a CanvasLayer) using the shared theme.
static func screen_root() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.theme = Game.theme
	return c


static func centered_panel(parent: Control, min_size := Vector2.ZERO) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box


## Links focus neighbours top-to-bottom and focuses the first enabled button.
static func focus_first(buttons: Array) -> void:
	for b in buttons:
		if b is Control and not (b is BaseButton and b.disabled) and b.visible:
			b.grab_focus.call_deferred()
			return
