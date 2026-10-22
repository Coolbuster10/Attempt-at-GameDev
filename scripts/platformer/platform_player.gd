class_name PlatformPlayer
extends CharacterBody2D
## Side-scrolling player: walk, sprint, jump (variable height, coyote time, buffering),
## crouch/crawl, climb vines, drop through planks, dash (with Gale Boots), trip on twigs.

signal prompt_changed(text: String)
signal died

const WALK := 95.0
const SPRINT := 160.0
const CRAWL := 42.0
const ACCEL := 1000.0
const AIR_ACCEL := 700.0
const FRICTION := 1200.0
const GRAVITY := 950.0
const FALL_GRAVITY_MULT := 1.25
const MAX_FALL := 430.0
const JUMP_VEL := -300.0
const JUMP_CUT := 0.45
const CLIMB_SPEED := 70.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.12
const DASH_SPEED := 290.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 0.35
const INVULN_TIME := 1.0
const MASK_ALL := 1 | 2  # world + one-way planks
const MASK_SOLID := 1

enum State { NORMAL, CLIMB, TRIP, HURT, DASH, LOCKED }

var state := State.NORMAL
var facing := 1
var crouching := false
## The PlatformerLevel; used for safe-ground checks and effects.
var level: Node
var last_safe := Vector2.ZERO

var _coyote := 0.0
var _buffer := 0.0
var _state_t := 0.0
var _invuln := 0.0
var _dash_cd := 0.0
var _air_dash_used := false
var _drop_t := 0.0
var _climb_lock := 0.0
var _safe_t := 0.0
var _vines: Array = []
var _nearby: Array = []
var _last_prompt := ""
var _was_on_floor := true
var _stand_shape: CollisionShape2D
var _crouch_shape: CollisionShape2D
var _head_check := RectangleShape2D.new()
var _sprite: AnimatedSprite2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = MASK_ALL
	floor_snap_length = 4.0
	_stand_shape = _make_shape(Vector2(10, 24), Vector2(0, -12))
	_crouch_shape = _make_shape(Vector2(12, 12), Vector2(0, -6))
	_crouch_shape.disabled = true
	_head_check.size = Vector2(8, 18)
	var shadow := SpriteLib.sprite("shadow")
	shadow.position.y = 3
	shadow.modulate.a = 0.7
	add_child(shadow)
	_sprite = SpriteLib.animated("player", "idle")
	add_child(_sprite)
	last_safe = global_position


func _make_shape(size: Vector2, pos: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = pos
	add_child(cs)
	return cs


# ------------------------------------------------------------------------------------------
# Hooks used by level objects
# ------------------------------------------------------------------------------------------
func add_interactable(it: Interactable) -> void:
	if not _nearby.has(it):
		_nearby.append(it)


func remove_interactable(it: Interactable) -> void:
	_nearby.erase(it)


func add_vine(area: Area2D) -> void:
	if not _vines.has(area):
		_vines.append(area)


func remove_vine(area: Area2D) -> void:
	_vines.erase(area)


func is_vulnerable() -> bool:
	return _invuln <= 0.0 and state != State.LOCKED


## Called by twigs. Walking/sprinting into one makes you stumble; sprinting also hurts.
func trip(dir: int) -> void:
	if state != State.NORMAL or crouching or not is_on_floor() or absf(velocity.x) < 20.0:
		return
	var hard := absf(velocity.x) > WALK + 10.0
	state = State.TRIP
	_state_t = 0.8
	velocity = Vector2(dir * 110.0, -120.0)
	_sprite.play("trip")
	Fx.dust(get_parent(), global_position)
	if level:
		level.on_player_tripped(hard)
	if hard and _invuln <= 0.0:
		Game.damage(1)
		_invuln = INVULN_TIME
		if Game.is_dead():
			_die()


func hurt(amount: int, from_x: float, respawn := false) -> void:
	if not is_vulnerable():
		return
	Game.damage(amount)
	_invuln = INVULN_TIME
	Fx.spark(get_parent(), global_position + Vector2(0, -12))
	if level:
		level.shake(4.0)
	if Game.is_dead():
		_die()
		return
	if respawn:
		_respawn_safe()
		return
	state = State.HURT
	_state_t = 0.3
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = -facing
	velocity = Vector2(dir * 160.0, -170.0)


## Fell into a pit: always costs a heart and puts you back on safe ground.
func fell() -> void:
	if state == State.LOCKED:
		return
	Game.damage(1)
	if Game.is_dead():
		_die()
		return
	_respawn_safe()


func lock(on: bool) -> void:
	state = State.LOCKED if on else State.NORMAL
	if on:
		velocity.x = 0.0


func _die() -> void:
	state = State.LOCKED
	velocity = Vector2(0, -200)
	_sprite.play("hurt")
	died.emit()


func _respawn_safe() -> void:
	state = State.LOCKED
	await Transition.cover(Transition.FADE, 0.15)
	global_position = last_safe
	velocity = Vector2.ZERO
	_set_crouch(false)
	_invuln = INVULN_TIME
	await Transition.reveal(Transition.FADE, 0.2)
	if state == State.LOCKED and not Game.is_dead():
		state = State.NORMAL


# ------------------------------------------------------------------------------------------
# Main loop
# ------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_invuln = maxf(_invuln - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_climb_lock = maxf(_climb_lock - delta, 0.0)
	_state_t -= delta
	if _drop_t > 0.0:
		_drop_t -= delta
		if _drop_t <= 0.0 and state != State.CLIMB:
			collision_mask = MASK_ALL

	var busy := Dialogue.active or Transition.busy
	var input_x := 0.0 if busy else Input.get_axis("move_left", "move_right")
	match state:
		State.NORMAL:
			if busy:
				_apply_gravity(delta)
				velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
			else:
				_normal(delta, input_x)
		State.CLIMB:
			_climb(input_x)
		State.TRIP, State.HURT, State.LOCKED:
			_apply_gravity(delta)
			velocity.x = move_toward(velocity.x, 0.0, (FRICTION * 0.4 if state == State.TRIP else FRICTION * 0.5) * delta)
			if state != State.LOCKED and _state_t <= 0.0:
				state = State.NORMAL
		State.DASH:
			velocity = Vector2(facing * DASH_SPEED, 0.0)
			if _state_t <= 0.0:
				state = State.NORMAL
				velocity.x = facing * SPRINT
	move_and_slide()

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and state != State.CLIMB:
		Fx.dust(get_parent(), global_position)
	_was_on_floor = on_floor
	_update_safe_spot(delta, on_floor)
	_update_anim(on_floor)
	_update_prompt(busy)
	if level and global_position.y > level.kill_y:
		fell()


func _apply_gravity(delta: float) -> void:
	var g := GRAVITY * (FALL_GRAVITY_MULT if velocity.y > 0.0 else 1.0)
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)


func _normal(delta: float, input_x: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE
		_air_dash_used = false
	else:
		_coyote -= delta
	if Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	else:
		_buffer -= delta
	var down := Input.is_action_pressed("move_down")
	var up := Input.is_action_pressed("move_up")

	# grab a vine
	if not _vines.is_empty() and _climb_lock <= 0.0:
		if up or (down and on_floor and not _solid_below()) or (down and not on_floor):
			_start_climb()
			return

	# crouch / crawl
	var want_crouch := down and on_floor
	if want_crouch and not crouching:
		_set_crouch(true)
	elif not want_crouch and crouching and _can_stand():
		_set_crouch(false)

	# horizontal movement
	var sprinting := Input.is_action_pressed("sprint") and not crouching
	var max_speed := CRAWL if crouching else (SPRINT if sprinting else WALK)
	var target := input_x * max_speed
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
		# keep sprint momentum in the air even if sprint is released mid-jump
		var keep := not on_floor and signf(velocity.x) == signf(target) and absf(velocity.x) > absf(target)
		if not keep:
			velocity.x = move_toward(velocity.x, target, (ACCEL if on_floor else AIR_ACCEL) * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, (FRICTION if on_floor else AIR_ACCEL * 0.5) * delta)

	# jump / drop through planks
	if _buffer > 0.0 and _coyote > 0.0:
		if down and on_floor and not _solid_below():
			_drop_t = 0.25
			collision_mask = MASK_SOLID
			position.y += 2.0
			_buffer = 0.0
		elif not crouching or _can_stand():
			_set_crouch(false)
			velocity.y = JUMP_VEL
			_buffer = 0.0
			_coyote = 0.0
			Fx.dust(get_parent(), global_position)
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT
	_apply_gravity(delta)

	# dash (Gale Boots upgrade)
	if Input.is_action_just_pressed("dodge") and Game.has_item("gale_boots") and _dash_cd <= 0.0 and not crouching:
		if on_floor or not _air_dash_used:
			if not on_floor:
				_air_dash_used = true
			if input_x != 0.0:
				facing = 1 if input_x > 0.0 else -1
			state = State.DASH
			_state_t = DASH_TIME
			_dash_cd = DASH_COOLDOWN
			Fx.dust(get_parent(), global_position + Vector2(-facing * 8, -10))


func _start_climb() -> void:
	state = State.CLIMB
	_set_crouch(false)
	velocity = Vector2.ZERO
	collision_mask = MASK_SOLID  # pass through planks while on the vine
	var vine: Area2D = _vines.back()
	global_position.x = vine.get_meta("x")


func _climb(input_x: float) -> void:
	var v := Input.get_axis("move_up", "move_down") if not (Dialogue.active or Transition.busy) else 0.0
	velocity = Vector2(0.0, v * CLIMB_SPEED)
	if Input.is_action_just_pressed("jump"):
		_exit_climb()
		velocity = Vector2(input_x * WALK, JUMP_VEL * 0.85)
		return
	if _vines.is_empty():
		_exit_climb()
		if v < 0.0:
			velocity.y = -220.0  # hop up onto the ledge at the top
		return
	if v > 0.0 and _solid_below():
		_exit_climb()


func _exit_climb() -> void:
	state = State.NORMAL
	collision_mask = MASK_ALL
	_climb_lock = 0.25


func _set_crouch(on: bool) -> void:
	crouching = on
	_stand_shape.disabled = on
	_crouch_shape.disabled = not on


func _can_stand() -> bool:
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _head_check
	q.transform = Transform2D(0.0, global_position + Vector2(0, -15))
	q.collision_mask = MASK_SOLID
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 1).is_empty()


func _solid_below() -> bool:
	var old := collision_mask
	collision_mask = MASK_SOLID
	var hit := test_move(global_transform, Vector2(0, 2))
	collision_mask = old
	return hit


func _update_safe_spot(delta: float, on_floor: bool) -> void:
	if on_floor and state == State.NORMAL and level and level.is_safe_ground(global_position):
		_safe_t += delta
		if _safe_t > 0.15:
			last_safe = global_position
	else:
		_safe_t = 0.0


func _update_anim(on_floor: bool) -> void:
	var anim := "idle"
	_sprite.speed_scale = 1.0
	match state:
		State.CLIMB:
			anim = "climb"
			_sprite.speed_scale = 1.0 if velocity.y != 0.0 else 0.0
		State.TRIP:
			anim = "trip"
		State.HURT:
			anim = "hurt"
		State.DASH:
			anim = "dash"
		State.LOCKED:
			anim = _sprite.animation if _sprite.animation in ["hurt", "victory"] else ("idle" if on_floor else "fall")
		_:
			if crouching:
				anim = "crawl" if absf(velocity.x) > 5.0 else "crouch"
			elif not on_floor:
				anim = "jump" if velocity.y < 0.0 else "fall"
			elif absf(velocity.x) > 5.0:
				anim = "run"
				_sprite.speed_scale = absf(velocity.x) / WALK
	if _sprite.animation != anim:
		_sprite.play(anim)
	_sprite.flip_h = facing < 0
	_sprite.modulate.a = 0.35 if _invuln > 0.0 and int(_invuln * 15.0) % 2 == 0 else 1.0


func play_victory() -> void:
	state = State.LOCKED
	_sprite.play("victory")


func _update_prompt(busy: bool) -> void:
	var best: Interactable = null
	var best_d := INF
	for it in _nearby:
		if is_instance_valid(it) and it.enabled:
			var d := global_position.distance_squared_to(it.global_position)
			if d < best_d:
				best_d = d
				best = it
	var text := ""
	if best and not busy and state == State.NORMAL:
		text = Controls.label("interact") + " " + best.prompt
	if text != _last_prompt:
		_last_prompt = text
		prompt_changed.emit(text)
	if text != "" and Input.is_action_just_pressed("interact"):
		best.interact(self)
