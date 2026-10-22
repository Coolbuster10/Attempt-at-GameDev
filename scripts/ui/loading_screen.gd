extends Control
## Loading screen: loads Game.loading_target on a background thread, shows progress,
## a running Pip and a gameplay tip, then swaps to the loaded scene.

const MIN_TIME := 1.2
const TIPS := [
	"Hold Sprint to run — you'll need the speed to clear wide gaps.",
	"Crouch while moving to crawl through low caves.",
	"Twigs will trip you up. Jump over them, or crawl carefully across.",
	"Press Up near vines to climb them.",
	"In battle, the higher an enemy's % gets, the farther they fly.",
	"Knock enemies off the stage for massive damage!",
	"Hold Dodge to raise your shield. Dodge + direction rolls away.",
	"Special while holding Up launches you upward — use it to recover.",
	"Rest on benches to heal and save your progress.",
	"Watch the Bramble King's roots — they sprout where the ground rumbles.",
]

var _elapsed := 0.0
var _done := false
var _bar: ProgressBar
var _label: Label
var _target := ""


func _ready() -> void:
	theme = Game.theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_target = Game.loading_target
	var bg := ColorRect.new()
	bg.color = UIKit.DARK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var runner := Node2D.new()
	runner.position = Vector2(320, 190)
	runner.scale = Vector2(3, 3)
	add_child(runner)
	var pip := SpriteLib.animated("player", "run")
	runner.add_child(pip)
	var shadow := SpriteLib.sprite("shadow")
	shadow.position.y = 3
	shadow.z_index = -1
	runner.add_child(shadow)

	_label = UIKit.label("Loading", 16, UIKit.GOLD)
	_label.position = Vector2(270, 210)
	_label.size = Vector2(100, 20)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.position = Vector2(220, 238)
	_bar.size = Vector2(200, 8)
	_bar.max_value = 1.0
	add_child(_bar)
	var tip := UIKit.label("TIP: " + TIPS.pick_random(), 10, UIKit.CREAM)
	tip.position = Vector2(40, 300)
	tip.size = Vector2(560, 30)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(tip)
	if _target == "" or ResourceLoader.load_threaded_request(_target) != OK:
		push_error("Loading screen has no valid target: %s" % _target)
		_target = Game.SCENES.menu
		ResourceLoader.load_threaded_request(_target)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	_label.text = "Loading" + ".".repeat(int(_elapsed * 3) % 4)
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_target, progress)
	var real: float = progress[0] if progress.size() > 0 else 0.0
	# Bar never runs ahead of the real progress or of the minimum display time.
	_bar.value = minf(real, _elapsed / MIN_TIME)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		push_error("Failed to load %s" % _target)
		_done = true
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED and _elapsed >= MIN_TIME:
		_done = true
		_finish()


func _finish() -> void:
	Game.finish_loading(ResourceLoader.load_threaded_get(_target))
