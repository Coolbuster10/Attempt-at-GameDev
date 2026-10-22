extends Node2D
## Smash-style battle arena. Entered from the adventure via Game.start_battle().
## Params: enemy ("thornling" | "dummy" | "bramble_king"), enemy_id, return_key,
## return_params, tutorial (bool), boss (bool).

const TILE := 16
const TUTORIAL_TASKS := [
	["move", "Move with {move_left} {move_right}"],
	["double_jump", "Double jump: {jump} in mid-air"],
	["jab", "Light attack: {attack}"],
	["up", "Up attack: hold {move_up} + {attack}"],
	["heavy", "Heavy attack: {heavy}"],
	["special", "Special shot: {special}"],
	["shield", "Shield: hold {dodge}"],
	["roll", "Roll: {dodge} + direction"],
	["ringout", "Knock the dummy off the stage!"],
]

var stage_half := 200.0
var blast_zone := Rect2(-470, -420, 940, 680)
var player: PlayerFighter
var enemy: Fighter
var hud: CombatHUD
var cam: Camera2D
var tutorial := false
var boss := false

var _params: Dictionary
var _shake := 0.0
var _hitstop_left := 0.0
var _cam_focus = null  # Vector2 override during cutscenes
var _cam_zoom_override := 0.0
var _ended := false
var _tasks_done := {}
var _stage_tex: Texture2D
var _bg: ParallaxBG


func _ready() -> void:
	Game.context = "combat"
	_params = Game.scene_params
	var kind: String = _params.get("enemy", "thornling")
	boss = kind == "bramble_king"
	tutorial = _params.get("tutorial", false)
	if boss:
		stage_half = 240.0
	_build_background()
	_build_stage()

	player = PlayerFighter.new()
	player.arena = self
	player.position = Vector2(-110, 0)
	add_child(player)
	if boss:
		enemy = BossFighter.new()
		enemy.phase_changed.connect(_on_boss_phase)
	else:
		enemy = AIFighter.create(kind)
	enemy.arena = self
	enemy.position = Vector2(110, 0)
	enemy.facing = -1
	add_child(enemy)
	player.opponent = enemy
	enemy.opponent = player
	player.defeated.connect(_on_player_defeated)
	enemy.defeated.connect(_on_enemy_defeated)
	player.ringed_out.connect(_on_ring_out)
	enemy.ringed_out.connect(_on_ring_out)

	hud = CombatHUD.new()
	add_child(hud)
	hud.add_fighter(player, true, Color("c8423b"))
	hud.add_fighter(enemy, false, Color("5e9c4a") if not boss else Color("8a2b2b"))

	cam = Camera2D.new()
	cam.position = Vector2(0, -80)
	cam.zoom = Vector2(1.3, 1.3)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 5.0
	add_child(cam)
	_bg.camera = cam

	player.state = "frozen"
	enemy.state = "frozen"
	if boss:
		_boss_intro.call_deferred()
	else:
		_ready_go.call_deferred()


# ------------------------------------------------------------------------------------------
# Building
# ------------------------------------------------------------------------------------------
func _build_background() -> void:
	_bg = ParallaxBG.new(-10)
	var tint := Color(0.75, 0.6, 0.75) if boss else Color.WHITE
	_bg.add_image("res://assets/backgrounds/dusk_sky.png" if boss else "res://assets/backgrounds/sky.png", 0.0, 0, tint)
	_bg.add_image("res://assets/backgrounds/hills_far.png", 0.1, 120, tint, 0.05)
	_bg.add_image("res://assets/backgrounds/hills_mid.png", 0.25, 140, tint.darkened(0.1), 0.1)
	_bg.add_image("res://assets/backgrounds/trees_near.png", 0.45, 170, tint.darkened(0.25), 0.15)
	add_child(_bg)
	if boss:
		# drifting thorny embers
		var motes := CPUParticles2D.new()
		motes.amount = 30
		motes.lifetime = 5.0
		motes.preprocess = 5.0
		motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		motes.emission_rect_extents = Vector2(400, 10)
		motes.position = Vector2(0, 60)
		motes.gravity = Vector2(10, -30)
		motes.scale_amount_min = 1.5
		motes.scale_amount_max = 2.5
		motes.color = Color(1.0, 0.45, 0.3, 0.8)
		motes.z_index = -1
		add_child(motes)


func _build_stage() -> void:
	_stage_tex = SpriteLib.texture("tiles")
	var body := StaticBody2D.new()
	body.collision_layer = 1
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(stage_half * 2.0, 48)
	cs.shape = r
	cs.position = Vector2(0, 24)
	body.add_child(cs)
	add_child(body)
	var visual := StageVisual.new()
	visual.arena = self
	visual.z_index = -1
	add_child(visual)
	var plats := [Vector2(-stage_half * 0.55, -72), Vector2(stage_half * 0.55, -72)]
	if not boss:
		plats.append(Vector2(0, -136))
	for p in plats:
		var pb := StaticBody2D.new()
		pb.collision_layer = 2
		pb.position = p
		var pcs := CollisionShape2D.new()
		var pr := RectangleShape2D.new()
		pr.size = Vector2(80, 6)
		pcs.shape = pr
		pcs.position = Vector2(0, 3)
		pcs.one_way_collision = true
		pb.add_child(pcs)
		add_child(pb)
		visual.platforms.append(p)


class StageVisual extends Node2D:
	var arena
	var platforms: Array = []

	func _draw() -> void:
		var tex: Texture2D = arena._stage_tex
		var half: float = arena.stage_half
		var cols := int(half * 2.0 / 16.0)
		for i in cols:
			var x := -half + i * 16.0
			draw_texture_rect_region(tex, Rect2(x, 0, 16, 16), Rect2(0, 0, 16, 16))
			for row in [1, 2]:
				draw_texture_rect_region(tex, Rect2(x, row * 16, 16, 16), Rect2((1 if row == 1 else 9) * 16, 0, 16, 16))
		# floating-island underside
		var pts := PackedVector2Array([Vector2(-half, 48), Vector2(half, 48), Vector2(half * 0.55, 96),
				Vector2(half * 0.15, 130), Vector2(-half * 0.2, 118), Vector2(-half * 0.6, 92)])
		draw_colored_polygon(pts, Color("3f2817"))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color("2b1d14"), 2.0)
		for p in platforms:
			for k in 5:
				draw_texture_rect_region(tex, Rect2(p.x - 40 + k * 16, p.y, 16, 16), Rect2(4 * 16, 0, 16, 16))


# ------------------------------------------------------------------------------------------
# Camera, hitstop, shake
# ------------------------------------------------------------------------------------------
func _process(delta: float) -> void:
	if _hitstop_left > 0.0:
		_hitstop_left -= delta / maxf(Engine.time_scale, 0.001)  # unscaled frame time
		if _hitstop_left <= 0.0 and not _ended:
			Engine.time_scale = 1.0
	var focus: Vector2
	var zoom := 1.3
	if _cam_focus != null:
		focus = _cam_focus
		zoom = _cam_zoom_override
	else:
		var a := player.global_position
		var b := enemy.global_position if enemy.state != "dead" else a
		focus = (a + b) / 2.0 + Vector2(0, -50)
		var span := maxf(absf(a.x - b.x) + 200.0, (absf(a.y - b.y) + 160.0) * 16.0 / 9.0)
		zoom = clampf(640.0 / span, 0.95, 1.6)
		focus.x = clampf(focus.x, -stage_half, stage_half)
		focus.y = clampf(focus.y, -220.0, 20.0)
	cam.global_position = focus
	var z := lerpf(cam.zoom.x, zoom, minf(delta * 3.0, 1.0))
	cam.zoom = Vector2(z, z)
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 25.0, 0.0)
		cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
	else:
		cam.offset = Vector2.ZERO


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	_hitstop_left = maxf(_hitstop_left, seconds)


## Called by fighters when they get hit.
func on_hit(target: Fighter, dmg: float, kb: float, shielded: bool) -> void:
	var at := target.global_position + Vector2(0, -target.body_size.y * 0.6)
	if shielded:
		Fx.spark(self, at, 0.6)
		hitstop(0.04)
		return
	Fx.spark(self, at, 1.0 + kb / 400.0)
	Fx.float_text(self, at + Vector2(0, -18), str(int(dmg)), UIKit.CREAM)
	hitstop(0.03 + dmg * 0.006)
	shake(2.0 + kb / 80.0)


func _on_ring_out(f: Fighter) -> void:
	shake(10.0)
	Transition.flash(1, 0.05, Color(1, 1, 1), 0.5)
	if tutorial and f == enemy:
		_task_done("ringout")
		hud.big_text("RING OUT!", UIKit.GOLD, 0.6)
	elif f.hp > 0.0:
		hud.big_text("RING OUT!  -%d HP" % int(f.ring_out_damage), UIKit.RED if f == player else UIKit.GOLD, 0.6)


# ------------------------------------------------------------------------------------------
# Flow: intro → fight → victory / defeat
# ------------------------------------------------------------------------------------------
func _ready_go() -> void:
	if tutorial:
		hud.show_checklist(TUTORIAL_TASKS)
		player.action_used.connect(_task_done)
	await Transition.wait(0.5)
	hud.big_text("READY?", UIKit.CREAM, 0.5)
	await Transition.wait(0.9)
	hud.big_text("FIGHT!", UIKit.GOLD, 0.5)
	player.state = "idle"
	enemy.state = "idle"


func _boss_intro() -> void:
	enemy.state = "cutscene"
	enemy.visible = false
	enemy.position = Vector2(120, -360)
	hud.letterbox(true)
	_cam_focus = Vector2(-60, -60)
	_cam_zoom_override = 1.4
	await Transition.wait(0.8)
	# the king drops in
	enemy.visible = true
	var tw := create_tween()
	tw.tween_property(enemy, "position:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	shake(12.0)
	Fx.dust(self, enemy.global_position + Vector2(-20, 0))
	Fx.dust(self, enemy.global_position + Vector2(20, 0))
	Transition.flash(1, 0.06, Color.WHITE, 0.8)
	_cam_focus = enemy.global_position + Vector2(0, -40)
	_cam_zoom_override = 2.0
	await Transition.wait(0.5)
	enemy.sprite.play("roar")
	for i in 6:
		shake(7.0)
		await Transition.wait(0.12)
	Transition.flash(2, 0.05, Color.WHITE, 0.7)
	hud.name_card("THE BRAMBLE KING", "Thorned Tyrant of Hollowmere")
	await Transition.wait(2.2)
	hud.letterbox(false)
	_cam_focus = null
	hud.big_text("FIGHT!", UIKit.GOLD, 0.5)
	enemy.sprite.play("idle")
	enemy.state = "idle"
	player.state = "idle"


func _on_boss_phase(_phase: int) -> void:
	Transition.flash(2, 0.05, Color(1, 0.5, 0.4), 0.6)
	shake(10.0)
	hud.big_text("HE'S ENRAGED!", UIKit.RED, 0.8)
	_bg.modulate = Color(1.0, 0.75, 0.75)


func _task_done(task: String) -> void:
	if not tutorial or _ended:
		return
	if task in ["jump"]:
		task = "move"
	if task == "air":
		task = "jab"
	if _tasks_done.has(task):
		return
	if not TUTORIAL_TASKS.any(func(t): return t[0] == task):
		return
	_tasks_done[task] = true
	hud.check(task)
	if _tasks_done.size() >= TUTORIAL_TASKS.size():
		_victory()


func _physics_process(_delta: float) -> void:
	if tutorial and not _ended and player.state != "frozen" and absf(player.velocity.x) > 20.0:
		_task_done("move")


func _on_enemy_defeated(_f: Fighter) -> void:
	_victory()


func _victory() -> void:
	if _ended:
		return
	_ended = true
	player.invuln = 99.0
	Engine.time_scale = 0.25
	Transition.flash(1, 0.06, Color.WHITE, 0.8)
	shake(12.0)
	hud.big_text("K.O.!" if not tutorial else "TRAINING COMPLETE!", UIKit.GOLD, 0.0)
	if not tutorial:
		enemy.state = "dead"
		enemy.velocity = Vector2(signf(enemy.global_position.x - player.global_position.x) * 300.0, -350.0)
		var tw := enemy.create_tween().set_ignore_time_scale(false)
		tw.tween_property(enemy, "rotation", TAU * 2.0 * signf(enemy.velocity.x), 1.0)
		tw.parallel().tween_property(enemy, "modulate:a", 0.0, 1.0)
	await Transition.wait(1.2)
	Engine.time_scale = 1.0
	player.state = "frozen"
	player.sprite.play("victory")
	hud.big_text("VICTORY!", UIKit.GOLD, 0.0)

	Game.set_hp(ceili(player.hp / Game.HP_PER_HEART))
	Game.set_flag("defeated:" + str(_params.get("enemy_id", "")))
	var reward := ""
	if boss:
		reward = "heart_seed"
		Game.set_flag("boss_defeated")
		Game.set_flag("level_done:forest")
	elif not tutorial and randf() < 0.5:
		reward = "berry_tonic"
	await Transition.wait(1.4)
	if reward != "":
		Game.add_item(reward, 1, false)
		hud.big_text("Got %s!" % Game.ITEMS[reward].name, UIKit.CREAM, 0.0)
		await Transition.wait(1.4)
	if boss:
		Game.goto("overworld", {"spawn": "node:forest", "after_boss": true}, "iris")
	else:
		Game.goto(_params.get("return_key", "overworld"), _params.get("return_params", {}), "fade")


func _on_player_defeated(_f: Fighter) -> void:
	if _ended:
		return
	_ended = true
	Engine.time_scale = 0.3
	Transition.flash(1, 0.06, Color(1, 0.3, 0.3), 0.6)
	hud.big_text("DEFEATED...", UIKit.RED, 0.0)
	await Transition.wait(1.6)
	Engine.time_scale = 1.0
	Game.set_hp(0)
	var retry_params: Dictionary = _params.get("return_params", {})
	Game.goto("game_over", {"retry_key": _params.get("return_key", "overworld"), "retry_params": retry_params})
