class_name CombatHUD
extends CanvasLayer
## Battle HUD: Street Fighter-style HP bars + Smash-style damage percent, big announcer
## text, cinematic letterbox bars, boss name card and the combat-tutorial checklist.

var _root: Control
var _bars := {}  # fighter -> {bar, hp, pct}
var _big: Label
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _card_title: Label
var _card_sub: Label
var _checklist: VBoxContainer
var _check_labels := {}
var _tip: Label
var _fighter_boxes: Array = []


func _ready() -> void:
	layer = 10
	_root = UIKit.screen_root()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_top_bar = _bar_rect(true)
	_bottom_bar = _bar_rect(false)

	_big = UIKit.label("", 40, UIKit.GOLD)
	_big.add_theme_constant_override("outline_size", 10)
	_big.position = Vector2(0, 130)
	_big.size = Vector2(640, 60)
	_big.pivot_offset = Vector2(320, 30)
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(_big)

	_card_title = UIKit.label("", 28, UIKit.CREAM)
	_card_title.add_theme_constant_override("outline_size", 8)
	_card_title.position = Vector2(-640, 236)
	_card_title.size = Vector2(600, 40)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_card_title)
	_card_sub = UIKit.label("", 12, UIKit.GOLD)
	_card_sub.position = Vector2(-640, 272)
	_card_sub.size = Vector2(600, 20)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_card_sub)

	_tip = UIKit.label("", 9, UIKit.CREAM)
	_tip.position = Vector2(0, 342)
	_tip.size = Vector2(640, 14)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_tip)
	_tip.text = Controls.format("{attack} light   {heavy} heavy   {special} special (+Up: recover)   {dodge} shield / roll   {jump} jump x2")


func _bar_rect(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.size = Vector2(640, 40)
	r.position = Vector2(0, -40 if top else 360)
	_root.add_child(r)
	return r


func add_fighter(f: Fighter, left: bool, color: Color) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.position = Vector2(12 if left else 388, 8)
	box.custom_minimum_size = Vector2(240, 0)
	_root.add_child(box)
	_fighter_boxes.append(box)
	var name := UIKit.label(f.display_name.to_upper(), 12, UIKit.GOLD)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if left else HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(name)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(240, 10)
	bar.max_value = f.max_hp
	bar.value = f.hp
	bar.fill_mode = ProgressBar.FILL_BEGIN_TO_END if left else ProgressBar.FILL_END_TO_BEGIN
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if left else BoxContainer.ALIGNMENT_END
	box.add_child(row)
	var hp_label := UIKit.label("", 10)
	var pct := UIKit.label("0%", 20, UIKit.CREAM)
	pct.add_theme_constant_override("outline_size", 6)
	if left:
		row.add_child(hp_label)
		row.add_child(pct)
	else:
		row.add_child(pct)
		row.add_child(hp_label)
	_bars[f] = {"bar": bar, "hp": hp_label, "pct": pct}
	f.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(f)


func _on_hp_changed(f: Fighter) -> void:
	var e: Dictionary = _bars.get(f, {})
	if e.is_empty():
		return
	var tw := create_tween()
	tw.tween_property(e.bar, "value", f.hp, 0.2)
	e.hp.text = "HP %d/%d" % [ceili(f.hp), int(f.max_hp)] if f.max_hp < 900 else "HP ∞"
	e.pct.text = "%d%%" % int(f.percent)
	# percent colour heats up like in Smash
	var heat := clampf(f.percent / 150.0, 0.0, 1.0)
	e.pct.add_theme_color_override("font_color", UIKit.CREAM.lerp(UIKit.RED, heat))
	var s := create_tween()
	e.pct.pivot_offset = e.pct.size / 2.0
	s.tween_property(e.pct, "scale", Vector2(1.3, 1.3), 0.05)
	s.tween_property(e.pct, "scale", Vector2.ONE, 0.15)


func big_text(text: String, color := UIKit.GOLD, hold := 0.8) -> void:
	_big.text = text
	_big.add_theme_color_override("font_color", color)
	_big.scale = Vector2(2.5, 2.5)
	_big.modulate.a = 1.0
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_big, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hold > 0.0:
		tw.tween_interval(hold)
		tw.tween_property(_big, "modulate:a", 0.0, 0.25)


func letterbox(on: bool, duration := 0.4) -> void:
	var tw := create_tween().set_parallel().set_ignore_time_scale(true)
	for b in _fighter_boxes:
		tw.tween_property(b, "modulate:a", 0.0 if on else 1.0, duration)
	tw.tween_property(_tip, "modulate:a", 0.0 if on else 1.0, duration)
	tw.tween_property(_top_bar, "position:y", 0.0 if on else -40.0, duration)
	tw.tween_property(_bottom_bar, "position:y", 320.0 if on else 360.0, duration)


func name_card(title: String, subtitle: String) -> void:
	_card_title.text = title
	_card_sub.text = subtitle
	var tw := create_tween().set_parallel()
	tw.tween_property(_card_title, "position:x", 16.0, 0.35).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card_sub, "position:x", 16.0, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.6)
	tw.chain().tween_property(_card_title, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(_card_sub, "modulate:a", 0.0, 0.3)


func show_checklist(tasks: Array) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 74)
	_root.add_child(panel)
	_checklist = VBoxContainer.new()
	_checklist.add_theme_constant_override("separation", 0)
	panel.add_child(_checklist)
	_checklist.add_child(UIKit.label("COMBAT TRAINING", 11, UIKit.GOLD))
	for t in tasks:
		var l := UIKit.label("☐ " + Controls.format(t[1]), 10)
		_checklist.add_child(l)
		_check_labels[t[0]] = [l, Controls.format(t[1])]


func check(task: String) -> void:
	if _check_labels.has(task):
		var e: Array = _check_labels[task]
		e[0].text = "☑ " + e[1]
		e[0].add_theme_color_override("font_color", UIKit.GOLD)


func set_tip(text: String) -> void:
	_tip.text = text
