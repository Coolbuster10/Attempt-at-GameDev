class_name Twig
extends Area2D
## Trip hazard. Walking or sprinting into it makes the player stumble; jump over it or crawl across.


func _ready() -> void:
	collision_layer = 16
	collision_mask = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 6)
	cs.shape = r
	cs.position = Vector2(0, -3)
	add_child(cs)
	add_child(SpriteLib.sprite("twig"))
	body_entered.connect(func(body):
		if body is PlatformPlayer:
			body.trip(1 if body.velocity.x >= 0.0 else -1))
