class_name PlayerFighter
extends Fighter
## Pip in battle. HP comes from the adventure hearts (1 heart = Game.HP_PER_HEART HP).

const MOVES := {
	"jab": {"anim": "jab", "startup": 0.05, "active": 0.08, "recovery": 0.12,
		"dmg": 4.0, "kb": 110.0, "growth": 1.6, "angle": 25.0, "box": Rect2(6, -22, 20, 12)},
	"up": {"anim": "up", "startup": 0.07, "active": 0.1, "recovery": 0.15,
		"dmg": 6.0, "kb": 150.0, "growth": 2.2, "angle": 85.0, "box": Rect2(-10, -44, 24, 26)},
	"air": {"anim": "air", "startup": 0.05, "active": 0.18, "recovery": 0.12, "air_ok": true,
		"dmg": 6.0, "kb": 130.0, "growth": 2.0, "angle": 40.0, "box": Rect2(-18, -26, 36, 22)},
	"heavy": {"anim": "heavy", "startup": 0.26, "active": 0.1, "recovery": 0.3, "lunge": 60.0,
		"dmg": 12.0, "kb": 200.0, "growth": 4.0, "angle": 35.0, "box": Rect2(6, -28, 28, 22)},
	"special": {"anim": "special", "startup": 0.1, "recovery": 0.2, "projectile": true, "cooldown": 0.6},
	"rise": {"anim": "up", "startup": 0.0, "active": 0.25, "recovery": 0.2, "rise": -440.0, "air_ok": true,
		"dmg": 5.0, "kb": 140.0, "growth": 1.5, "angle": 80.0, "box": Rect2(-12, -40, 24, 30)},
}


func _init() -> void:
	display_name = "Pip"
	sheet = "player"
	max_hp = Game.max_hp * Game.HP_PER_HEART
	hp = maxf(Game.hp * Game.HP_PER_HEART, 1.0)
	ring_out_damage = Game.HP_PER_HEART
	if Game.has_item("thorn_charm"):
		damage_mult = 1.25
	if Game.has_item("gale_boots"):
		dodge_mult = 1.4


func _attacks() -> Dictionary:
	return MOVES


func _think(_delta: float) -> void:
	var busy := get_tree().paused or Dialogue.active
	in_x = 0.0 if busy else Input.get_axis("move_left", "move_right")
	in_y = 0.0 if busy else Input.get_axis("move_up", "move_down")
	in_jump = not busy and Input.is_action_just_pressed("jump")
	in_jump_held = Input.is_action_pressed("jump")
	in_attack = not busy and Input.is_action_just_pressed("attack")
	in_heavy = not busy and Input.is_action_just_pressed("heavy")
	in_special = not busy and Input.is_action_just_pressed("special")
	in_dodge = not busy and Input.is_action_just_pressed("dodge")
	in_dodge_held = Input.is_action_pressed("dodge")
