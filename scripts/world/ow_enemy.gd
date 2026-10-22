class_name OverworldEnemy
extends Node2D
## A visible wandering enemy on the world map. Touching it starts a battle (symbol encounter).

signal touched_player(enemy: OverworldEnemy)

const WANDER_SPEED := 22.0
const CHASE_SPEED := 52.0
const NOTICE_RANGE := 72.0
const TOUCH_RANGE := 11.0

var enemy_id := ""
var enemy_type := "thornling"
var player: Node2D
var depth_scale: Callable
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _timer := 0.0
var _sprite: AnimatedSprite2D
var _alert: Label
var _triggered := false


func _ready() -> void:
	_home = position
	_target = position
	var shadow := SpriteLib.sprite("shadow")
	shadow.position.y = 2
	add_child(shadow)
	_sprite = SpriteLib.animated("thornling", "idle")
	_sprite.scale = Vector2(0.6, 0.6)
	_sprite.offset.y = -14
	add_child(_sprite)
	_alert = UIKit.label("!", 14, UIKit.RED)
	_alert.position = Vector2(-3, -36)
	_alert.visible = false
	add_child(_alert)


func _process(delta: float) -> void:
	if depth_scale.is_valid():
		scale = Vector2.ONE * depth_scale.call(position.y)
	if _triggered or get_tree().paused or Dialogue.active or Transition.busy or player == null:
		return
	var to_player := player.global_position - global_position
	var chasing := to_player.length() < NOTICE_RANGE
	_alert.visible = chasing
	var speed := WANDER_SPEED
	if chasing:
		_target = player.global_position
		speed = CHASE_SPEED
	else:
		_timer -= delta
		if _timer <= 0.0:
			_timer = randf_range(1.0, 2.5)
			_target = _home + Vector2(randf_range(-40, 40), randf_range(-24, 24))
	var step := _target - position
	if step.length() > 2.0:
		position += step.normalized() * speed * delta
		_sprite.flip_h = step.x < 0
		_sprite.play("run")
	else:
		_sprite.play("idle")
	if to_player.length() < TOUCH_RANGE:
		_triggered = true
		touched_player.emit(self)
