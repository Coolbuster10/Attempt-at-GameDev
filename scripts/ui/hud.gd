class_name HUD
extends CanvasLayer
## Adventure HUD: hearts, tonic count, interaction prompt, toasts and tutorial hints.

var _hearts: HBoxContainer
var _tonic: Label
var _prompt: Label
var _toast: Label
var _hint_panel: PanelContainer
var _hint: Label
var _area_name: Label
var _toast_tween: Tween


func _ready() -> void:
	layer = 10
	var root := UIKit.screen_root()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_hearts = HBoxContainer.new()
	_hearts.position = Vector2(10, 8)
	_hearts.add_theme_constant_override("separation", 2)
	root.add_child(_hearts)
	_tonic = UIKit.label("", 10)
	_tonic.position = Vector2(10, 24)
	root.add_child(_tonic)

	_prompt = UIKit.label("", 12, UIKit.GOLD)
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -40
	_prompt.offset_bottom = -20
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_prompt)

	_toast = UIKit.label("", 14, UIKit.CREAM)
	_toast.anchor_right = 1.0
	_toast.offset_top = 60
	_toast.offset_bottom = 80
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	root.add_child(_toast)

	_area_name = UIKit.label("", 20, UIKit.GOLD)
	_area_name.add_theme_constant_override("outline_size", 6)
	_area_name.anchor_right = 1.0
	_area_name.offset_top = 120
	_area_name.offset_bottom = 150
	_area_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_name.modulate.a = 0.0
	root.add_child(_area_name)

	_hint_panel = PanelContainer.new()
	_hint_panel.anchor_left = 0.5
	_hint_panel.anchor_right = 0.5
	_hint_panel.offset_left = -170
	_hint_panel.offset_right = 170
	_hint_panel.offset_top = 8
	_hint_panel.visible = false
	root.add_child(_hint_panel)
	_hint = UIKit.label("", 11)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_panel.add_child(_hint)

	Game.hp_changed.connect(func(_h, _m): _refresh())
	Game.inventory_changed.connect(_refresh)
	Game.toast.connect(show_toast)
	_refresh()


func _refresh() -> void:
	for c in _hearts.get_children():
		c.queue_free()
	for i in Game.max_hp:
		var t := TextureRect.new()
		t.texture = SpriteLib.frame_texture("heart", 0 if i < Game.hp else 1)
		_hearts.add_child(t)
	var tonics := Game.item_count("berry_tonic")
	_tonic.text = "Tonics x%d  %s" % [tonics, Controls.label("inventory")] if tonics > 0 else ""


func set_prompt(text: String) -> void:
	_prompt.text = text


func show_toast(text: String) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func show_area_name(text: String) -> void:
	_area_name.text = text
	var tw := create_tween()
	tw.tween_property(_area_name, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.6)
	tw.tween_property(_area_name, "modulate:a", 0.0, 0.8)


func show_hint(text: String) -> void:
	_hint.text = text
	_hint_panel.visible = text != ""
