class_name OverworldPlayer
extends CharacterBody2D
## Top-down (3/4 view) player for the world map, Cuphead-overworld style.

signal prompt_changed(text: String)

const SPEED := 70.0
const SPRINT_SPEED := 115.0

var facing := "down"
var frozen := false
## Callable(y) -> float provided by the overworld for fake-perspective scaling.
var depth_scale: Callable
var _nearby: Array = []
var _sprite: AnimatedSprite2D
var _last_prompt := ""
var _dust_t := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.5
	shape.shape = circle
	add_child(shape)
	var shadow := SpriteLib.sprite("shadow")
	shadow.position.y = 3
	add_child(shadow)
	_sprite = SpriteLib.animated("ow_player", "idle_down")
	add_child(_sprite)


func add_interactable(it: Interactable) -> void:
	if not _nearby.has(it):
		_nearby.append(it)


func remove_interactable(it: Interactable) -> void:
	_nearby.erase(it)


func _closest() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	for it in _nearby:
		if is_instance_valid(it) and it.enabled:
			var d := global_position.distance_squared_to(it.global_position)
			if d < best_d:
				best_d = d
				best = it
	return best


func _physics_process(delta: float) -> void:
	if depth_scale.is_valid():
		scale = Vector2.ONE * depth_scale.call(global_position.y)
	var busy := frozen or Dialogue.active or Transition.busy or get_tree().paused
	var dir := Vector2.ZERO if busy else Controls.move_vector()
	var sprinting := Input.is_action_pressed("sprint")
	velocity = dir * (SPRINT_SPEED if sprinting else SPEED)
	move_and_slide()

	if dir.length() > 0.1:
		if absf(dir.x) > absf(dir.y):
			facing = "side"
			_sprite.flip_h = dir.x < 0
		else:
			facing = "down" if dir.y > 0 else "up"
		_sprite.play("walk_" + facing)
		_sprite.speed_scale = 1.6 if sprinting else 1.0
		_dust_t -= delta
		if sprinting and _dust_t <= 0.0:
			_dust_t = 0.15
			Fx.dust(get_parent(), global_position)
	else:
		_sprite.play("idle_" + facing)

	var target := _closest()
	var text := "" if busy or target == null else Controls.label("interact") + " " + target.prompt
	if text != _last_prompt:
		_last_prompt = text
		prompt_changed.emit(text)
	if not busy and target and Input.is_action_just_pressed("interact"):
		target.interact(self)
