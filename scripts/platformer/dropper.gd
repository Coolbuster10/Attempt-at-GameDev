class_name Dropper
extends Node2D
## A nest that shakes, then drops an acorn straight down.

var interval := 1.8
var player: Node2D
var _t := 1.0
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = SpriteLib.texture("nest")
	add_child(_sprite)
	_t = randf_range(0.3, interval)


func _physics_process(delta: float) -> void:
	_t -= delta
	# telegraph: shake for the last 0.4s
	_sprite.position.x = sin(_t * 60.0) * 1.0 if _t < 0.4 else 0.0
	if _t > 0.0:
		return
	_t = interval
	if player and absf(player.global_position.x - global_position.x) > 400.0:
		return
	Projectile.spawn(get_parent(), "acorn", global_position + Vector2(0, 6), Vector2.ZERO, 500.0)
