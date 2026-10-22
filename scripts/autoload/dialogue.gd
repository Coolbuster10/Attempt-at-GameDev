extends CanvasLayer
## Typewriter dialogue box with speaker name, portrait and optional choices.
##
## Usage:
##   await Dialogue.say([
##       {"name": "Elder", "portrait": "npc_elder", "text": "Hello there!"},
##       "Plain strings work too.",
##       {"name": "Elder", "text": "Rest here?", "choices": ["Yes", "No"]},
##   ])
## `say` returns the index of the last choice picked (or -1). The game is paused while it is open.

signal _advance
signal _chosen(index: int)

const CHARS_PER_SEC := 50.0

var active := false
var _root: Control
var _panel: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: Label
var _arrow: Label
var _choices: VBoxContainer
var _typing := false
var _input_lock := 0.0
var _was_paused := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = UIKit.screen_root()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 24
	_panel.offset_right = -24
	_panel.offset_top = -96
	_panel.offset_bottom = -12
	_root.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_panel.add_child(row)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(48, 64)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	_name = UIKit.label("", 12, UIKit.GOLD)
	col.add_child(_name)
	_text = UIKit.label("", 12)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.anchor_left = 1.0
	_choices.anchor_right = 1.0
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.offset_left = -180
	_choices.offset_right = -32
	_choices.offset_top = -170
	_choices.offset_bottom = -104
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(_choices)
	_arrow = UIKit.label("▼", 10, UIKit.GOLD)
	_arrow.anchor_left = 1.0
	_arrow.anchor_right = 1.0
	_arrow.anchor_top = 1.0
	_arrow.anchor_bottom = 1.0
	_arrow.offset_left = -44
	_arrow.offset_top = -30
	_root.add_child(_arrow)
	_root.visible = false


func say(lines: Array) -> int:
	if active:
		return -1
	active = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_root.visible = true
	var choice := -1
	for raw in lines:
		var line: Dictionary = raw if raw is Dictionary else {"text": str(raw)}
		_show_line(line)
		_input_lock = 0.15
		if line.has("choices"):
			while _typing and active:
				await get_tree().process_frame
			if active:
				choice = await _ask(line.choices)
		else:
			await _advance
		if not active:
			return -1
	close()
	return choice


func close() -> void:
	if not active:
		return
	active = false
	_root.visible = false
	for c in _choices.get_children():
		c.queue_free()
	get_tree().paused = _was_paused
	_advance.emit()


func _show_line(line: Dictionary) -> void:
	_name.text = line.get("name", "")
	_name.visible = _name.text != ""
	var portrait: String = line.get("portrait", "")
	_portrait.visible = portrait != ""
	if portrait != "":
		_portrait.texture = SpriteLib.frame_texture(portrait, 0)
	_text.text = Controls.format(line.get("text", ""))
	_text.visible_characters = 0
	_typing = true
	_arrow.visible = false


func _ask(options: Array) -> int:
	_arrow.visible = false
	var buttons := []
	for i in options.size():
		var b := UIKit.button(str(options[i]), _chosen.emit.bind(i), 120)
		_choices.add_child(b)
		buttons.append(b)
	UIKit.focus_first(buttons)
	var idx: int = await _chosen
	for c in _choices.get_children():
		c.queue_free()
	return idx


func _process(delta: float) -> void:
	if not active:
		return
	_input_lock = maxf(_input_lock - delta, 0.0)
	if _typing:
		_text.visible_characters += max(1, int(CHARS_PER_SEC * delta + 0.5))
		if _text.visible_ratio >= 1.0:
			_text.visible_characters = -1
			_typing = false
	_arrow.visible = not _typing and _choices.get_child_count() == 0
	_arrow.offset_top = -30 + (2 if int(Time.get_ticks_msec() / 300) % 2 == 0 else 0)


func _unhandled_input(event: InputEvent) -> void:
	if not active or _input_lock > 0.0 or _choices.get_child_count() > 0:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") \
			or event.is_action_pressed("jump") or event.is_action_pressed("attack"):
		get_viewport().set_input_as_handled()
		if _typing:
			_text.visible_characters = -1
			_typing = false
		else:
			_advance.emit()
