class_name Fighter
extends CharacterBody2D
## Base class for everything that fights in the arena (Super Smash Bros.-style).
##
## Damage works two ways at once:
##  * HP (Street Fighter-style bar): when it hits 0 the fighter is defeated.
##  * Percent (Smash-style): every hit adds to it, and knockback grows with it, so
##    battered fighters fly farther. Getting knocked past the blast zone costs a big
##    chunk of HP and resets the percent.
##
## Subclasses fill the in_* intent variables in `_think()` (player input or AI), and
## define their moves in `_attacks()`. Hits are simple rectangle overlaps, no physics areas.

signal hp_changed(fighter: Fighter)
signal defeated(fighter: Fighter)
signal ringed_out(fighter: Fighter)
signal action_used(action: String)

var display_name := "Fighter"
var sheet := "player"
var max_hp := 100.0
var hp := 100.0
var percent := 0.0
var weight := 1.0
var gravity := 1100.0
var run_speed := 150.0
var air_speed := 140.0
var jump_vel := -390.0
var double_jump_vel := -340.0
var max_fall := 420.0
var fast_fall_speed := 600.0
var max_jumps := 2
var damage_mult := 1.0
var dodge_mult := 1.0
## Super armor: takes damage but is not stunned or launched (bosses).
var armor := false
var can_ring_out := true
var ring_out_damage := 20.0
var body_size := Vector2(12, 24)
var arena: Node
var opponent: Fighter
var facing := 1
## idle | attack | hitstun | shield | dodge | frozen (gravity only) | cutscene (no physics) | dead
var state := "idle"

# Intents, refreshed every physics frame by _think().
var in_x := 0.0
var in_y := 0.0
var in_jump := false
var in_jump_held := false
var in_attack := false
var in_heavy := false
var in_special := false
var in_dodge := false
var in_dodge_held := false

var jumps_left := 2
var hitstun := 0.0
var invuln := 0.0
var shield_hp := 60.0
var attack: Dictionary = {}
var attack_name := ""
var attack_t := 0.0
var special_cd := 0.0
var dodge_cd := 0.0
var dodge_t := 0.0
var up_special_used := false
var sprite: AnimatedSprite2D

var _attack_hit := false
var _fired := false
var _drop_t := 0.0
var _flash := 0.0
var _flash_mat: ShaderMaterial
var _was_on_floor := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	floor_snap_length = 4.0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = body_size
	cs.shape = r
	cs.position = Vector2(0, -body_size.y / 2.0)
	add_child(cs)
	var shadow := SpriteLib.sprite("shadow")
	shadow.position.y = 3
	shadow.scale = Vector2.ONE * maxf(1.0, body_size.x / 14.0)
	add_child(shadow)
	sprite = SpriteLib.animated(sheet, "idle")
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = load("res://assets/shaders/hit_flash.gdshader")
	sprite.material = _flash_mat
	add_child(sprite)
	jumps_left = max_jumps


## Override: dictionary of move name -> move data. Keys used:
## anim, startup, active, recovery, dmg, kb, growth, angle, box (Rect2 facing right),
## lunge (x speed at start), rise (y speed at start), projectile (true), air_ok (keep momentum).
func _attacks() -> Dictionary:
	return {}


## Override: set the in_* intents.
func _think(_delta: float) -> void:
	pass


func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-body_size.x / 2.0, -body_size.y), body_size)


func hitbox_rect(box: Rect2) -> Rect2:
	var b := box
	if facing < 0:
		b.position.x = -box.position.x - box.size.x
	b.position += global_position
	return b


func is_grounded() -> bool:
	return is_on_floor()


# ------------------------------------------------------------------------------------------
# Taking hits
# ------------------------------------------------------------------------------------------
## hit: {dmg, kb, growth, angle}. dir: horizontal direction of the launch (+1 / -1).
func take_hit(hit: Dictionary, dir: int) -> bool:
	if invuln > 0.0 or state in ["dead", "cutscene"]:
		return false
	var dmg: float = hit.dmg
	if state == "shield":
		shield_hp -= dmg * 1.5
		velocity.x = dir * 90.0
		arena.on_hit(self, 0.0, 60.0, true)
		if shield_hp <= 0.0:
			shield_hp = 0.0
			state = "hitstun"
			hitstun = 1.2
			velocity = Vector2(0, -200)
			Fx.float_text(get_parent(), global_position + Vector2(0, -40), "SHIELD BREAK!", UIKit.RED)
		return true
	hp = maxf(hp - dmg, 0.0)
	percent += dmg
	var kb: float = (hit.kb + percent * hit.get("growth", 1.0)) / weight
	var ang := deg_to_rad(hit.get("angle", 40.0))
	var launch := Vector2(cos(ang) * dir, -sin(ang)) * kb
	_flash = 1.0
	if armor:
		velocity.x += launch.x * 0.15
	else:
		attack = {}
		state = "hitstun"
		hitstun = 0.1 + kb * 0.0011
		velocity = launch
		facing = -dir
	arena.on_hit(self, dmg, kb, false)
	hp_changed.emit(self)
	if hp <= 0.0:
		_defeat()
	return true


func _defeat() -> void:
	state = "dead"
	attack = {}
	defeated.emit(self)


func _ring_out() -> void:
	hp = maxf(hp - ring_out_damage, 0.0)
	percent = 0.0
	hp_changed.emit(self)
	ringed_out.emit(self)
	if hp <= 0.0:
		_defeat()
		return
	global_position = Vector2(randf_range(-40, 40), -170)
	velocity = Vector2.ZERO
	state = "idle"
	attack = {}
	invuln = 2.0
	jumps_left = max_jumps


# ------------------------------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_flash_mat.set_shader_parameter("flash", _flash)
	if state == "cutscene":
		return
	if state in ["dead", "frozen"]:
		velocity.y = minf(velocity.y + gravity * delta, max_fall)
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		move_and_slide()
		_update_anim()
		_check_blast_zone()
		return
	_think(delta)
	invuln = maxf(invuln - delta, 0.0)
	special_cd = maxf(special_cd - delta, 0.0)
	dodge_cd = maxf(dodge_cd - delta, 0.0)
	if state != "shield":
		shield_hp = minf(shield_hp + 12.0 * delta, 60.0)
	if _drop_t > 0.0:
		_drop_t -= delta
		if _drop_t <= 0.0:
			collision_mask = 1 | 2

	match state:
		"hitstun":
			_apply_gravity(delta, false)
			velocity.x = move_toward(velocity.x, 0.0, 260.0 * delta)
			hitstun -= delta
			if hitstun <= 0.0:
				state = "idle"
		"attack":
			_do_attack(delta)
		"shield":
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			_apply_gravity(delta, false)
			shield_hp -= 10.0 * delta
			if not in_dodge_held or shield_hp <= 0.0:
				state = "idle"
		"dodge":
			dodge_t -= delta
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			_apply_gravity(delta, false)
			if dodge_t <= 0.0:
				state = "idle"
		_:
			_move(delta)
	move_and_slide()
	var on_floor := is_on_floor()
	if on_floor:
		jumps_left = max_jumps
		up_special_used = false
		if not _was_on_floor:
			Fx.dust(get_parent(), global_position)
	_was_on_floor = on_floor
	_update_anim()
	_check_blast_zone()
	queue_redraw()


func _check_blast_zone() -> void:
	if can_ring_out and arena and not arena.blast_zone.has_point(global_position) and state != "dead":
		_ring_out()
	elif state == "dead" and global_position.y > 600.0:
		set_physics_process(false)


func _apply_gravity(delta: float, allow_fast_fall := true) -> void:
	var g := gravity
	var cap := max_fall
	if velocity.y < 0.0 and not in_jump_held and state == "idle":
		g *= 1.7  # short hop when jump is released early
	if allow_fast_fall and in_y > 0.6 and velocity.y > 0.0:
		cap = fast_fall_speed
		velocity.y = maxf(velocity.y, fast_fall_speed * 0.7)
	velocity.y = minf(velocity.y + g * delta, cap)


func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		velocity.x = move_toward(velocity.x, in_x * run_speed, 1400.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, in_x * air_speed, 700.0 * delta)
	if in_x != 0.0:
		facing = 1 if in_x > 0.0 else -1

	if in_jump:
		if on_floor and in_y > 0.6 and not _solid_below():
			_drop_t = 0.25
			collision_mask = 1
			position.y += 2.0
		elif jumps_left > 0:
			velocity.y = jump_vel if on_floor else double_jump_vel
			action_used.emit("jump" if on_floor else "double_jump")
			jumps_left -= 1
			if not on_floor:
				Fx.dust(get_parent(), global_position)
	_apply_gravity(delta)

	var moves := _attacks()
	if in_attack:
		if in_y < -0.6 and moves.has("up"):
			start_attack("up")
		elif not on_floor and moves.has("air"):
			start_attack("air")
		else:
			start_attack("jab")
	elif in_heavy and moves.has("heavy"):
		start_attack("heavy")
	elif in_special:
		if in_y < -0.6 and not up_special_used and moves.has("rise"):
			start_attack("rise")
		elif special_cd <= 0.0 and moves.has("special"):
			start_attack("special")
	elif in_dodge and dodge_cd <= 0.0:
		if on_floor and absf(in_x) < 0.3:
			state = "shield"
			action_used.emit("shield")
		else:
			_start_dodge(on_floor)


func _start_dodge(on_floor: bool) -> void:
	state = "dodge"
	dodge_cd = 0.5
	dodge_t = 0.32
	invuln = 0.3
	if on_floor:
		var d := signf(in_x) if in_x != 0.0 else float(-facing)
		velocity.x = d * 230.0 * dodge_mult
	else:
		var dir := Vector2(in_x, in_y)
		velocity = dir.normalized() * 190.0 * dodge_mult if dir.length() > 0.3 else Vector2(velocity.x * 0.3, 0.0)
	action_used.emit("roll")


func start_attack(name: String) -> void:
	var moves := _attacks()
	if not moves.has(name):
		return
	attack = moves[name]
	attack_name = name
	attack_t = 0.0
	_attack_hit = false
	_fired = false
	state = "attack"
	if attack.has("rise"):
		velocity.y = attack.rise
		up_special_used = true
	if attack.has("lunge"):
		velocity.x = facing * attack.lunge
	if attack.get("projectile", false):
		special_cd = attack.get("cooldown", 0.6)
	_play(attack.anim)
	action_used.emit(name)


func _do_attack(delta: float) -> void:
	attack_t += delta
	var a := attack
	var on_floor := is_on_floor()
	if on_floor and not a.get("air_ok", false):
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	elif not on_floor:
		velocity.x = move_toward(velocity.x, in_x * air_speed, 300.0 * delta)
	_apply_gravity(delta, false)
	var startup: float = a.startup
	var active: float = a.get("active", 0.0)
	if a.get("projectile", false):
		if attack_t >= startup and not _fired:
			_fired = true
			_fire_projectile()
	elif attack_t >= startup and attack_t < startup + active and not _attack_hit and opponent:
		if hitbox_rect(a.box).intersects(opponent.hurt_rect()):
			var hit := {"dmg": a.dmg * damage_mult, "kb": a.kb, "growth": a.growth, "angle": a.angle}
			if opponent.take_hit(hit, facing):
				_attack_hit = true
	if attack_t >= startup + active + a.recovery:
		state = "idle"
		attack = {}


## Override for custom projectiles.
func _fire_projectile() -> void:
	var p := CombatHazard.new()
	p.sheet = "seed"
	p.target = opponent
	p.position = global_position + Vector2(facing * 12, -16)
	p.velocity = Vector2(facing * 230.0, 0.0)
	p.hit = {"dmg": 5.0 * damage_mult, "kb": 90.0, "growth": 0.8, "angle": 20.0}
	p.size = Vector2(8, 8)
	p.life = 1.6
	get_parent().add_child(p)


func _solid_below() -> bool:
	var old := collision_mask
	collision_mask = 1
	var hit := test_move(global_transform, Vector2(0, 2))
	collision_mask = old
	return hit


# ------------------------------------------------------------------------------------------
# Animation / drawing
# ------------------------------------------------------------------------------------------
const ANIM_FALLBACKS := {
	"jab": "attack", "up": "attack", "air": "attack", "heavy": "attack", "special": "attack",
	"fall": "jump", "roll": "run", "shield": "idle", "victory": "idle", "attack": "idle",
}


func _play(anim: String) -> void:
	var a := anim
	while not sprite.sprite_frames.has_animation(a):
		a = ANIM_FALLBACKS.get(a, "idle")
		if a == "idle":
			break
	if sprite.animation != a or not sprite.is_playing():
		sprite.play(a)


func _update_anim() -> void:
	sprite.flip_h = facing < 0
	sprite.modulate.a = 0.4 if invuln > 0.0 and int(invuln * 15.0) % 2 == 0 and state != "dodge" else 1.0
	match state:
		"attack":
			return
		"hitstun", "dead":
			_play("hurt")
		"shield":
			_play("shield")
		"dodge":
			_play("roll")
		_:
			if not is_on_floor():
				_play("jump" if velocity.y < 0.0 else "fall")
			elif absf(velocity.x) > 10.0:
				_play("run")
			else:
				_play("idle")


func _draw() -> void:
	if state == "shield":
		var r := 8.0 + 10.0 * (shield_hp / 60.0)
		draw_circle(Vector2(0, -body_size.y / 2.0), r, Color(0.55, 0.95, 0.55, 0.35))
		draw_arc(Vector2(0, -body_size.y / 2.0), r, 0, TAU, 24, Color(0.8, 1, 0.8, 0.8), 1.0)
	if Game.settings.show_hitboxes:
		var hr := hurt_rect()
		draw_rect(Rect2(hr.position - global_position, hr.size), Color(0.2, 0.6, 1.0, 0.8), false)
		if state == "attack" and attack.has("box"):
			var a_active: bool = attack_t >= attack.startup and attack_t < attack.startup + attack.get("active", 0.0)
			var b := hitbox_rect(attack.box)
			draw_rect(Rect2(b.position - global_position, b.size), Color(1, 0.2, 0.2, 0.8 if a_active else 0.3), false)
