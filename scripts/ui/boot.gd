extends Node
## Entry point: short splash, then the loading screen brings up the main menu.


func _ready() -> void:
	Game.context = "menu"
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := UIKit.screen_root()
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = UIKit.DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var l := UIKit.label("a prototype made with Godot", 12, UIKit.MUTED)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(l)
	await get_tree().create_timer(0.8).timeout
	Game.goto("menu", {}, "loading")
