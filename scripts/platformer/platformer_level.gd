extends Node2D
## Builds a side-scrolling stage from LevelData (ASCII map) and runs it.
## Params (Game.scene_params): level (id in LevelData.LEVELS), spawn ([x, y], optional),
## first_run (tutorial started from a new game: finishing leads into the story).

const TILE := 16
## Tile indices in assets/sprites/tiles.png (see TILE_NAMES in tools/gen_assets.py).
enum T { GRASS, DIRT, STONE_TOP, STONE, PLANK, VINE, CAVE, BRICK, THORNS, DIRT_DARK }
const SOLID_TILES := [T.GRASS, T.DIRT, T.STONE_TOP, T.STONE, T.BRICK, T.DIRT_DARK]

var level_id := ""
var data: Dictionary
var player: PlatformPlayer
var hud: HUD
var cam: Camera2D
var kill_y := 0.0
var grid: Array = []
var size_cells := Vector2i.ZERO

var _tiles: TileMapLayer
var _deco: TileMapLayer
var _spawn := Vector2.ZERO
var _thorn_cells := {}
var _shake := 0.0
var _trip_tip_shown := false
var _finished := false


func _ready() -> void:
	Game.context = "level"
	level_id = Game.scene_params.get("level", "tutorial")
	data = LevelData.LEVELS[level_id]
	var w := 0
	for row in data.map:
		w = maxi(w, row.length())
	for row in data.map:
		grid.append(row.rpad(w, "."))
	size_cells = Vector2i(w, grid.size())
	kill_y = size_cells.y * TILE + 40.0

	_build_background()
	_build_tiles()
	hud = HUD.new()
	add_child(hud)
	_spawn_player()
	_build_objects()
	_setup_camera()
	_build_foreground()
	hud.show_area_name(data.name)
	if not data.hints.is_empty() and not Game.scene_params.has("spawn"):
		hud.show_hint(Controls.format(data.hints[0]))


func get_save_position() -> Vector2:
	return player.global_position


# ------------------------------------------------------------------------------------------
# Grid queries (used by the player and enemies)
# ------------------------------------------------------------------------------------------
func cell(x: int, y: int) -> String:
	if x < 0 or x >= size_cells.x:
		return "%"
	if y < 0 or y >= size_cells.y:
		return "."
	return grid[y][x]


func _cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.y / TILE))


func is_solid_at(pos: Vector2) -> bool:
	var c := _cell_at(pos)
	return cell(c.x, c.y) in ["#", "%"]


func is_floor_at(pos: Vector2) -> bool:
	var c := _cell_at(pos)
	return cell(c.x, c.y) in ["#", "%", "=", "+"]


## Ground the player can be safely respawned on (not next to thorns or a ledge).
func is_safe_ground(feet: Vector2) -> bool:
	for dx in [-7.0, 7.0]:
		if not is_floor_at(feet + Vector2(dx, 2)):
			return false
	var c := _cell_at(feet + Vector2(0, -2))
	for x in range(c.x - 1, c.x + 2):
		if _thorn_cells.has(Vector2i(x, c.y)):
			return false
	return true


# ------------------------------------------------------------------------------------------
# Building
# ------------------------------------------------------------------------------------------
func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 2)
	ts.set_physics_layer_collision_mask(1, 0)
	var src := TileSetAtlasSource.new()
	src.texture = SpriteLib.texture("tiles")
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var thin := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -3), Vector2(-8, -3)])
	for i in T.size():
		src.create_tile(Vector2i(i, 0))
		var td := src.get_tile_data(Vector2i(i, 0), 0)
		if i in SOLID_TILES:
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, full)
		elif i == T.PLANK:
			td.add_collision_polygon(1)
			td.set_collision_polygon_points(1, 0, thin)
			td.set_collision_polygon_one_way(1, 0, true)
	return ts


func _build_tiles() -> void:
	var ts := _make_tileset()
	_deco = TileMapLayer.new()
	_deco.tile_set = ts
	_deco.z_index = -1
	add_child(_deco)
	_tiles = TileMapLayer.new()
	_tiles.tile_set = ts
	add_child(_tiles)
	for y in size_cells.y:
		for x in size_cells.x:
			var ch := cell(x, y)
			var p := Vector2i(x, y)
			match ch:
				"#":
					var open_above := not cell(x, y - 1) in ["#", "%"]
					var deep := cell(x, y - 3) == "#" and cell(x, y - 2) == "#"
					_tiles.set_cell(p, 0, Vector2i(T.GRASS if open_above else (T.DIRT_DARK if deep else T.DIRT), 0))
				"%":
					var open_above := not cell(x, y - 1) in ["#", "%"]
					_tiles.set_cell(p, 0, Vector2i(T.STONE_TOP if open_above else T.STONE, 0))
				"=":
					_tiles.set_cell(p, 0, Vector2i(T.PLANK, 0))
				"+":
					_tiles.set_cell(p, 0, Vector2i(T.PLANK, 0))
					_deco.set_cell(p, 0, Vector2i(T.VINE, 0))
				"|":
					_deco.set_cell(p, 0, Vector2i(T.VINE, 0))
				"c":
					_deco.set_cell(p, 0, Vector2i(T.CAVE, 0))
				"^":
					_deco.set_cell(p, 0, Vector2i(T.THORNS, 0))
					_thorn_cells[p] = true


func _area(rect: Rect2, on_enter: Callable, mask := 4) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 16
	a.collision_mask = mask
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = rect.size
	cs.shape = r
	cs.position = rect.get_center()
	a.add_child(cs)
	a.body_entered.connect(on_enter)
	add_child(a)
	return a


func _build_objects() -> void:
	var counters := {"o": 0, "?": 0, "!": 0}
	# column-major so numbered things (items/hints/signs) count left to right
	for x in size_cells.x:
		for y in size_cells.y:
			var ch := cell(x, y)
			var foot := Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
			var center := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match ch:
				"|", "+":
					# one area per continuous vine run (top tile = first vine cell of the run)
					if not cell(x, y - 1) in ["|", "+"]:
						var run := 1
						while cell(x, y + run) in ["|", "+"]:
							run += 1
						var top := y * TILE - 4  # reach a little above so you can grab from the plank on top
						var vine := _area(Rect2(x * TILE + 4, top, 8, run * TILE + 4), func(_b): pass)
						vine.position = Vector2.ZERO
						var col_center := x * TILE + TILE / 2.0
						vine.set_meta("x", col_center)
						vine.body_entered.connect(func(b):
							if b is PlatformPlayer:
								b.add_vine(vine))
						vine.body_exited.connect(func(b):
							if b is PlatformPlayer:
								b.remove_vine(vine))
				"^":
					_area(Rect2(center + Vector2(-7, -2), Vector2(14, 10)), func(b):
						if b is PlatformPlayer:
							b.hurt(1, b.global_position.x, true))
				"w":
					var tw := Twig.new()
					tw.position = foot
					add_child(tw)
				"<", ">":
					var pod := SeedPod.new()
					pod.dir = -1 if ch == "<" else 1
					pod.position = foot
					pod.player = player
					add_child(pod)
				"v":
					var d := Dropper.new()
					d.position = center
					d.player = player
					add_child(d)
				"o":
					var item: String = data["items"][counters.o]
					counters.o += 1
					var flag := "item:%s:%d_%d" % [level_id, x, y]
					if not Game.flag(flag):
						var pk := Pickup.new()
						pk.item_id = item
						pk.flag_name = flag
						pk.position = foot
						add_child(pk)
				"?":
					var text: String = data["hints"][counters["?"]]
					counters["?"] += 1
					_area(Rect2(x * TILE, 0, TILE, size_cells.y * TILE), func(b):
						if b is PlatformPlayer:
							hud.show_hint(Controls.format(text)))
				"!":
					var text: String = data["signs"][counters["!"]]
					counters["!"] += 1
					var s := SpriteLib.sprite("sign")
					s.position = foot
					s.z_index = -1
					add_child(s)
					var it := Interactable.create(Vector2(24, 24), "Read", func(_p): Dialogue.say([text]))
					it.position = foot + Vector2(0, -10)
					add_child(it)
				"E", "D":
					var id := "%s_%d_%d" % [level_id, x, y]
					if not Game.flag("defeated:" + id):
						var e := PatrolEnemy.new()
						e.enemy_id = id
						e.level = self
						e.player = player
						e.position = foot
						if ch == "D":
							e.enemy_type = "dummy"
							e.sheet = "dummy"
							e.speed = 0.0
						e.touched_player.connect(_on_enemy_touched)
						add_child(e)
				"k":
					var bench := SpriteLib.sprite("bench")
					bench.position = foot
					bench.z_index = -1
					add_child(bench)
					var it := Interactable.create(Vector2(32, 24), "Rest", _on_bench)
					it.position = foot + Vector2(0, -10)
					add_child(it)
				"G":
					var goal := SpriteLib.animated("goal", "default")
					goal.position = foot
					goal.z_index = -1
					add_child(goal)
					_area(Rect2(foot + Vector2(-8, -32), Vector2(16, 32)), func(b):
						if b is PlatformPlayer:
							_complete())
				"B":
					var gate := SpriteLib.sprite("boss_gate")
					gate.position = foot
					gate.z_index = -1
					add_child(gate)
					var it := Interactable.create(Vector2(32, 40), "Enter the lair", _on_boss_gate)
					it.position = foot + Vector2(0, -20)
					add_child(it)


func _spawn_player() -> void:
	for y in size_cells.y:
		for x in size_cells.x:
			if cell(x, y) == "P":
				_spawn = Vector2(x * TILE + TILE / 2.0, (y + 1) * TILE)
	player = PlatformPlayer.new()
	player.level = self
	var saved = Game.param_vec(Game.scene_params.get("spawn"))
	player.position = saved if saved != null else _spawn
	player.prompt_changed.connect(hud.set_prompt)
	player.died.connect(_on_player_died)
	add_child(player)
	player.last_safe = player.position


func _setup_camera() -> void:
	cam = Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)
	cam.limit_left = 0
	cam.limit_top = -64
	cam.limit_right = size_cells.x * TILE
	cam.limit_bottom = size_cells.y * TILE
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.global_position = player.global_position
	cam.reset_smoothing.call_deferred()


func _build_background() -> void:
	var bg := ParallaxBG.new(-10)
	var forest: bool = data.theme == "forest"
	var tint := Color(0.75, 0.85, 0.8) if forest else Color.WHITE
	bg.add_image("res://assets/backgrounds/sky.png", 0.0, 0, tint)
	bg.add_image("res://assets/backgrounds/hills_far.png", 0.12, 110, tint, 0.05)
	bg.add_image("res://assets/backgrounds/hills_mid.png", 0.3, 130, tint, 0.1)
	bg.add_image("res://assets/backgrounds/trees_near.png", 0.55, 110 if forest else 140, tint.darkened(0.1), 0.15)
	add_child(bg)
	set_meta("bg", bg)


func _build_foreground() -> void:
	var bg: ParallaxBG = get_meta("bg")
	bg.camera = cam
	var fg := ParallaxBG.new(5)
	fg.camera = cam
	fg.add_image("res://assets/backgrounds/foreground.png", 1.4, 0, Color(1, 1, 1, 0.85), 0.2)
	add_child(fg)
	# drifting leaves between the world and the foreground for extra depth
	var leaves := CPUParticles2D.new()
	leaves.amount = 18
	leaves.lifetime = 7.0
	leaves.preprocess = 7.0
	leaves.local_coords = false
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(260, 4)
	leaves.position = Vector2(0, -140)
	leaves.gravity = Vector2(-6, 18)
	leaves.direction = Vector2(-1, 0.5)
	leaves.initial_velocity_min = 5
	leaves.initial_velocity_max = 15
	leaves.angular_velocity_min = -90
	leaves.angular_velocity_max = 90
	leaves.scale_amount_min = 2.0
	leaves.scale_amount_max = 3.0
	leaves.color = Color("8cc65a") if data.theme == "forest" else Color("f2c14e")
	leaves.z_index = 4
	cam.add_child(leaves)


func _process(delta: float) -> void:
	if player and cam:
		var look := Vector2(player.facing * 28.0, -12.0)
		cam.global_position = player.global_position + look
		if _shake > 0.0:
			_shake = maxf(_shake - delta * 20.0, 0.0)
			cam.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		else:
			cam.offset = Vector2.ZERO


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func on_player_tripped(hard: bool) -> void:
	if not _trip_tip_shown:
		_trip_tip_shown = true
		hud.show_toast("Tripped! Jump over twigs, or crawl across them.")
	elif hard:
		hud.show_toast("Ouch! Sprinting into twigs hurts.")


# ------------------------------------------------------------------------------------------
# Events
# ------------------------------------------------------------------------------------------
func _return_params() -> Dictionary:
	var p := Game.scene_params.duplicate(true)
	p["level"] = level_id
	return p


func _on_enemy_touched(enemy: PatrolEnemy) -> void:
	player.lock(true)
	var p := _return_params()
	var back := player.global_position + Vector2(-20 if enemy.global_position.x > player.global_position.x else 20, 0)
	if not is_safe_ground(back):
		back = player.last_safe
	p["spawn"] = [back.x, back.y]
	var extra := {}
	if enemy.enemy_type == "dummy":
		extra["tutorial"] = true
	Game.start_battle(enemy.enemy_type, enemy.enemy_id, "level", p, extra)


func _on_bench(_p) -> void:
	var c := await Dialogue.say([{"text": "Rest on the bench? (Restores health and saves your game.)",
			"choices": ["Rest & Save", "Leave"]}])
	if c == 0:
		Game.heal(Game.max_hp)
		Game.save_game(player.global_position)


func _on_boss_gate(_p) -> void:
	var c := await Dialogue.say([{"text": "A cold wind howls from the gate. Something huge is breathing inside...",
			"choices": ["Enter", "Not yet"]}])
	if c != 0:
		return
	player.lock(true)
	var p := _return_params()
	p["spawn"] = [player.global_position.x - 24, player.global_position.y]
	Game.start_battle("bramble_king", "boss_" + level_id, "level", p, {"boss": true})


func _complete() -> void:
	if _finished:
		return
	_finished = true
	player.play_victory()
	Game.set_flag("level_done:" + level_id)
	hud.show_area_name("STAGE CLEAR!")
	Transition.flash(1, 0.08, Color(1, 1, 0.8), 0.6)
	await get_tree().create_timer(2.0).timeout
	if Game.scene_params.get("first_run", false):
		Game.goto("overworld", {"spawn": "start", "intro": true}, "loading")
	else:
		Game.goto("overworld", {"spawn": "node:" + level_id}, "iris")


func _on_player_died() -> void:
	await get_tree().create_timer(1.0).timeout
	var p := _return_params()
	p.erase("spawn")
	Game.goto("game_over", {"retry_key": "level", "retry_params": p})
