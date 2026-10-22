extends Node
## Global game state: health, inventory, story flags, settings, saving/loading and scene routing.

signal hp_changed(hp: int, max_hp: int)
signal inventory_changed
signal toast(text: String)

const TITLE := "Project Bramble"  # placeholder name — change it here
const SAVE_PATH := "user://savegame.json"
const SETTINGS_PATH := "user://settings.cfg"
const SAVE_VERSION := 1
## Combat HP per adventure heart: 5 hearts = 100 HP in a fight.
const HP_PER_HEART := 20

const SCENES := {
	"menu": "res://scenes/main_menu.tscn",
	"overworld": "res://scenes/overworld.tscn",
	"level": "res://scenes/platformer_level.tscn",
	"combat": "res://scenes/combat_arena.tscn",
	"loading": "res://scenes/loading_screen.tscn",
	"game_over": "res://scenes/game_over.tscn",
}

## Item database. kind: consumable (used from inventory), upgrade (passive, permanent),
## key (quest item), heart (applied instantly on pickup).
const ITEMS := {
	"berry_tonic": {"name": "Berry Tonic", "icon": 0, "kind": "consumable", "heal": 2,
		"desc": "A fizzy red tonic. Restores 2 hearts."},
	"gale_boots": {"name": "Gale Boots", "icon": 1, "kind": "upgrade",
		"desc": "Lets you DASH, even in mid-air. In combat, dodges cover more ground."},
	"thorn_charm": {"name": "Thorn Charm", "icon": 2, "kind": "upgrade",
		"desc": "A prickly charm. Your attacks deal 25% more damage in combat."},
	"rusty_key": {"name": "Rusty Key", "icon": 3, "kind": "key",
		"desc": "An old key covered in moss. Someone in the village lost it."},
	"heart_seed": {"name": "Heart Seed", "icon": 4, "kind": "heart",
		"desc": "Raises your maximum health by one heart."},
}

var hp := 5
var max_hp := 5
var inventory: Dictionary = {}  # item_id -> count
var flags: Dictionary = {}  # progress flags, e.g. "defeated:forest_e1", "level_done:forest"
var play_time := 0.0
var settings := {"retro_filter": true, "fullscreen": false, "show_hitboxes": false}

## Which scene we are in + the params it was opened with (used for saving and returning from fights).
var scene_key := ""
var scene_params: Dictionary = {}
## Set by gameplay scenes: "menu", "overworld", "level", "combat", "cutscene".
var context := "menu"
var loading_target := ""
var theme: Theme

var _changing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UIKit.build_theme()
	_load_settings()


func _process(delta: float) -> void:
	if context in ["overworld", "level", "combat"] and not get_tree().paused:
		play_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			set_setting("fullscreen", not settings.fullscreen)
		elif event.keycode == KEY_F3:
			set_setting("show_hitboxes", not settings.show_hitboxes)


# ------------------------------------------------------------------------------------------
# Health
# ------------------------------------------------------------------------------------------
func damage(amount: int) -> void:
	hp = clampi(hp - amount, 0, max_hp)
	hp_changed.emit(hp, max_hp)


func heal(amount: int) -> void:
	hp = clampi(hp + amount, 0, max_hp)
	hp_changed.emit(hp, max_hp)


func set_hp(value: int) -> void:
	hp = clampi(value, 0, max_hp)
	hp_changed.emit(hp, max_hp)


func is_dead() -> bool:
	return hp <= 0


# ------------------------------------------------------------------------------------------
# Inventory
# ------------------------------------------------------------------------------------------
func add_item(id: String, count := 1, announce := true) -> void:
	var info: Dictionary = ITEMS[id]
	if info.kind == "heart":
		max_hp += count
		heal(max_hp)
	else:
		inventory[id] = inventory.get(id, 0) + count
	inventory_changed.emit()
	if announce:
		toast.emit("Got %s%s!" % [info.name, " x%d" % count if count > 1 else ""])


func has_item(id: String) -> bool:
	return inventory.get(id, 0) > 0


func item_count(id: String) -> int:
	return inventory.get(id, 0)


## Returns true if the item was used.
func use_item(id: String) -> bool:
	if not has_item(id):
		return false
	var info: Dictionary = ITEMS[id]
	if info.kind != "consumable":
		return false
	if info.has("heal"):
		if hp >= max_hp:
			toast.emit("Already at full health.")
			return false
		heal(info.heal)
	inventory[id] -= 1
	if inventory[id] <= 0:
		inventory.erase(id)
	inventory_changed.emit()
	return true


# ------------------------------------------------------------------------------------------
# Flags
# ------------------------------------------------------------------------------------------
func flag(name: String) -> bool:
	return flags.get(name, false)


func set_flag(name: String, value := true) -> void:
	flags[name] = value


# ------------------------------------------------------------------------------------------
# Scene routing
# ------------------------------------------------------------------------------------------
## style: "fade", "iris", "battle" (Pokemon-style flash + bars) or "loading" (via loading screen).
func goto(key: String, params := {}, style := "fade") -> void:
	if _changing:
		return
	_changing = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	Dialogue.close()
	match style:
		"battle":
			await Transition.battle_cover()
		"iris":
			await Transition.cover(Transition.IRIS, 0.5)
		_:
			await Transition.cover(Transition.FADE, 0.3)
	scene_key = key
	scene_params = params.duplicate(true)
	context = "cutscene"
	if style == "loading":
		loading_target = SCENES[key]
		get_tree().change_scene_to_file(SCENES.loading)
	else:
		get_tree().change_scene_to_file(SCENES[key])
	await get_tree().process_frame
	await get_tree().process_frame
	_changing = false
	if style == "iris":
		await Transition.reveal(Transition.IRIS, 0.5)
	elif style == "battle":
		await Transition.reveal(Transition.BARS, 0.4)
	else:
		await Transition.reveal(Transition.FADE, 0.3)


## Called by the loading screen once the target scene is loaded (runs here because the
## loading screen itself is freed by the scene change).
func finish_loading(packed: PackedScene) -> void:
	_changing = true
	await Transition.cover(Transition.FADE, 0.25)
	get_tree().change_scene_to_packed(packed)
	await get_tree().process_frame
	await get_tree().process_frame
	_changing = false
	await Transition.reveal(Transition.FADE, 0.35)


func is_changing_scene() -> bool:
	return _changing


## Starts a fight. `return_params` must let the caller's scene rebuild itself (incl. a spawn point).
func start_battle(enemy: String, enemy_id: String, return_key: String, return_params: Dictionary, extra := {}) -> void:
	var params := {"enemy": enemy, "enemy_id": enemy_id, "return_key": return_key, "return_params": return_params}
	params.merge(extra)
	goto("combat", params, "battle")


func new_game() -> void:
	_reset_state()
	goto("overworld", {"spawn": "start", "intro": true}, "loading")


## New game that starts with the training grounds; finishing it leads to the overworld.
func new_game_tutorial() -> void:
	_reset_state()
	goto("level", {"level": "tutorial", "first_run": true}, "loading")


func _reset_state() -> void:
	hp = 5
	max_hp = 5
	inventory = {}
	flags = {}
	play_time = 0.0
	inventory_changed.emit()
	hp_changed.emit(hp, max_hp)


# ------------------------------------------------------------------------------------------
# Save / load (single slot, JSON in user://)
# ------------------------------------------------------------------------------------------
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Saves at a position inside the current scene. Scenes call this from benches/pause menu.
func save_game(spawn_position: Vector2) -> bool:
	var params := scene_params.duplicate(true)
	params["spawn"] = [spawn_position.x, spawn_position.y]
	params.erase("intro")
	var data := {
		"version": SAVE_VERSION,
		"hp": hp,
		"max_hp": max_hp,
		"inventory": inventory,
		"flags": flags,
		"play_time": play_time,
		"scene": scene_key,
		"params": params,
		"timestamp": Time.get_datetime_string_from_system(false, true),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "\t"))
	toast.emit("Game saved.")
	return true


func read_save() -> Dictionary:
	if not has_save():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	return parsed if parsed is Dictionary else {}


func load_game() -> bool:
	var data := read_save()
	if data.is_empty() or not SCENES.has(data.get("scene", "")):
		return false
	max_hp = int(data.get("max_hp", 5))
	hp = clampi(int(data.get("hp", max_hp)), 1, max_hp)
	inventory = {}
	for k in data.get("inventory", {}):
		inventory[k] = int(data.inventory[k])
	flags = data.get("flags", {})
	play_time = float(data.get("play_time", 0.0))
	inventory_changed.emit()
	hp_changed.emit(hp, max_hp)
	goto(data.scene, data.get("params", {}), "loading")
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## Helper for scenes: turns a saved [x, y] (or Vector2) into a Vector2, or returns null.
static func param_vec(value) -> Variant:
	if value is Vector2:
		return value
	if value is Array and value.size() == 2:
		return Vector2(value[0], value[1])
	return null


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


# ------------------------------------------------------------------------------------------
# Settings
# ------------------------------------------------------------------------------------------
func set_setting(key: String, value) -> void:
	settings[key] = value
	_apply_settings()
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings:
			settings[k] = cfg.get_value("settings", k, settings[k])
	_apply_settings.call_deferred()


func _apply_settings() -> void:
	PostFX.set_enabled(settings.retro_filter)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
