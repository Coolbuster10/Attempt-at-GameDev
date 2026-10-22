extends Node2D
## The world map (Cuphead-style overworld). Built from the ASCII MAP below.
##
## Fake-3D tricks used here: y-sorting, soft drop shadows, perspective scaling (things
## higher on the map are drawn smaller = farther away), swaying trees, drifting cloud
## shadows and a blurred-looking foreground canopy that scrolls faster than the camera.
##
## Legend:
##   .  grass        :  path         ~  water        =  bridge      f  flowers
##   T  tree         t  bush         r  rock         H  house       b  bench (save)
##   s  sign         P  player start E  wandering thornling (battle on touch)
##   e  Elder        v  Villager     k  Kid          g  Guard
##   1/2/3  level entrances (see NODES)

const TILE := 16
const MAP := [
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
	"TTTTT.....TTTTTTT.........~~~......TTTTTTTTTTTTTTTT.....TTTT",
	"TTT...f.......TT..........~~~........TTTTTTTTTTTT.....2...TT",
	"TT........................~~~.........TTTTTTTTT.......:...TT",
	"TT...H......H......r......~~~...f.......TTTTTT....r...:...TT",
	"TT........................~~~...........TTT...........:...TT",
	"TT...f...........t........~~~..................t..g...:...TT",
	"TT.....:::::::::::::......~~~.......................:::...TT",
	"TT.....:...v.......:......~~~.........::::::::::::::::....TT",
	"TT..b..:...........:::::::===::::::::::............E......TT",
	"TT.....:..e....s...:......~~~.........:....f..............TT",
	"TT.....:...........:......~~~.........:........TT.........TT",
	"TT.H...::::P::::::::......~~~.....r...:.......TTTT....1...TT",
	"TT.........:........k.....~~~.........:........TT.....:...TT",
	"TT..t......:..............~~~.........::::::::::::::::::..TT",
	"TT.........:.......r......~~~.............E...............TT",
	"TT...f.....:..............~~~....f..................t.....TT",
	"TT.........3..............~~~........TT.......f...........TT",
	"TT.....t........f.........~~~.......TTTT...............r..TT",
	"TTT.......................~~~........TT...................TT",
	"TTTT.......r.......t......~~~..............t......f......TTT",
	"TTTTT.........f..........~~~~~.........................TTTTT",
	"TTTTTTT..........TTT....~~~~~~~.....TTT.........TTT...TTTTTT",
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",
]

const NODES := {
	"1": {"level": "forest", "name": "Whispering Woods",
		"desc": "A tangled forest of twigs, vines and seed-spitting pods. The Bramble King waits at its heart."},
	"3": {"level": "tutorial", "name": "Training Grounds",
		"desc": "A safe course to practise running, jumping, crawling, climbing and fighting."},
	"2": {"level": "", "name": "Thornspire", "locked": true,
		"desc": "A tower choked by brambles. (Coming in the full game!)"},
}

var player: OverworldPlayer
var hud: HUD
var cam: Camera2D
var entities: Node2D
var map_size := Vector2.ZERO
var _walls: StaticBody2D
var _spawns := {}
var _water_frame := 0
var _ground: GroundLayer
var _ground_tex: Texture2D
var _sway_mat: ShaderMaterial
var _clouds: Array = []
var _grid: Array = []


func _ready() -> void:
	Game.context = "overworld"
	_grid = []
	var w := 0
	for row in MAP:
		w = maxi(w, row.length())
	for row in MAP:
		_grid.append(row.rpad(w, "T"))
	map_size = Vector2(w, _grid.size()) * TILE

	_sway_mat = ShaderMaterial.new()
	_sway_mat.shader = load("res://assets/shaders/sway.gdshader")

	_ground = GroundLayer.new()
	_ground.map = self
	add_child(_ground)
	_walls = StaticBody2D.new()
	_walls.collision_layer = 1
	add_child(_walls)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	_build()
	_build_atmosphere()

	hud = HUD.new()
	add_child(hud)
	_place_player()

	cam = Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map_size.x)
	cam.limit_bottom = int(map_size.y)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.global_position = player.global_position
	add_child(cam)
	cam.reset_smoothing.call_deferred()

	var fg := ParallaxBG.new(5)
	fg.camera = cam
	fg.add_image("res://assets/backgrounds/foreground.png", 1.5, 0, Color(1, 1, 1, 0.55))
	add_child(fg)

	var timer := Timer.new()
	timer.wait_time = 0.6
	timer.autostart = true
	timer.timeout.connect(func():
		_water_frame = 1 - _water_frame
		_ground.queue_redraw())
	add_child(timer)

	if Game.scene_params.get("intro", false):
		_intro.call_deferred()
	elif Game.scene_params.get("after_boss", false):
		_after_boss.call_deferred()
	else:
		hud.show_area_name("Hollowmere Valley")


## Used by the pause menu's Save option.
func get_save_position() -> Vector2:
	return player.global_position


func depth_scale(y: float) -> float:
	return lerpf(0.82, 1.12, clampf(y / map_size.y, 0.0, 1.0))


# ------------------------------------------------------------------------------------------
# Building the map
# ------------------------------------------------------------------------------------------
func _cell(x: int, y: int) -> String:
	if y < 0 or y >= _grid.size() or x < 0 or x >= _grid[y].length():
		return "T"
	return _grid[y][x]


class GroundLayer extends Node2D:
	var map

	func _draw() -> void:
		map.draw_ground(self)


func draw_ground(canvas: Node2D) -> void:
	# keep a reference: a texture only held by a local would be freed right after drawing
	if _ground_tex == null:
		_ground_tex = SpriteLib.texture("ow_tiles")
	var tex := _ground_tex
	for y in _grid.size():
		for x in _grid[y].length():
			var ch := _cell(x, y)
			var idx := 0 if (x * 7 + y * 13) % 5 != 0 else 1
			match ch:
				":", "P", "1", "2", "3":
					idx = 2
				"~":
					idx = 3 if (_water_frame + x + y) % 2 == 0 else 6
				"=":
					idx = 5
				"f":
					idx = 4
			canvas.draw_texture_rect_region(tex, Rect2(x * TILE, y * TILE, TILE, TILE), Rect2(idx * 16, 0, 16, 16))
			# darker river banks give the water some depth
			if ch == "~" and _cell(x, y - 1) != "~" and _cell(x, y - 1) != "=":
				canvas.draw_rect(Rect2(x * TILE, y * TILE, TILE, 3), Color(0.1, 0.2, 0.3, 0.5))


func _add_wall(rect: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	cs.position = rect.get_center()
	_walls.add_child(cs)


func _prop(sheet: String, foot: Vector2, collider := Vector2.ZERO, sway := false, shadow := true) -> Node2D:
	var n := Node2D.new()
	n.position = foot
	if shadow:
		var sh := SpriteLib.sprite("shadow")
		sh.position.y = 3
		sh.scale = Vector2(2.0, 1.5) if sheet.begins_with("tree") or sheet == "house" else Vector2.ONE
		n.add_child(sh)
	var s := SpriteLib.sprite(sheet)
	if sway:
		s.material = _sway_mat
	n.add_child(s)
	n.scale = Vector2.ONE * depth_scale(foot.y)
	entities.add_child(n)
	if collider != Vector2.ZERO:
		_add_wall(Rect2(foot - Vector2(collider.x / 2, collider.y), collider))
	return n


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for y in _grid.size():
		var x := 0
		while x < _grid[y].length():
			var ch := _cell(x, y)
			var foot := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE - 2)
			var center := Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)
			match ch:
				"~":
					# merge horizontal runs of water into one collider
					var run := 1
					while _cell(x + run, y) == "~":
						run += 1
					_add_wall(Rect2(x * TILE, y * TILE + 4, run * TILE, TILE - 4))
					x += run
					continue
				"T":
					var border := _cell(x - 1, y) == "T" and _cell(x + 1, y) == "T" and _cell(x, y - 1) == "T"
					var t := _prop("tree_dark" if border or rng.randf() < 0.3 else "tree",
							foot + Vector2(rng.randf_range(-2, 2), 0), Vector2(10, 6), true)
					if border:
						t.modulate = Color(0.85, 0.85, 0.9)
					# solid block so the map edges can't be walked through between trunks
					_add_wall(Rect2(x * TILE, y * TILE, TILE, TILE))
				"t":
					_prop("bush", foot, Vector2(12, 6), true)
				"r":
					_prop("rock", foot, Vector2(12, 6))
				"H":
					_prop("house", foot + Vector2(0, 1), Vector2(40, 18))
				"b":
					var bench := _prop("bench", foot, Vector2(20, 5))
					var it := Interactable.create(Vector2(32, 26), "Rest", _on_bench)
					it.position = Vector2(0, -4)
					bench.add_child(it)
				"s":
					var sign_node := _prop("sign", foot, Vector2(8, 4))
					var it := Interactable.create(Vector2(24, 24), "Read", func(_p):
						Dialogue.say(["West: Mossbrook Village.\nSouth: Training Grounds.\nEast: Whispering Woods.\nNorth-east: Thornspire."]))
					sign_node.add_child(it)
				"e", "v", "k", "g":
					_spawn_npc(ch, foot)
				"P":
					_spawns["start"] = center
				"E":
					var id := "ow_%d_%d" % [x, y]
					if not Game.flag("defeated:" + id):
						var e := OverworldEnemy.new()
						e.enemy_id = id
						e.position = foot
						e.depth_scale = depth_scale
						e.touched_player.connect(_on_enemy_touch)
						entities.add_child(e)
				"1", "2", "3":
					_spawn_node(ch, foot)
			x += 1
	# outer bounds
	_add_wall(Rect2(-16, -16, map_size.x + 32, 16))
	_add_wall(Rect2(-16, map_size.y, map_size.x + 32, 16))
	_add_wall(Rect2(-16, 0, 16, map_size.y))
	_add_wall(Rect2(map_size.x, 0, 16, map_size.y))


func _build_atmosphere() -> void:
	# drifting cloud shadows passing over everything
	var layer := Node2D.new()
	layer.z_index = 10
	add_child(layer)
	for i in 5:
		var c := SpriteLib.sprite("cloud_shadow")
		c.scale = Vector2(2.5, 2.5)
		c.position = Vector2(randf() * map_size.x, randf() * map_size.y)
		layer.add_child(c)
		_clouds.append(c)
	# floating pollen motes
	var motes := CPUParticles2D.new()
	motes.amount = 40
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = map_size / 2
	motes.position = map_size / 2
	motes.gravity = Vector2(4, -2)
	motes.direction = Vector2(1, -0.3)
	motes.initial_velocity_min = 2
	motes.initial_velocity_max = 8
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.0
	motes.color = Color(1, 0.95, 0.7, 0.7)
	motes.z_index = 11
	add_child(motes)


func _process(delta: float) -> void:
	for c in _clouds:
		c.position += Vector2(9, 3) * delta
		if c.position.x > map_size.x + 150:
			c.position = Vector2(-150, randf() * map_size.y)
		if c.position.y > map_size.y + 80:
			c.position.y = -80
	if player:
		cam.global_position = player.global_position


func _place_player() -> void:
	player = OverworldPlayer.new()
	player.depth_scale = depth_scale
	var spawn = Game.scene_params.get("spawn", "start")
	var pos = Game.param_vec(spawn)
	if pos == null:
		pos = _spawns.get(spawn, _spawns.get("start", map_size / 2))
	player.position = pos
	player.prompt_changed.connect(hud.set_prompt)
	entities.add_child(player)
	for e in entities.get_children():
		if e is OverworldEnemy:
			e.player = player


# ------------------------------------------------------------------------------------------
# Level entrances
# ------------------------------------------------------------------------------------------
func _spawn_node(ch: String, foot: Vector2) -> void:
	var info: Dictionary = NODES[ch]
	var locked: bool = info.get("locked", false)
	var done := Game.flag("level_done:" + info.level)
	var n := Node2D.new()
	n.position = foot
	n.scale = Vector2.ONE * depth_scale(foot.y)
	entities.add_child(n)
	if locked:
		n.add_child(SpriteLib.sprite("tower"))
		_add_wall(Rect2(foot - Vector2(10, 8), Vector2(20, 8)))
	else:
		var flag := SpriteLib.animated("flag_gold" if done else "flag_red", "default")
		n.add_child(flag)
		# little bobbing hover so entrances stand out
		var tw := flag.create_tween().set_loops()
		tw.tween_property(flag, "position:y", -2.0, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(flag, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	var label := UIKit.label(info.name + (" ✓" if done else ""), 8, UIKit.GOLD)
	label.position = Vector2(-40, 2)
	label.size = Vector2(80, 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.add_child(label)
	var it := Interactable.create(Vector2(28, 28), "Enter " + info.name, func(_p): _enter_node(info))
	it.position.y = -6 if not locked else 4
	n.add_child(it)
	_spawns["node:" + info.level] = foot + Vector2(0, 14)


func _enter_node(info: Dictionary) -> void:
	if info.get("locked", false):
		await Dialogue.say([{"name": info.name, "text": info.desc}])
		return
	var choice := await Dialogue.say([{"name": info.name, "text": info.desc, "choices": ["Enter", "Not yet"]}])
	if choice == 0:
		Game.goto("level", {"level": info.level}, "iris")


func _on_enemy_touch(enemy: OverworldEnemy) -> void:
	var away: Vector2 = player.global_position + (player.global_position - enemy.global_position).normalized() * 20
	Game.start_battle(enemy.enemy_type, enemy.enemy_id, "overworld", {"spawn": [away.x, away.y]})


func _on_bench(_p) -> void:
	var c := await Dialogue.say([{"text": "A sturdy old bench. Rest here? (Restores health and saves your game.)",
			"choices": ["Rest & Save", "Leave"]}])
	if c == 0:
		Game.heal(Game.max_hp)
		Game.save_game(player.global_position)


# ------------------------------------------------------------------------------------------
# NPCs + story
# ------------------------------------------------------------------------------------------
const NPC_INFO := {
	"e": {"sheet": "npc_elder", "name": "Elder Moss"},
	"v": {"sheet": "npc_villager", "name": "Farmer Bram"},
	"k": {"sheet": "npc_kid", "name": "Little Fern"},
	"g": {"sheet": "npc_guard", "name": "Guard Ostler"},
}


func _spawn_npc(ch: String, foot: Vector2) -> void:
	var info: Dictionary = NPC_INFO[ch]
	var n := Node2D.new()
	n.position = foot
	n.scale = Vector2.ONE * depth_scale(foot.y)
	entities.add_child(n)
	var sh := SpriteLib.sprite("shadow")
	sh.position.y = 2
	n.add_child(sh)
	var s := SpriteLib.animated(info.sheet, "idle")
	n.add_child(s)
	_add_wall(Rect2(foot - Vector2(6, 6), Vector2(12, 7)))
	var it := Interactable.create(Vector2(30, 30), "Talk", func(_p):
		s.play("talk")
		await _talk(ch)
		s.play("idle"))
	it.position.y = -6
	n.add_child(it)


func _line(ch: String, text: String) -> Dictionary:
	return {"name": NPC_INFO[ch].name, "portrait": NPC_INFO[ch].sheet, "text": text}


func _talk(ch: String) -> void:
	match ch:
		"e":
			if Game.flag("boss_defeated"):
				await Dialogue.say([
					_line(ch, "You did it, Pip! The thorns are pulling back from the valley."),
					_line(ch, "But the brambles around Thornspire still grow... this is only the beginning."),
					_line(ch, "(Thanks for playing the prototype! Explore, fight thornlings, or replay the Woods.)"),
				])
			elif not Game.flag("met_elder"):
				Game.set_flag("met_elder")
				await Dialogue.say([
					_line(ch, "Ah, Pip! Thank the roots you're here."),
					_line(ch, "The Bramble King has awoken in the Whispering Woods, east across the river."),
					_line(ch, "His thorns creep closer every night. Someone must stop him."),
					_line(ch, "If you're rusty, the Training Grounds to the south will sharpen you up."),
					_line(ch, "Take these Berry Tonics. Open your bag ({inventory}) to drink one when you're hurt."),
				])
				Game.add_item("berry_tonic", 2)
			else:
				await Dialogue.say([_line(ch, "The Whispering Woods lie east, over the bridge. Rest on the bench if you're weary.")])
		"v":
			if Game.flag("level_done:forest"):
				await Dialogue.say([_line(ch, "Birdsong in the woods again! Never thought I'd hear it.")])
			else:
				await Dialogue.say([
					_line(ch, "Those thornlings roam the fields now. Touch one and it'll pick a fight!"),
					_line(ch, "Tip from an old farmer: in a scrap, the more you hit 'em, the farther they fly. Knock 'em clean off the edge!"),
				])
		"k":
			if Game.flag("charm_given"):
				await Dialogue.say([_line(ch, "Be careful out there! That charm's got real thorns.")])
			elif Game.has_item("rusty_key"):
				await Dialogue.say([
					_line(ch, "My key! You found it in the woods? You're the best!"),
					_line(ch, "Here — take my lucky Thorn Charm. It'll make your hits sting more!"),
				])
				Game.inventory.erase("rusty_key")
				Game.set_flag("charm_given")
				Game.add_item("thorn_charm")
			else:
				await Dialogue.say([_line(ch, "I dropped my key somewhere in the Whispering Woods... It's high up where the vines grow. Can you find it?")])
		"g":
			if Game.flag("boss_defeated"):
				await Dialogue.say([_line(ch, "The road to Thornspire will open soon. (Next stage — coming in the full game!)")])
			else:
				await Dialogue.say([_line(ch, "Halt! Thornspire is sealed by brambles. Nobody passes while the Bramble King lives.")])
	for i in 2:
		await get_tree().process_frame


func _intro() -> void:
	player.frozen = true
	await Transition.wait(0.6)
	await Dialogue.say([
		"Hollowmere Valley was once green and peaceful...",
		"...until the Bramble King awoke, and his thorns began to swallow the land.",
		"You are Pip — a wandering tinker with a leaf for a hat and more courage than sense.",
		{"name": "Elder Moss", "portrait": "npc_elder", "text": "Pip! Over here, by the village! Come talk to me."},
	])
	player.frozen = false
	hud.show_area_name("Hollowmere Valley")
	hud.show_hint(Controls.format("Move with {move_up}{move_left}{move_down}{move_right}. Hold {sprint} to run. Talk with {interact}."))
	await Transition.wait(6.0)
	if is_instance_valid(hud):
		hud.show_hint("")


func _after_boss() -> void:
	player.frozen = true
	await Transition.wait(0.6)
	await Dialogue.say([
		"With the Bramble King defeated, the thorns around Hollowmere begin to wither.",
		"But far to the north-east, Thornspire's brambles still grow...",
		{"name": "DEMO COMPLETE", "text": "Thanks for playing! Talk to Elder Moss, or keep exploring."},
	])
	player.frozen = false
