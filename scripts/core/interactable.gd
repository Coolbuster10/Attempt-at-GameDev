class_name Interactable
extends Area2D
## Anything the player can press Interact on (NPCs, signs, benches, level entrances).
## Works in both the overworld and the platformer: the player keeps a list of nearby
## Interactables and calls `interact()` on the closest one.

signal interacted(interactable: Interactable)

@export var prompt := "Talk"
var enabled := true
## Optional callable run on interact (alternative to connecting the signal).
var on_interact: Callable


static func create(size: Vector2, prompt_text: String, callback: Callable = Callable()) -> Interactable:
	var it := Interactable.new()
	it.prompt = prompt_text
	it.on_interact = callback
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	it.add_child(shape)
	return it


func _ready() -> void:
	collision_layer = 16  # triggers
	collision_mask = 4  # player
	monitorable = false
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
	if body.has_method("add_interactable"):
		body.add_interactable(self)


func _on_exit(body: Node) -> void:
	if body.has_method("remove_interactable"):
		body.remove_interactable(self)


func interact(by: Node) -> void:
	if not enabled:
		return
	interacted.emit(self)
	if on_interact.is_valid():
		on_interact.call(by)
