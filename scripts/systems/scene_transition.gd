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

## RIDENET travel: a short synthwave drive interstitial, then the normal
## fade transition. Skippable with any key. Used for street-to-street rides.
var _ride_layer: CanvasLayer
var _ride_skip := false

const DRIVER_LINES := [
	"driver: 'crazy night out there. saw a drone drop a package on 5th.'",
	"driver: 'you hear about Nexus Bank? something about a stable coin...'",
	"driver: 'this city never sleeps. neither do the corps.'",
	"driver: 'they're putting chips in the burgers now. flavor chips. still creepy.'",
	"driver: 'ghost, right? hop in.'",
]

func ride_to(target_scene_id: String, spawn_id: String, dest_label: String) -> void:
	if _busy:
		return
	_busy = true
	_ride_skip = false
	_ride_layer = CanvasLayer.new()
	_ride_layer.layer = 95
	add_child(_ride_layer)
	var drive := _DriveView.new()
	drive.dest_label = dest_label
	drive.driver_line = DRIVER_LINES[randi() % DRIVER_LINES.size()]
	drive.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ride_layer.add_child(drive)
	var t := 0.0
	while t < 2.6 and not _ride_skip:
		await get_tree().process_frame
		t += get_process_delta_time()
	_ride_layer.queue_free()
	_ride_layer = null
	_busy = false
	go(target_scene_id, spawn_id)

func _unhandled_input(event: InputEvent) -> void:
	if _ride_layer != null and (event is InputEventKey or event is InputEventMouseButton) 			and event.pressed:
		_ride_skip = true

class _DriveView extends Control:
	var dest_label := ""
	var driver_line := ""
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		# Night drive: sky band, horizon glow, road rushing past
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.005, 0.03), true)
		var horizon := size.y * 0.42
		draw_rect(Rect2(Vector2(0, horizon - 3), Vector2(size.x, 5)),
			Color(0.9, 0.2, 0.7, 0.5), true)
		# City silhouettes sliding by
		var off := fposmod(_t * 320.0, 220.0)
		var bx := -off
		var i := 0
		while bx < size.x + 220.0:
			var h := 60.0 + fposmod(float(i) * 73.0, 130.0)
			draw_rect(Rect2(Vector2(bx, horizon - h), Vector2(90.0, h)),
				Color(0.05, 0.04, 0.10), true)
			var wy := horizon - h + 12.0
			while wy < horizon - 10.0:
				if int(bx * 0.3 + wy * 0.7) % 3 == 0:
					draw_rect(Rect2(Vector2(bx + 14.0 + fposmod(wy, 40.0), wy),
						Vector2(7, 9)), Color(1.2, 0.9, 0.4, 0.8), true)
				wy += 22.0
			bx += 110.0 + fposmod(float(i) * 37.0, 90.0)
			i += 1
		# Road
		draw_rect(Rect2(Vector2(0, horizon), Vector2(size.x, size.y - horizon)),
			Color(0.03, 0.03, 0.045), true)
		var dash_off := fposmod(_t * 900.0, 140.0)
		var dx := -dash_off
		while dx < size.x + 140.0:
			draw_rect(Rect2(Vector2(dx, size.y * 0.74), Vector2(70, 8)),
				Color(1.3, 1.0, 0.2), true)
			dx += 140.0
		# Dash silhouette
		draw_rect(Rect2(Vector2(0, size.y * 0.86), Vector2(size.x, size.y * 0.14)),
			Color(0.02, 0.02, 0.03), true)
		draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 160, size.y * 0.16),
			"RIDENET  →  " + dest_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
			Color(0.3, 1.1, 1.2))
		draw_string(ThemeDB.fallback_font, Vector2(60, size.y * 0.94),
			driver_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.75, 0.8))
		draw_string(ThemeDB.fallback_font, Vector2(size.x - 220, size.y * 0.94),
			"any key to skip", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.5, 0.55))

func _fade_to(target_alpha: float, dur: float) -> void:
	if _fade == null:
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", target_alpha, dur)
	await tw.finished
