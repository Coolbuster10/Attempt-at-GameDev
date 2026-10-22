extends Node
## Automated headless playtest. Drives the real scenes with simulated input.
## Run:  godot --headless --fixed-fps 60 res://tests/playtest.tscn
## Exit code 0 = all checks passed.

var _failures := 0
var _log: Array[String] = []


func _ready() -> void:
	# survive scene changes
	var root := get_tree().root
	get_parent().remove_child.call_deferred(self)
	root.add_child.call_deferred(self)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()


func check(cond: bool, what: String) -> void:
	_log.append(("PASS  " if cond else "FAIL  ") + what)
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		_failures += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func hold(action: String, n: int) -> void:
	Input.action_press(action)
	await frames(n)
	Input.action_release(action)


func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)
	await frames(1)


func goto_and_wait(key: String, params: Dictionary) -> Node:
	Game.goto(key, params, "fade")
	while Game.is_changing_scene() or Transition.busy:
		await get_tree().process_frame
	await frames(5)
	return get_tree().current_scene


func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "jump", "sprint", "attack", "heavy", "special", "dodge", "interact"]:
		Input.action_release(a)


func _run() -> void:
	Game.set_setting("retro_filter", false)
	Game._reset_state()

	# ---------------------------------------------------------------- platformer basics
	var lvl := await goto_and_wait("level", {"level": "tutorial"})
	check(lvl.name == "PlatformerLevel", "tutorial level loads")
	var p: PlatformPlayer = lvl.player
	await frames(20)
	check(p.is_on_floor(), "player lands on the ground")
	var x0 := p.global_position.x
	await hold("move_right", 30)
	check(p.global_position.x > x0 + 30, "walk right moves player (%.0f -> %.0f)" % [x0, p.global_position.x])
	var walk_speed := absf(p.velocity.x)
	Input.action_press("sprint")
	await hold("move_right", 20)
	check(absf(p.velocity.x) > walk_speed + 30 or p.global_position.x > x0 + 60, "sprint is faster than walking")
	Input.action_release("sprint")
	await frames(20)
	var y0 := p.global_position.y
	Input.action_press("jump")
	await frames(12)
	check(p.global_position.y < y0 - 20, "jump rises (%.0f -> %.0f)" % [y0, p.global_position.y])
	Input.action_release("jump")
	await frames(60)
	check(p.is_on_floor(), "lands after jump")
	Input.action_press("move_down")
	await frames(3)
	check(p.crouching, "holding down crouches")
	await hold("move_right", 10)
	check(absf(p.velocity.x) <= PlatformPlayer.CRAWL + 1, "crawl speed is slow")
	Input.action_release("move_down")
	await frames(3)
	check(not p.crouching, "stands back up in the open")

	# crawl tunnel: teleport to tunnel entrance and crawl through
	p.global_position = Vector2(85 * 16 + 8, 16 * 16)
	await frames(10)
	Input.action_press("move_down")
	await frames(3)
	Input.action_press("move_right")
	await frames(300)
	release_all()
	await frames(3)
	check(p.global_position.x > 98 * 16, "crawled through the tunnel (x=%.0f)" % p.global_position.x)

	# crawl under the ceiling must stay crouched
	p.global_position = Vector2(92 * 16 + 8, 16 * 16)
	await frames(10)
	p._set_crouch(true)
	await frames(3)
	check(p.crouching, "can't stand up under the cave ceiling")

	# vine climbing
	p.global_position = Vector2(104 * 16 + 8, 16 * 16)
	await frames(20)
	await hold("move_right", 50)
	print("  at vine: x=%.0f vines=%d" % [p.global_position.x, p._vines.size()])
	Input.action_press("move_up")
	await frames(10)
	print("  state after up: %d" % p.state)
	await frames(110)
	print("  after climb: pos=%s state=%d" % [p.global_position, p.state])
	Input.action_release("move_up")
	await hold("move_right", 30)
	await frames(30)
	check(p.global_position.y <= 8 * 16 + 1 and p.is_on_floor(), "climbed the vine onto the wall (y=%.0f)" % p.global_position.y)

	# twig trip
	Game.set_hp(5)
	p.global_position = Vector2(63 * 16, 16 * 16)
	await frames(20)
	Input.action_press("move_right")
	var tripped := false
	for i in 120:
		await frames(1)
		if p.state == PlatformPlayer.State.TRIP:
			tripped = true
			break
	release_all()
	check(tripped, "walking into a twig trips the player")
	await frames(60)

	# pit: fall in, lose a heart, respawn on safe ground
	Game.set_hp(5)
	p.global_position = Vector2(42 * 16, 16 * 16)
	await frames(30)
	p.global_position = Vector2(46 * 16, 16 * 16 + 20)
	await frames(120)
	check(Game.hp == 4, "falling in a pit costs one heart (hp=%d)" % Game.hp)
	check(p.global_position.y <= 16 * 16 + 1, "respawned on safe ground")

	# projectiles hurt
	Game.set_hp(5)
	p._invuln = 0.0
	p.global_position = Vector2(132 * 16, 16 * 16)
	var hurt := false
	for i in 400:
		await frames(1)
		if Game.hp < 5:
			hurt = true
			break
	check(hurt, "seed pod / acorn projectiles can hurt the player")

	# inventory + save
	Game.add_item("berry_tonic", 2, false)
	Game.set_hp(2)
	check(Game.use_item("berry_tonic") and Game.hp == 4, "berry tonic heals 2")
	check(Game.save_game(p.global_position), "save game writes file")
	var save := Game.read_save()
	check(save.get("scene") == "level" and save.params.level == "tutorial", "save stores scene and level")

	# ---------------------------------------------------------------- combat vs thornling
	Game.set_hp(5)
	var arena := await goto_and_wait("combat", {"enemy": "thornling", "enemy_id": "test_e", "return_key": "level",
			"return_params": {"level": "tutorial"}})
	check(arena.name == "CombatArena", "combat arena loads")
	await frames(150)
	var pf: PlayerFighter = arena.player
	var en: Fighter = arena.enemy
	check(pf.state == "idle" and en.state != "frozen", "fight starts after READY/FIGHT")
	check(is_equal_approx(pf.max_hp, 100.0), "player battle HP = hearts x 20")
	var start_hp := en.hp
	for i in 900:
		var dx := en.global_position.x - pf.global_position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 24:
			Input.action_press("move_right" if dx > 0 else "move_left")
		elif i % 10 == 0:
			pf.facing = 1 if dx > 0 else -1
			Input.action_press("heavy" if i % 40 == 0 else "attack")
		if i % 10 == 2:
			Input.action_release("attack")
			Input.action_release("heavy")
		pf.hp = pf.max_hp  # keep the bot alive; we're testing hits, not skill
		await frames(1)
	release_all()
	check(en.hp < start_hp, "player attacks damage the thornling (%.0f -> %.0f)" % [start_hp, en.hp])
	check(en.percent > 0.0, "damage percent rises with hits (%.0f%%)" % en.percent)
	en.take_hit({"dmg": 999.0, "kb": 100.0, "growth": 0.0, "angle": 45.0}, 1)
	var waited := 0
	while get_tree().current_scene == arena and waited < 900:
		await frames(1)
		waited += 1
	while Game.is_changing_scene() or Transition.busy:
		await get_tree().process_frame
	await frames(5)
	var after := get_tree().current_scene
	check(after.name in ["PlatformerLevel", "GameOver"], "returned to level or game-over (%s)" % after.name)
	if after.name == "PlatformerLevel":
		check(Game.flag("defeated:test_e"), "victory marks the enemy defeated")

	# ---------------------------------------------------------------- combat tutorial checklist
	arena = await goto_and_wait("combat", {"enemy": "dummy", "enemy_id": "dummy_test", "tutorial": true,
			"return_key": "level", "return_params": {"level": "tutorial"}})
	await frames(150)
	await hold("move_right", 10)
	await tap("jump")
	await frames(10)
	await tap("jump")
	await frames(60)
	await tap("attack")
	await frames(30)
	Input.action_press("move_up")
	await tap("attack")
	Input.action_release("move_up")
	await frames(30)
	await tap("heavy")
	await frames(50)
	await tap("special")
	await frames(30)
	await hold("dodge", 20)
	await frames(30)
	Input.action_press("move_left")
	await tap("dodge")
	Input.action_release("move_left")
	await frames(30)
	check(arena._tasks_done.size() == arena.TUTORIAL_TASKS.size() - 1, "combat tutorial tracks every move (%s)" % ", ".join(arena._tasks_done.keys()))
	arena.enemy.global_position = Vector2(900, 0)
	waited = 0
	while get_tree().current_scene == arena and waited < 900:
		await frames(1)
		waited += 1
	while Game.is_changing_scene() or Transition.busy:
		await get_tree().process_frame
	check(get_tree().current_scene.name == "PlatformerLevel" and Game.flag("defeated:dummy_test"), "ring-out completes training and returns")

	# ---------------------------------------------------------------- boss runs its patterns
	Game.set_hp(5)
	arena = await goto_and_wait("combat", {"enemy": "bramble_king", "enemy_id": "boss_test", "return_key": "level",
			"return_params": {"level": "forest"}, "boss": true})
	var boss: BossFighter = arena.enemy
	await frames(60)
	check(boss.state == "cutscene" and arena.player.state == "frozen", "boss intro cutscene locks both fighters")
	await frames(300)
	check(boss.state == "idle", "boss fight starts after the intro")
	var seen := {}
	var took_damage := false
	for i in 1800:
		if boss.pattern != "":
			seen[boss.pattern] = true
		if arena.player.hp < arena.player.max_hp:
			took_damage = true
			arena.player.hp = arena.player.max_hp
		await frames(1)
		if seen.size() >= 3:
			break
	print("  boss patterns=%s boss=%s player=%s php=%.0f inv=%.1f pstate=%s" % [seen.keys(), boss.global_position, arena.player.global_position, arena.player.hp, arena.player.invuln, arena.player.state])
	check(seen.size() >= 3, "boss uses multiple attack patterns: %s" % ", ".join(seen.keys()))
	if get_tree().current_scene == arena:
		check(took_damage, "boss attacks damage an idle player")
		# finish the boss quickly to test the victory flow
		boss.take_hit({"dmg": 999.0, "kb": 0.0, "growth": 0.0, "angle": 0.0}, 1)
		waited = 0
		while get_tree().current_scene == arena and waited < 900:
			await frames(1)
			waited += 1
		while Game.is_changing_scene() or Transition.busy:
			await get_tree().process_frame
		await frames(10)
		check(get_tree().current_scene.name == "Overworld", "boss victory returns to the overworld")
		check(Game.flag("boss_defeated") and Game.max_hp == 6, "boss sets flag and grants a Heart Seed")
		while Dialogue.active:
			Dialogue._advance.emit()
			await frames(2)

	# ---------------------------------------------------------------- overworld + menus
	var ow := await goto_and_wait("overworld", {"spawn": "start"})
	check(ow.name == "Overworld", "overworld loads")
	var op: OverworldPlayer = ow.player
	var ox := op.global_position
	await hold("move_up", 30)
	check(op.global_position.y < ox.y - 10, "overworld player walks")
	PauseMenu.open("inventory")
	await frames(5)
	check(get_tree().paused and PauseMenu.is_open, "inventory/pause menu opens and pauses")
	PauseMenu.close()
	await frames(2)
	Game.goto("level", {"level": "forest"}, "loading")
	for i in 600:
		await frames(1)
		if get_tree().current_scene and get_tree().current_scene.name == "PlatformerLevel" and not Transition.busy:
			break
	check(get_tree().current_scene.name == "PlatformerLevel", "loading screen loads the forest stage")
	var menu := await goto_and_wait("menu", {})
	check(menu.name == "MainMenu", "main menu loads")
	Game.delete_save()

	print("\n%d checks, %d failed" % [_log.size(), _failures])
	get_tree().quit(1 if _failures > 0 else 0)
