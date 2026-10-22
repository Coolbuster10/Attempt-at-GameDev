class_name Projectile
extends Area2D
## Simple hazard projectile (seeds, acorns). Hurts the player, breaks on walls.

var velocity := Vector2.ZERO
var fall_gravity := 0.0
var life := 6.0


static func spawn(parent: Node, sheet: String, pos: Vector2, vel: Vector2, grav := 0.0) -> Projectile:
	var p := Projectile.new()
	p.velocity = vel
	p.fall_gravity = grav
	p.position = pos
	var s := Sprite2D.new()
	s.texture = SpriteLib.texture(sheet)
	s.flip_h = vel.x < 0.0
	p.add_child(s)
	parent.add_child(p)
	return p


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1 | 4
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 3.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	velocity.y += fall_gravity * delta
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body(body: Node) -> void:
	if body is PlatformPlayer:
		if not body.is_vulnerable():
			return
		body.hurt(1, global_position.x)
	Fx.spark(get_parent(), global_position, 0.5)
	queue_free()
