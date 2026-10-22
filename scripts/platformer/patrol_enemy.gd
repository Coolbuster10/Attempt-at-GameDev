class_name PatrolEnemy
extends Node2D
## Walks back and forth on the ground; chases when the player is close. Touch = battle.

signal touched_player(enemy: PatrolEnemy)

var enemy_id := ""
var enemy_type := "thornling"
var sheet := "thornling"
var speed := 28.0
var chase_speed := 55.0
var level: Node
var player: Node2D
var _dir := -1
var _sprite: AnimatedSprite2D
var _triggered := false


func _ready() -> void:
	var shadow := SpriteLib.sprite("shadow")
	shadow.position.y = 2
	add_child(shadow)
	_sprite = SpriteLib.animated(sheet, "idle")
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	if _triggered or player == null or Dialogue.active or Transition.busy:
		return
	var to_player := player.global_position - global_position
	var spd := speed
	if speed > 0.0 and absf(to_player.x) < 110.0 and absf(to_player.y) < 40.0:
		_dir = 1 if to_player.x > 0.0 else -1
		spd = chase_speed
	if spd > 0.0:
		var ahead := global_position + Vector2(_dir * 10, 0)
		if level.is_solid_at(ahead + Vector2(0, -8)) or not level.is_floor_at(ahead + Vector2(0, 4)):
			_dir = -_dir
		else:
			global_position.x += _dir * spd * delta
		_sprite.play("run")
		_sprite.flip_h = _dir < 0
	if absf(to_player.x) < 14.0 and absf(to_player.y) < 22.0:
		_triggered = true
		touched_player.emit(self)
