extends Node3D

## ApartmentScene — Godot port of hacking-game/src/phaser/scenes/ApartmentScene.js
##
## Spacious one-room cyberpunk apartment.
## Layout (room is 52 × 36, camera looks from +x+z corner):
##   • Working corner (NE)   — desk + 2 monitors + chair + neon strip
##   • Kitchen (NW)          — counter + fridge + microwave (red LED)
##   • Cozy corner (SW)      — bed + nightstand + plant
##   • Lounge (SE)           — couch + TV + coffee table + floor lamp
## Plus center rug, ceiling lamps, far-wall window with rain + lightning.
##
## Dynamic content:
##   • TV cycles "channels" every ~3-6s with shifting emission color
##   • Computer CRT has scrolling green text + blinking cursor
##   • Rain falls across the window
##   • Lightning flashes every 8-18s, lighting the whole room briefly
##
## Controls:
##   WASD  — iso-projected movement
##   R     — sprint (held)
##   1-6   — select hotbar slot
##   E     — interact
##   ESC   — back to title

const AnimatedBillboardScript := preload("res://scripts/systems/animated_billboard.gd")

const ROOM_W := 52.0
const ROOM_D := 36.0
const ROOM_H := 5.5
const WALL_T := 0.4

const WALK_SPEED := 7.0
const SPRINT_MULT := 1.7

# Iso camera offset relative to the player (kept constant by the follow code)
const CAMERA_OFFSET := Vector3(26, 27, 26)
const CAMERA_FOLLOW_LERP := 6.0  # higher = snappier

# Dynamic refs
var _camera: Camera3D
var _player: CharacterBody3D
var _player_anim: Node3D
var _cat_anim: Node3D
var _cat_pivot: Node3D
var _cat_t := 0.0
var _cat_idle_dwell := 3.0
var _cat_target: Vector3
var _door_zone: Area3D
var _on_door := false
var _exiting := false

var _hotbar_slots: Array = []
var _hotbar_active := 1
var _hud_status: Label

# TV — cycling channels
var _tv_mat: StandardMaterial3D
var _tv_light: OmniLight3D
var _tv_channel := 0
var _tv_t := 0.0
var _tv_dwell := 3.0

# Computer CRT — scrolling text lines
var _crt_mat: StandardMaterial3D
var _crt_text_mat: StandardMaterial3D
var _crt_text_sprite: Sprite3D
var _crt_lines: PackedStringArray = [
	"> connecting to grid_node_07...",
	"> auth: ghost@nulldrift",
	"> 0x4f7a 0x1c92 0x8eff 0x002b",
	"> packet 17/24 ▒▒▒▒▒░░░░░",
	"> WARNING: trace probe detected",
	"> rerouting via /dev/shadow",
	"> handshake ack ✓",
	"> downloading payload_v3.bin",
	"> [######### ] 89%",
	"> connection stable",
	"> echo $WHO_AM_I",
	"> ghost",
	"> _",
]
var _crt_scroll := 0
var _crt_t := 0.0
var _crt_label: Label3D
var _crt_cursor_t := 0.0
var _crt_cursor_label: Label3D

# Rain — sprites falling down the window face
var _rain_drops: Array = []
const RAIN_COUNT := 40
const RAIN_FALL_SPEED := 4.0

# Lightning
var _lightning_light: DirectionalLight3D
var _lightning_window_mat: StandardMaterial3D
var _lightning_base_emission := 0.9
var _lightning_active := 0.0    # remaining seconds in current flash
var _lightning_pulse := 0.0     # 0..1 envelope
var _lightning_next := 6.0
var _env: Environment

# Window panel position (used by rain + lightning)
var _window_pos: Vector3
var _window_size := Vector2(8.0, 3.5)

func _ready() -> void:
	_setup_camera()
	_setup_environment()
	_build_room()
	_build_window()
	_build_working_corner()
	_build_kitchen()
	_build_cozy_corner()
	_build_lounge()
	_build_center_rug()
	_build_ceiling_lamps()
	_build_door()
	_build_player()
	_build_lightning()
	_build_hud()
	_apply_pending_spawn()
	Music.play_category("apartment")

func _apply_pending_spawn() -> void:
	var spawn: String = SceneTransition.consume_spawn()
	if spawn == "" or _player == null:
		return
	var marker := find_child(spawn, true, false)
	if marker and marker is Node3D:
		_player.global_position = (marker as Node3D).global_position + Vector3(0, 0.85, 0)

# ═══════════════════════════════════════════════════════════════════════
# CAMERA + ENVIRONMENT
# ═══════════════════════════════════════════════════════════════════════

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 32.0
	_camera.position = CAMERA_OFFSET + Vector3(0, 1, 0)
	_camera.current = true
	add_child(_camera)
	# Aim once — then NEVER call look_at again. For an iso camera the rotation
	# is fixed; if we keep look_at-ing each frame, tiny angle changes as the
	# player moves cause a sickening floor-slide effect.
	_camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)

func _setup_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.005, 0.005, 0.012)

	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	_env.glow_strength = 1.1
	_env.glow_bloom = 0.05
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_hdr_threshold = 1.2
	_env.set("glow_levels/2", true)
	_env.set("glow_levels/4", true)
	_env.set("glow_levels/6", true)

	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 1.0

	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.18, 0.16, 0.24)
	_env.ambient_light_energy = 1.2   # dim, cozy — lightning bumps this to ~2.8

	_env.ssao_enabled = true
	_env.ssao_intensity = 1.0
	_env.ssao_radius = 1.4

	_env.fog_enabled = true
	_env.fog_density = 0.004
	_env.fog_light_color = Color(0.04, 0.03, 0.08)

	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

# ═══════════════════════════════════════════════════════════════════════
# ROOM — floor + 4 walls (StaticBody3D for collision)
# ═══════════════════════════════════════════════════════════════════════

func _build_room() -> void:
	# Wider, slightly warmer floor
	_add_box(Vector3(0, -0.05, 0), Vector3(ROOM_W, 0.1, ROOM_D),
		Color(0.16, 0.12, 0.13), 0.0, 0.75)

	# Back wall (-z)
	_add_wall(Vector3(0, ROOM_H / 2.0, -ROOM_D / 2.0),
		Vector3(ROOM_W, ROOM_H, WALL_T), Color(0.18, 0.16, 0.22))
	# Front wall (+z) — darker, partial so iso reads inside clearly
	_add_wall(Vector3(0, ROOM_H / 2.0, ROOM_D / 2.0),
		Vector3(ROOM_W, ROOM_H, WALL_T), Color(0.1, 0.09, 0.13))
	# Left wall (-x)
	_add_wall(Vector3(-ROOM_W / 2.0, ROOM_H / 2.0, 0),
		Vector3(WALL_T, ROOM_H, ROOM_D), Color(0.18, 0.16, 0.22))
	# Right wall — split for door opening
	var door_z := ROOM_D / 5.0
	var gap := 2.0
	# Back half (-z of door)
	_add_wall(Vector3(ROOM_W / 2.0, ROOM_H / 2.0, (door_z - gap / 2.0 + -ROOM_D / 2.0) / 2.0),
		Vector3(WALL_T, ROOM_H, abs(door_z - gap / 2.0 + ROOM_D / 2.0)),
		Color(0.18, 0.16, 0.22))
	# Front half (+z of door)
	var south_len: float = (ROOM_D / 2.0) - (door_z + gap / 2.0)
	_add_wall(Vector3(ROOM_W / 2.0, ROOM_H / 2.0,
				door_z + gap / 2.0 + south_len / 2.0),
		Vector3(WALL_T, ROOM_H, south_len),
		Color(0.18, 0.16, 0.22))
	# Header above door
	_add_box(Vector3(ROOM_W / 2.0, ROOM_H - 0.65, door_z),
		Vector3(WALL_T, 1.2, gap), Color(0.07, 0.06, 0.09))

# ═══════════════════════════════════════════════════════════════════════
# WINDOW — emissive cityscape, rain, frame, sill
# ═══════════════════════════════════════════════════════════════════════

func _build_window() -> void:
	var wx := -6.0
	var wy := 3.0
	var wz := -ROOM_D / 2.0 + WALL_T / 2.0 + 0.02
	var ww := 8.0
	var wh := 3.5

	# Z-LAYERING (all thicknesses < gap to neighbour to avoid z-fighting):
	#   frame      : wz + 0.00   thick 0.04   →  -0.02 .. +0.02
	#   view panel : wz + 0.06   thick 0.02   →  +0.05 .. +0.07
	#   building dot: wz + 0.10  thick 0.01   →  +0.095.. +0.105
	#   mullions   : wz + 0.13   thick 0.02   →  +0.12 .. +0.14
	#   rain       : wz + 0.18   thick 0.01   →  +0.175.. +0.185

	# Frame (thin, hugging the wall)
	_add_box(Vector3(wx, wy, wz), Vector3(ww + 0.3, wh + 0.3, 0.04),
		Color(0.02, 0.02, 0.03), 0.4, 0.6)

	# View panel — emissive cool blue night sky
	var view_mat := StandardMaterial3D.new()
	view_mat.albedo_color = Color(0.02, 0.05, 0.12)
	view_mat.metallic = 0.0
	view_mat.roughness = 0.3
	view_mat.emission_enabled = true
	view_mat.emission = Color(0.15, 0.4, 0.95)
	view_mat.emission_energy_multiplier = _lightning_base_emission
	var view_mesh := BoxMesh.new()
	view_mesh.size = Vector3(ww, wh, 0.02)
	view_mesh.material = view_mat
	var view_mi := MeshInstance3D.new()
	view_mi.mesh = view_mesh
	view_mi.position = Vector3(wx, wy, wz + 0.06)
	add_child(view_mi)
	_lightning_window_mat = view_mat

	# Distant building lit windows — tiny emissive dots
	var window_colors := [
		Color(1.0, 0.0, 0.4),
		Color(0.0, 1.0, 1.0),
		Color(0.27, 1.0, 0.53),
		Color(1.0, 0.67, 0.0),
	]
	var rng := RandomNumberGenerator.new()
	rng.set_seed(7)
	for i in range(90):
		if rng.randf() >= 0.5:
			continue
		var bx := wx + rng.randf_range(-ww / 2.0 + 0.15, ww / 2.0 - 0.15)
		var by := wy + rng.randf_range(-wh / 2.0 + 0.15, wh / 2.0 - 0.15)
		var color: Color = window_colors[rng.randi() % window_colors.size()]
		_add_box(Vector3(bx, by, wz + 0.10), Vector3(0.12, 0.18, 0.01),
			color * 0.5, 0.0, 0.3, true, color, 4.0)

	# Window sill (in front of the frame so it juts inward)
	_add_box(Vector3(wx, wy - wh / 2.0 - 0.15, wz + 0.5),
		Vector3(ww + 0.5, 0.12, 0.8), Color(0.08, 0.06, 0.05), 0.0, 0.7)

	# Window mullion cross — gives the glass scale
	_add_box(Vector3(wx, wy, wz + 0.13), Vector3(ww, 0.05, 0.02),
		Color(0.04, 0.04, 0.05), 0.5, 0.4)
	_add_box(Vector3(wx, wy, wz + 0.13), Vector3(0.05, wh, 0.02),
		Color(0.04, 0.04, 0.05), 0.5, 0.4)

	_window_pos = Vector3(wx, wy, wz + 0.18)
	_window_size = Vector2(ww, wh)

	# Spill into room — cool blue
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.55, 1.0)
	light.light_energy = 1.6
	light.omni_range = 12.0
	light.omni_attenuation = 1.5
	light.position = Vector3(wx, wy, wz + 3.0)
	add_child(light)

	# Rain drops in front of the window pane
	_build_rain()

# ═══════════════════════════════════════════════════════════════════════
# RAIN — thin white sprites streaming down the window
# ═══════════════════════════════════════════════════════════════════════

func _build_rain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.set_seed(19)
	var drop_mat := StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.65, 0.78, 0.95)
	drop_mat.metallic = 0.0
	drop_mat.roughness = 0.1
	drop_mat.emission_enabled = true
	drop_mat.emission = Color(0.7, 0.85, 1.0)
	drop_mat.emission_energy_multiplier = 1.3
	for i in range(RAIN_COUNT):
		var drop := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.02, rng.randf_range(0.12, 0.24), 0.01)
		mesh.material = drop_mat
		drop.mesh = mesh
		drop.position = Vector3(
			_window_pos.x + rng.randf_range(-_window_size.x / 2.0, _window_size.x / 2.0),
			_window_pos.y + rng.randf_range(-_window_size.y / 2.0, _window_size.y / 2.0),
			_window_pos.z + 0.02)
		add_child(drop)
		_rain_drops.append({
			"node": drop,
			"speed": rng.randf_range(3.0, 5.5),
			"x_offset": drop.position.x,
		})

func _tick_rain(delta: float) -> void:
	for d in _rain_drops:
		var node: MeshInstance3D = d["node"]
		node.position.y -= d["speed"] * delta
		if node.position.y < _window_pos.y - _window_size.y / 2.0:
			node.position.y = _window_pos.y + _window_size.y / 2.0

# ═══════════════════════════════════════════════════════════════════════
# WORKING CORNER (NE: +x, -z) — desk + monitors + chair + neon strip
# ═══════════════════════════════════════════════════════════════════════

func _build_working_corner() -> void:
	var dx := ROOM_W / 2.0 - 5.5
	var dz := -ROOM_D / 2.0 + 2.0

	# Desk top
	_add_box(Vector3(dx, 0.9, dz), Vector3(7.5, 0.1, 2.0),
		Color(0.18, 0.13, 0.1), 0.0, 0.7)
	# Desk legs
	for off in [Vector3(-3.5, 0, -0.9), Vector3(3.5, 0, -0.9),
				Vector3(-3.5, 0, 0.9), Vector3(3.5, 0, 0.9)]:
		_add_box(Vector3(dx + off.x, 0.45, dz + off.z),
			Vector3(0.1, 0.9, 0.1), Color(0.05, 0.05, 0.06), 0.3, 0.6)

	# Left monitor — main CRT, animated text
	_add_box(Vector3(dx - 1.5, 1.0, dz), Vector3(0.9, 0.18, 0.9),
		Color(0.04, 0.04, 0.05), 0.5, 0.4)
	_add_box(Vector3(dx - 1.5, 1.85, dz), Vector3(2.2, 1.6, 0.55),
		Color(0.03, 0.03, 0.04), 0.5, 0.4)
	_crt_mat = StandardMaterial3D.new()
	_crt_mat.albedo_color = Color(0.0, 0.4, 0.18)
	_crt_mat.metallic = 0.0
	_crt_mat.roughness = 0.25
	_crt_mat.emission_enabled = true
	_crt_mat.emission = Color(0.0, 1.0, 0.5)
	_crt_mat.emission_energy_multiplier = 1.8
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(2.0, 1.4, 0.02)
	screen_mesh.material = _crt_mat
	var screen_mi := MeshInstance3D.new()
	screen_mi.mesh = screen_mesh
	screen_mi.position = Vector3(dx - 1.5, 1.85, dz + 0.29)
	add_child(screen_mi)

	# Scrolling text as a Label3D in front of the screen
	_crt_label = Label3D.new()
	_crt_label.text = ""
	_crt_label.font_size = 56
	_crt_label.outline_size = 0
	_crt_label.modulate = Color(0.5, 1.0, 0.6)
	_crt_label.no_depth_test = false
	_crt_label.fixed_size = false
	_crt_label.pixel_size = 0.008
	_crt_label.position = Vector3(dx - 1.5 - 0.85, 1.85 + 0.55, dz + 0.31)
	_crt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_crt_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_crt_label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	add_child(_crt_label)

	_crt_cursor_label = Label3D.new()
	_crt_cursor_label.text = "_"
	_crt_cursor_label.font_size = 56
	_crt_cursor_label.modulate = Color(0.6, 1.0, 0.6)
	_crt_cursor_label.pixel_size = 0.008
	_crt_cursor_label.position = Vector3(dx - 1.5 - 0.85, 1.85 - 0.55, dz + 0.31)
	add_child(_crt_cursor_label)

	# Right monitor — cyan terminal (static)
	_add_box(Vector3(dx + 1.5, 1.0, dz), Vector3(0.8, 0.18, 0.8),
		Color(0.04, 0.04, 0.05), 0.5, 0.4)
	_add_box(Vector3(dx + 1.5, 1.8, dz), Vector3(2.0, 1.4, 0.5),
		Color(0.03, 0.03, 0.04), 0.5, 0.4)
	_add_box(Vector3(dx + 1.5, 1.8, dz + 0.27), Vector3(1.8, 1.2, 0.02),
		Color(0.0, 0.3, 0.4), 0.0, 0.3,
		true, Color(0.0, 0.85, 1.0), 1.5)

	# Keyboard
	_add_box(Vector3(dx, 0.98, dz + 0.6), Vector3(2.2, 0.06, 0.45),
		Color(0.06, 0.06, 0.08), 0.3, 0.5)
	# Coffee mug
	_add_box(Vector3(dx + 0.9, 1.05, dz - 0.2), Vector3(0.22, 0.3, 0.22),
		Color(0.4, 0.18, 0.1), 0.1, 0.5)
	# Chair
	_add_box(Vector3(dx, 0.5, dz + 2.0), Vector3(1.1, 0.1, 1.1),
		Color(0.12, 0.05, 0.08), 0.2, 0.6)
	_add_box(Vector3(dx, 1.25, dz + 2.45), Vector3(1.1, 1.4, 0.1),
		Color(0.12, 0.05, 0.08), 0.2, 0.6)
	_add_box(Vector3(dx, 0.22, dz + 2.0), Vector3(0.1, 0.45, 0.1),
		Color(0.04, 0.04, 0.06), 0.5, 0.3)

	# Neon strip under desk
	_add_box(Vector3(dx, 0.05, dz - 0.85), Vector3(6.0, 0.05, 0.1),
		Color(1.0, 0.0, 0.4), 0.0, 0.5,
		true, Color(1.0, 0.0, 0.4), 4.0)

	# Spill lights
	var crt_light := OmniLight3D.new()
	crt_light.light_color = Color(0.0, 1.0, 0.53)
	crt_light.light_energy = 1.6
	crt_light.omni_range = 6.0
	crt_light.omni_attenuation = 1.7
	crt_light.position = Vector3(dx - 1.5, 1.85, dz + 1.0)
	add_child(crt_light)
	var cy := OmniLight3D.new()
	cy.light_color = Color(0.0, 0.85, 1.0)
	cy.light_energy = 1.1
	cy.omni_range = 5.0
	cy.omni_attenuation = 1.8
	cy.position = Vector3(dx + 1.5, 1.8, dz + 0.9)
	add_child(cy)
	var nk := OmniLight3D.new()
	nk.light_color = Color(1.0, 0.0, 0.4)
	nk.light_energy = 1.6
	nk.omni_range = 5.5
	nk.omni_attenuation = 1.5
	nk.position = Vector3(dx, 0.2, dz)
	add_child(nk)

	# Compute initial CRT lines
	_render_crt()

# ═══════════════════════════════════════════════════════════════════════
# KITCHEN (NW: -x, -z) — counter + fridge + microwave
# ═══════════════════════════════════════════════════════════════════════

func _build_kitchen() -> void:
	var kx := -ROOM_W / 2.0 + 3.0
	var kz := -ROOM_D / 2.0 + 2.5

	# Counter
	_add_box(Vector3(kx + 4.0, 0.9, kz), Vector3(10.0, 0.1, 1.8),
		Color(0.24, 0.22, 0.2), 0.0, 0.5)
	_add_box(Vector3(kx + 4.0, 0.45, kz), Vector3(10.0, 0.9, 1.6),
		Color(0.08, 0.07, 0.09), 0.0, 0.85)
	# Sink basin
	_add_box(Vector3(kx + 4.0, 0.96, kz), Vector3(1.4, 0.04, 1.0),
		Color(0.02, 0.02, 0.03), 0.6, 0.3)
	# Faucet
	_add_box(Vector3(kx + 4.0, 1.25, kz - 0.55), Vector3(0.08, 0.6, 0.08),
		Color(0.7, 0.7, 0.75), 0.7, 0.25)
	_add_box(Vector3(kx + 4.0, 1.5, kz - 0.35), Vector3(0.08, 0.08, 0.5),
		Color(0.7, 0.7, 0.75), 0.7, 0.25)

	# Fridge
	_add_box(Vector3(kx, 1.3, kz), Vector3(1.8, 2.6, 1.6),
		Color(0.85, 0.85, 0.9), 0.4, 0.35)
	_add_box(Vector3(kx + 0.93, 2.0, kz), Vector3(0.05, 0.7, 0.06),
		Color(0.6, 0.6, 0.7), 0.6, 0.2,
		true, Color(0.0, 1.0, 0.6), 1.4)
	# Fridge magnets
	for i in range(4):
		_add_box(Vector3(kx - 0.92, 1.5 + i * 0.3, kz + (0.4 - i * 0.15)),
			Vector3(0.04, 0.18, 0.18),
			Color(1.0 - i * 0.2, 0.4 + i * 0.1, 0.6), 0.0, 0.5)

	# Microwave
	_add_box(Vector3(kx + 7.5, 1.2, kz - 0.2), Vector3(1.3, 0.7, 0.9),
		Color(0.06, 0.06, 0.08), 0.4, 0.5)
	# Microwave clock — red LED
	_add_box(Vector3(kx + 7.5, 1.2, kz + 0.26), Vector3(0.7, 0.24, 0.01),
		Color(0.06, 0.0, 0.0), 0.0, 0.3,
		true, Color(1.0, 0.0, 0.0), 3.5)
	# Microwave button stripe
	_add_box(Vector3(kx + 7.5, 0.9, kz + 0.26), Vector3(0.7, 0.06, 0.01),
		Color(0.2, 0.2, 0.25), 0.5, 0.3)

	# Cabinets overhead
	_add_box(Vector3(kx + 2.0, 3.4, kz - 0.2), Vector3(4.5, 1.2, 1.0),
		Color(0.18, 0.14, 0.12), 0.0, 0.6)
	_add_box(Vector3(kx + 7.0, 3.4, kz - 0.2), Vector3(2.5, 1.2, 1.0),
		Color(0.18, 0.14, 0.12), 0.0, 0.6)

	# Soft red glow from microwave
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.1, 0.1)
	l.light_energy = 0.7
	l.omni_range = 4.0
	l.omni_attenuation = 1.8
	l.position = Vector3(kx + 7.5, 1.2, kz + 0.5)
	add_child(l)
	# Soft fridge LED glow
	var fl := OmniLight3D.new()
	fl.light_color = Color(0.0, 1.0, 0.6)
	fl.light_energy = 0.5
	fl.omni_range = 2.5
	fl.omni_attenuation = 1.8
	fl.position = Vector3(kx + 0.93, 2.0, kz + 0.5)
	add_child(fl)

# ═══════════════════════════════════════════════════════════════════════
# COZY CORNER (SW: -x, +z) — bed + nightstand + plant
# ═══════════════════════════════════════════════════════════════════════

func _build_cozy_corner() -> void:
	var bx := -ROOM_W / 2.0 + 3.5
	var bz := ROOM_D / 2.0 - 5.0

	# Frame
	_add_box(Vector3(bx, 0.4, bz), Vector3(4.0, 0.4, 6.0),
		Color(0.1, 0.07, 0.05), 0.0, 0.8)
	# Mattress
	_add_box(Vector3(bx, 0.75, bz), Vector3(3.8, 0.35, 5.8),
		Color(0.2, 0.18, 0.25), 0.0, 0.9)
	# Pillow
	_add_box(Vector3(bx, 1.05, bz - 2.0), Vector3(3.0, 0.22, 1.2),
		Color(0.85, 0.85, 0.88), 0.0, 0.85)
	# Blanket — teal
	_add_box(Vector3(bx, 0.98, bz + 1.0), Vector3(3.6, 0.08, 3.4),
		Color(0.05, 0.18, 0.22), 0.0, 0.85)
	# Tossed blanket fold accent
	_add_box(Vector3(bx + 1.4, 1.08, bz + 1.8), Vector3(0.8, 0.05, 1.6),
		Color(0.04, 0.14, 0.18), 0.0, 0.85)

	# Nightstand
	_add_box(Vector3(bx + 3.1, 0.7, bz - 2.4), Vector3(1.4, 1.4, 1.4),
		Color(0.12, 0.09, 0.08), 0.0, 0.75)
	# Bedside lamp — warm
	_add_box(Vector3(bx + 3.1, 1.6, bz - 2.4), Vector3(0.45, 0.45, 0.45),
		Color(0.95, 0.85, 0.6), 0.0, 0.3,
		true, Color(1.0, 0.85, 0.5), 2.4)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.5)
	lamp.light_energy = 2.4
	lamp.omni_range = 6.5
	lamp.omni_attenuation = 1.5
	lamp.position = Vector3(bx + 3.1, 1.85, bz - 2.4)
	add_child(lamp)

	# Plant in the corner — vase + emissive cyan-green leaves
	_add_box(Vector3(bx - 1.6, 0.5, bz + 2.6), Vector3(0.8, 1.0, 0.8),
		Color(0.15, 0.1, 0.08), 0.0, 0.6)
	for i in range(7):
		var ang := i * 0.9
		_add_box(Vector3(bx - 1.6 + 0.3 * cos(ang), 1.4 + i * 0.16,
				bz + 2.6 + 0.3 * sin(ang)),
			Vector3(0.12, 0.5 + i * 0.08, 0.12),
			Color(0.05, 0.4, 0.25), 0.0, 0.7,
			true, Color(0.0, 1.0, 0.6), 0.8)

	# A small floor sparkle near the bed — pickup hint
	_add_box(Vector3(bx + 2.0, 0.1, bz + 1.5),
		Vector3(0.15, 0.05, 0.15),
		Color(0.4, 0.3, 0.6), 0.0, 0.4,
		true, Color(0.9, 0.4, 1.0), 2.5)

# ═══════════════════════════════════════════════════════════════════════
# LOUNGE (SE: +x, +z) — couch + TV + coffee table + floor lamp
# ═══════════════════════════════════════════════════════════════════════

func _build_lounge() -> void:
	var cx := ROOM_W / 2.0 - 7.0
	var cz := ROOM_D / 2.0 - 5.5

	# Couch — facing -z (toward the TV)
	_add_box(Vector3(cx, 0.55, cz + 1.2), Vector3(7.2, 1.1, 2.4),
		Color(0.15, 0.08, 0.12), 0.0, 0.85)
	_add_box(Vector3(cx, 1.4, cz + 2.1), Vector3(7.2, 1.4, 0.4),
		Color(0.15, 0.08, 0.12), 0.0, 0.85)
	# Couch cushions — slight magenta tint
	for ox in [-2.4, 0.0, 2.4]:
		_add_box(Vector3(cx + ox, 1.25, cz + 0.6),
			Vector3(1.8, 0.3, 1.5),
			Color(0.25, 0.12, 0.2), 0.0, 0.8)

	# Coffee table
	_add_box(Vector3(cx, 0.45, cz - 1.8), Vector3(3.4, 0.1, 1.8),
		Color(0.12, 0.09, 0.07), 0.4, 0.4)
	for off in [Vector3(-1.5, 0, -0.7), Vector3(1.5, 0, -0.7),
				Vector3(-1.5, 0, 0.7), Vector3(1.5, 0, 0.7)]:
		_add_box(Vector3(cx + off.x, 0.22, cz - 1.8 + off.z),
			Vector3(0.08, 0.45, 0.08),
			Color(0.04, 0.04, 0.05), 0.5, 0.4)
	# Pizza box
	_add_box(Vector3(cx - 0.9, 0.55, cz - 1.6), Vector3(1.2, 0.1, 1.2),
		Color(0.5, 0.35, 0.18), 0.0, 0.6)
	# Datapad — green glow
	_add_box(Vector3(cx + 0.5, 0.52, cz - 1.8), Vector3(0.6, 0.04, 0.4),
		Color(0.04, 0.04, 0.06), 0.4, 0.4,
		true, Color(0.0, 1.0, 0.5), 1.0)
	# Soda can — red
	_add_box(Vector3(cx + 1.2, 0.6, cz - 1.4), Vector3(0.22, 0.4, 0.22),
		Color(0.8, 0.1, 0.1), 0.4, 0.4)

	# TV stand
	_add_box(Vector3(cx, 0.6, cz - 4.0), Vector3(5.0, 1.2, 1.2),
		Color(0.06, 0.05, 0.07), 0.3, 0.6)
	# TV body
	_add_box(Vector3(cx, 2.4, cz - 4.0), Vector3(5.6, 3.0, 0.25),
		Color(0.02, 0.02, 0.03), 0.7, 0.3)
	# TV screen — animated emission
	_tv_mat = StandardMaterial3D.new()
	_tv_mat.albedo_color = Color(0.05, 0.03, 0.08)
	_tv_mat.metallic = 0.0
	_tv_mat.roughness = 0.25
	_tv_mat.emission_enabled = true
	_tv_mat.emission = Color(0.85, 0.2, 0.95)
	_tv_mat.emission_energy_multiplier = 1.2
	var tv_mesh := BoxMesh.new()
	tv_mesh.size = Vector3(5.1, 2.55, 0.02)
	tv_mesh.material = _tv_mat
	var tv_mi := MeshInstance3D.new()
	tv_mi.mesh = tv_mesh
	tv_mi.position = Vector3(cx, 2.4, cz - 3.86)
	add_child(tv_mi)
	# TV light — animates with channel
	_tv_light = OmniLight3D.new()
	_tv_light.light_color = Color(0.85, 0.2, 0.95)
	_tv_light.light_energy = 1.4
	_tv_light.omni_range = 8.0
	_tv_light.omni_attenuation = 1.4
	_tv_light.position = Vector3(cx, 2.4, cz - 3.0)
	add_child(_tv_light)

	# Floor lamp — back-right of couch
	_add_box(Vector3(cx + 4.0, 0.08, cz + 1.5), Vector3(0.5, 0.15, 0.5),
		Color(0.05, 0.05, 0.06), 0.5, 0.4)
	_add_box(Vector3(cx + 4.0, 1.5, cz + 1.5), Vector3(0.1, 2.8, 0.1),
		Color(0.07, 0.07, 0.08), 0.5, 0.4)
	_add_box(Vector3(cx + 4.0, 3.0, cz + 1.5), Vector3(0.7, 0.6, 0.7),
		Color(0.95, 0.85, 0.55), 0.0, 0.3,
		true, Color(1.0, 0.8, 0.45), 2.0)
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.8, 0.45)
	fl.light_energy = 2.4
	fl.omni_range = 8.0
	fl.omni_attenuation = 1.3
	fl.position = Vector3(cx + 4.0, 3.1, cz + 1.5)
	add_child(fl)

# ═══════════════════════════════════════════════════════════════════════
# CENTER — anchor rug
# ═══════════════════════════════════════════════════════════════════════

func _build_center_rug() -> void:
	_add_box(Vector3(0, 0.01, 0), Vector3(8.5, 0.02, 5.5),
		Color(0.2, 0.08, 0.18), 0.0, 0.95)
	_add_box(Vector3(0, 0.015, 0), Vector3(7.5, 0.022, 4.5),
		Color(0.32, 0.1, 0.25), 0.0, 0.95)
	_add_box(Vector3(0, 0.02, 0), Vector3(3.5, 0.024, 2.2),
		Color(0.42, 0.16, 0.32), 0.0, 0.95)

# ═══════════════════════════════════════════════════════════════════════
# CEILING LAMPS — main + 2 quadrants
# ═══════════════════════════════════════════════════════════════════════

func _build_ceiling_lamps() -> void:
	var lamp_positions := [
		Vector3(0, 0, 0),
		Vector3(12, 0, -10),    # over working corner
		Vector3(-12, 0, 9),     # over cozy corner
		Vector3(12, 0, 9),      # over lounge (helps balance)
	]
	for p in lamp_positions:
		_add_box(Vector3(p.x, ROOM_H - 0.15, p.z), Vector3(0.9, 0.14, 0.9),
			Color(0.05, 0.05, 0.06), 0.5, 0.4)
		_add_box(Vector3(p.x, ROOM_H - 0.32, p.z), Vector3(0.4, 0.22, 0.4),
			Color(1.0, 0.9, 0.6), 0.0, 0.3,
			true, Color(1.0, 0.85, 0.55), 1.6)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.88, 0.6)
		l.light_energy = 3.8
		l.omni_range = 18.0
		l.omni_attenuation = 1.0
		l.shadow_enabled = (p == Vector3.ZERO)
		l.position = Vector3(p.x, ROOM_H - 0.4, p.z)
		add_child(l)

	# Soft purple fill — broad
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.65, 0.55, 0.85)
	fill.light_energy = 1.6
	fill.omni_range = 32.0
	fill.omni_attenuation = 1.4
	fill.position = Vector3(0, 2.5, 0)
	add_child(fill)

# ═══════════════════════════════════════════════════════════════════════
# DOOR — visible frame + interact trigger
# ═══════════════════════════════════════════════════════════════════════

func _build_door() -> void:
	var dx := ROOM_W / 2.0
	var dz := ROOM_D / 5.0
	# Door panel — soft cyan glow so the exit reads from across the room
	_add_box(Vector3(dx - 0.06, 1.4, dz),
		Vector3(0.10, 2.8, 1.9),
		Color(0.08, 0.18, 0.22), 0.0, 0.4,
		true, Color(0.0, 0.55, 0.75), 0.8)
	# Inner darker pane
	_add_box(Vector3(dx - 0.12, 1.3, dz),
		Vector3(0.02, 2.2, 1.4),
		Color(0.04, 0.06, 0.08), 0.0, 0.6, false, Color.BLACK, 0.0, false)
	# Hot neon frame — bright cyan tube outlining the doorway
	_add_box(Vector3(dx - 0.08, 0.0, dz),
		Vector3(0.05, 0.06, 2.0),
		Color(0.0, 0.5, 0.6), 0.0, 0.2,
		true, Color(0.0, 1.2, 1.4), 4.0, false)
	_add_box(Vector3(dx - 0.08, 2.8, dz),
		Vector3(0.05, 0.06, 2.0),
		Color(0.0, 0.5, 0.6), 0.0, 0.2,
		true, Color(0.0, 1.2, 1.4), 4.0, false)
	for fz in [dz - 0.95, dz + 0.95]:
		_add_box(Vector3(dx - 0.08, 1.4, fz),
			Vector3(0.05, 2.8, 0.06),
			Color(0.0, 0.5, 0.6), 0.0, 0.2,
			true, Color(0.0, 1.2, 1.4), 4.0, false)
	# Exit sign above the door
	_add_box(Vector3(dx - 0.20, 3.0, dz),
		Vector3(0.04, 0.30, 1.0),
		Color(0.02, 0.06, 0.08), 0.0, 0.2,
		true, Color(0.0, 1.4, 1.5), 6.0, false)
	# Floor pool — cyan spill in front of the door so the path lights up
	var pool := OmniLight3D.new()
	pool.position = Vector3(dx - 1.5, 0.5, dz)
	pool.light_color = Color(0.0, 1.0, 1.0)
	pool.light_energy = 3.5
	pool.omni_range = 4.5
	pool.omni_attenuation = 1.8
	add_child(pool)
	# Door handle — small but bright
	_add_box(Vector3(dx - 0.14, 1.2, dz - 0.7),
		Vector3(0.05, 0.14, 0.05),
		Color(0.7, 0.7, 0.75), 0.7, 0.2,
		true, Color(0.0, 1.0, 1.0), 2.0, false)
	# Trigger
	_door_zone = Area3D.new()
	_door_zone.position = Vector3(dx - 1.0, 1.2, dz)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.4, 2.0)
	col.shape = shape
	_door_zone.add_child(col)
	_door_zone.body_entered.connect(_on_door_entered)
	_door_zone.body_exited.connect(_on_door_exited)
	add_child(_door_zone)

	# Spawn marker for SceneTransition: when the player returns from the
	# hallway via spawn id "from_hall", they land at this marker.
	var marker := Node3D.new()
	marker.name = "from_hall"
	marker.position = Vector3(dx - 1.5, 0.0, dz)
	add_child(marker)

func _on_door_entered(body: Node3D) -> void:
	if body == _player:
		_on_door = true
		_set_status("[E] LEAVE APARTMENT")

func _on_door_exited(body: Node3D) -> void:
	if body == _player:
		_on_door = false
		_set_status("")

# ═══════════════════════════════════════════════════════════════════════
# PLAYER — smaller billboard so it reads as a person in a big room
# ═══════════════════════════════════════════════════════════════════════

func _build_player() -> void:
	_player = CharacterBody3D.new()
	# Body y = capsule half-height (0.85) so the capsule bottom rests on the floor.
	_player.position = Vector3(0, 0.85, 4.0)
	add_child(_player)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.7
	col.shape = shape
	_player.add_child(col)

	# AnimatedBillboard origin at world y = 0 → sprite feet sit on the floor.
	_player_anim = AnimatedBillboardScript.new()
	_player_anim.pixel_size = 0.04
	_player_anim.position = Vector3(0, -0.85, 0)
	_player.add_child(_player_anim)
	_player_anim.load_sheet("res://assets/sprites/player-pizza.png")

	# Cat — wanders the apartment
	_build_cat()

func _build_cat() -> void:
	_cat_pivot = Node3D.new()
	_cat_pivot.position = Vector3(-2.0, 0.0, 5.0)
	add_child(_cat_pivot)
	_cat_anim = AnimatedBillboardScript.new()
	_cat_anim.pixel_size = 0.035
	_cat_pivot.add_child(_cat_anim)
	_cat_anim.load_sheet("res://assets/sprites/blackCat.png")
	_cat_target = _cat_pivot.position
	_pick_cat_target()

# ═══════════════════════════════════════════════════════════════════════
# LIGHTNING — DirectionalLight3D pulsed every 8-18s, plus ambient kick
# ═══════════════════════════════════════════════════════════════════════

func _build_lightning() -> void:
	_lightning_light = DirectionalLight3D.new()
	_lightning_light.light_color = Color(0.85, 0.9, 1.0)
	_lightning_light.light_energy = 0.0
	# Aim like sunlight coming through the window: from window toward room
	_lightning_light.rotation_degrees = Vector3(-45, -60, 0)
	add_child(_lightning_light)
	_lightning_next = randf_range(6.0, 10.0)

func _tick_lightning(delta: float) -> void:
	if _lightning_active > 0.0:
		_lightning_active -= delta
		# Two-pulse envelope: hard flash, brief dip, soft after-flash
		var t := 1.0 - _lightning_active / 0.45
		var pulse := 0.0
		if t < 0.1:
			pulse = t / 0.1
		elif t < 0.18:
			pulse = 1.0
		elif t < 0.32:
			pulse = 0.25
		elif t < 0.42:
			pulse = 0.7
		elif t < 0.6:
			pulse = lerp(0.7, 0.0, (t - 0.42) / 0.18)
		else:
			pulse = 0.0
		_lightning_pulse = pulse
		_lightning_light.light_energy = pulse * 4.5
		if _lightning_window_mat:
			_lightning_window_mat.emission_energy_multiplier = \
				_lightning_base_emission + pulse * 5.0
		if _env:
			_env.ambient_light_energy = 1.2 + pulse * 1.8
		if _lightning_active <= 0.0:
			_lightning_light.light_energy = 0.0
			if _lightning_window_mat:
				_lightning_window_mat.emission_energy_multiplier = _lightning_base_emission
			if _env:
				_env.ambient_light_energy = 1.2
			_lightning_next = randf_range(7.0, 17.0)
	else:
		_lightning_next -= delta
		if _lightning_next <= 0.0:
			_lightning_active = 0.45

# ═══════════════════════════════════════════════════════════════════════
# TV — cycle channels
# ═══════════════════════════════════════════════════════════════════════

const TV_CHANNELS := [
	{ "color": Color(0.85, 0.2, 0.95), "energy": 1.3, "flicker": 0.05 },   # cyberpunk
	{ "color": Color(0.1, 0.5, 1.0),   "energy": 1.1, "flicker": 0.10 },   # noir blue
	{ "color": Color(1.0, 0.7, 0.2),   "energy": 1.0, "flicker": 0.03 },   # warm news
	{ "color": Color(0.95, 0.1, 0.2),  "energy": 1.5, "flicker": 0.15 },   # action
	{ "color": Color(0.5, 1.0, 0.4),   "energy": 0.9, "flicker": 0.04 },   # nature
	{ "color": Color(0.9, 0.9, 0.95),  "energy": 0.6, "flicker": 0.35 },   # static
]

func _tick_tv(delta: float) -> void:
	_tv_t += delta
	if _tv_t >= _tv_dwell:
		_tv_t = 0.0
		_tv_channel = (_tv_channel + 1) % TV_CHANNELS.size()
		_tv_dwell = randf_range(2.5, 6.0)
	var ch: Dictionary = TV_CHANNELS[_tv_channel]
	var base_e: float = ch["energy"]
	var flicker: float = ch["flicker"]
	var e := base_e + sin(_tv_t * 18.0) * flicker + randf_range(-flicker, flicker) * 0.5
	if _tv_mat:
		_tv_mat.emission = ch["color"]
		_tv_mat.emission_energy_multiplier = max(0.1, e)
	if _tv_light:
		_tv_light.light_color = ch["color"]
		_tv_light.light_energy = max(0.2, 1.2 + sin(_tv_t * 12.0) * flicker)

# ═══════════════════════════════════════════════════════════════════════
# CRT — scrolling text
# ═══════════════════════════════════════════════════════════════════════

const CRT_LINES_SHOWN := 9

func _render_crt() -> void:
	if _crt_label == null:
		return
	var lines := []
	for i in CRT_LINES_SHOWN:
		var idx := (_crt_scroll + i) % _crt_lines.size()
		lines.append(_crt_lines[idx])
	_crt_label.text = "\n".join(lines)

func _tick_crt(delta: float) -> void:
	_crt_t += delta
	if _crt_t >= 0.9:
		_crt_t = 0.0
		_crt_scroll = (_crt_scroll + 1) % _crt_lines.size()
		_render_crt()
	_crt_cursor_t += delta
	if _crt_cursor_label:
		_crt_cursor_label.visible = fmod(_crt_cursor_t, 1.0) < 0.55

# ═══════════════════════════════════════════════════════════════════════
# HUD — title, status, hint, 6-slot hotbar
# ═══════════════════════════════════════════════════════════════════════

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var title := Label.new()
	title.text = "YOUR APARTMENT"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0, 1, 0.53))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	title.add_theme_constant_override("outline_size", 4)
	title.position = Vector2(24, 22)
	layer.add_child(title)

	_hud_status = Label.new()
	_hud_status.text = ""
	_hud_status.add_theme_font_size_override("font_size", 16)
	_hud_status.add_theme_color_override("font_color", Color(0.4, 1.0, 1.0))
	_hud_status.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hud_status.add_theme_constant_override("outline_size", 3)
	_hud_status.position = Vector2(24, 56)
	layer.add_child(_hud_status)

	var hint := Label.new()
	hint.text = "WASD MOVE  ·  R SPRINT  ·  1-6 HOTBAR  ·  E INTERACT  ·  P PHONE  ·  ESC TITLE"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.7))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hint.add_theme_constant_override("outline_size", 2)
	hint.position = Vector2(24, 696)
	layer.add_child(hint)

	# Hotbar
	var slot_size := 52
	var slot_gap := 6
	var hb_y := 660 - slot_size
	for i in range(6):
		var panel := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.05, 0.08, 0.85)
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.2, 0.3, 0.45)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override("panel", sb)
		panel.position = Vector2(24 + i * (slot_size + slot_gap), hb_y)
		panel.size = Vector2(slot_size, slot_size)
		layer.add_child(panel)

		var num := Label.new()
		num.text = str(i + 1)
		num.add_theme_font_size_override("font_size", 14)
		num.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
		num.position = Vector2(4, 0)
		panel.add_child(num)
		_hotbar_slots.append(panel)
	_highlight_hotbar()

func _set_status(t: String) -> void:
	if _hud_status:
		_hud_status.text = t

func _highlight_hotbar() -> void:
	for i in _hotbar_slots.size():
		var panel := _hotbar_slots[i] as Panel
		var sb := panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if i + 1 == _hotbar_active:
			sb.border_color = Color(0.0, 1.0, 1.0)
			sb.bg_color = Color(0.1, 0.25, 0.35, 0.95)
		else:
			sb.border_color = Color(0.2, 0.3, 0.45)
			sb.bg_color = Color(0.04, 0.05, 0.08, 0.85)
		panel.add_theme_stylebox_override("panel", sb)

# ═══════════════════════════════════════════════════════════════════════
# PROCESS — input, movement, TV / CRT / rain / lightning ticks
# ═══════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if _exiting:
		return
	_tick_tv(delta)
	_tick_crt(delta)
	_tick_rain(delta)
	_tick_lightning(delta)
	_tick_cat(delta)
	_tick_camera(delta)

func _tick_camera(delta: float) -> void:
	if _camera == null or _player == null:
		return
	# Pure translation — orientation stays fixed from _setup_camera.
	var target := _player.global_position + CAMERA_OFFSET
	_camera.global_position = _camera.global_position.lerp(
		target, clamp(CAMERA_FOLLOW_LERP * delta, 0.0, 1.0))

# ═══════════════════════════════════════════════════════════════════════
# CAT — wanders the apartment to random nearby points, idles between moves
# ═══════════════════════════════════════════════════════════════════════

func _tick_cat(delta: float) -> void:
	if _cat_pivot == null:
		return
	var to_target := _cat_target - _cat_pivot.position
	to_target.y = 0
	if to_target.length() < 0.15:
		_cat_anim.set_moving(false)
		_cat_t += delta
		if _cat_t >= _cat_idle_dwell:
			_cat_t = 0.0
			_cat_idle_dwell = randf_range(2.5, 6.0)
			_pick_cat_target()
		return
	var dir := to_target.normalized()
	_cat_pivot.position += dir * 1.2 * delta
	# Convert world direction to screen input convention for facing
	var screen_x := dir.x - dir.z   # iso right axis ∝ (+x, -z)
	var screen_y := dir.x + dir.z   # iso down axis  ∝ (+x, +z)
	_cat_anim.update_facing_from_input(Vector2(screen_x, screen_y))
	_cat_anim.set_moving(true)

func _pick_cat_target() -> void:
	# Stay roughly in the cozy/center area of the apartment, avoid walls.
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var x := rng.randf_range(-8.0, 4.0)
	var z := rng.randf_range(-3.0, 7.0)
	_cat_target = Vector3(x, 0.0, z)

func _physics_process(_delta: float) -> void:
	if _player == null or _exiting:
		return
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if input.length() > 1:
		input = input.normalized()

	# Iso projection — camera at (+x,+y,+z) looking at origin
	var world_dir := Vector3(input.x + input.y, 0, -input.x + input.y) * (1.0 / sqrt(2.0))
	var speed := WALK_SPEED
	if Input.is_action_pressed("sprint"):
		speed *= SPRINT_MULT
	_player.velocity = world_dir * speed
	_player.move_and_slide()

	if _player_anim:
		_player_anim.update_facing_from_input(input)
		_player_anim.set_moving(input.length_squared() > 0.01)

func _input(event: InputEvent) -> void:
	if _exiting:
		return
	if event.is_action_pressed("interact") and _on_door:
		_exit_to_city()
	elif event.is_action_pressed("ui_cancel"):
		_exit_to_title()
	else:
		for i in range(1, 7):
			if event.is_action_pressed("hotbar_" + str(i)):
				_hotbar_active = i
				_highlight_hotbar()
				_set_status("[" + str(i) + "] slot active")
				break

func _exit_to_title() -> void:
	_exiting = true
	get_tree().change_scene_to_file("res://scenes/title.tscn")

func _exit_to_city() -> void:
	# Front door now leads to the hallway, not straight to the street.
	# Players reach the city via the hallway's elevator.
	_exiting = true
	SceneTransition.go("hallway", "from_apt_404")

# ═══════════════════════════════════════════════════════════════════════
# HELPERS — boxes + walls
# ═══════════════════════════════════════════════════════════════════════

func _add_box(pos: Vector3, sz: Vector3, col: Color, metallic: float = 0.0,
		roughness: float = 0.8, emissive: bool = false,
		emission_col: Color = Color.BLACK, emission_energy: float = 0.0,
		collision: bool = true) -> MeshInstance3D:
	# Every furniture / decoration box gets collision by default. Things that
	# need to pass through the player (rain drops, screen graphics, ceiling
	# strips out of reach) explicitly pass collision=false.
	var mesh := BoxMesh.new()
	mesh.size = sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metallic
	mat.roughness = roughness
	if emissive:
		mat.emission_enabled = true
		mat.emission = emission_col
		mat.emission_energy_multiplier = emission_energy
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if collision:
		var body := StaticBody3D.new()
		body.position = pos
		var col_shape := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = sz
		col_shape.shape = shape
		body.add_child(col_shape)
		body.add_child(mi)
		add_child(body)
	else:
		mi.position = pos
		add_child(mi)
	return mi

func _add_wall(pos: Vector3, sz: Vector3, col: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	col_shape.shape = shape
	body.add_child(col_shape)

	var mesh := BoxMesh.new()
	mesh.size = sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.0
	mat.roughness = 0.85
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	add_child(body)
