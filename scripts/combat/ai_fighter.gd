class_name AIFighter
extends Fighter
## Computer-controlled fighter: thornlings, and the passive training dummy.

const THORNLING_MOVES := {
	"jab": {"anim": "attack", "startup": 0.18, "active": 0.1, "recovery": 0.3, "lunge": 120.0,
		"dmg": 6.0, "kb": 120.0, "growth": 1.5, "angle": 30.0, "box": Rect2(2, -22, 22, 18)},
	"up": {"anim": "attack", "startup": 0.14, "active": 0.12, "recovery": 0.25,
		"dmg": 6.0, "kb": 140.0, "growth": 1.6, "angle": 80.0, "box": Rect2(-12, -42, 24, 24)},
	"air": {"anim": "attack", "startup": 0.1, "active": 0.2, "recovery": 0.2, "air_ok": true,
		"dmg": 6.0, "kb": 120.0, "growth": 1.5, "angle": 45.0, "box": Rect2(-16, -28, 32, 28)},
	"heavy": {"anim": "attack", "startup": 0.4, "active": 0.2, "recovery": 0.45, "lunge": 40.0,
		"dmg": 10.0, "kb": 170.0, "growth": 2.5, "angle": 45.0, "box": Rect2(-18, -30, 40, 30)},
	"special": {"anim": "attack", "startup": 0.25, "recovery": 0.35, "projectile": true, "cooldown": 1.6},
	"rise": {"anim": "jump", "startup": 0.0, "active": 0.2, "recovery": 0.25, "rise": -430.0, "air_ok": true,
		"dmg": 4.0, "kb": 100.0, "growth": 1.0, "angle": 80.0, "box": Rect2(-12, -36, 24, 26)},
}

## Training dummies never attack.
var passive := false
var aggression := 1.0
var _decide_t := 0.0
var _shield_t := 0.0


static func create(kind: String) -> AIFighter:
	var f := AIFighter.new()
	match kind:
		"dummy":
			f.display_name = "Training Dummy"
			f.sheet = "dummy"
			f.passive = true
			f.max_hp = 999.0
			f.weight = 1.0
			f.ring_out_damage = 0.0
		_:
			f.display_name = "Thornling"
			f.sheet = "thornling"
			f.max_hp = 60.0
			f.weight = 0.9
			f.run_speed = 115.0
			f.ring_out_damage = 25.0
	f.hp = f.max_hp
	f.body_size = Vector2(18, 22)
	return f


func _attacks() -> Dictionary:
	return {} if passive else THORNLING_MOVES


func _fire_projectile() -> void:
	var p := CombatHazard.new()
	p.sheet = "seed"
	p.target = opponent
	p.position = global_position + Vector2(facing * 12, -14)
	p.velocity = Vector2(facing * 170.0, -160.0)
	p.fall_gravity = 500.0
	p.floor_y = 0.0
	p.floor_half = arena.stage_half
	p.hit = {"dmg": 5.0, "kb": 90.0, "growth": 0.8, "angle": 30.0}
	p.life = 2.5
	get_parent().add_child(p)


func _think(delta: float) -> void:
	in_jump = false
	in_attack = false
	in_heavy = false
	in_special = false
	in_dodge = false
	in_jump_held = true
	if opponent == null:
		return
	var pos := global_position
	var half: float = arena.stage_half
	var offstage := absf(pos.x) > half - 4.0 or pos.y > 8.0
	# --- recovery: always try to get back to the stage -----------------------------
	if offstage and not is_on_floor():
		in_x = -signf(pos.x)
		in_y = 0.0
		if velocity.y > 0.0:
			if jumps_left > 0:
				in_jump = true
			elif not up_special_used and not passive:
				in_y = -1.0
				in_special = true
			elif not up_special_used and passive:
				velocity.y = -420.0  # dummies get a free boost so the lesson can continue
				up_special_used = true
		return
	if passive:
		in_x = 0.0
		in_dodge_held = false
		return

	_shield_t -= delta
	in_dodge_held = _shield_t > 0.0
	_decide_t -= delta
	if _decide_t > 0.0 or state != "idle":
		return
	_decide_t = randf_range(0.12, 0.3) / aggression
	var to := opponent.global_position - pos
	var dist := absf(to.x)
	in_y = 0.0
	in_x = signf(to.x) if dist > 26.0 else 0.0
	if in_x != 0.0 and absf(pos.x + in_x * 24.0) > half - 6.0:
		in_x = 0.0  # don't walk off the edge
	if to.x != 0.0:
		facing = 1 if to.x > 0.0 else -1
	if to.y < -40.0 and is_on_floor() and randf() < 0.5:
		in_jump = true
	if dist < 34.0 and to.y < -26.0:
		in_y = -1.0
		in_attack = true
	elif dist < 38.0 and absf(to.y) < 30.0:
		var r := randf()
		if opponent.state == "attack" and r < 0.25:
			in_dodge = true
			_shield_t = 0.4
		elif r < 0.6:
			in_attack = true
		elif r < 0.85:
			in_heavy = true
	elif dist > 110.0 and special_cd <= 0.0 and randf() < 0.3:
		in_x = 0.0
		in_special = true
