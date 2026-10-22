class_name CombatHazard
extends Node2D
## Projectiles and area attacks in the arena (seeds, root spikes, shockwaves).
## Hits `target` once via rectangle overlap. Optional telegraph delay before it becomes active.

var target: Fighter
var hit := {"dmg": 5.0, "kb": 100.0, "growth": 1.0, "angle": 30.0}
var sheet := "seed"
var velocity := Vector2.ZERO
var fall_gravity := 0.0
var life := 2.0
## Hit rectangle size; anchored at the node's center, or bottom-center when `ground_anchor`.
var size := Vector2(8, 8)
var ground_anchor := false
## Seconds of warning (shows `warning_sheet`) before the hazard appears and can hit.
var telegraph := 0.0
var warning_sheet := ""
var pierce := false
## Falling hazards break on the stage floor: y of the floor and half its width (0 = never).
var floor_y := 0.0
var floor_half := 0.0
var _sprite: Sprite2D
var _warning: Sprite2D
var _done := false


func _ready() -> void:
	z_index = 3
	_sprite = Sprite2D.new()
	_sprite.texture = SpriteLib.texture(sheet)
	_sprite.flip_h = velocity.x < 0.0
	if ground_anchor:
		_sprite.offset.y = -_sprite.texture.get_height() / 2.0
	add_child(_sprite)
	if telegraph > 0.0:
		_sprite.visible = false
		if warning_sheet != "":
			_warning = Sprite2D.new()
			_warning.texture = SpriteLib.texture(warning_sheet)
			_warning.offset.y = -_warning.texture.get_height() / 2.0
			add_child(_warning)


func _rect() -> Rect2:
	var top_left := global_position - Vector2(size.x / 2.0, size.y if ground_anchor else size.y / 2.0)
	return Rect2(top_left, size)


func _physics_process(delta: float) -> void:
	if telegraph > 0.0:
		telegraph -= delta
		if _warning:
			_warning.position.x = sin(telegraph * 70.0)
		if telegraph <= 0.0:
			_sprite.visible = true
			if _warning:
				_warning.queue_free()
			if ground_anchor:
				_sprite.scale.y = 0.2
				create_tween().tween_property(_sprite, "scale:y", 1.0, 0.06)
		return
	velocity.y += fall_gravity * delta
	position += velocity * delta
	if fall_gravity > 0.0:
		_sprite.rotation = velocity.angle()
	life -= delta
	var on_floor := floor_half > 0.0 and velocity.y > 0.0 and position.y > floor_y and absf(position.x) < floor_half
	if life <= 0.0 or on_floor:
		_break()
		return
	if _done or target == null or not is_instance_valid(target):
		return
	if _rect().intersects(target.hurt_rect()):
		var dir := signf(velocity.x)
		if dir == 0.0:
			dir = signf(target.global_position.x - global_position.x)
		if dir == 0.0:
			dir = 1.0
		if target.take_hit(hit, int(dir)):
			if pierce:
				_done = true
			else:
				_break()


func _break() -> void:
	Fx.spark(get_parent(), global_position, 0.5)
	queue_free()
