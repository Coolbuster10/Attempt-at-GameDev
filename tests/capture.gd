extends Node
## Dev helper: opens a scene with params for screenshots, e.g.
##   CAP_SCENE=combat CAP_PARAMS='{"enemy":"bramble_king","boss":true}' godot res://tests/capture.tscn --write-movie out.png ...


func _ready() -> void:
	Game.set_setting("retro_filter", OS.get_environment("CAP_FILTER") == "1")
	var params = JSON.parse_string(OS.get_environment("CAP_PARAMS")) if OS.get_environment("CAP_PARAMS") != "" else {}
	Game.goto(OS.get_environment("CAP_SCENE"), params if params is Dictionary else {}, "fade")
	if OS.get_environment("CAP_PAUSE") != "":
		Game.add_item("berry_tonic", 2, false)
		Game.add_item("gale_boots", 1, false)
		Game.add_item("rusty_key", 1, false)
		# bound to the PauseMenu autoload because this node is freed by the scene change
		get_tree().create_timer(1.5).timeout.connect(PauseMenu.open.bind(OS.get_environment("CAP_PAUSE")))
