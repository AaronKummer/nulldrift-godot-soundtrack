extends Node

## Interaction — autoload. One global prompt system.
##
## Scenes register interactable nodes via `register(id, position, radius, prompt,
## action)` and the manager:
##   - tracks the player (set via `set_player`)
##   - shows the closest in-range prompt as a CanvasLayer label
##   - on "interact" action, emits `interacted(id, action_data)`
##
## Mirrors hacking-game's InteractionManager.js (the floating prompt + on-press).

signal interacted(id: String, action_data: Dictionary)

class InteractZone:
	var id: String
	var position: Vector3
	var radius: float
	var prompt: String
	var action_data: Dictionary  # arbitrary payload e.g. {"action": "exit_scene", "target": "city"}

var _zones: Array[InteractZone] = []
var _player: Node3D
var _layer: CanvasLayer
var _label: Label
var _active_zone: InteractZone

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = -240
	_label.offset_right = 240
	_label.offset_top = -110
	_label.offset_bottom = -78
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible = false
	_layer.add_child(_label)
	process_mode = Node.PROCESS_MODE_ALWAYS

func clear_zones() -> void:
	_zones.clear()
	_active_zone = null
	_label.visible = false

func register(id: String, position: Vector3, radius: float, prompt: String,
		action_data: Dictionary) -> void:
	var z := InteractZone.new()
	z.id = id
	z.position = position
	z.radius = radius
	z.prompt = prompt
	z.action_data = action_data
	_zones.append(z)

func set_player(player: Node3D) -> void:
	_player = player

func _process(_delta: float) -> void:
	if _player == null:
		_label.visible = false
		return
	var p_pos := _player.global_position
	var closest: InteractZone = null
	var closest_d2 := INF
	for z in _zones:
		var d2 := p_pos.distance_squared_to(z.position)
		if d2 <= z.radius * z.radius and d2 < closest_d2:
			closest = z
			closest_d2 = d2
	_active_zone = closest
	if closest != null:
		_label.text = closest.prompt
		_label.visible = true
	else:
		_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if _active_zone == null:
		return
	if event.is_action_pressed("interact"):
		interacted.emit(_active_zone.id, _active_zone.action_data)
		get_viewport().set_input_as_handled()
