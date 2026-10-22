class_name BossFighter
extends Fighter
## The Bramble King — a Hollow Knight-style pattern boss inside the Smash-style arena.
## Heavy and armored (no hitstun), never rings out, and cycles through telegraphed attacks:
##   charge  - lowers his head, then barrels across the stage
##   volley  - lobs arcing thorn seeds at you
##   spikes  - roots erupt from the ground where you stand (watch for the rumble)
##   leap    - jumps at you and slams down, sending shockwaves both ways
## Below 50% HP he enters phase 2: faster, more seeds and more roots.

signal phase_changed(phase: int)

const CONTACT_HIT := {"dmg": 8.0, "kb": 200.0, "growth": 1.2, "angle": 40.0}
const CHARGE_HIT := {"dmg": 12.0, "kb": 260.0, "growth": 1.6, "angle": 35.0}

var phase := 1
var pattern := ""
var _pt := 0.0
var _step := 0
var _cooldown := 1.2
var _contact_cd := 0.0
var _airborne := false
var _last_pattern := ""


func _init() -> void:
	display_name = "The Bramble King"
	sheet = "bramble_king"
	max_hp = 320.0
	hp = max_hp
	weight = 3.0
	armor = true
	can_ring_out = false
	body_size = Vector2(46, 62)
	run_speed = 45.0
	gravity = 1300.0
	max_fall = 700.0


func _ready() -> void:
	super._ready()
	collision_mask = 1  # ignore the one-way side platforms so his ground attacks stay grounded


func _speed() -> float:
	return 1.35 if phase == 2 else 1.0


func take_hit(hit: Dictionary, dir: int) -> bool:
	var landed := super.take_hit(hit, dir)
	if landed and phase == 1 and hp > 0.0 and hp <= max_hp * 0.5:
		phase = 2
		phase_changed.emit(2)
	return landed


func _physics_process(delta: float) -> void:
	_flash = maxf(_flash - delta * 6.0, 0.0)
	_flash_mat.set_shader_parameter("flash", _flash)
	if state == "cutscene":
		return
	velocity.y = minf(velocity.y + gravity * delta, max_fall)
	if state in ["dead", "frozen"]:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return
	invuln = maxf(invuln - delta, 0.0)
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	_run_pattern(delta)
	move_and_slide()
	var half: float = arena.stage_half - body_size.x / 2.0
	if absf(global_position.x) > half:
		global_position.x = clampf(global_position.x, -half, half)
		velocity.x = 0.0
	_contact_damage()
	sprite.flip_h = facing < 0
	queue_redraw()


func _face_player() -> void:
	if opponent:
		facing = 1 if opponent.global_position.x > global_position.x else -1


func _contact_damage() -> void:
	if opponent == null or _contact_cd > 0.0:
		return
	if hurt_rect().grow(-6.0).intersects(opponent.hurt_rect()):
		var h := CHARGE_HIT if pattern == "charge" and _step == 1 else CONTACT_HIT
		var dir := 1 if opponent.global_position.x > global_position.x else -1
		if opponent.take_hit(h, dir):
			_contact_cd = 0.8


func _start(p: String) -> void:
	pattern = p
	_last_pattern = p
	_pt = 0.0
	_step = 0
	_face_player()


func _run_pattern(delta: float) -> void:
	_pt += delta * _speed()
	match pattern:
		"":
			_face_player()
			var dx := opponent.global_position.x - global_position.x if opponent else 0.0
			velocity.x = signf(dx) * run_speed if absf(dx) > 50.0 else 0.0
			_play("run" if velocity.x != 0.0 else "idle")
			sprite.speed_scale = 0.5 if velocity.x != 0.0 else 1.0
			_cooldown -= delta * _speed()
			if _cooldown <= 0.0:
				sprite.speed_scale = 1.0
				var options := ["charge", "volley", "spikes", "leap"]
				options.erase(_last_pattern)
				_start(options.pick_random())
		"charge":
			match _step:
				0:  # wind-up telegraph
					velocity.x = 0.0
					_play("roar")
					sprite.position.x = sin(_pt * 80.0) * 1.5
					if _pt > 0.7:
						_step = 1
						_pt = 0.0
						sprite.position.x = 0.0
				1:
					_play("run")
					velocity.x = facing * 330.0 * _speed()
					if _pt > 0.15 and int(_pt * 20.0) % 2 == 0:
						Fx.dust(get_parent(), global_position + Vector2(-facing * 20, 0))
					var edge: float = arena.stage_half - body_size.x / 2.0 - 4.0
					if absf(global_position.x) >= edge or _pt > 1.6:
						arena.shake(5.0)
						_step = 2
						_pt = 0.0
				2:
					velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
					_play("hurt")
					if _pt > 0.7:
						_end_pattern(0.9)
		"volley":
			velocity.x = 0.0
			_play("cast")
			var shots := 5 if phase == 2 else 3
			if _step < shots and _pt > 0.5 + _step * 0.28:
				_step += 1
				_throw_seed()
			if _pt > 0.6 + shots * 0.28 + 0.5:
				_end_pattern(0.8)
		"spikes":
			velocity.x = 0.0
			_play("cast")
			var count := 5 if phase == 2 else 3
			if _step < count and _pt > 0.4 + _step * 0.45:
				_step += 1
				_spawn_root(opponent.global_position.x if opponent else 0.0)
			if _pt > 0.4 + count * 0.45 + 0.9:
				_end_pattern(0.8)
		"leap":
			match _step:
				0:
					velocity.x = 0.0
					_play("roar")
					if _pt > 0.45:
						_face_player()
						var tx := opponent.global_position.x if opponent else 0.0
						velocity = Vector2((tx - global_position.x) / 0.85, -560.0)
						_airborne = true
						_step = 1
						_pt = 0.0
				1:
					_play("jump")
					if _pt > 0.15 and is_on_floor():
						_step = 2
						_pt = 0.0
						velocity.x = 0.0
						_slam()
				2:
					_play("slam")
					if _pt > 0.6:
						_end_pattern(0.9)


func _end_pattern(cooldown: float) -> void:
	pattern = ""
	_cooldown = cooldown
	sprite.position.x = 0.0


func _throw_seed() -> void:
	if opponent == null:
		return
	var from := global_position + Vector2(facing * 18, -58)
	var target_x := opponent.global_position.x + randf_range(-30, 30)
	var t := 0.9
	var p := CombatHazard.new()
	p.sheet = "seed"
	p.target = opponent
	p.position = from
	p.fall_gravity = 600.0
	p.velocity = Vector2((target_x - from.x) / t, (0.0 - from.y - 0.5 * 600.0 * t * t) / t)
	p.floor_y = 0.0
	p.floor_half = arena.stage_half
	p.size = Vector2(10, 10)
	p.hit = {"dmg": 7.0, "kb": 130.0, "growth": 1.0, "angle": 45.0}
	p.life = 3.0
	get_parent().add_child(p)


func _spawn_root(x: float) -> void:
	var p := CombatHazard.new()
	p.sheet = "root_spike"
	p.warning_sheet = "root_warning"
	p.target = opponent
	p.position = Vector2(clampf(x, -arena.stage_half + 8.0, arena.stage_half - 8.0), 0.0)
	p.ground_anchor = true
	p.size = Vector2(12, 44)
	p.telegraph = 0.65 / _speed()
	p.life = 0.45
	p.pierce = true
	p.hit = {"dmg": 10.0, "kb": 230.0, "growth": 1.5, "angle": 80.0}
	get_parent().add_child(p)


func _slam() -> void:
	arena.shake(9.0)
	Fx.dust(get_parent(), global_position + Vector2(-16, 0))
	Fx.dust(get_parent(), global_position + Vector2(16, 0))
	for dir in [-1, 1]:
		var p := CombatHazard.new()
		p.sheet = "shockwave"
		p.target = opponent
		p.position = global_position + Vector2(dir * 26, 0)
		p.ground_anchor = true
		p.velocity = Vector2(dir * 210.0 * _speed(), 0)
		p.size = Vector2(20, 14)
		p.life = 1.6
		p.hit = {"dmg": 9.0, "kb": 190.0, "growth": 1.2, "angle": 70.0}
		get_parent().add_child(p)


func _draw() -> void:
	if Game.settings.show_hitboxes:
		var hr := hurt_rect()
		draw_rect(Rect2(hr.position - global_position, hr.size), Color(0.2, 0.6, 1.0, 0.8), false)
