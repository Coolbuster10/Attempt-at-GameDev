extends Control
## Shown when the player runs out of health. Params: retry_key / retry_params (where "Try Again" goes).


func _ready() -> void:
	Game.context = "menu"
	theme = Game.theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1a0d0d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var pip := SpriteLib.animated("player", "trip")
	pip.position = Vector2(320, 120)
	pip.scale = Vector2(3, 3)
	add_child(pip)
	var title := UIKit.label("YOU WERE DEFEATED", 24, UIKit.RED)
	title.add_theme_constant_override("outline_size", 8)
	title.position = Vector2(0, 140)
	title.size = Vector2(640, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var box := VBoxContainer.new()
	box.position = Vector2(250, 200)
	box.custom_minimum_size = Vector2(140, 0)
	add_child(box)
	var buttons := []
	if Game.has_save():
		buttons.append(UIKit.button("Load Last Save", func(): Game.load_game()))
	var p := Game.scene_params
	if p.has("retry_key"):
		buttons.append(UIKit.button("Try Again", func():
			Game.set_hp(Game.max_hp)
			Game.goto(p.retry_key, p.get("retry_params", {}), "fade")))
	buttons.append(UIKit.button("Quit to Title", func(): Game.goto("menu")))
	for b in buttons:
		box.add_child(b)
	UIKit.focus_first(buttons)
