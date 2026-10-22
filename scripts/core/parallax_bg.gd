class_name ParallaxBG
extends CanvasLayer
## Screen-space parallax: each layer scrolls at a fraction of the camera's x position.
## factor < 1 = far away (background), factor > 1 = in front of the world (foreground).
## Layers that move at different speeds are what sells the "3D" depth in a 2D scene.

var camera: Camera2D
## Extra scroll for menus (pixels/sec), applied on top of the camera position.
var auto_scroll := 0.0
var _layers: Array = []  # [{sprite, factor, y_factor, base_y}]
var _auto := 0.0


func _init(canvas_layer := -10) -> void:
	layer = canvas_layer
	follow_viewport_enabled = false


## y is the screen position of the image's top edge. y_factor moves the layer vertically
## with the camera (0 = fixed on screen).
func add_image(path: String, factor: float, y := 0.0, tint := Color.WHITE, y_factor := 0.0) -> Sprite2D:
	var tex: Texture2D = load(path)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_rect = Rect2(0, 0, 640, tex.get_height())
	s.position = Vector2(0, y)
	s.modulate = tint
	add_child(s)
	_layers.append({"sprite": s, "factor": factor, "y_factor": y_factor, "base_y": y})
	return s


func _process(delta: float) -> void:
	_auto += auto_scroll * delta
	var cam_pos := Vector2.ZERO
	if is_instance_valid(camera):
		cam_pos = camera.get_screen_center_position()
	for l in _layers:
		var s: Sprite2D = l.sprite
		s.region_rect.position.x = (cam_pos.x + _auto) * l.factor
		s.position.y = l.base_y - cam_pos.y * l.y_factor
