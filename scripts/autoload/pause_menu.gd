extends CanvasLayer
## In-game pause menu: resume, inventory, save, settings, controls, quit to title, exit game.
## Opens with Pause (Esc / Start). Inventory (Tab / Back) jumps straight to the inventory page.

var is_open := false
var _root: Control
var _box: VBoxContainer
var _page := ""


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = UIKit.screen_root()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_box = UIKit.centered_panel(_root, Vector2(220, 0))
	_root.visible = false


func can_open() -> bool:
	return Game.context in ["overworld", "level", "combat"] and not Dialogue.active \
		and not Transition.busy and not Game.is_changing_scene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if is_open:
			close()
		elif can_open():
			open("main")
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		if is_open and _page == "inventory":
			close()
		elif is_open or can_open():
			open("inventory")
	elif is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _page == "main":
			close()
		else:
			_show("main")


func open(page := "main") -> void:
	is_open = true
	get_tree().paused = true
	_root.visible = true
	_show(page)


func close() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()


func _title(text: String) -> void:
	var l := UIKit.label(text, 18, UIKit.GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)


func _show(page: String) -> void:
	_page = page
	_clear()
	match page:
		"main":
			_build_main()
		"inventory":
			_build_inventory()
		"settings":
			_build_settings()
		"controls":
			_build_controls()
		"quit_confirm":
			_build_confirm("Quit to the title screen?\nUnsaved progress will be lost.", _quit_to_title)
		"exit_confirm":
			_build_confirm("Exit the game?\nUnsaved progress will be lost.", func(): get_tree().quit())


func _build_main() -> void:
	_title("Paused")
	var buttons := [
		UIKit.button("Resume", close),
		UIKit.button("Inventory", _show.bind("inventory")),
		UIKit.button("Save Game", _save),
		UIKit.button("Settings", _show.bind("settings")),
		UIKit.button("Controls", _show.bind("controls")),
		UIKit.button("Quit to Title", _show.bind("quit_confirm")),
		UIKit.button("Exit Game", _show.bind("exit_confirm")),
	]
	var scene := get_tree().current_scene
	if Game.context == "combat" or scene == null or not scene.has_method("get_save_position"):
		buttons[2].disabled = true
		buttons[2].text = "Save (not in battle)" if Game.context == "combat" else "Save Game"
	for b in buttons:
		_box.add_child(b)
	var info := UIKit.label("Play time  %s" % Game.format_time(Game.play_time), 10, UIKit.MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(info)
	UIKit.focus_first(buttons)


func _save() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("get_save_position"):
		Game.save_game(scene.get_save_position())
	close()


func _quit_to_title() -> void:
	close()
	Game.goto("menu", {}, "fade")


func _build_confirm(text: String, on_yes: Callable) -> void:
	var l := UIKit.label(text, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(l)
	var no := UIKit.button("No", _show.bind("main"))
	var yes := UIKit.button("Yes", on_yes)
	_box.add_child(no)
	_box.add_child(yes)
	UIKit.focus_first([no])


# ------------------------------------------------------------------------------------------
# Inventory
# ------------------------------------------------------------------------------------------
func _build_inventory(selected := "") -> void:
	_title("Inventory")
	var hp := UIKit.label("Health  %d / %d" % [Game.hp, Game.max_hp], 12, UIKit.RED)
	hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(hp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.custom_minimum_size = Vector2(150, 80)
	row.add_child(grid)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size = Vector2(170, 90)
	row.add_child(detail)
	var dname := UIKit.label("", 12, UIKit.GOLD)
	var ddesc := UIKit.label("", 10)
	ddesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ddesc.custom_minimum_size = Vector2(170, 0)
	var use := UIKit.button("Use", func(): pass, 80)
	detail.add_child(dname)
	detail.add_child(ddesc)
	detail.add_child(use)
	use.visible = false

	var buttons := []
	var ids: Array = Game.inventory.keys()
	ids.sort()
	for id in ids:
		var info: Dictionary = Game.ITEMS[id]
		var b := Button.new()
		b.icon = SpriteLib.frame_texture("items", info.icon)
		b.text = "x%d" % Game.inventory[id] if Game.inventory[id] > 1 else ""
		b.custom_minimum_size = Vector2(34, 30)
		b.expand_icon = false
		var show_detail := func():
			dname.text = info.name
			ddesc.text = info.desc + ("\n(Upgrade — always active)" if info.kind == "upgrade" else "")
			use.visible = info.kind == "consumable"
			for conn in use.pressed.get_connections():
				use.pressed.disconnect(conn.callable)
			use.pressed.connect(func():
				if Game.use_item(id):
					_clear()
					_build_inventory(id if Game.has_item(id) else ""))
		b.focus_entered.connect(show_detail)
		b.mouse_entered.connect(show_detail)
		b.pressed.connect(func():
			if use.visible:
				use.grab_focus())
		grid.add_child(b)
		buttons.append(b)
		if id == selected:
			buttons.erase(b)
			buttons.push_front(b)
	if ids.is_empty():
		dname.text = "Empty"
		ddesc.text = "Explore the world to find items and upgrades."
	var back := UIKit.button("Back", _show.bind("main"))
	_box.add_child(back)
	buttons.append(back)
	UIKit.focus_first(buttons)


# ------------------------------------------------------------------------------------------
# Settings / controls
# ------------------------------------------------------------------------------------------
func _build_settings() -> void:
	_title("Settings")
	var opts := [
		["retro_filter", "Old-film filter"],
		["fullscreen", "Fullscreen (F11)"],
		["show_hitboxes", "Show hitboxes (F3)"],
	]
	var first: Control = null
	for o in opts:
		var cb := CheckButton.new()
		cb.text = o[1]
		cb.button_pressed = Game.settings[o[0]]
		cb.toggled.connect(func(on): Game.set_setting(o[0], on))
		_box.add_child(cb)
		if first == null:
			first = cb
	var back := UIKit.button("Back", _show.bind("main"))
	_box.add_child(back)
	UIKit.focus_first([first])


func _build_controls() -> void:
	_title("Controls")
	_box.add_child(controls_grid())
	var back := UIKit.button("Back", _show.bind("main"))
	_box.add_child(back)
	UIKit.focus_first([back])


## Shared with the main menu.
static func controls_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 1)
	var rows := [
		["Action", "Keyboard", "Controller"],
		["Move / Climb", "WASD / Arrows", "L-Stick / D-Pad"],
		["Jump (x2 in battle)", "Space / Z", "A"],
		["Sprint (hold)", "Shift", "B / RT"],
		["Crouch / Crawl", "S / ↓", "Down"],
		["Dash / Dodge / Shield", "C", "LB / LT"],
		["Talk / Interact", "E", "Y"],
		["Light attack", "J / X", "X"],
		["Heavy attack", "K", "Y"],
		["Special (↑ = recover)", "L", "RB"],
		["Inventory", "Tab / I", "Back"],
		["Pause", "Esc / P", "Start"],
	]
	for i in rows.size():
		for cell in rows[i]:
			grid.add_child(UIKit.label(cell, 10, UIKit.GOLD if i == 0 else UIKit.CREAM))
	return grid
