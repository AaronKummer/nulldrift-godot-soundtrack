## SceneTransition — autoload. Wraps scene swaps with a fade-to-black and a
## named-spawn-marker protocol.
##
## Caller flow:
##     SceneTransition.go("hallway", "from_apt_404")
##
## Target scene's flow (in _ready()):
##     var spawn := SceneTransition.consume_spawn()
##     if spawn != "" and _player:
##         var marker := find_child(spawn, true, false)
##         if marker:
##             _player.global_position = marker.global_position
##
## Spawn markers are just Node3D children with the matching name. Convention:
## name them "from_<origin>" so it's obvious what door delivered the player.
extends CanvasLayer

const SceneGraphData := preload("res://data/scene_graph.gd")
const FADE_OUT_S := 0.35
const FADE_IN_S := 0.35

var _fade: ColorRect
var _pending_spawn: String = ""
var _busy: bool = false

func _ready() -> void:
	layer = 100  # stays on top of everything
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.z_index = 4096
	add_child(_fade)

## Transition to a scene by graph id, depositing the player at a named marker.
func go(target_scene_id: String, spawn_id: String) -> void:
	if _busy:
		return
	var path: String = SceneGraphData.path_of(target_scene_id)
	if path == "":
		push_error("SceneTransition.go: unknown scene '%s'" % target_scene_id)
		return
	_busy = true
	_pending_spawn = spawn_id
	await _fade_to(1.0, FADE_OUT_S)
	get_tree().change_scene_to_file(path)
	# Give the new scene a frame to build itself + read the spawn marker.
	await get_tree().process_frame
	await _fade_to(0.0, FADE_IN_S)
	_busy = false

## Target scene calls this in _ready() to retrieve and clear the pending
## spawn marker name. Returns "" if none pending.
func consume_spawn() -> String:
	var s := _pending_spawn
	_pending_spawn = ""
	return s

func _fade_to(target_alpha: float, dur: float) -> void:
	if _fade == null:
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", target_alpha, dur)
	await tw.finished
