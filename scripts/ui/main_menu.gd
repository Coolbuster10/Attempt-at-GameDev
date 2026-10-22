extends Control
## Title screen: Continue / New Game / Tutorial / Settings / Controls / Quit.

var _box: VBoxContainer
var _bg: ParallaxBG
var _title: Label


func _ready() -> void:
	Game.context = "menu"
	get_tree().paused = false
	theme = Game.theme
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_bg = ParallaxBG.new(-10)
	_bg.auto_scroll = 60.0
	_bg.add_image("res://assets/backgrounds/sky.png", 0.05)
	_bg.add_image("res://assets/backgrounds/hills_far.png", 0.2, 140, Color(1, 1, 1))
	_bg.add_image("res://assets/backgrounds/hills_mid.png", 0.45, 150)
	_bg.add_image("res://assets/backgrounds/trees_near.png", 0.8, 130)
	add_child(_bg)
	var fg := ParallaxBG.new(-5)
	fg.auto_scroll = 60.0
	fg.add_image("res://assets/backgrounds/foreground.png", 1.6, 30, Color(1, 1, 1, 0.9))
	add_child(fg)

	# ground strip with Pip running and a thornling giving chase
	var ground := ColorRect.new()
	ground.color = Color("5c3a22")
	ground.position = Vector2(0, 318)
	ground.size = Vector2(640, 42)
	add_child(ground)
	var grass := ColorRect.new()
	grass.color = Color("5e9c4a")
	grass.position = Vector2(0, 314)
	grass.size = Vector2(640, 6)
	add_child(grass)
	var actors := Node2D.new()
	add_child(actors)
	var pip := SpriteLib.animated("player", "run")
	pip.position = Vector2(575, 316)
	pip.scale = Vector2(2, 2)
	actors.add_child(pip)
	var chaser := SpriteLib.animated("thornling", "run")
	chaser.position = Vector2(470, 316)
	chaser.scale = Vector2(2, 2)
	chaser.flip_h = false
	actors.add_child(chaser)
	var bob := create_tween().set_loops()
	bob.tween_property(chaser, "position:x", 490.0, 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(chaser, "position:x", 465.0, 0.8).set_trans(Tween.TRANS_SINE)

	var banner := TextureRect.new()
	banner.texture = SpriteLib.texture("banner")
	banner.position = Vector2(160, 24)
	banner.size = Vector2(320, 80)
	banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(banner)
	_title = UIKit.label(Game.TITLE, 28, UIKit.CREAM)
	_title.add_theme_constant_override("outline_size", 8)
	_title.position = Vector2(160, 34)
	_title.size = Vector2(320, 50)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.pivot_offset = Vector2(160, 25)
	add_child(_title)
	var sub := UIKit.label("~ a tale of thorns and tinkers ~", 10, UIKit.GOLD)
	sub.position = Vector2(160, 80)
	sub.size = Vector2(320, 16)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var panel := PanelContainer.new()
	panel.position = Vector2(232, 112)
	panel.custom_minimum_size = Vector2(176, 0)
	add_child(panel)
	_box = VBoxContainer.new()
	panel.add_child(_box)
	_show_main()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_title.rotation = sin(t * 1.5) * 0.03
	_title.scale = Vector2.ONE * (1.0 + sin(t * 3.0) * 0.02)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_show_main()


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _show_main() -> void:
	_clear()
	var save := Game.read_save()
	var cont := UIKit.button("Continue", _continue)
	cont.disabled = save.is_empty()
	var buttons := [
		cont,
		UIKit.button("New Game", _new_game),
		UIKit.button("Tutorial", _tutorial),
		UIKit.button("Settings", _show_settings),
		UIKit.button("Controls", _show_controls),
		UIKit.button("Quit", func(): get_tree().quit()),
	]
	for b in buttons:
		_box.add_child(b)
	if not save.is_empty():
		var info := UIKit.label("Save: %s  •  %s" % [str(save.get("timestamp", "")).substr(0, 16),
				Game.format_time(float(save.get("play_time", 0)))], 9, UIKit.MUTED)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(info)
	UIKit.focus_first(buttons)


func _continue() -> void:
	if not Game.load_game():
		_show_message("The save file could not be read.")


func _new_game() -> void:
	if Game.has_save():
		_confirm("Start a new game?\nYour current save will be overwritten\nthe next time you save.", _ask_tutorial)
	else:
		_ask_tutorial()


func _ask_tutorial() -> void:
	_clear()
	var l := UIKit.label("Play the tutorial first?", 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	var yes := UIKit.button("Yes, teach me", _tutorial)
	var no := UIKit.button("No, jump right in", func(): Game.new_game())
	_box.add_child(yes)
	_box.add_child(no)
	UIKit.focus_first([yes])


func _tutorial() -> void:
	Game.new_game_tutorial()


func _confirm(text: String, on_yes: Callable) -> void:
	_clear()
	var l := UIKit.label(text, 11)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	var no := UIKit.button("No", _show_main)
	var yes := UIKit.button("Yes", on_yes)
	_box.add_child(no)
	_box.add_child(yes)
	UIKit.focus_first([no])


func _show_message(text: String) -> void:
	_clear()
	_box.add_child(UIKit.label(text, 11))
	var ok := UIKit.button("OK", _show_main)
	_box.add_child(ok)
	UIKit.focus_first([ok])


func _show_settings() -> void:
	_clear()
	var opts := [["retro_filter", "Old-film filter"], ["fullscreen", "Fullscreen (F11)"]]
	var first: Control = null
	for o in opts:
		var cb := CheckButton.new()
		cb.text = o[1]
		cb.button_pressed = Game.settings[o[0]]
		cb.toggled.connect(func(on): Game.set_setting(o[0], on))
		_box.add_child(cb)
		if first == null:
			first = cb
	var del := UIKit.button("Delete save file", func():
		_confirm("Really delete your save?", func():
			Game.delete_save()
			_show_main()))
	del.disabled = not Game.has_save()
	_box.add_child(del)
	_box.add_child(UIKit.button("Back", _show_main))
	UIKit.focus_first([first])


func _show_controls() -> void:
	_clear()
	_box.add_child(PauseMenu.controls_grid())
	var back := UIKit.button("Back", _show_main)
	_box.add_child(back)
	UIKit.focus_first([back])
