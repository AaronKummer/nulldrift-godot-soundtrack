## Hallway — hotel-style corridor connecting apartments to balcony + elevator.
##
## Data-driven: door layout comes from `data/scene_graph.gd` so adding more
## floors or rooms is one entry in the SceneGraph dict.
##
## Visual goal: dramatic cyberpunk corridor — heavy fog, flickering fluorescent
## ceiling lights, emissive door-panel room-number readouts, runway-strip
## emissive accent down the carpet. Reads as "you're in act 1, walking out of
## your shitty hotel apartment toward the elevator down to the street."
extends Node3D

const SceneGraphData := preload("res://data/scene_graph.gd")
const InteractableDoorScript := preload("res://scripts/systems/interactable_door.gd")
const AnimatedBillboardScript := preload("res://scripts/systems/animated_billboard.gd")

# Corridor runs along +X. West end (-X) is the balcony, east end (+X) is the
# elevator. Player apartment 404 is on the south wall near center.
const HALL_LEN := 36.0   # length along X (west ↔ east)
const HALL_W   := 5.5    # width along Z (north ↔ south)
const HALL_H   := 3.6
const WALL_T   := 0.4

const CAMERA_OFFSET := Vector3(20, 22, 20)
const CAMERA_FOLLOW_LERP := 6.0

# Door layout for this scene id. Order = visual ordering along the corridor.
# Each entry: door_id (matches scene_graph), x position, side ("N"|"S"|"W"|"E").
const DOOR_LAYOUT := [
	{ "id": "apt_401", "x": -10.0, "side": "N" },
	{ "id": "apt_402", "x":  -5.0, "side": "S" },
	{ "id": "apt_403", "x":   0.0, "side": "N" },
	{ "id": "apt_404", "x":   5.0, "side": "S" },   # player's door
	{ "id": "apt_405", "x":  10.0, "side": "N" },
	{ "id": "apt_406", "x":  15.0, "side": "S" },
]

# Per-door color theme so the player can tell them apart at a glance.
const DOOR_COLORS := {
	"apt_404":    Color(0.0, 1.0, 1.0),    # cyan — YOUR room
	"apt_401":    Color(0.55, 0.10, 0.10), # locked red
	"apt_402":    Color(0.55, 0.10, 0.10),
	"apt_403":    Color(0.55, 0.10, 0.10),
	"apt_405":    Color(0.55, 0.10, 0.10),
	"apt_406":    Color(0.55, 0.10, 0.10),
	"balcony_door": Color(1.0, 0.35, 0.8), # magenta — open air
	"elevator":   Color(1.0, 0.85, 0.10),  # yellow — way out
}

var _camera: Camera3D
var _env: Environment
var _player: CharacterBody3D
var _player_anim
var _door_areas: Array[InteractableDoorScript] = []
var _flicker_lamps: Array[OmniLight3D] = []
var _flicker_t: float = 0.0
var _status_label: Label
var _near_door: InteractableDoorScript = null


func _ready() -> void:
	_setup_camera()
	_setup_environment()
	_build_floor_and_walls()
	_build_doors()
	_build_endcaps()
	_build_ceiling_lights()
	_build_player()
	_build_hud()
	_apply_pending_spawn()
	Music.play_category("apartment")  # reuse mood until hallway track exists


# ─────────────────────────────────────────────────────────────────────────
# CAMERA + ENVIRONMENT (mirrors apartment style, tuned for corridor)
# ─────────────────────────────────────────────────────────────────────────

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 18.0
	_camera.current = true
	add_child(_camera)
	_camera.position = CAMERA_OFFSET
	_camera.look_at(Vector3.ZERO, Vector3.UP)

func _setup_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.005, 0.005, 0.008)

	# Bloom — door panels and ceiling LEDs pop
	_env.glow_enabled = true
	_env.glow_intensity = 0.9
	_env.glow_strength = 1.2
	_env.glow_bloom = 0.08
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_hdr_threshold = 1.0
	_env.set("glow_levels/2", true)
	_env.set("glow_levels/4", true)
	_env.set("glow_levels/6", true)

	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 1.0

	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.10, 0.09, 0.14)
	_env.ambient_light_energy = 0.6

	_env.ssao_enabled = true
	_env.ssao_intensity = 1.2
	_env.ssao_radius = 1.0

	# Heavy fog — the corridor should feel long and atmospheric.
	_env.fog_enabled = true
	_env.fog_density = 0.025
	_env.fog_light_color = Color(0.05, 0.04, 0.10)
	_env.fog_light_energy = 0.6
	_env.fog_aerial_perspective = 0.5

	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)


# ─────────────────────────────────────────────────────────────────────────
# FLOOR + WALLS — carpet w/ emissive strip, dark grimy walls
# ─────────────────────────────────────────────────────────────────────────

func _build_floor_and_walls() -> void:
	# Carpet floor — slightly warm, low roughness so the strip reflects
	_add_box(Vector3(0, -0.05, 0), Vector3(HALL_LEN, 0.1, HALL_W),
		Color(0.10, 0.07, 0.08), 0.0, 0.85)

	# Emissive runway strip down the center — pulls the eye along the hall.
	_add_box(Vector3(0, 0.005, 0), Vector3(HALL_LEN - 1.0, 0.012, 0.18),
		Color(0.0, 0.6, 0.8), 0.6, 0.2,
		true, Color(0.0, 1.0, 1.2), 2.5)

	# Walls — north + south long sides, plus end caps
	_add_box(Vector3(0, HALL_H / 2.0, -HALL_W / 2.0),
		Vector3(HALL_LEN, HALL_H, WALL_T), Color(0.13, 0.11, 0.16))
	_add_box(Vector3(0, HALL_H / 2.0, HALL_W / 2.0),
		Vector3(HALL_LEN, HALL_H, WALL_T), Color(0.11, 0.10, 0.14))
	# West cap (balcony end)
	_add_box(Vector3(-HALL_LEN / 2.0, HALL_H / 2.0, 0),
		Vector3(WALL_T, HALL_H, HALL_W), Color(0.10, 0.10, 0.13))
	# East cap (elevator end)
	_add_box(Vector3(HALL_LEN / 2.0, HALL_H / 2.0, 0),
		Vector3(WALL_T, HALL_H, HALL_W), Color(0.10, 0.10, 0.13))

	# No solid ceiling — iso camera looks down from above, a ceiling box
	# would occlude the entire corridor. Ceiling lamps stay as floating
	# emissive fixtures and still light the floor.

	# Subtle baseboard accent on both long walls — thin glowing trim
	for z in [-HALL_W / 2.0 + WALL_T / 2.0 + 0.01,
			   HALL_W / 2.0 - WALL_T / 2.0 - 0.01]:
		_add_box(Vector3(0, 0.06, z), Vector3(HALL_LEN - 0.5, 0.04, 0.03),
			Color(0.4, 0.1, 0.3), 0.0, 0.3,
			true, Color(0.6, 0.05, 0.4), 1.4)


# ─────────────────────────────────────────────────────────────────────────
# DOORS — built from DOOR_LAYOUT + DOOR_COLORS + scene_graph data
# ─────────────────────────────────────────────────────────────────────────

func _build_doors() -> void:
	for d in DOOR_LAYOUT:
		_build_door(d.id, d.x, d.side)

func _build_door(door_id: String, x: float, side: String) -> void:
	# Side N = -Z wall (door panel faces +Z into corridor)
	var wall_z: float
	var into_hall_z: float
	if side == "N":
		wall_z = -HALL_W / 2.0 + WALL_T / 2.0 + 0.02
		into_hall_z = 1.2
	else:  # S
		wall_z = HALL_W / 2.0 - WALL_T / 2.0 - 0.02
		into_hall_z = -1.2
	var color: Color = DOOR_COLORS.get(door_id, Color(0.5, 0.5, 0.5))

	# Door is a recessed neon-framed alcove. The panel itself glows softly
	# in the room's color so each door reads as a beacon from across the
	# corridor under the iso camera.
	var z_off := 0.06 if side == "S" else -0.06

	# Glowing door panel — soft color wash on a darker base
	_add_box(Vector3(x, 1.25, wall_z + z_off * 0.4),
		Vector3(1.5, 2.5, 0.06),
		color * Color(0.20, 0.20, 0.20, 1.0), 0.0, 0.3,
		true, color, 1.8)
	# Inner darker pane so the panel has interior depth
	_add_box(Vector3(x, 1.25, wall_z + z_off * 0.8),
		Vector3(1.0, 2.0, 0.02),
		Color(0.04, 0.04, 0.06), 0.0, 0.6)

	# Hot neon frame — bright tube outlining the doorway
	for fy in [0.05, 2.45]:
		_add_box(Vector3(x, fy, wall_z + z_off),
			Vector3(1.7, 0.06, 0.04),
			color * Color(0.4, 0.4, 0.4, 1.0), 0.0, 0.2,
			true, color, 4.5)
	for fx in [-0.85, 0.85]:
		_add_box(Vector3(x + fx, 1.25, wall_z + z_off),
			Vector3(0.06, 2.5, 0.04),
			color * Color(0.4, 0.4, 0.4, 1.0), 0.0, 0.2,
			true, color, 4.5)

	# Room-number readout — sign hung above the door
	_add_box(Vector3(x, 2.75, wall_z + z_off * 1.3),
		Vector3(0.55, 0.22, 0.05),
		Color(0.02, 0.02, 0.04), 0.0, 0.2,
		true, color, 6.0)
	# Floor pool — colored light spill in front of door so the iso view
	# reads each entry from the floor too.
	var pool := OmniLight3D.new()
	pool.position = Vector3(x, 0.6, wall_z + (1.5 if side == "S" else -1.5))
	pool.light_color = color
	pool.light_energy = 1.8
	pool.omni_range = 2.0
	pool.omni_attenuation = 1.8
	add_child(pool)

	# Door handle
	var handle_offset := -0.35 if side == "N" else 0.35
	_add_box(Vector3(x + handle_offset, 1.15, wall_z + z_off),
		Vector3(0.06, 0.18, 0.05), Color(0.7, 0.7, 0.75), 0.85, 0.2,
		true, color, 1.0)

	# Interactable trigger — built via the reusable component
	var door := InteractableDoorScript.new()
	door.scene_id = "hallway"
	door.door_id = door_id
	door.position = Vector3(x, 1.0, wall_z + into_hall_z * 0.7)
	door.auto_collision_size = Vector3(1.8, 2.4, 1.6)
	door.player_entered.connect(func(): _on_door_near(door))
	door.player_exited.connect(func(): _on_door_far(door))
	door.locked_attempted.connect(func(label): _set_status("[ " + label + " ]"))
	add_child(door)
	_door_areas.append(door)

	# Spawn marker for return-from-this-target trips
	# (e.g. coming back from apartment lands at "from_apt_404")
	if door_id == "apt_404":
		var m := Node3D.new()
		m.name = "from_apt_404"
		m.position = Vector3(x, 0.0, wall_z + into_hall_z * 0.6)
		add_child(m)

func _on_door_near(d: InteractableDoorScript) -> void:
	_near_door = d
	_set_status("[E] " + d.label())

func _on_door_far(d: InteractableDoorScript) -> void:
	if _near_door == d:
		_near_door = null
		_set_status("")


# ─────────────────────────────────────────────────────────────────────────
# END CAPS — balcony door (west) and elevator (east)
# ─────────────────────────────────────────────────────────────────────────

func _build_endcaps() -> void:
	# Balcony door — west end, glass-panel feel, magenta sky beyond
	var bx: float = -HALL_LEN / 2.0 + WALL_T / 2.0 + 0.05
	_add_box(Vector3(bx, 1.3, 0),
		Vector3(0.06, 2.6, 2.6), Color(0.05, 0.04, 0.10), 0.4, 0.3,
		true, Color(0.8, 0.1, 0.5), 0.6)
	# Frame
	_add_box(Vector3(bx, 0.05, 0), Vector3(0.10, 0.10, 3.0),
		Color(0.18, 0.16, 0.22), 0.6, 0.4)
	_add_box(Vector3(bx, 2.6, 0), Vector3(0.10, 0.10, 3.0),
		Color(0.18, 0.16, 0.22), 0.6, 0.4)
	# Sky-glow lamp behind to suggest open air beyond
	var sky := OmniLight3D.new()
	sky.position = Vector3(bx - 1.5, 1.8, 0)
	sky.light_color = Color(0.9, 0.4, 0.8)
	sky.light_energy = 4.0
	sky.omni_range = 5.0
	sky.omni_attenuation = 1.4
	add_child(sky)

	var balcony_door := InteractableDoorScript.new()
	balcony_door.scene_id = "hallway"
	balcony_door.door_id = "balcony_door"
	balcony_door.position = Vector3(bx + 1.0, 1.0, 0)
	balcony_door.auto_collision_size = Vector3(2.0, 2.4, 2.4)
	balcony_door.player_entered.connect(func(): _on_door_near(balcony_door))
	balcony_door.player_exited.connect(func(): _on_door_far(balcony_door))
	add_child(balcony_door)
	_door_areas.append(balcony_door)

	# Marker for return from balcony
	var bm := Node3D.new()
	bm.name = "from_balcony"
	bm.position = Vector3(bx + 1.8, 0.0, 0)
	add_child(bm)

	# Elevator — east end, recessed alcove with sliding-door look
	var ex: float = HALL_LEN / 2.0 - WALL_T / 2.0 - 0.05
	_add_box(Vector3(ex, 1.3, 0),
		Vector3(0.06, 2.6, 2.4), Color(0.08, 0.07, 0.10), 0.8, 0.2)
	# Two sliding panels — vertical seam in middle
	_add_box(Vector3(ex - 0.04, 1.3, -0.6),
		Vector3(0.04, 2.5, 1.1), Color(0.16, 0.16, 0.20), 0.9, 0.15)
	_add_box(Vector3(ex - 0.04, 1.3, 0.6),
		Vector3(0.04, 2.5, 1.1), Color(0.16, 0.16, 0.20), 0.9, 0.15)
	# Call button + floor indicator (yellow LED above)
	_add_box(Vector3(ex - 0.08, 1.3, -1.45), Vector3(0.04, 0.18, 0.10),
		Color(0.5, 0.4, 0.1), 0.0, 0.3, true, Color(1.0, 0.85, 0.1), 2.5)
	_add_box(Vector3(ex - 0.05, 2.75, 0), Vector3(0.04, 0.16, 0.5),
		Color(0.3, 0.25, 0.05), 0.0, 0.3, true, Color(1.0, 0.85, 0.1), 2.0)

	var elev_door := InteractableDoorScript.new()
	elev_door.scene_id = "hallway"
	elev_door.door_id = "elevator"
	elev_door.position = Vector3(ex - 1.0, 1.0, 0)
	elev_door.auto_collision_size = Vector3(2.0, 2.4, 2.4)
	elev_door.player_entered.connect(func(): _on_door_near(elev_door))
	elev_door.player_exited.connect(func(): _on_door_far(elev_door))
	add_child(elev_door)
	_door_areas.append(elev_door)

	# Marker for return from elevator
	var em := Node3D.new()
	em.name = "from_elevator"
	em.position = Vector3(ex - 1.8, 0.0, 0)
	add_child(em)


# ─────────────────────────────────────────────────────────────────────────
# CEILING LIGHTS — fluorescent fixtures with subtle flicker
# ─────────────────────────────────────────────────────────────────────────

func _build_ceiling_lights() -> void:
	var count := 6
	for i in count:
		var t := (float(i) + 0.5) / float(count)
		var x := lerpf(-HALL_LEN / 2.0 + 2.0, HALL_LEN / 2.0 - 2.0, t)
		# Fixture housing — slim white emissive plane
		_add_box(Vector3(x, HALL_H - 0.05, 0),
			Vector3(2.0, 0.04, 0.4), Color(0.85, 0.88, 0.95), 0.4, 0.2,
			true, Color(0.9, 0.93, 1.0), 3.0)
		# Light source
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(x, HALL_H - 0.4, 0)
		lamp.light_color = Color(0.85, 0.90, 1.0)
		lamp.light_energy = 4.5
		lamp.omni_range = 7.0
		lamp.omni_attenuation = 1.6
		add_child(lamp)
		# A couple flicker; rest stay steady
		if i == 1 or i == 4:
			_flicker_lamps.append(lamp)


# ─────────────────────────────────────────────────────────────────────────
# PLAYER + HUD + spawn marker
# ─────────────────────────────────────────────────────────────────────────

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.position = Vector3(5.0, 0.85, 0)  # near 404 by default
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
	title.text = "HOTEL HALLWAY · FLOOR 4"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 1.0))
	title.position = Vector2(24, 18)
	cl.add_child(title)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_status_label.position = Vector2(24, 40)
	cl.add_child(_status_label)

	var hint := Label.new()
	hint.text = "WASD MOVE · R SPRINT · E INTERACT · P PHONE"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hint.anchor_left = 0.0
	hint.anchor_bottom = 1.0
	hint.anchor_top = 1.0
	hint.offset_left = 24
	hint.offset_top = -24
	hint.offset_bottom = -8
	cl.add_child(hint)

func _set_status(txt: String) -> void:
	if _status_label:
		_status_label.text = txt

func _apply_pending_spawn() -> void:
	var spawn: String = SceneTransition.consume_spawn()
	if spawn == "" or _player == null:
		return
	var marker := find_child(spawn, true, false)
	if marker and marker is Node3D:
		_player.global_position = (marker as Node3D).global_position + Vector3(0, 0.85, 0)


# ─────────────────────────────────────────────────────────────────────────
# MOVEMENT + camera follow (iso projection — matches apartment.gd)
# ─────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_tick_player(delta)
	_tick_camera(delta)
	_tick_flicker(delta)

func _tick_player(delta: float) -> void:
	if _player == null:
		return
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down"),
	)
	var speed := 4.5
	if Input.is_action_pressed("sprint"):
		speed *= 1.7
	# Iso projection: screen input → world XZ on a 45° axis (matches apartment).
	var inv_sqrt2 := 1.0 / sqrt(2.0)
	var world_dir := Vector3(input.x + input.y, 0, -input.x + input.y) * inv_sqrt2
	_player.velocity.x = world_dir.x * speed
	_player.velocity.z = world_dir.z * speed
	_player.velocity.y = 0.0
	_player.move_and_slide()
	if _player_anim:
		_player_anim.update_facing_from_input(input)
		_player_anim.set_moving(input.length() > 0.1)

func _tick_camera(_delta: float) -> void:
	if _camera == null or _player == null:
		return
	var target := _player.global_position + CAMERA_OFFSET
	_camera.global_position = _camera.global_position.lerp(target,
		clampf(_delta * CAMERA_FOLLOW_LERP, 0.0, 1.0))

func _tick_flicker(_delta: float) -> void:
	_flicker_t += _delta
	for lamp in _flicker_lamps:
		# Cheap fluorescent flicker — 90% time on, occasional dim/restrike.
		var n := sin(_flicker_t * 17.0 + lamp.get_instance_id() * 0.1)
		var r := randf()
		if r > 0.985:
			lamp.light_energy = lerpf(0.5, 4.5, randf())
		elif n > 0.85:
			lamp.light_energy = 4.0
		else:
			lamp.light_energy = 4.5


# ─────────────────────────────────────────────────────────────────────────
# Mesh + collision helpers (mirrors apartment.gd _add_box)
# ─────────────────────────────────────────────────────────────────────────

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone_toggle"):
		Phone.toggle()
	elif event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/title.tscn")
