## InteriorBase — shared plumbing for enterable shop interiors (bar, diner,
## comics...). Same philosophy as StreetBase: subclass, implement
## _build_interior(), get camera/env/player/HUD/interacts/exit for free.
##
## Iso room in the apartment/arcade visual language. Exits return to the
## street scene named by `exit_scene` at marker `exit_spawn`.
extends Node3D

const AnimatedBillboardScript := preload("res://scripts/systems/animated_billboard.gd")
const DoorGlowScript := preload("res://scripts/systems/door_glow.gd")

var room_w := 30.0
var room_d := 20.0
var room_h := 4.6
var exit_scene := "city"
var exit_spawn := "from_bar"
var interior_name := "???"

const WALL_T := 0.4
const WALK_SPEED := 7.0
const SPRINT_MULT := 1.7

var _camera: Camera3D
var _player: CharacterBody3D
var _player_anim
var _status_label: Label
var _near_zone: Dictionary = {}
var _menu_open := false          # subclass overlays set this to eat input

func _ready() -> void:
	_setup_camera()
	_setup_environment()
	_build_room_shell()
	_build_interior()
	_build_exit()
	_build_player()
	_build_hud()
	SceneTransition.consume_spawn()

## Subclass hooks
func _build_interior() -> void:
	pass

func _ambient() -> Color:
	return Color(0.30, 0.24, 0.20)

func _wall_color() -> Color:
	return Color(0.16, 0.13, 0.15)

func _floor_color() -> Color:
	return Color(0.15, 0.11, 0.10)

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = maxf(room_w, room_d) * 0.72
	_camera.position = Vector3(room_w * 0.45, room_w * 0.5, room_w * 0.45)
	_camera.current = true
	add_child(_camera)
	_camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.003, 0.006)
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.1
	env.glow_bloom = 0.06
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	env.set("glow_levels/2", true)
	env.set("glow_levels/4", true)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _ambient()
	env.ambient_light_energy = 0.85
	env.ssao_enabled = true
	env.ssao_intensity = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Interior key light — warm overhead so the room never goes black
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.9, 0.75)
	key.light_energy = 0.5
	key.rotation_degrees = Vector3(-60, -25, 0)
	add_child(key)

func _build_room_shell() -> void:
	_add_box(Vector3(0, -0.05, 0), Vector3(room_w, 0.1, room_d),
		_floor_color(), 0.0, 0.8)
	# Back (-z) and west (-x) walls visible; near walls collision-only
	_add_box(Vector3(0, room_h / 2.0, -room_d / 2.0),
		Vector3(room_w, room_h, WALL_T), _wall_color())
	_add_box(Vector3(-room_w / 2.0, room_h / 2.0, 0),
		Vector3(WALL_T, room_h, room_d), _wall_color() * 0.9)
	for wall_def in [[Vector3(0, room_h / 2.0, room_d / 2.0), Vector3(room_w, room_h, WALL_T)],
			[Vector3(room_w / 2.0, room_h / 2.0, 0), Vector3(WALL_T, room_h, room_d)]]:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall_def[1]
		cs.shape = box
		body.position = wall_def[0]
		body.add_child(cs)
		add_child(body)

func _build_exit() -> void:
	# Door on the east wall, DoorGlow standard
	var dx := room_w / 2.0
	var dz := room_d * 0.2
	_add_box(Vector3(dx - 0.06, 1.4, dz), Vector3(0.10, 2.8, 1.8),
		Color(0.06, 0.05, 0.05), 0.4, 0.3, true, Color(1.0, 0.6, 0.2), 0.5)
	var glow := DoorGlowScript.new()
	glow.color = Color(1.0, 0.6, 0.2)
	glow.opening = Vector2(1.8, 2.8)
	glow.position = Vector3(dx - 0.10, 0.0, dz)
	glow.rotation.y = PI / 2.0
	add_child(glow)
	add_interact(Vector3(dx - 1.2, 1.2, dz), Vector3(2.4, 2.4, 2.6),
		"back to the street", func():
			SceneTransition.go(exit_scene, exit_spawn))
	glow.set_active(true)

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.position = Vector3(room_w / 2.0 - 3.0, 0.85, room_d * 0.2)
	add_child(_player)
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.7
	col.shape = shape
	_player.add_child(col)
	_player_anim = AnimatedBillboardScript.new()
	_player_anim.pixel_size = 0.04
	_player_anim.position = Vector3(0, -0.85, 0)
	_player.add_child(_player_anim)
	_player_anim.load_sheet("res://assets/sprites/player-pizza.png")

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var title := Label.new()
	title.text = interior_name
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	title.position = Vector2(24, 18)
	cl.add_child(title)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_status_label.position = Vector2(24, 40)
	cl.add_child(_status_label)
	var hint := Label.new()
	hint.text = "WASD MOVE · SHIFT SNEAK · E INTERACT · I PHONE"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hint.anchor_left = 0.0
	hint.anchor_bottom = 1.0
	hint.anchor_top = 1.0
	hint.offset_left = 24
	hint.offset_top = -24
	hint.offset_bottom = -8
	cl.add_child(hint)

func _set_status(t: String) -> void:
	if _status_label:
		_status_label.text = t

func add_interact(pos: Vector3, size: Vector3, prompt: String,
		callback: Callable) -> void:
	var zone := { "prompt": prompt, "callback": callback }
	var area := Area3D.new()
	area.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(b):
		if b is CharacterBody3D:
			_near_zone = zone
			_set_status("[E] " + prompt))
	area.body_exited.connect(func(b):
		if b is CharacterBody3D and _near_zone == zone:
			_near_zone = {}
			_set_status(""))
	add_child(area)

func add_npc(sheet: String, pos: Vector3, facing: int = 0,
		tint: Color = Color(1, 1, 1)) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var ab = AnimatedBillboardScript.new()
	ab.show_floor_shadow = false
	ab.pixel_size = 0.04
	pivot.add_child(ab)
	ab.tint = tint
	ab.load_sheet(sheet)
	ab.facing = facing
	ab.set_moving(false)
	return pivot

func _physics_process(_delta: float) -> void:
	if _player == null or _menu_open:
		return
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up"))
	if input.length() > 1:
		input = input.normalized()
	var world_dir := Vector3(input.x + input.y, 0, -input.x + input.y) * (1.0 / sqrt(2.0))
	var speed := WALK_SPEED
	GameState.sneaking = Input.is_action_pressed("sneak")
	if GameState.sneaking:
		speed *= 0.5              # slow and quiet — guards fill their meter slower
	elif Input.is_action_pressed("sprint"):
		speed *= SPRINT_MULT
	_player.velocity = world_dir * speed
	_player.move_and_slide()
	if _player_anim:
		_player_anim.update_facing_from_input(input)
		_player_anim.set_moving(input.length_squared() > 0.01)

func _unhandled_input(event: InputEvent) -> void:
	if _menu_open or DialogueOverlay.is_active():
		return
	if event.is_action_pressed("interact") and not _near_zone.is_empty():
		_near_zone.callback.call()
	elif event.is_action_pressed("ui_cancel"):
		SceneTransition.go(exit_scene, exit_spawn)

func _add_box(pos: Vector3, sz: Vector3, col: Color,
		metallic: float = 0.0, roughness: float = 0.8,
		emissive: bool = false, emission: Color = Color.BLACK,
		emission_energy: float = 1.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metallic
	mat.roughness = roughness
	if emissive:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	mesh.material_override = mat
	body.add_child(mesh)
	var col_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	col_shape.shape = shape
	body.add_child(col_shape)
	add_child(body)
	return body
