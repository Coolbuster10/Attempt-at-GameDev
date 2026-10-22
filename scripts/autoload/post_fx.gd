extends CanvasLayer
## Full-screen "old cartoon" filter (vignette, grain, warm tint). Toggle in Settings.

var _rect: ColorRect


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/post_fx.gdshader")
	_rect.material = mat
	add_child(_rect)


func set_enabled(on: bool) -> void:
	visible = on
