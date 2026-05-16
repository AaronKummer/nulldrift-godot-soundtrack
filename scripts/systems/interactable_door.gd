## InteractableDoor — drop-in Area3D component for scene transitions.
##
## Wire it up:
##     var d := InteractableDoor.new()
##     d.scene_id = "hallway"               # current scene id (for label lookup)
##     d.door_id  = "main_door"             # matches scene_graph.gd door entry
##     d.position = Vector3(...)
##     add_child(d)
##
## On collision with the player body + 'interact' action, the door reads its
## target from `data/scene_graph.gd` and calls `SceneTransition.go(...)`. If
## the door is marked locked in the graph, it fires `locked_attempted` instead.
class_name InteractableDoor
extends Area3D

const SceneGraphData := preload("res://data/scene_graph.gd")

signal player_entered
signal player_exited
signal locked_attempted(label: String)

@export var scene_id: String = ""
@export var door_id: String = ""
## Optional shape — caller can attach their own CollisionShape3D instead.
@export var auto_collision_size: Vector3 = Vector3(1.6, 2.0, 1.6)

var _on_door: bool = false
var _entry: Dictionary = {}

func _ready() -> void:
	monitoring = true
	monitorable = false
	# Auto-add a default collision shape if the caller didn't provide one.
	var has_shape := false
	for c in get_children():
		if c is CollisionShape3D:
			has_shape = true
			break
	if not has_shape:
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = auto_collision_size
		col.shape = box
		add_child(col)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Cache the data-graph entry once
	for d in SceneGraphData.doors_for(scene_id):
		if d.get("id", "") == door_id:
			_entry = d
			break

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		_on_door = true
		player_entered.emit()

func _on_body_exited(body: Node3D) -> void:
	if body is CharacterBody3D:
		_on_door = false
		player_exited.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not _on_door:
		return
	if not event.is_action_pressed("interact"):
		return
	if _entry.is_empty():
		push_warning("InteractableDoor: no scene_graph entry for %s/%s" % [scene_id, door_id])
		return
	if _entry.get("locked", false) or _entry.get("target", null) == null:
		locked_attempted.emit(_entry.get("label", "locked"))
		return
	SceneTransition.go(_entry["target"], _entry.get("spawn", ""))

## Convenience: what to show in the prompt UI when player is near.
func label() -> String:
	return _entry.get("label", door_id)
