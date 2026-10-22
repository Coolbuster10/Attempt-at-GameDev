class_name Fx
## One-shot visual effects (dust puffs, hit sparks, floating text).


static func _oneshot(parent: Node, sheet: String, pos: Vector2, z := 5, scale := 1.0) -> AnimatedSprite2D:
	if parent == null or not parent.is_inside_tree():
		return null
	var s := SpriteLib.animated(sheet, "default")
	s.offset = Vector2.ZERO
	s.z_index = z
	s.scale = Vector2.ONE * scale
	parent.add_child(s)
	s.global_position = pos
	s.animation_finished.connect(s.queue_free)
	return s


static func dust(parent: Node, pos: Vector2) -> void:
	_oneshot(parent, "fx_dust", pos + Vector2(0, -6), 0)


static func spark(parent: Node, pos: Vector2, scale := 1.0) -> void:
	_oneshot(parent, "fx_spark", pos, 20, scale)


static func float_text(parent: Node, pos: Vector2, text: String, color := UIKit.CREAM) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := UIKit.label(text, 12, color)
	l.z_index = 30
	l.position = pos - Vector2(30, 10)
	l.size = Vector2(60, 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 18, 0.6).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.tween_callback(l.queue_free)
