class_name Pickup
extends Area2D
## Collectible item. Upgrades show a short "you found..." message.

var item_id := ""
var flag_name := ""


func _ready() -> void:
	collision_layer = 16
	collision_mask = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 18)
	cs.shape = r
	cs.position = Vector2(0, -8)
	add_child(cs)
	var icon := Sprite2D.new()
	icon.texture = SpriteLib.frame_texture("items", Game.ITEMS[item_id].icon)
	icon.position = Vector2(0, -9)
	add_child(icon)
	var tw := icon.create_tween().set_loops()
	tw.tween_property(icon, "position:y", -13.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(icon, "position:y", -9.0, 0.6).set_trans(Tween.TRANS_SINE)
	var glow := CPUParticles2D.new()
	glow.amount = 6
	glow.lifetime = 1.0
	glow.position = Vector2(0, -9)
	glow.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	glow.emission_sphere_radius = 7.0
	glow.gravity = Vector2(0, -12)
	glow.initial_velocity_max = 4.0
	glow.color = Color(1, 0.9, 0.5, 0.9)
	add_child(glow)
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if not body is PlatformPlayer:
		return
	set_deferred("monitoring", false)
	Game.set_flag(flag_name)
	var info: Dictionary = Game.ITEMS[item_id]
	Fx.spark(get_parent(), global_position + Vector2(0, -9))
	queue_free()
	if info.kind == "consumable":
		Game.add_item(item_id)
	else:
		Game.add_item(item_id, 1, false)
		Dialogue.say([{"name": "You found the " + info.name + "!", "text": info.desc}])
