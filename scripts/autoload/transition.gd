extends CanvasLayer
## Screen transitions (fade, Pokemon-style battle bars, iris) and screen flashes.
## All waits ignore pause and Engine.time_scale so they work during slow-mo and menus.

signal finished

enum { FADE, BARS, IRIS }

var _rect: ColorRect
var _flash: ColorRect
var _mat: ShaderMaterial
var busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/transition.gdshader")
	_rect.material = _mat
	add_child(_rect)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color.WHITE
	_flash.modulate.a = 0.0
	add_child(_flash)
	_set_progress(0.0)


func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)


func _tween() -> Tween:
	return create_tween().set_ignore_time_scale(true)


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func cover(mode := FADE, duration := 0.35, color := Color.BLACK) -> void:
	busy = true
	_mat.set_shader_parameter("mode", mode)
	_mat.set_shader_parameter("tint", color)
	var tw := _tween()
	tw.tween_method(_set_progress, 0.0, 1.0, duration)
	await tw.finished


func reveal(mode := FADE, duration := 0.35) -> void:
	_mat.set_shader_parameter("mode", mode)
	var tw := _tween()
	tw.tween_method(_set_progress, 1.0, 0.0, duration)
	await tw.finished
	busy = false
	finished.emit()


## Instantly covers the screen (e.g. before a scene that will reveal itself).
func set_covered(color := Color.BLACK) -> void:
	_mat.set_shader_parameter("mode", FADE)
	_mat.set_shader_parameter("tint", color)
	_set_progress(1.0)


func flash(times := 1, on_time := 0.06, color := Color.WHITE, alpha := 1.0) -> void:
	_flash.color = color
	for i in times:
		_flash.modulate.a = alpha
		await wait(on_time)
		_flash.modulate.a = 0.0
		await wait(on_time)


## Classic "wild enemy appeared" transition: white flashes, then sweeping black bars.
func battle_cover() -> void:
	busy = true
	await flash(3, 0.07)
	await cover(BARS, 0.55)
