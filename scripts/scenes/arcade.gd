## Arcade — ARCADE. A main zone: 3D iso walk-around room in the
## apartment's visual language (heavy glow, emissive props, animated
## screens). Port of hacking-game's ArcadeScene.
##
## Layout (iso camera from +x+z corner, like apartment):
##   • Back (-z) wall — row of upright cabinets: NET RUNNER (playable),
##     DATA DUEL (playable), VOID INVADERS (dead), and the wide 2-PLAYER
##     NEON SURVIVORS cabinet with twin control decks.
##   • West (-x) wall — two linked NEON RACER sit-down cabinets (2P) and
##     the CYBER DANCE stage with chasing arrow pads.
##   • Center — DUEL TABLE: 2-player cocktail cabinet with an upward
##     glowing screen and stools on opposite sides.
##   • East (+x) wall — exit to the street + humming vending machine.
##   • Monitor wall above the cabinets cycles TV channels (apartment
##     TV trick, x3) under the ARCADE neon sign.
extends Node3D

const SceneGraphData := preload("res://data/scene_graph.gd")
const InteractableDoorScript := preload("res://scripts/systems/interactable_door.gd")
const AnimatedBillboardScript := preload("res://scripts/systems/animated_billboard.gd")
const DoorGlowScript := preload("res://scripts/systems/door_glow.gd")

const ROOM_W := 42.0    # x
const ROOM_D := 30.0    # z
const ROOM_H := 5.5
const WALL_T := 0.5

const CAMERA_OFFSET := Vector3(21, 22, 21)
const CAMERA_FOLLOW_LERP := 6.0
const WALK_SPEED := 7.0
const SPRINT_MULT := 1.7

# Upright cabinets along the back (-z) wall. 2P cabinets are wide and get
# twin control decks. Playable ones carry a "game" scene id.
const CABINETS := [
	{ "id": "snake",     "x": -14.0, "name": "NET RUNNER",
	  "color": Color(0.0, 1.0, 0.55), "game": "snake" },
	{ "id": "breakout",  "x":  -9.0, "name": "DATA DUEL",
	  "color": Color(0.0, 0.85, 1.0), "game": "breakout" },
	{ "id": "invaders",  "x":  -4.0, "name": "VOID INVADERS",
	  "color": Color(0.8, 0.4, 1.0), "game": "invaders" },
	{ "id": "survivors", "x":   3.0, "name": "NEON SURVIVORS",
	  "color": Color(1.0, 0.12, 0.55), "game": "survivors", "players": 2 },
]

const TV_CHANNELS := [
	{ "color": Color(0.85, 0.2, 0.95), "energy": 1.3, "flicker": 0.05 },
	{ "color": Color(0.1, 0.5, 1.0),   "energy": 1.1, "flicker": 0.10 },
	{ "color": Color(0.95, 0.1, 0.2),  "energy": 1.5, "flicker": 0.15 },
	{ "color": Color(0.5, 1.0, 0.4),   "energy": 0.9, "flicker": 0.04 },
	{ "color": Color(0.9, 0.9, 0.95),  "energy": 0.6, "flicker": 0.35 },
]

var _camera: Camera3D
var _player: CharacterBody3D
var _player_anim
var _status_label: Label
var _near_zone: Dictionary = {}       # {kind, ...} for the closest interact
var _screen_mats: Array = []          # cabinet attract screens
var _screen_t := 0.0
var _tvs: Array = []                  # monitor wall: {mat, light, ch, t, dwell}
var _ddr_pads: Array = []             # 4 arrow pad materials
var _ddr_t := 0.0
var _coin_label: Label3D
var _coin_t := 0.0

func _ready() -> void:
	_setup_camera()
	_setup_environment()
	_build_room()
	_build_back_wall_cabinets()
	_build_racing_corner()
	_build_ddr_stage()
	_build_duel_table()
	_build_east_side()
	_build_prize_counter()
	_build_crt_stack()
	_build_posters()
	_build_npcs()
	_build_ceiling()
	_build_player()
	_build_hud()
	_apply_pending_spawn()
	Music.play_category("city")   # street mood until an arcade track exists


# ═══════════════════════════════════════════════════════════════════════
# CAMERA + ENVIRONMENT — apartment recipe, tuned darker + hotter neon
# ═══════════════════════════════════════════════════════════════════════

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 26.0
	_camera.position = CAMERA_OFFSET + Vector3(0, 1, 0)
	_camera.current = true
	add_child(_camera)
	# Aim ONCE — per-frame look_at causes floor-slide (apartment gotcha)
	_camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.003, 0.002, 0.006)
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.2
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	env.set("glow_levels/2", true)
	env.set("glow_levels/4", true)
	env.set("glow_levels/6", true)
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.11, 0.09, 0.16)
	env.ambient_light_energy = 0.75
	env.ssao_enabled = true
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_density = 0.012
	env.fog_light_color = Color(0.07, 0.03, 0.11)
	env.fog_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ═══════════════════════════════════════════════════════════════════════
# ROOM SHELL — floor with glow walkway, two visible walls, neon trim
# ═══════════════════════════════════════════════════════════════════════

func _build_room() -> void:
	# Floor — violet carpet with a faint self-glow so it NEVER reads black
	_add_box(Vector3(0, -0.05, 0), Vector3(ROOM_W, 0.1, ROOM_D),
		Color(0.22, 0.17, 0.27), 0.0, 0.75,
		true, Color(0.16, 0.11, 0.22), 0.35)
	# Carpet runner from the entrance to the cabinet row, neon edge trim —
	# reads as an actual walkway instead of floating squares
	_add_box(Vector3(1.0, 0.004, 2.0), Vector3(ROOM_W - 6.0, 0.012, 3.6),
		Color(0.30, 0.09, 0.24), 0.0, 0.7, true, Color(0.30, 0.06, 0.22), 0.5)
	for edge in [-1.9, 1.9]:
		_add_box(Vector3(1.0, 0.010, 2.0 + edge), Vector3(ROOM_W - 6.0, 0.012, 0.12),
			Color(0.3, 0.05, 0.25), 0.0, 0.3, true, Color(1.0, 0.15, 0.7), 1.6)
	# Cabinet-row apron — cyan strip along the base of the machine row
	_add_box(Vector3(-5.5, 0.004, -11.4), Vector3(24.0, 0.012, 1.4),
		Color(0.08, 0.20, 0.26), 0.0, 0.7, true, Color(0.0, 0.55, 0.7), 0.6)
	# Walls — back (-z) + west (-x) bright enough to read; near walls
	# darker. East wall gets a REAL gap for the exit door (apartment trick —
	# the doorway reads through the opening from the iso camera).
	_add_box(Vector3(0, ROOM_H / 2.0, -ROOM_D / 2.0),
		Vector3(ROOM_W, ROOM_H, WALL_T), Color(0.17, 0.14, 0.22))
	_add_box(Vector3(-ROOM_W / 2.0, ROOM_H / 2.0, 0),
		Vector3(WALL_T, ROOM_H, ROOM_D), Color(0.16, 0.13, 0.21))
	_add_box(Vector3(0, ROOM_H / 2.0, ROOM_D / 2.0),
		Vector3(ROOM_W, ROOM_H, WALL_T), Color(0.10, 0.09, 0.13))
	var door_z := 4.0
	var gap := 2.4
	var north_len: float = (door_z - gap / 2.0) - (-ROOM_D / 2.0)
	_add_box(Vector3(ROOM_W / 2.0, ROOM_H / 2.0, -ROOM_D / 2.0 + north_len / 2.0),
		Vector3(WALL_T, ROOM_H, north_len), Color(0.16, 0.13, 0.21))
	var south_len: float = (ROOM_D / 2.0) - (door_z + gap / 2.0)
	_add_box(Vector3(ROOM_W / 2.0, ROOM_H / 2.0, door_z + gap / 2.0 + south_len / 2.0),
		Vector3(WALL_T, ROOM_H, south_len), Color(0.16, 0.13, 0.21))
	# Header above the doorway
	_add_box(Vector3(ROOM_W / 2.0, ROOM_H - 0.65, door_z),
		Vector3(WALL_T, 1.3, gap), Color(0.08, 0.07, 0.10))
	# Baseboard neon trim on the two visible walls
	_add_box(Vector3(0, 0.08, -ROOM_D / 2.0 + WALL_T / 2.0 + 0.02),
		Vector3(ROOM_W - 1.0, 0.06, 0.04),
		Color(0.4, 0.05, 0.3), 0.0, 0.3, true, Color(1.0, 0.15, 0.7), 1.6)
	_add_box(Vector3(-ROOM_W / 2.0 + WALL_T / 2.0 + 0.02, 0.08, 0),
		Vector3(0.04, 0.06, ROOM_D - 1.0),
		Color(0.05, 0.3, 0.4), 0.0, 0.3, true, Color(0.1, 0.9, 1.1), 1.6)
	# ARCADE — big neon sign high on the back wall
	var sign_label := Label3D.new()
	sign_label.text = "ARCADE"
	sign_label.font_size = 320
	sign_label.pixel_size = 0.01
	sign_label.modulate = Color(1.0, 0.2, 0.75)
	sign_label.outline_size = 36
	sign_label.outline_modulate = Color(0.25, 0.0, 0.18)
	sign_label.position = Vector3(3.0, ROOM_H - 0.7, -ROOM_D / 2.0 + WALL_T)
	add_child(sign_label)
	var sign_light := OmniLight3D.new()
	sign_light.position = Vector3(3.0, ROOM_H - 0.8, -ROOM_D / 2.0 + 2.5)
	sign_light.light_color = Color(1.0, 0.2, 0.75)
	sign_light.light_energy = 2.4
	sign_light.omni_range = 9.0
	add_child(sign_light)


# ═══════════════════════════════════════════════════════════════════════
# UPRIGHT CABINETS — back wall row (incl. the 2P NEON SURVIVORS)
# ═══════════════════════════════════════════════════════════════════════

func _build_back_wall_cabinets() -> void:
	var wall_face := -ROOM_D / 2.0 + WALL_T / 2.0
	for cab in CABINETS:
		_build_cabinet(cab, wall_face)
	# Monitor wall — three channel-cycling screens above the cabinets
	for i in 3:
		_build_wall_tv(Vector3(-13.0 + i * 5.0, 4.35, wall_face + 0.18),
			Vector2(3.6, 1.7))
	# Blinking INSERT COIN over the 2P cabinet
	_coin_label = Label3D.new()
	_coin_label.text = "INSERT COIN"
	_coin_label.font_size = 120
	_coin_label.pixel_size = 0.01
	_coin_label.modulate = Color(1.0, 0.85, 0.2)
	_coin_label.outline_size = 24
	_coin_label.outline_modulate = Color(0.2, 0.12, 0.0)
	_coin_label.position = Vector3(3.0, 4.35, wall_face + 1.2)
	add_child(_coin_label)

func _build_cabinet(cab: Dictionary, wall_face: float) -> void:
	var x: float = cab.x
	var color: Color = cab.color
	var playable: bool = cab.get("game", "") != ""
	var two_p: bool = cab.get("players", 1) == 2
	var w: float = 4.6 if two_p else 2.0
	var d := 1.6
	var h := 3.4
	var cz := wall_face + d / 2.0 + 0.1
	# Body — dark shell, faint self-glow in the game color
	_add_box(Vector3(x, h / 2.0, cz), Vector3(w, h, d),
		Color(0.05, 0.04, 0.08), 0.3, 0.4,
		true, color * Color(0.08, 0.08, 0.08, 1.0), 0.6)
	# Side trim tubes down the front corners
	for fx in [-w / 2.0 - 0.04, w / 2.0 + 0.04]:
		_add_box(Vector3(x + fx, h / 2.0, cz + d * 0.28),
			Vector3(0.08, h, 0.08),
			color * Color(0.3, 0.3, 0.3, 1.0), 0.0, 0.3, true, color,
			2.4 if playable or two_p else 0.6)
	# Screen — animated attract mode (dead cabinets get a dim stuck frame)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(w * 0.72, 1.35, 0.04)
	screen.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color * Color(0.12, 0.12, 0.12, 1.0)
	smat.emission_enabled = true
	smat.emission = color
	smat.emission_energy_multiplier = 1.8
	_screen_mats.append({ "mat": smat, "color": color, "phase": randf() * TAU })
	screen.material_override = smat
	screen.position = Vector3(x, 2.35, cz + d / 2.0 + 0.03)
	add_child(screen)
	# Game content on the screen — bright contrast pixels so it reads as a
	# live game, not a lit rectangle
	_dress_screen(Vector3(x, 2.35, cz + d / 2.0 + 0.06), w * 0.72, 1.35, color)
	if two_p:
		var hs := Label3D.new()
		hs.text = "HI 3000  ·  CHAD"
		hs.font_size = 40
		hs.pixel_size = 0.008
		hs.modulate = Color(1.4, 1.3, 1.5)
		hs.outline_size = 10
		hs.outline_modulate = Color(0, 0, 0)
		hs.position = Vector3(x, 2.85, cz + d / 2.0 + 0.08)
		add_child(hs)
	# Screen glow spill onto the floor in front
	var pool := OmniLight3D.new()
	pool.position = Vector3(x, 1.2, cz + d / 2.0 + 1.6)
	pool.light_color = color
	pool.light_energy = 1.8 if (playable or two_p) else 0.7
	pool.omni_range = 3.4
	pool.omni_attenuation = 1.8
	add_child(pool)
	# Control deck(s) — 2P cabinets get twin decks with joystick nubs
	var decks: Array = [x] if not two_p else [x - w * 0.25, x + w * 0.25]
	for dxx in decks:
		_add_box(Vector3(dxx, 1.55, cz + d / 2.0 + 0.28),
			Vector3((w * 0.42) if two_p else (w * 0.8), 0.14, 0.55),
			Color(0.08, 0.07, 0.11), 0.4, 0.4,
			true, color * Color(0.12, 0.12, 0.12, 1.0), 0.8)
		# Joystick + two buttons
		_add_box(Vector3(dxx - 0.3, 1.72, cz + d / 2.0 + 0.28),
			Vector3(0.08, 0.22, 0.08), Color(0.7, 0.1, 0.15), 0.3, 0.4,
			true, Color(1.0, 0.15, 0.2), 0.9)
		for bo in [0.15, 0.4]:
			_add_box(Vector3(dxx + bo, 1.64, cz + d / 2.0 + 0.32),
				Vector3(0.12, 0.05, 0.12), color * Color(0.4, 0.4, 0.4, 1.0),
				0.3, 0.3, true, color, 1.4)
	# Marquee — glowing name
	var marquee := Label3D.new()
	marquee.text = cab.name
	marquee.font_size = 110
	marquee.pixel_size = 0.008
	marquee.modulate = color
	marquee.outline_size = 22
	marquee.outline_modulate = Color(0, 0, 0)
	marquee.position = Vector3(x, h + 0.25, cz + d / 2.0 + 0.05)
	add_child(marquee)
	if not (playable or two_p):
		var ooo := Label3D.new()
		ooo.text = "OUT OF ORDER"
		ooo.font_size = 60
		ooo.pixel_size = 0.008
		ooo.modulate = Color(0.95, 0.3, 0.25)
		ooo.position = Vector3(x, 2.35, cz + d / 2.0 + 0.1)
		add_child(ooo)
	# Return-spawn marker + interact area
	if playable:
		var m := Node3D.new()
		m.name = "from_game_" + cab.game
		m.position = Vector3(x, 0.0, cz + d / 2.0 + 1.6)
		add_child(m)
	_add_interact_area(Vector3(x, 1.2, cz + d / 2.0 + 1.3),
		Vector3(maxf(w + 0.6, 2.4), 2.4, 2.2),
		{ "kind": "cabinet", "cab": cab })


func _dress_screen(center: Vector3, w: float, h: float, color: Color) -> void:
	# A few hot pixels + a dark play-field band = the screen looks mid-game
	var accents := [Color(1.6, 1.6, 1.6), color * 2.0,
		Color(1.6, 1.3, 0.2), Color(1.6, 1.6, 1.6)]
	var spots := [Vector2(-0.28, 0.18), Vector2(0.10, -0.10),
		Vector2(0.30, 0.22), Vector2(-0.08, -0.28)]
	for i in spots.size():
		var sp: Vector2 = spots[i]
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.10, 0.10, 0.015)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.1)
		mat.emission_enabled = true
		mat.emission = accents[i]
		mat.emission_energy_multiplier = 2.6
		mi.material_override = mat
		mi.position = center + Vector3(sp.x * w, sp.y * h, 0)
		add_child(mi)
	# Dark band across the lower third — the "play field" silhouette
	var band := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(w * 0.9, h * 0.22, 0.012)
	band.mesh = bb
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.02, 0.02, 0.04)
	band.material_override = bmat
	band.position = center + Vector3(0, -h * 0.3, 0.005)
	add_child(band)


# ═══════════════════════════════════════════════════════════════════════
# RACING CORNER — two linked sit-down NEON RACER cabinets (2P)
# ═══════════════════════════════════════════════════════════════════════

func _build_racing_corner() -> void:
	var wall_face := -ROOM_W / 2.0 + WALL_T / 2.0
	var colors := [Color(1.0, 0.45, 0.1), Color(1.0, 0.2, 0.25)]
	for i in 2:
		var z := -6.0 + i * 4.2
		var cx := wall_face + 1.6
		var col: Color = colors[i]
		# Seat + body (facing +x into the room)
		_add_box(Vector3(cx + 1.6, 0.55, z), Vector3(1.6, 1.1, 1.5),
			Color(0.06, 0.05, 0.09), 0.3, 0.5,
			true, col * Color(0.08, 0.08, 0.08, 1.0), 0.5)
		_add_box(Vector3(cx + 2.3, 1.2, z), Vector3(0.3, 1.2, 1.5),
			Color(0.07, 0.06, 0.10), 0.3, 0.5)
		# Console with screen
		_add_box(Vector3(cx + 0.4, 1.5, z), Vector3(0.9, 3.0, 2.0),
			Color(0.05, 0.04, 0.08), 0.3, 0.4,
			true, col * Color(0.1, 0.1, 0.1, 1.0), 0.6)
		var screen := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.04, 1.2, 1.5)
		screen.mesh = sm
		var smat := StandardMaterial3D.new()
		smat.albedo_color = col * Color(0.12, 0.12, 0.12, 1.0)
		smat.emission_enabled = true
		smat.emission = col
		smat.emission_energy_multiplier = 1.4
		screen.material_override = smat
		screen.position = Vector3(cx + 0.88, 2.0, z)
		add_child(screen)
		_screen_mats.append({ "mat": smat, "color": col, "phase": randf() * TAU })
		# Wheel
		_add_box(Vector3(cx + 1.0, 1.35, z), Vector3(0.12, 0.35, 0.35),
			Color(0.1, 0.1, 0.12), 0.5, 0.3, true, col, 0.8)
		# Glow spill
		var pool := OmniLight3D.new()
		pool.position = Vector3(cx + 1.8, 0.9, z)
		pool.light_color = col
		pool.light_energy = 1.2
		pool.omni_range = 3.0
		add_child(pool)
	# Shared marquee
	var marquee := Label3D.new()
	marquee.text = "NEON RACER — 2P LINK"
	marquee.font_size = 100
	marquee.pixel_size = 0.008
	marquee.modulate = Color(1.0, 0.45, 0.1)
	marquee.outline_size = 22
	marquee.outline_modulate = Color(0, 0, 0)
	marquee.position = Vector3(wall_face + 1.2, 3.5, -3.9)
	marquee.rotation.y = PI / 2.0
	add_child(marquee)
	_add_interact_area(Vector3(wall_face + 2.6, 1.2, -3.9),
		Vector3(3.4, 2.4, 8.0),
		{ "kind": "flavor",
		  "prompt": "NEON RACER — 2P LINK",
		  "line": "twin racing pods, engines idling. BLITZ carved his initials in the seat." })


# ═══════════════════════════════════════════════════════════════════════
# CYBER DANCE — DDR stage with chasing arrow pads
# ═══════════════════════════════════════════════════════════════════════

func _build_ddr_stage() -> void:
	var wall_face := -ROOM_W / 2.0 + WALL_T / 2.0
	var cx := wall_face + 2.4
	var cz := 6.5
	var pink := Color(1.0, 0.1, 0.58)
	# Stage platform
	_add_box(Vector3(cx + 1.0, 0.12, cz), Vector3(3.2, 0.24, 3.2),
		Color(0.09, 0.07, 0.12), 0.4, 0.4)
	# Four arrow pads — animated chase
	var offsets := [Vector3(0, 0, -0.9), Vector3(0, 0, 0.9),
		Vector3(-0.9, 0, 0), Vector3(0.9, 0, 0)]
	for off in offsets:
		var pad := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.8, 0.05, 0.8)
		pad.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = pink * Color(0.15, 0.15, 0.15, 1.0)
		pmat.emission_enabled = true
		pmat.emission = pink
		pmat.emission_energy_multiplier = 0.6
		pad.material_override = pmat
		pad.position = Vector3(cx + 1.0, 0.27, cz) + off
		add_child(pad)
		_ddr_pads.append(pmat)
	# Tall screen tower against the wall
	_add_box(Vector3(cx - 0.9, 1.9, cz), Vector3(0.8, 3.8, 2.6),
		Color(0.05, 0.04, 0.08), 0.3, 0.4,
		true, pink * Color(0.1, 0.1, 0.1, 1.0), 0.6)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.04, 1.6, 2.0)
	screen.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = pink * Color(0.12, 0.12, 0.12, 1.0)
	smat.emission_enabled = true
	smat.emission = pink
	smat.emission_energy_multiplier = 1.4
	screen.material_override = smat
	screen.position = Vector3(cx - 0.47, 2.4, cz)
	add_child(screen)
	_screen_mats.append({ "mat": smat, "color": pink, "phase": randf() * TAU })
	var marquee := Label3D.new()
	marquee.text = "CYBER DANCE"
	marquee.font_size = 100
	marquee.pixel_size = 0.008
	marquee.modulate = pink
	marquee.outline_size = 22
	marquee.outline_modulate = Color(0, 0, 0)
	marquee.position = Vector3(cx - 0.4, 4.05, cz)
	marquee.rotation.y = PI / 2.0
	add_child(marquee)
	_add_interact_area(Vector3(cx + 1.4, 1.2, cz), Vector3(4.0, 2.4, 4.0),
		{ "kind": "flavor",
		  "prompt": "CYBER DANCE",
		  "line": "the pads still chase a beat nobody is dancing to." })


# ═══════════════════════════════════════════════════════════════════════
# DUEL TABLE — 2-player cocktail cabinet in the center
# ═══════════════════════════════════════════════════════════════════════

var _table_mat: StandardMaterial3D

func _build_duel_table() -> void:
	var cx := 2.0
	var cz := 3.0
	var cyan := Color(0.1, 0.95, 1.0)
	# Table body
	_add_box(Vector3(cx, 0.65, cz), Vector3(3.0, 1.3, 2.0),
		Color(0.06, 0.05, 0.09), 0.4, 0.4,
		true, cyan * Color(0.08, 0.08, 0.08, 1.0), 0.5)
	# Upward-facing screen — animated (its own slow color cycle)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(2.2, 0.03, 1.3)
	screen.mesh = sm
	_table_mat = StandardMaterial3D.new()
	_table_mat.albedo_color = cyan * Color(0.12, 0.12, 0.12, 1.0)
	_table_mat.emission_enabled = true
	_table_mat.emission = cyan
	_table_mat.emission_energy_multiplier = 1.6
	screen.material_override = _table_mat
	screen.position = Vector3(cx, 1.33, cz)
	add_child(screen)
	# Up-light from the table screen
	var up := OmniLight3D.new()
	up.position = Vector3(cx, 2.0, cz)
	up.light_color = cyan
	up.light_energy = 1.6
	up.omni_range = 4.0
	add_child(up)
	# Two control edges + stools on opposite sides (2 PLAYER head-to-head)
	for side in [-1.0, 1.0]:
		_add_box(Vector3(cx, 1.28, cz + side * 1.05), Vector3(2.4, 0.08, 0.25),
			Color(0.08, 0.07, 0.11), 0.4, 0.4, true, cyan * Color(0.15, 0.15, 0.15, 1.0), 0.9)
		# Stool
		_add_box(Vector3(cx, 0.4, cz + side * 2.0), Vector3(0.55, 0.8, 0.55),
			Color(0.10, 0.08, 0.14), 0.5, 0.4)
		_add_box(Vector3(cx, 0.84, cz + side * 2.0), Vector3(0.7, 0.08, 0.7),
			Color(0.6, 0.15, 0.45), 0.2, 0.3, true, Color(0.8, 0.2, 0.6), 0.6)
	var marquee := Label3D.new()
	marquee.text = "DUEL TABLE · 2P"
	marquee.font_size = 80
	marquee.pixel_size = 0.008
	marquee.modulate = cyan
	marquee.outline_size = 20
	marquee.outline_modulate = Color(0, 0, 0)
	marquee.position = Vector3(cx, 2.6, cz)
	add_child(marquee)
	_add_interact_area(Vector3(cx, 1.2, cz), Vector3(4.6, 2.4, 5.6),
		{ "kind": "cabinet",
		  "cab": { "id": "pong", "name": "DATA PONG", "game": "pong" } })
	var m := Node3D.new()
	m.name = "from_game_pong"
	m.position = Vector3(cx - 2.8, 0.0, cz)
	add_child(m)


# ═══════════════════════════════════════════════════════════════════════
# EAST SIDE — exit door + vending machine
# ═══════════════════════════════════════════════════════════════════════

func _build_east_side() -> void:
	var dx := ROOM_W / 2.0
	var dz := 4.0
	# Door panel — warm orange spill toward the street
	_add_box(Vector3(dx - 0.06, 1.5, dz), Vector3(0.10, 3.0, 2.0),
		Color(0.05, 0.04, 0.07), 0.4, 0.3,
		true, Color(1.0, 0.55, 0.1), 0.5)
	# DoorGlow rotated for the east wall
	var glow := DoorGlowScript.new()
	glow.color = Color(1.0, 0.6, 0.1)
	glow.opening = Vector2(2.0, 3.0)
	glow.position = Vector3(dx - 0.10, 0.0, dz)
	glow.rotation.y = PI / 2.0
	add_child(glow)
	# Interactable door back to the city
	var door := InteractableDoorScript.new()
	door.scene_id = "arcade"
	door.door_id = "exit_door"
	door.position = Vector3(dx - 1.2, 1.2, dz)
	door.auto_collision_size = Vector3(2.4, 2.4, 2.6)
	door.glow_color = Color(0, 0, 0, 0)   # custom glow above (east wall)
	door.player_entered.connect(func():
		glow.set_active(true)
		_set_status("[E] " + door.label()))
	door.player_exited.connect(func():
		glow.set_active(false)
		_set_status(""))
	add_child(door)
	# Spawn marker for arriving from the city
	var m := Node3D.new()
	m.name = "from_city"
	m.position = Vector3(dx - 2.2, 0.0, dz)
	add_child(m)
	# Vending machine — on the back wall past the cabinets, glowing front
	var vx := 9.5
	var vz := -ROOM_D / 2.0 + WALL_T / 2.0 + 0.8
	_add_box(Vector3(vx, 1.5, vz), Vector3(1.6, 3.0, 1.2),
		Color(0.06, 0.06, 0.10), 0.5, 0.3)
	_add_box(Vector3(vx, 1.7, vz + 0.62), Vector3(1.0, 2.0, 0.04),
		Color(0.1, 0.2, 0.3), 0.2, 0.2, true, Color(0.2, 0.8, 1.2), 1.4)
	for ry in [1.1, 1.7, 2.3]:
		_add_box(Vector3(vx, ry, vz + 0.64), Vector3(0.85, 0.12, 0.03),
			Color(0.8, 0.3, 0.5), 0.2, 0.3, true, Color(1.2, 0.4, 0.7), 1.2)
	var vend_light := OmniLight3D.new()
	vend_light.position = Vector3(vx, 1.4, vz + 1.6)
	vend_light.light_color = Color(0.2, 0.8, 1.2)
	vend_light.light_energy = 1.2
	vend_light.omni_range = 3.5
	add_child(vend_light)
	_add_interact_area(Vector3(vx, 1.2, vz + 1.5), Vector3(2.2, 2.4, 2.2),
		{ "kind": "flavor",
		  "prompt": "VEND-O-TRON",
		  "line": "the vending machine hums. everything inside expired in 2047." })


# ═══════════════════════════════════════════════════════════════════════
# PRIZE COUNTER + CRT STACK — free-standing set dressing
# ═══════════════════════════════════════════════════════════════════════

func _build_prize_counter() -> void:
	# BLACK MARKET — glass counter with glowing contraband, SE open floor
	var cx := 12.0
	var cz := 8.5
	var magenta := Color(1.0, 0.1, 0.65)
	_add_box(Vector3(cx, 0.6, cz), Vector3(5.0, 1.2, 1.6),
		Color(0.07, 0.06, 0.10), 0.4, 0.3)
	# Glass top with neon rim
	_add_box(Vector3(cx, 1.24, cz), Vector3(5.2, 0.06, 1.8),
		Color(0.10, 0.14, 0.18), 0.2, 0.1, true, Color(0.2, 0.5, 0.7), 0.5)
	_add_box(Vector3(cx, 1.30, cz - 0.88), Vector3(5.2, 0.05, 0.05),
		magenta * Color(0.3, 0.3, 0.3, 1.0), 0.0, 0.3, true, magenta, 2.0)
	# Contraband under glass — glowing bits and pieces
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xB14CC
	for i in 5:
		var ox := -1.9 + i * 0.95
		var pc: Color = [Color(0.1, 1.0, 0.6), Color(1.0, 0.8, 0.1),
			Color(0.4, 0.6, 1.2), magenta][rng.randi() % 4]
		_add_box(Vector3(cx + ox, 1.05, cz + rng.randf_range(-0.3, 0.3)),
			Vector3(0.4, 0.15, 0.3), pc * Color(0.3, 0.3, 0.3, 1.0),
			0.2, 0.3, true, pc, 1.2)
	var sign_label := Label3D.new()
	sign_label.text = "BLACK MARKET"
	sign_label.font_size = 90
	sign_label.pixel_size = 0.008
	sign_label.modulate = magenta
	sign_label.outline_size = 20
	sign_label.outline_modulate = Color(0, 0, 0)
	sign_label.position = Vector3(cx, 2.3, cz)
	add_child(sign_label)
	var counter_light := OmniLight3D.new()
	counter_light.position = Vector3(cx, 1.8, cz - 1.2)
	counter_light.light_color = magenta
	counter_light.light_energy = 1.4
	counter_light.omni_range = 4.0
	add_child(counter_light)
	_add_interact_area(Vector3(cx, 1.2, cz - 1.8), Vector3(5.4, 2.4, 2.0),
		{ "kind": "flavor",
		  "prompt": "BLACK MARKET",
		  "line": "the prize guy looks you over. 'win something first, ghost.'" })

func _build_crt_stack() -> void:
	# Tower of three old CRTs, screens cycling channels (faces the camera)
	var cx := 17.5
	var cz := -8.0
	for i in 3:
		var size := 1.5 - i * 0.2
		var y := 0.5 + i * 1.15
		_add_box(Vector3(cx, y, cz), Vector3(size + 0.3, 1.1, size),
			Color(0.05, 0.05, 0.07), 0.5, 0.4)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.03, 0.8, size * 0.75)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.03, 0.08)
		mat.roughness = 0.25
		mat.emission_enabled = true
		mat.emission = TV_CHANNELS[i % TV_CHANNELS.size()].color
		mat.emission_energy_multiplier = 1.0
		mi.material_override = mat
		mi.position = Vector3(cx - (size + 0.3) / 2.0 - 0.02, y, cz)
		add_child(mi)
		var light := OmniLight3D.new()
		light.position = Vector3(cx - 1.4, y, cz)
		light.light_color = TV_CHANNELS[i % TV_CHANNELS.size()].color
		light.light_energy = 0.7
		light.omni_range = 3.0
		add_child(light)
		_tvs.append({ "mat": mat, "light": light,
			"ch": i % TV_CHANNELS.size(), "t": randf() * 3.0,
			"dwell": randf_range(2.5, 6.0) })
	_add_interact_area(Vector3(cx - 1.6, 1.2, cz), Vector3(2.2, 2.4, 2.6),
		{ "kind": "flavor",
		  "prompt": "CRT STACK",
		  "line": "three dead channels stacked into a shrine. one shows only static." })


# ═══════════════════════════════════════════════════════════════════════
# NPCS — Chad hogs the 2P cabinet, Nyx watches, Blitz haunts the racers,
# a drifter feuds with the vending machine. Billboard sprites + dialogue.
# ═══════════════════════════════════════════════════════════════════════

const NPCS := [
	{ "id": "chad", "name": "CHAD", "sheet": "res://assets/sprites/npc-thug.png",
	  "pos": Vector3(2.4, 0, -10.6), "facing": "up",
	  "glow": Color(1.0, 0.85, 0.3) },
	{ "id": "nyx_arcade", "name": "NYX", "sheet": "res://assets/sprites/smoking_drifter.png",
	  "pos": Vector3(4.6, 0, -10.0), "facing": "left",
	  "glow": Color(0.75, 0.35, 1.0) },
	{ "id": "blitz", "name": "BLITZ", "sheet": "res://assets/sprites/npc-cyberpunk.png",
	  "pos": Vector3(-16.2, 0, -1.2), "facing": "left",
	  "glow": Color(1.0, 0.55, 0.1) },
	{ "id": "arcade_drifter", "name": "SCRAPPER",
	  "sheet": "res://assets/sprites/smoking_scrapper.png",
	  "pos": Vector3(11.8, 0, -11.0), "facing": "down",
	  "glow": Color(0.4, 0.7, 0.9) },
]

func _build_npcs() -> void:
	for npc in NPCS:
		var pivot := Node3D.new()
		pivot.position = npc.pos
		add_child(pivot)
		var ab = AnimatedBillboardScript.new()
		ab.show_floor_shadow = false
		ab.pixel_size = 0.04
		pivot.add_child(ab)
		ab.load_sheet(npc.sheet)
		match npc.facing:
			"up": ab.facing = AnimatedBillboardScript.Facing.UP
			"left": ab.facing = AnimatedBillboardScript.Facing.LEFT
			"right": ab.facing = AnimatedBillboardScript.Facing.RIGHT
			_: ab.facing = AnimatedBillboardScript.Facing.DOWN
		ab.set_moving(false)
		# Soft accent light so each NPC reads in the neon murk
		var light := OmniLight3D.new()
		light.position = npc.pos + Vector3(0, 1.0, 0.6)
		light.light_color = npc.glow
		light.light_energy = 0.8
		light.omni_range = 2.4
		light.omni_attenuation = 2.0
		add_child(light)
		_add_interact_area(npc.pos + Vector3(0, 1.2, 0.4),
			Vector3(2.2, 2.4, 2.4),
			{ "kind": "npc", "npc": npc.id, "prompt": npc.name })


# ═══════════════════════════════════════════════════════════════════════
# POSTERS + entrance mat — wall dressing
# ═══════════════════════════════════════════════════════════════════════

func _build_posters() -> void:
	# Neon-framed posters on the back wall, right of the vending machine
	var wall_z := -ROOM_D / 2.0 + WALL_T / 2.0 + 0.06
	var posters := [
		{ "x": 13.5, "c": Color(0.9, 0.2, 0.4), "t": "VOID
INVADERS II" },
		{ "x": 16.5, "c": Color(0.2, 0.9, 0.7), "t": "SIGNAL
HOLLOW" },
	]
	for pdef in posters:
		_add_box(Vector3(pdef.x, 2.6, wall_z), Vector3(2.0, 2.6, 0.06),
			pdef.c * Color(0.10, 0.10, 0.10, 1.0), 0.0, 0.5,
			true, pdef.c, 0.35)
		_add_box(Vector3(pdef.x, 2.6, wall_z + 0.01), Vector3(2.12, 2.72, 0.04),
			pdef.c * Color(0.3, 0.3, 0.3, 1.0), 0.0, 0.3, true, pdef.c, 1.2)
		var t := Label3D.new()
		t.text = pdef.t
		t.font_size = 64
		t.pixel_size = 0.008
		t.modulate = pdef.c * 1.4
		t.outline_size = 16
		t.outline_modulate = Color(0, 0, 0)
		t.position = Vector3(pdef.x, 2.6, wall_z + 0.08)
		add_child(t)
	# Entrance mat inside the door gap — warm welcome strip
	_add_box(Vector3(ROOM_W / 2.0 - 1.8, 0.003, 4.0), Vector3(2.4, 0.012, 2.2),
		Color(0.5, 0.25, 0.05), 0.0, 0.6, true, Color(1.0, 0.55, 0.1), 0.4)
	# Trash can by the prize counter
	_add_box(Vector3(9.0, 0.45, 7.5), Vector3(0.7, 0.9, 0.7),
		Color(0.09, 0.08, 0.12), 0.5, 0.5)
	_add_box(Vector3(9.0, 0.93, 7.5), Vector3(0.75, 0.06, 0.75),
		Color(0.3, 0.5, 0.6), 0.3, 0.3, true, Color(0.2, 0.8, 1.0), 0.5)


# ═══════════════════════════════════════════════════════════════════════
# CEILING + monitor wall
# ═══════════════════════════════════════════════════════════════════════

func _build_ceiling() -> void:
	# Neon rails crossing the room
	_add_box(Vector3(0, ROOM_H - 0.15, -4.0), Vector3(ROOM_W - 4.0, 0.08, 0.08),
		Color(0.4, 0.05, 0.3), 0.0, 0.3, true, Color(1.0, 0.15, 0.7), 2.0)
	_add_box(Vector3(0, ROOM_H - 0.15, 5.0), Vector3(ROOM_W - 4.0, 0.08, 0.08),
		Color(0.05, 0.3, 0.4), 0.0, 0.3, true, Color(0.1, 0.9, 1.1), 2.0)
	# Ceiling omnis in two rows so the floor never goes pitch black
	for lx in [-14.0, -5.0, 4.0, 13.0]:
		for lz in [-6.0, 6.0]:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(lx, ROOM_H - 0.6, lz)
			lamp.light_color = Color(0.62, 0.52, 0.92)
			lamp.light_energy = 2.1
			lamp.omni_range = 13.0
			lamp.omni_attenuation = 1.9
			add_child(lamp)

func _build_wall_tv(pos: Vector3, size: Vector2) -> void:
	# Bezel
	_add_box(pos + Vector3(0, 0, -0.06), Vector3(size.x + 0.25, size.y + 0.25, 0.15),
		Color(0.02, 0.02, 0.03), 0.7, 0.3)
	# Screen with channel-cycling emission (apartment TV trick)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, size.y, 0.03)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.03, 0.08)
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = TV_CHANNELS[0].color
	mat.emission_energy_multiplier = 1.2
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, -0.4, 1.6)
	light.light_color = TV_CHANNELS[0].color
	light.light_energy = 0.9
	light.omni_range = 4.5
	add_child(light)
	_tvs.append({ "mat": mat, "light": light, "ch": randi() % TV_CHANNELS.size(),
		"t": randf() * 3.0, "dwell": randf_range(2.5, 6.0) })


# ═══════════════════════════════════════════════════════════════════════
# INTERACT AREAS — one helper, one _near_zone dict
# ═══════════════════════════════════════════════════════════════════════

func _add_interact_area(pos: Vector3, size: Vector3, zone: Dictionary) -> void:
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
			_show_zone_prompt(zone))
	area.body_exited.connect(func(b):
		if b is CharacterBody3D and _near_zone == zone:
			_near_zone = {}
			_set_status(""))
	add_child(area)

func _show_zone_prompt(zone: Dictionary) -> void:
	match zone.get("kind", ""):
		"cabinet":
			var cab: Dictionary = zone.cab
			if cab.get("game", "") != "":
				var best := GameState.arcade_best(cab.game)
				var hs := ("  ·  best %d" % best) if best > 0 else ""
				_set_status("[E] play " + cab.name + hs)
			else:
				_set_status(cab.name + " — out of order")
		"flavor":
			_set_status("[E] " + zone.get("prompt", "?"))
		"npc":
			_set_status("[E] talk to " + zone.get("prompt", "?"))


# ═══════════════════════════════════════════════════════════════════════
# PLAYER + HUD + spawn
# ═══════════════════════════════════════════════════════════════════════

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.position = Vector3(2.0, 0.85, 6.5)
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
	title.text = "ARCADE"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.8))
	title.position = Vector2(24, 18)
	cl.add_child(title)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_status_label.position = Vector2(24, 40)
	cl.add_child(_status_label)
	var hint := Label.new()
	hint.text = "WASD MOVE · R SPRINT · E INTERACT · I PHONE"
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


# ═══════════════════════════════════════════════════════════════════════
# PROCESS — iso movement, camera follow, attract animations
# ═══════════════════════════════════════════════════════════════════════

func _physics_process(_delta: float) -> void:
	if _player == null:
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

func _process(delta: float) -> void:
	_tick_camera(delta)
	_tick_screens(delta)
	_tick_tvs(delta)
	_tick_ddr(delta)
	_tick_coin(delta)

func _tick_camera(_delta: float) -> void:
	if _camera == null or _player == null:
		return
	var target := _player.global_position + CAMERA_OFFSET
	_camera.global_position = _camera.global_position.lerp(target,
		clampf(_delta * CAMERA_FOLLOW_LERP, 0.0, 1.0))

func _tick_screens(delta: float) -> void:
	_screen_t += delta
	for e in _screen_mats:
		var p: float = _screen_t * 1.8 + e.phase
		var k := 0.5 + 0.5 * sin(p)
		e.mat.emission_energy_multiplier = 1.1 + k * 1.2
		e.mat.emission = e.color.lerp(Color(1, 1, 1), 0.25 * (0.5 + 0.5 * sin(p * 0.37)))
	if _table_mat:
		# Duel table slowly sweeps hue between cyan and magenta
		var t := 0.5 + 0.5 * sin(_screen_t * 0.6)
		_table_mat.emission = Color(0.1, 0.95, 1.0).lerp(Color(1.0, 0.15, 0.7), t)

func _tick_tvs(delta: float) -> void:
	for tv in _tvs:
		tv.t += delta
		if tv.t >= tv.dwell:
			tv.t = 0.0
			tv.ch = (tv.ch + 1) % TV_CHANNELS.size()
			tv.dwell = randf_range(2.5, 6.0)
		var ch: Dictionary = TV_CHANNELS[tv.ch]
		var e: float = ch.energy + sin(tv.t * 18.0) * ch.flicker \
			+ randf_range(-ch.flicker, ch.flicker) * 0.5
		tv.mat.emission = ch.color
		tv.mat.emission_energy_multiplier = maxf(0.1, e)
		tv.light.light_color = ch.color
		tv.light.light_energy = maxf(0.2, 0.9 + sin(tv.t * 12.0) * ch.flicker)

func _tick_ddr(delta: float) -> void:
	_ddr_t += delta
	for i in _ddr_pads.size():
		var on := int(_ddr_t * 3.0) % _ddr_pads.size() == i
		_ddr_pads[i].emission_energy_multiplier = 2.6 if on else 0.5

func _tick_coin(delta: float) -> void:
	_coin_t += delta
	if _coin_label:
		_coin_label.visible = fmod(_coin_t, 1.2) < 0.75


# ═══════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	# The dialogue overlay advances on E itself — and this handler runs
	# BEFORE autoloads, so without the guard E would also re-trigger zones.
	if DialogueOverlay.is_active():
		return
	if event.is_action_pressed("interact") and not _near_zone.is_empty():
		match _near_zone.get("kind", ""):
			"cabinet":
				var cab: Dictionary = _near_zone.cab
				var game: String = cab.get("game", "")
				if game != "":
					SceneTransition.go(game, "")
				else:
					_set_status(cab.get("dead_line", cab.name + " is dead."))
			"flavor":
				_set_status(_near_zone.get("line", "..."))
			"npc":
				DialogueOverlay.play(_near_zone.get("npc", ""))
	elif event.is_action_pressed("ui_cancel"):
		SceneTransition.go("city", "from_arcade")


# ═══════════════════════════════════════════════════════════════════════
# Mesh helper
# ═══════════════════════════════════════════════════════════════════════

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
