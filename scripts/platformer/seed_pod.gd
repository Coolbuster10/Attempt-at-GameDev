class_name SeedPod
extends Node2D
## Plant turret that spits seeds horizontally at a fixed rhythm. Touching it also hurts.

var dir := -1
var interval := 2.0
var player: Node2D
var _t := 1.0
var _sprite: AnimatedSprite2D


func _ready() -> void:
	_sprite = SpriteLib.animated("turret", "idle")
	_sprite.flip_h = dir < 0
	add_child(_sprite)
	var hurt := Area2D.new()
	hurt.collision_layer = 16
	hurt.collision_mask = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 12)
	cs.shape = r
	cs.position = Vector2(0, -7)
	hurt.add_child(cs)
	hurt.body_entered.connect(func(b):
		if b is PlatformPlayer:
			b.hurt(1, global_position.x))
	add_child(hurt)
	_t = randf_range(0.5, interval)


func _physics_process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = interval
	# only shoot when the player is reasonably close (saves seeds flying across the whole map)
	if player and absf(player.global_position.x - global_position.x) > 420.0:
		return
	_sprite.play("shoot")
	Projectile.spawn(get_parent(), "seed", global_position + Vector2(dir * 9, -7), Vector2(dir * 110.0, 0.0))
