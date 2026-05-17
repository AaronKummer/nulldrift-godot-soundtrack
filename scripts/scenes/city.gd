## City — ONE hand-detailed block.
##
## Aaron's spec: "one block. one city block. should be massive. several stores.
## puddles, manhole covers etc."
##
## Approach: hand-place everything. No procedural generation. Real textures
## (concrete asphalt, metal-brushed walls, metal-rust accents), real
## OmniLight3D + SpotLight3D fixtures, scifi-asset Environment recipe.
## 6 storefronts visible from the sidewalk, each with its own color identity.
## Detail props: puddles (low-roughness reflective planes), manhole covers,
## trash bins, fire hydrants, ATM, food cart.
##
## Camera: 3/4 view (~28° pitch), NOT iso. Player ~1/8 screen height.
extends Node3D

const SceneGraphData            := preload("res://data/scene_graph.gd")
const InteractableDoorScript    := preload("res://scripts/systems/interactable_door.gd")
const AnimatedBillboardScript   := preload("res://scripts/systems/animated_billboard.gd")

# ─── Camera: 3/4 view, lower-pitch than apartment iso ────────────────────
const CAMERA_OFFSET      := Vector3(0.0, 14.0, 24.0)
const CAMERA_AIM_OFFSET  := Vector3(0.0, 2.0, -2.0)
const CAMERA_FOLLOW_LERP := 6.0
const CAMERA_ORTHO_SIZE  := 40.0

# ─── Block layout ────────────────────────────────────────────────────────
# Long block running east-west. Player walks ~120m to reach the end.
const BLOCK_LENGTH  := 120.0
const ROAD_WIDTH    := 22.0
const SIDEWALK_W    := 5.0
const BLOCK_HALF_W  := BLOCK_LENGTH * 0.5

# ─── Storefronts: each at a fixed X along the block, hand-designed ───────
# Real generated neon sign textures applied as emissive panels. The "sign"
# color drives the per-store omni back-glow. The "sign_aspect" is the
# image w/h ratio — diner/pet/bar/guns are 1:1, comics/arcade are 3:2.
const STOREFRONTS := [
	{ "id": "diner",   "x": -50.0, "label": "DINER",
	  "tex":  "res://assets/world/signs/diner.png",
	  "sign": Color(1.0, 0.55, 0.15), "awning": Color(0.50, 0.10, 0.15),
	  "sign_w": 4.6, "sign_h": 4.6 },
	{ "id": "pet",     "x": -28.0, "label": "PET",
	  "tex":  "res://assets/world/signs/pet.png",
	  "sign": Color(1.0, 0.20, 0.55), "awning": Color(0.25, 0.50, 0.30),
	  "sign_w": 4.4, "sign_h": 4.4 },
	{ "id": "comics",  "x":  -4.0, "label": "COMICS",
	  "tex":  "res://assets/world/signs/comics.png",
	  "sign": Color(0.30, 0.85, 1.0), "awning": Color(0.10, 0.30, 0.45),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "bar",     "x":  22.0, "label": "BAR",
	  "tex":  "res://assets/world/signs/bar.png",
	  "sign": Color(1.0, 0.20, 0.85), "awning": Color(0.45, 0.10, 0.30),
	  "sign_w": 4.4, "sign_h": 4.4 },
	{ "id": "guns",    "x":  44.0, "label": "GUNS+",
	  "tex":  "res://assets/world/signs/guns.png",
	  "sign": Color(1.0, 0.20, 0.10), "awning": Color(0.30, 0.10, 0.10),
	  "sign_w": 4.4, "sign_h": 4.4 },
	{ "id": "arcade",  "x":  64.0, "label": "ARCADE",
	  "tex":  "res://assets/world/signs/arcade.png",
	  "sign": Color(0.85, 0.40, 1.0), "awning": Color(0.30, 0.10, 0.55),
	  "sign_w": 6.6, "sign_h": 4.4 },
]

# ─── State ──────────────────────────────────────────────────────────────
var _camera: Camera3D
var _env: Environment
var _player: CharacterBody3D
var _player_anim
var _status_label: Label
var _near_store: Dictionary = {}
var _store_zones: Array = []
var _camera_locked_rotation: Vector3 = Vector3.ZERO
var _npcs: Array = []          # walking pedestrians [{node, ab, dir, speed, x_min, x_max}]
var _cars: Array = []          # driving cars [{node, speed}]


func _ready() -> void:
	_setup_camera()
	_setup_environment()
	_build_ground()
	_build_buildings_north_side()
	_build_buildings_south_side()
	_build_alley()                 # NEW — cut between storefronts
	_build_sidewalk_props()
	_build_ac_units_and_grime()    # NEW — facade detail
	_build_streetlamps()
	_build_atm_scene()
	_build_food_cart()
	_build_puddles_and_manholes()
	# Steam puff particles temporarily disabled — they were rendering as
	# tall stacks of square quads (each particle = hard-alpha QuadMesh).
	# Needs a soft circular alpha texture before re-enabling.
	# _build_steam_from_manholes()
	_build_storefront_interactables()
	_build_walking_npcs()          # pedestrians
	_build_cars()                  # cars driving the road, headlight beams
	_build_player()
	_build_hud()
	_apply_pending_spawn()
	Music.play_category("city")


# ─────────────────────────────────────────────────────────────────────────
# CAMERA + ENVIRONMENT — scifi-asset recipe (proven look)
# ─────────────────────────────────────────────────────────────────────────

func _setup_camera() -> void:
	# IMPORTANT: set rotation ONCE here, NEVER call look_at again during
	# _process. Per-frame look_at causes the screen to subtly rotate as the
	# camera lerps to the player position. Same gotcha bit apartment.gd.
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_ORTHO_SIZE
	_camera.near = 0.05
	_camera.far = 400.0
	_camera.current = true
	add_child(_camera)
	_camera.position = CAMERA_OFFSET
	_camera.look_at(CAMERA_AIM_OFFSET, Vector3.UP)
	# Cache the rotation so the camera never re-rotates as it follows
	_camera_locked_rotation = _camera.rotation

func _setup_environment() -> void:
	_env = Environment.new()
	# Procedural sky — deep purple dusk
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.015, 0.010, 0.040)
	sky_mat.sky_horizon_color = Color(0.18, 0.04, 0.18)
	sky_mat.sky_curve = 0.10
	sky_mat.ground_horizon_color = Color(0.05, 0.02, 0.08)
	sky_mat.ground_bottom_color = Color(0.005, 0.005, 0.015)
	sky.sky_material = sky_mat
	_env.sky = sky

	# Glow — toned down so neon glows but doesn't blow to white
	_env.glow_enabled = true
	_env.glow_intensity = 0.4
	_env.glow_strength = 1.0
	_env.glow_bloom = 0.10
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.glow_hdr_threshold = 1.5
	_env.set("glow_levels/2", true)
	_env.set("glow_levels/4", true)

	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 1.05

	# Darker ambient — neon-drenched city should be lit by the SIGNS, not
	# by ambient. Lowered from 1.1 → 0.65 so emissives carry the look.
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.18, 0.16, 0.28)
	_env.ambient_light_energy = 0.65

	_env.ssao_enabled = true
	_env.ssao_radius = 1.4
	_env.ssao_intensity = 1.6

	_env.fog_enabled = true
	_env.fog_density = 0.003
	_env.fog_light_color = Color(0.18, 0.08, 0.28)
	_env.fog_light_energy = 0.6
	_env.fog_aerial_perspective = 0.35

	# Volumetric fog — the magic. Streetlamp cones cut through it.
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.035
	_env.volumetric_fog_albedo = Color(0.55, 0.30, 0.65)
	_env.volumetric_fog_anisotropy = 0.3
	_env.volumetric_fog_length = 60.0
	_env.volumetric_fog_ambient_inject = 0.4

	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	# Moonlight — subtle cool blue from above-east. Dialed back from 0.7
	# → 0.35 because v14 read as "too blue / too light". Real surfaces
	# get most of their light from the neon signs, lamps, and car beams.
	var moonlight := DirectionalLight3D.new()
	moonlight.light_color = Color(0.50, 0.55, 0.85)
	moonlight.light_energy = 0.35
	moonlight.shadow_enabled = true
	moonlight.rotation_degrees = Vector3(-55, -20, 0)
	add_child(moonlight)

	# SSR disabled — view-dependent reflections in the wet road were
	# making streetlamp highlights "bend" toward the player as the camera
	# moved. For a top-down/3-4 view where lights should appear static,
	# SSR is the wrong tool. Puddles still read as wet via low-roughness
	# specular without it.
	_env.ssr_enabled = false


# ─────────────────────────────────────────────────────────────────────────
# GROUND — road + sidewalks. Real concrete texture, wet sheen on asphalt.
# ─────────────────────────────────────────────────────────────────────────

func _build_ground() -> void:
	# Asphalt road — dark, slightly metallic, low-roughness (wet look)
	var road := StaticBody3D.new()
	road.position = Vector3(0, 0, ROAD_WIDTH * 0.5)
	add_child(road)
	var road_mi := MeshInstance3D.new()
	var road_mesh := BoxMesh.new()
	road_mesh.size = Vector3(BLOCK_LENGTH + 60, 0.1, ROAD_WIDTH)
	road_mi.mesh = road_mesh
	var road_mat := StandardMaterial3D.new()
	# Matte asphalt — no glossy specular that would slide across the road
	# as the camera moves. Top-down view needs static lighting.
	road_mat.albedo_color = Color(0.05, 0.05, 0.07)
	road_mat.metallic = 0.0
	road_mat.roughness = 0.85
	road_mat.metallic_specular = 0.15
	road_mi.material_override = road_mat
	road.add_child(road_mi)
	var rc := CollisionShape3D.new()
	var rs := BoxShape3D.new(); rs.size = road_mesh.size
	rc.shape = rs
	road.add_child(rc)

	# Yellow center-line dashes — emissive, BIGGER + brighter so they read
	var t := -BLOCK_HALF_W - 20
	while t < BLOCK_HALF_W + 20:
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(4.0, 0.04, 0.45)
		dash.mesh = dm
		var dmat := StandardMaterial3D.new()
		dmat.albedo_color = Color(0.7, 0.55, 0.08)
		dmat.emission_enabled = true
		dmat.emission = Color(1.0, 0.85, 0.18)
		dmat.emission_energy_multiplier = 2.0
		dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dash.material_override = dmat
		dash.position = Vector3(t, 0.06, ROAD_WIDTH * 0.5)
		dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dash)
		t += 5.5

	# Sidewalks — north + south of road. Concrete-textured.
	var concrete_tex := load("res://assets/world/textures/concrete/albedo.png") as Texture2D
	var concrete_normal := load("res://assets/world/textures/concrete/normal.png") as Texture2D
	var concrete_rough := load("res://assets/world/textures/concrete/roughness.png") as Texture2D
	for sz_dir in [-1, 1]:
		var sb := StaticBody3D.new()
		var sw_z: float
		if sz_dir < 0:
			sw_z = -SIDEWALK_W * 0.5
		else:
			sw_z = ROAD_WIDTH + SIDEWALK_W * 0.5
		sb.position = Vector3(0, 0.10, sw_z)
		add_child(sb)
		var smi := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(BLOCK_LENGTH + 60, 0.2, SIDEWALK_W)
		smi.mesh = sm
		var smat := StandardMaterial3D.new()
		# Brighter concrete tint so the sidewalk reads against the dark road
		smat.albedo_color = Color(0.40, 0.40, 0.48)
		if concrete_tex:
			smat.albedo_texture = concrete_tex
		if concrete_normal:
			smat.normal_enabled = true
			smat.normal_texture = concrete_normal
		if concrete_rough:
			smat.roughness_texture = concrete_rough
		smat.uv1_scale = Vector3(BLOCK_LENGTH / 4.0, 1.0, SIDEWALK_W / 4.0)
		smat.metallic = 0.05
		smat.roughness = 0.85
		smi.material_override = smat
		sb.add_child(smi)
		var sc := CollisionShape3D.new()
		var ss := BoxShape3D.new(); ss.size = sm.size
		sc.shape = ss
		sb.add_child(sc)
		# Curb edge accent — brighter cyan emissive so the curb line reads
		var curb := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(BLOCK_LENGTH + 60, 0.08, 0.14)
		curb.mesh = cm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.20, 0.30, 0.40)
		cmat.emission_enabled = true
		cmat.emission = Color(0.10, 0.40, 0.55)
		cmat.emission_energy_multiplier = 0.6
		curb.material_override = cmat
		curb.position = Vector3(0, 0.16, (-SIDEWALK_W * 0.5 + 0.05) if sz_dir < 0 else (SIDEWALK_W * 0.5 - 0.05))
		sb.add_child(curb)


# ─────────────────────────────────────────────────────────────────────────
# BUILDINGS — hand-placed, varied widths/heights. North side is the
# back wall behind storefronts. South side is across the street.
# ─────────────────────────────────────────────────────────────────────────

func _build_buildings_north_side() -> void:
	# Tall continuous wall of buildings BEHIND the storefronts (storefronts
	# are the FRONT — buildings tower above + behind them).
	var bx := -BLOCK_HALF_W
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC177101
	while bx < BLOCK_HALF_W:
		var bw := rng.randf_range(14.0, 24.0)
		var bh := rng.randf_range(14.0, 26.0)
		var bz := -SIDEWALK_W - bw * 0.0 - 4.0   # set back behind the storefront facades
		_build_one_building(Vector3(bx + bw * 0.5, 0, -SIDEWALK_W - 4.0),
			Vector3(bw, bh, 8.0), rng, true)
		bx += bw

func _build_buildings_south_side() -> void:
	# DISABLED. The previous south-side buildings sat at z=+23 which put
	# the camera (at z=+20) *inside* one of them — the building's west
	# wall occluded the player and the near-face windows projected to
	# the bottom of the frame looking like square lights on the sidewalk.
	# A FAR distant skyline strip far behind the block would be a future
	# add, but no nearby south-side geometry for now.
	pass

func _build_one_building(pos: Vector3, size: Vector3,
		rng: RandomNumberGenerator, is_north_side: bool) -> void:
	# Body — bumped slightly brighter so silhouettes read against the sky
	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, size.y * 0.5, 0)
	add_child(body)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	var hue := rng.randf_range(0.0, 0.05)
	# Was (0.06, 0.05, 0.10) — barely visible. Bumped so the wall surface
	# reads as a real building face instead of disappearing into the void.
	mat.albedo_color = Color(0.22 + hue, 0.18, 0.30 + hue)
	mat.metallic = 0.1
	mat.roughness = 0.7
	mi.material_override = mat
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new(); cs.size = size
	col.shape = cs
	body.add_child(col)

	# Rooftop dark trim
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(size.x + 0.2, 0.3, size.z + 0.2)
	roof.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.03, 0.025, 0.05)
	roof.material_override = rmat
	roof.position = pos + Vector3(0, size.y + 0.15, 0)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roof)

	# Window grid on the FRONT face (facing the street). Real spacing,
	# warm + occasional cyan, ~40% lit.
	var front_face_z: float = pos.z + size.z * 0.5 + 0.05
	if not is_north_side:
		front_face_z = pos.z - size.z * 0.5 - 0.05
	var step_x := 2.8
	var step_y := 3.2
	var cols: int = max(2, int((size.x - 1.0) / step_x))
	var rows: int = max(3, int((size.y - 2.5) / step_y))
	var x0 := pos.x - size.x * 0.5 + (size.x - (cols - 1) * step_x) * 0.5
	var y0 := 2.5 + (size.y - 3.0 - (rows - 1) * step_y) * 0.5
	# Each window = 3 nested layers giving architectural depth:
	#   1. Outer metallic frame (slightly lighter than wall)
	#   2. Recessed dark inset behind the frame
	#   3. Smaller lit pane (only if window is "lit") emitting from inside
	# This reads as a real window inset in a wall, not an LCD pixel.
	var win_w := 1.5
	var win_h := 1.9
	for cx in cols:
		for ry in rows:
			var lit := rng.randf() < 0.42
			var wx := x0 + cx * step_x
			var wy := y0 + ry * step_y

			# 1) Outer frame — thin metallic rim
			var frame_mi := MeshInstance3D.new()
			var fm := BoxMesh.new()
			fm.size = Vector3(win_w + 0.18, win_h + 0.18, 0.08)
			frame_mi.mesh = fm
			var fmat := StandardMaterial3D.new()
			fmat.albedo_color = Color(0.25, 0.23, 0.30)
			fmat.metallic = 0.6
			fmat.roughness = 0.4
			frame_mi.material_override = fmat
			frame_mi.position = Vector3(wx, wy, front_face_z + 0.02)
			frame_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(frame_mi)

			# 2) Dark recessed inset (gives depth)
			var inset_mi := MeshInstance3D.new()
			var im := BoxMesh.new()
			im.size = Vector3(win_w, win_h, 0.06)
			inset_mi.mesh = im
			var imat := StandardMaterial3D.new()
			imat.albedo_color = Color(0.02, 0.02, 0.03)
			imat.metallic = 0.0
			imat.roughness = 0.8
			inset_mi.material_override = imat
			inset_mi.position = Vector3(wx, wy, front_face_z - 0.03)
			inset_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(inset_mi)

			# 3) Lit pane — only if the window is "on". Add real variety so
			# the city isn't all warm yellow.
			if lit:
				# Palette: 60% warm yellow (regular apartments), 18% cool
				# white-blue (TVs/screens), 10% magenta, 6% green, 6% red
				var roll := rng.randf()
				var color: Color
				if roll < 0.60:
					color = Color(1.0, 0.78, 0.30)   # warm
				elif roll < 0.78:
					color = Color(0.55, 0.78, 1.0)   # screen blue-white
				elif roll < 0.88:
					color = Color(0.95, 0.30, 0.85)  # magenta
				elif roll < 0.94:
					color = Color(0.40, 0.95, 0.50)  # green
				else:
					color = Color(1.0, 0.25, 0.30)   # red
				var lit_mi := MeshInstance3D.new()
				var lm := BoxMesh.new()
				lm.size = Vector3(win_w * 0.78, win_h * 0.78, 0.04)
				lit_mi.mesh = lm
				var lmat := StandardMaterial3D.new()
				lmat.albedo_color = color * Color(0.30, 0.30, 0.30, 1.0)
				lmat.emission_enabled = true
				lmat.emission = color
				lmat.emission_energy_multiplier = 0.85
				lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				lit_mi.material_override = lmat
				lit_mi.position = Vector3(wx, wy, front_face_z + 0.01)
				lit_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(lit_mi)
				# 12% of lit windows get an occupant SILHOUETTE — a tiny
				# darker rectangle inside, suggesting a person in the room
				if rng.randf() < 0.12:
					var sil_mi := MeshInstance3D.new()
					var sm := BoxMesh.new()
					sm.size = Vector3(win_w * 0.16, win_h * 0.55, 0.02)
					sil_mi.mesh = sm
					var smat := StandardMaterial3D.new()
					smat.albedo_color = Color(0.04, 0.04, 0.06)
					smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					sil_mi.material_override = smat
					var sil_off_x := rng.randf_range(-win_w * 0.20, win_w * 0.20)
					sil_mi.position = Vector3(wx + sil_off_x,
						wy - win_h * 0.10, front_face_z + 0.025)
					sil_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					add_child(sil_mi)


# ─────────────────────────────────────────────────────────────────────────
# STOREFRONTS — hand-placed. Awning + glowing sign + door + light pool.
# ─────────────────────────────────────────────────────────────────────────

func _build_storefront_interactables() -> void:
	for def in STOREFRONTS:
		_build_one_storefront(def)
		_store_zones.append(def)
	# Rooftop hero billboard — TACO neon. Lowered + shrunk so it fits in
	# the 3/4-view camera frame (was y=18, getting clipped at top).
	_build_textured_sign(Vector3(18.0, 12.0, -7.0), Vector2(6.5, 6.5),
		"res://assets/world/signs/billboard_taco.png", Color(1.0, 0.45, 0.10))

func _build_one_storefront(def: Dictionary) -> void:
	# Integrated facade: building section + door + window display + awning +
	# textured neon sign, all visually unified.
	var x: float = def.x
	var facade_w := 8.0
	var facade_h := 9.0
	var face_z := -SIDEWALK_W - 0.5     # building front face Z
	var into_z := -SIDEWALK_W + 0.0     # awning / sign reach toward street

	# 1) Building section body — darker than generic north wall so it pops
	_add_box(Vector3(x, facade_h * 0.5, face_z),
		Vector3(facade_w, facade_h, 1.4),
		Color(0.045, 0.04, 0.075), 0.10, 0.6)

	# 2) Window display (glass plate at eye height, lit interior visible)
	#    Width covers most of the facade; door cuts into the right portion.
	var win_w := 4.5
	var win_h := 2.6
	var win_y := 1.8
	var win_z := face_z + 0.72
	# Glass — emissive in the sign's color, low-roughness reflective
	_add_box(Vector3(x - 1.4, win_y, win_z),
		Vector3(win_w, win_h, 0.04),
		def.sign * Color(0.18, 0.18, 0.18, 1.0), 0.4, 0.10,
		true, def.sign, 0.55)
	# Window frame
	for fx in [x - 1.4 - win_w * 0.5 - 0.08, x - 1.4 + win_w * 0.5 + 0.08]:
		_add_box(Vector3(fx, win_y, win_z),
			Vector3(0.12, win_h + 0.18, 0.18),
			Color(0.20, 0.18, 0.22), 0.5, 0.4)
	_add_box(Vector3(x - 1.4, win_y + win_h * 0.5 + 0.08, win_z),
		Vector3(win_w + 0.2, 0.12, 0.18),
		Color(0.20, 0.18, 0.22), 0.5, 0.4)
	_add_box(Vector3(x - 1.4, win_y - win_h * 0.5 - 0.08, win_z),
		Vector3(win_w + 0.2, 0.12, 0.18),
		Color(0.20, 0.18, 0.22), 0.5, 0.4)
	# 2b) Interior props inside the window — silhouettes that hint at the store
	_build_window_display(def, Vector3(x - 1.4, win_y, win_z + 0.10))

	# 3) Door — to the right of the window, smaller, warm interior glow
	var door_x := x + 2.4
	var door_y := 1.55
	_add_box(Vector3(door_x, door_y, win_z),
		Vector3(1.6, 3.0, 0.10),
		Color(0.12, 0.10, 0.06), 0.3, 0.4,
		true, Color(1.0, 0.75, 0.30), 0.8)
	# Door inner darker pane
	_add_box(Vector3(door_x, door_y, win_z + 0.06),
		Vector3(1.2, 2.5, 0.02),
		Color(0.03, 0.03, 0.04), 0.0, 0.6)
	# Door frame
	for fx in [door_x - 0.85, door_x + 0.85]:
		_add_box(Vector3(fx, door_y, win_z + 0.02),
			Vector3(0.12, 3.1, 0.16),
			Color(0.22, 0.22, 0.26), 0.7, 0.4)
	# Door handle (warm)
	_add_box(Vector3(door_x + 0.65, door_y - 0.1, win_z + 0.10),
		Vector3(0.06, 0.16, 0.05),
		Color(0.7, 0.55, 0.20), 0.6, 0.3,
		true, Color(1.0, 0.85, 0.40), 1.8, false)

	# 4) Awning across the top of the facade — colored stripes feel
	var awning_y := facade_h * 0.5 + 1.5    # 1.5m above mid-height of facade
	awning_y = min(awning_y, 5.0)
	_add_box(Vector3(x, awning_y, win_z + 0.6),
		Vector3(facade_w - 0.3, 0.30, 1.0),
		def.awning, 0.1, 0.4)
	# Awning stripes (lighter band on top)
	_add_box(Vector3(x, awning_y + 0.15, win_z + 0.6),
		Vector3(facade_w - 0.3, 0.06, 1.02),
		def.awning * Color(1.5, 1.5, 1.5, 1.0), 0.1, 0.4)
	# Hanging chain lights below the awning (warm dots)
	for i in 5:
		var t: float = (i + 0.5) / 5.0
		var lx := x - facade_w * 0.5 + 0.5 + t * (facade_w - 1.0)
		_add_box(Vector3(lx, awning_y - 0.30, win_z + 0.95),
			Vector3(0.08, 0.08, 0.08),
			Color(1.0, 0.85, 0.30) * Color(0.2, 0.2, 0.2, 1.0), 0.0, 0.3,
			true, Color(1.0, 0.85, 0.30), 2.5, false)

	# 5) Textured neon sign — mounted ABOVE the awning, big
	var sign_w: float = def.sign_w
	var sign_h: float = def.sign_h
	var sign_y: float = awning_y + 0.4 + sign_h * 0.5
	_build_textured_sign(Vector3(x, sign_y, win_z + 0.05),
		Vector2(sign_w, sign_h), def.tex, def.sign)

	# 6) Sidewalk light pool below the door
	var pool := OmniLight3D.new()
	pool.position = Vector3(door_x, 0.6, win_z + 1.2)
	pool.light_color = Color(1.0, 0.78, 0.40)   # warm door spill
	pool.light_energy = 1.6
	pool.omni_range = 3.0
	pool.omni_attenuation = 2.2
	add_child(pool)
	# Sign-color back-glow (paints the awning + facade in the sign's hue)
	var back := OmniLight3D.new()
	back.position = Vector3(x, awning_y - 0.2, win_z + 0.4)
	back.light_color = def.sign
	back.light_energy = 1.2
	back.omni_range = 4.0
	back.omni_attenuation = 2.0
	add_child(back)

	# 7) Interactable trigger area in front of the door
	var area := Area3D.new()
	area.position = Vector3(door_x, 1.0, win_z + 1.8)
	var ac := CollisionShape3D.new()
	var as_ := BoxShape3D.new()
	as_.size = Vector3(2.4, 2.4, 2.5)
	ac.shape = as_
	area.add_child(ac)
	area.body_entered.connect(func(b): _on_store_near(def, b))
	area.body_exited.connect(func(b): _on_store_far(def, b))
	add_child(area)


## Per-store window display: a few silhouette props inside the lit glass
## window, hinting at what's sold inside.
func _build_window_display(def: Dictionary, win_center: Vector3) -> void:
	var kind: String = def.id
	if kind == "pet":
		# Fishtank silhouette: blue glow rectangle + 3 fish blobs
		_add_box(win_center + Vector3(-0.9, -0.4, -0.05),
			Vector3(1.6, 1.2, 0.04),
			Color(0.05, 0.20, 0.40), 0.0, 0.3,
			true, Color(0.15, 0.45, 0.95), 1.6, false)
		for i in 3:
			var fy := -0.6 + i * 0.20
			_add_box(win_center + Vector3(-0.9 - 0.2 + i * 0.30, fy, -0.04),
				Vector3(0.12, 0.06, 0.02),
				Color(0.95, 0.50, 0.10), 0.0, 0.3,
				true, Color(1.0, 0.60, 0.20), 1.4, false)
	elif kind == "comics":
		# Stack of comic covers — bright color rectangles
		var ccols := [Color(1.0, 0.85, 0.3), Color(1.0, 0.20, 0.85), Color(0.30, 0.85, 1.0)]
		for i in 3:
			_add_box(win_center + Vector3(-1.2 + i * 0.55, -0.3 + i * 0.08, -0.04),
				Vector3(0.42, 0.62, 0.06),
				ccols[i], 0.0, 0.3,
				true, ccols[i], 0.6, false)
	elif kind == "bar":
		# Liquor-bottle silhouettes glowing softly
		for i in 5:
			var bx := -1.5 + i * 0.55
			_add_box(win_center + Vector3(bx, -0.5, -0.04),
				Vector3(0.18, 0.7, 0.06),
				Color(0.30, 0.10, 0.05), 0.4, 0.4,
				true, Color(0.55, 0.20, 0.12), 0.7, false)
	elif kind == "diner":
		# Booth seats + counter — orange/red silhouettes
		_add_box(win_center + Vector3(-1.4, -0.7, -0.04),
			Vector3(0.8, 0.4, 0.04),
			Color(0.55, 0.10, 0.10), 0.0, 0.5)
		_add_box(win_center + Vector3(0.2, -0.7, -0.04),
			Vector3(0.8, 0.4, 0.04),
			Color(0.55, 0.10, 0.10), 0.0, 0.5)
		# Hanging fixture lights (yellow dots)
		for i in 3:
			_add_box(win_center + Vector3(-1.2 + i * 0.60, 0.4, -0.04),
				Vector3(0.10, 0.10, 0.04),
				Color(1.0, 0.85, 0.30), 0.0, 0.3,
				true, Color(1.0, 0.85, 0.30), 2.0, false)
	elif kind == "guns":
		# Dark interior with red weapon silhouettes
		_add_box(win_center + Vector3(-0.6, -0.2, -0.04),
			Vector3(1.4, 0.18, 0.04),
			Color(0.20, 0.05, 0.05), 0.4, 0.4)
		_add_box(win_center + Vector3(0.8, -0.5, -0.04),
			Vector3(0.9, 0.14, 0.04),
			Color(0.20, 0.05, 0.05), 0.4, 0.4)
	elif kind == "arcade":
		# Cabinet silhouettes glowing magenta
		for i in 3:
			_add_box(win_center + Vector3(-1.2 + i * 0.85, -0.2, -0.04),
				Vector3(0.55, 1.4, 0.06),
				Color(0.10, 0.05, 0.20), 0.3, 0.4,
				true, Color(0.85, 0.30, 1.0), 0.5, false)

## Build a textured emissive sign panel at the given world position.
## The texture's bright pixels emit; dark pixels stay dark. Perfect for
## a black-bg neon sign PNG. Backed by a small back-glow OmniLight in the
## sign's dominant color to spill onto the building face.
func _build_textured_sign(pos: Vector3, size: Vector2, tex_path: String,
		dominant: Color) -> void:
	var tex := load(tex_path) as Texture2D
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.emission_enabled = true
	mat.emission_texture = tex
	mat.emission = Color(1, 1, 1)
	# Lower energy so the sign reads as ART (the neon strokes are visible
	# against the near-black background) instead of bloomed to white solid.
	mat.emission_energy_multiplier = 0.9
	mat.metallic = 0.0
	mat.roughness = 0.6
	# Unshaded so the texture isn't darkened by lack of light hitting it.
	# The image already has its own "lighting" baked in via neon vs black.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Make it face the camera direction (toward +Z roughly — out into the street)
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# QuadMesh default normal is +Z. We want the sign facing +Z (toward street).
	# Storefronts are on the north side at z < 0 facing toward +Z, so default works.
	add_child(mi)

	# Back-glow light — paints the building face in the sign's dominant hue
	var back := OmniLight3D.new()
	back.position = pos + Vector3(0, 0, 0.6)
	back.light_color = dominant
	back.light_energy = 1.0
	back.omni_range = 4.5
	back.omni_attenuation = 2.0
	add_child(back)

func _on_store_near(def: Dictionary, body: Node) -> void:
	if body is CharacterBody3D:
		_near_store = def
		_set_status("[E] enter " + def.label)

func _on_store_far(def: Dictionary, body: Node) -> void:
	if body is CharacterBody3D and _near_store.get("id", "") == def.id:
		_near_store = {}
		_set_status("")


# ─────────────────────────────────────────────────────────────────────────
# ATM scene + food cart (scripted points of interest)
# ─────────────────────────────────────────────────────────────────────────

func _build_atm_scene() -> void:
	# ATM with COP CHASING HACKER mid-action — Aaron's "first scene" hook.
	var ax := -75.0
	# Cabinet
	_add_box(Vector3(ax, 1.5, -SIDEWALK_W + 0.3),
		Vector3(1.4, 3.0, 0.6),
		Color(0.05, 0.05, 0.08), 0.5, 0.4)
	# Screen — cyan emissive (HACKED reads in the texture later)
	_add_box(Vector3(ax, 2.4, -SIDEWALK_W + 0.05),
		Vector3(1.0, 0.8, 0.04),
		Color(0.04, 0.10, 0.18), 0.0, 0.2,
		true, Color(0.0, 1.0, 1.2), 2.0)
	# Keypad
	_add_box(Vector3(ax, 1.6, -SIDEWALK_W + 0.05),
		Vector3(0.7, 0.4, 0.04),
		Color(0.12, 0.12, 0.16), 0.4, 0.3)
	# Cyan light pool from the screen
	var atm_light := OmniLight3D.new()
	atm_light.position = Vector3(ax, 1.0, -SIDEWALK_W + 1.0)
	atm_light.light_color = Color(0.2, 0.9, 1.0)
	atm_light.light_energy = 1.4
	atm_light.omni_range = 3.5
	atm_light.omni_attenuation = 2.0
	add_child(atm_light)

	# HACKER NPC — orange-coverall scrapper sprite, positioned IN FRONT of ATM
	# (still touching it — caught mid-action)
	var hacker_pivot := Node3D.new()
	hacker_pivot.position = Vector3(ax + 0.9, 0, -SIDEWALK_W + 0.9)
	add_child(hacker_pivot)
	var hacker_ab = AnimatedBillboardScript.new()
	hacker_ab.show_floor_shadow = false
	hacker_ab.pixel_size = 0.04
	hacker_ab.position = Vector3(0, 0, 0)
	hacker_pivot.add_child(hacker_ab)
	hacker_ab.load_sheet("res://assets/sprites/npc-cyberpunk.png")
	hacker_ab.facing = AnimatedBillboardScript.Facing.LEFT  # facing the ATM
	hacker_ab.set_moving(false)

	# COP NPC — drifter sprite (dark hooded), approaching from the WEST
	var cop_pivot := Node3D.new()
	cop_pivot.position = Vector3(ax - 4.5, 0, -SIDEWALK_W + 1.5)
	add_child(cop_pivot)
	var cop_ab = AnimatedBillboardScript.new()
	cop_ab.show_floor_shadow = false
	cop_ab.pixel_size = 0.04
	cop_ab.position = Vector3(0, 0, 0)
	cop_pivot.add_child(cop_ab)
	cop_ab.load_sheet("res://assets/sprites/npc-cop.png")
	cop_ab.facing = AnimatedBillboardScript.Facing.RIGHT  # facing toward hacker
	cop_ab.set_moving(false)

	# Cop's flashlight spotlight beam — points at the hacker, cuts through fog
	var beam := SpotLight3D.new()
	beam.position = cop_pivot.position + Vector3(0, 1.6, 0)
	beam.look_at_from_position(beam.position,
		hacker_pivot.position + Vector3(0, 1.0, 0), Vector3.UP)
	beam.light_color = Color(1.0, 0.95, 0.85)
	beam.light_energy = 5.0
	beam.spot_range = 7.0
	beam.spot_angle = 25.0
	beam.spot_attenuation = 1.3
	add_child(beam)

	# Red emergency strobe at the cop's feet (siren)
	var siren := OmniLight3D.new()
	siren.position = cop_pivot.position + Vector3(0, 0.4, 0)
	siren.light_color = Color(1.0, 0.20, 0.20)
	siren.light_energy = 2.2
	siren.omni_range = 3.5
	siren.omni_attenuation = 2.0
	add_child(siren)

func _build_food_cart() -> void:
	# Food cart at x=+34 on the sidewalk
	var fx := 34.0
	# Cart body
	_add_box(Vector3(fx, 0.9, -SIDEWALK_W + 1.2),
		Vector3(3.2, 1.4, 1.8),
		Color(0.45, 0.10, 0.12), 0.3, 0.5)
	# Awning over cart
	_add_box(Vector3(fx, 2.4, -SIDEWALK_W + 1.2),
		Vector3(3.6, 0.10, 2.2),
		Color(1.0, 0.85, 0.20), 0.0, 0.3,
		true, Color(1.0, 0.85, 0.30), 1.5)
	# Cart sign (Chinese-style vertical neon)
	_add_box(Vector3(fx - 1.5, 1.8, -SIDEWALK_W + 1.95),
		Vector3(0.08, 1.6, 0.08),
		Color(0.5, 0.05, 0.20), 0.0, 0.3,
		true, Color(1.0, 0.20, 0.45), 3.5)
	# Warm steam-light from the food
	var cart_light := OmniLight3D.new()
	cart_light.position = Vector3(fx, 1.5, -SIDEWALK_W + 1.2)
	cart_light.light_color = Color(1.0, 0.75, 0.35)
	cart_light.light_energy = 1.4
	cart_light.omni_range = 3.5
	cart_light.omni_attenuation = 2.0
	add_child(cart_light)

	# VENDOR NPC behind the cart — billboard sprite, facing the player
	var vendor_pivot := Node3D.new()
	vendor_pivot.position = Vector3(fx, 0, -SIDEWALK_W + 0.4)
	add_child(vendor_pivot)
	var vendor_ab = AnimatedBillboardScript.new()
	vendor_ab.show_floor_shadow = false
	vendor_ab.pixel_size = 0.04
	vendor_ab.position = Vector3(0, 0, 0)
	vendor_pivot.add_child(vendor_ab)
	vendor_ab.load_sheet("res://assets/sprites/npc-corpo.png")
	vendor_ab.facing = AnimatedBillboardScript.Facing.DOWN  # toward camera
	vendor_ab.set_moving(false)


# ─────────────────────────────────────────────────────────────────────────
# ALLEY — cut a dark gap between two storefronts. Dim red light at the back.
# ─────────────────────────────────────────────────────────────────────────

func _build_alley() -> void:
	# Alley sits between PET (-28) and COMICS (-4). Center around x=-16.
	var ax := -16.0
	var alley_z_far := -SIDEWALK_W - 10.0  # deep into the building wall
	var alley_w := 3.6
	# Dark alley floor
	_add_box(Vector3(ax, 0.10, alley_z_far + 4.5),
		Vector3(alley_w, 0.20, 9.0),
		Color(0.04, 0.03, 0.06), 0.1, 0.85)
	# Side walls of alley (extending from the storefront facades)
	for sx_sign in [-1, 1]:
		_add_box(Vector3(ax + sx_sign * alley_w * 0.5, 4.0, alley_z_far + 4.5),
			Vector3(0.3, 8.0, 9.0),
			Color(0.045, 0.04, 0.075), 0.1, 0.6)
	# Back wall (closes the alley off)
	_add_box(Vector3(ax, 4.0, alley_z_far),
		Vector3(alley_w + 0.6, 8.0, 0.4),
		Color(0.04, 0.035, 0.06), 0.1, 0.6)
	# Dim red neon strip at the back — single accent
	_add_box(Vector3(ax, 3.5, alley_z_far + 0.3),
		Vector3(2.0, 0.10, 0.10),
		Color(0.50, 0.05, 0.10), 0.0, 0.3,
		true, Color(1.0, 0.18, 0.30), 2.2, false)
	# Real red back-glow light
	var bglow := OmniLight3D.new()
	bglow.position = Vector3(ax, 2.0, alley_z_far + 1.5)
	bglow.light_color = Color(1.0, 0.20, 0.30)
	bglow.light_energy = 1.5
	bglow.omni_range = 5.0
	bglow.omni_attenuation = 2.0
	add_child(bglow)
	# Dumpster in the alley
	_add_box(Vector3(ax - 0.8, 0.7, alley_z_far + 1.4),
		Vector3(1.2, 1.2, 1.6),
		Color(0.06, 0.20, 0.10), 0.3, 0.5)
	# Graffiti accent on the back wall — magenta tag (just an emissive strip)
	_add_box(Vector3(ax + 0.6, 2.6, alley_z_far + 0.25),
		Vector3(0.9, 0.25, 0.04),
		Color(0.55, 0.10, 0.40), 0.0, 0.3,
		true, Color(1.0, 0.20, 0.85), 0.9, false)


# ─────────────────────────────────────────────────────────────────────────
# SIDEWALK PROPS — trash bins, fire hydrants, news racks
# ─────────────────────────────────────────────────────────────────────────

func _build_sidewalk_props() -> void:
	# Hand-placed at non-uniform x positions for organic feel
	var trash_xs := [-72.0, -34.0, 14.0, 55.0]
	for tx in trash_xs:
		# Trash bin — dark cylinder
		var bin := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.35
		cyl.height = 1.1
		bin.mesh = cyl
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.08, 0.07, 0.10)
		bmat.metallic = 0.7
		bmat.roughness = 0.5
		bin.material_override = bmat
		bin.position = Vector3(tx, 0.65, -SIDEWALK_W + 1.0)
		add_child(bin)

	# Fire hydrants — red emissive
	var hydrant_xs := [-50.0, 10.0]
	for hx in hydrant_xs:
		var hyd := MeshInstance3D.new()
		var hm := CylinderMesh.new()
		hm.top_radius = 0.18
		hm.bottom_radius = 0.20
		hm.height = 0.7
		hyd.mesh = hm
		var hmat := StandardMaterial3D.new()
		hmat.albedo_color = Color(0.7, 0.10, 0.10)
		hmat.metallic = 0.4
		hmat.roughness = 0.4
		hyd.material_override = hmat
		hyd.position = Vector3(hx, 0.45, -SIDEWALK_W + 2.6)
		add_child(hyd)

	# News rack at one location — small yellow box
	var nr := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.6, 1.0, 0.4)
	nr.mesh = nm
	var nrmat := StandardMaterial3D.new()
	nrmat.albedo_color = Color(0.75, 0.55, 0.10)
	nrmat.metallic = 0.5
	nrmat.roughness = 0.4
	nr.material_override = nrmat
	nr.position = Vector3(40.0, 0.5, -SIDEWALK_W + 1.0)
	add_child(nr)


# ─────────────────────────────────────────────────────────────────────────
# AC UNITS + GRIME — boxes hanging off building facades, scattered trash
# ─────────────────────────────────────────────────────────────────────────

func _build_ac_units_and_grime() -> void:
	# AC units protruding from upper floors of north-side buildings
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xAC121E
	var ac_xs := [-65.0, -38.0, -10.0, 12.0, 30.0, 55.0]
	for ax in ac_xs:
		var ay := rng.randf_range(5.0, 8.5)
		_add_box(Vector3(ax, ay, -SIDEWALK_W - 0.7),
			Vector3(1.0, 0.7, 0.6),
			Color(0.18, 0.18, 0.22), 0.6, 0.5)
		# Vent slats — slightly emissive (warm)
		_add_box(Vector3(ax, ay - 0.05, -SIDEWALK_W - 1.0),
			Vector3(0.85, 0.55, 0.04),
			Color(0.10, 0.10, 0.12), 0.4, 0.3,
			true, Color(1.0, 0.65, 0.30), 0.25, false)

	# Hanging cables (thin dark boxes) strung between buildings — visual mess
	for cy in [6.5, 7.5, 8.2]:
		_add_box(Vector3(0, cy, -SIDEWALK_W - 0.4),
			Vector3(BLOCK_LENGTH * 0.9, 0.06, 0.06),
			Color(0.04, 0.04, 0.07), 0.5, 0.5, false, Color.BLACK, 0.0, false)

	# Scattered trash boxes on sidewalk
	var trash_spots := [-68.0, -42.0, -8.0, 18.0, 52.0]
	for tx in trash_spots:
		var trash := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.4, 0.3, 0.3)
		trash.mesh = tm
		var tmat := StandardMaterial3D.new()
		var trash_colors := [Color(0.7, 0.5, 0.2), Color(0.5, 0.5, 0.55), Color(0.8, 0.1, 0.1)]
		var tc: Color = trash_colors[int(absf(tx)) % 3]
		tmat.albedo_color = tc
		tmat.metallic = 0.1
		tmat.roughness = 0.7
		trash.material_override = tmat
		trash.position = Vector3(tx, 0.25, -SIDEWALK_W + 0.7)
		add_child(trash)


# ─────────────────────────────────────────────────────────────────────────
# STREETLAMPS — every 14m. OmniLight + warm bulb that glows in fog.
# ─────────────────────────────────────────────────────────────────────────

func _build_streetlamps() -> void:
	# Streetlamps on BOTH sides of the road, alternating positions
	var lamp_step := 14.0
	var t := -BLOCK_HALF_W + 6.0
	var side_toggle := 0
	while t < BLOCK_HALF_W:
		var lamp_z: float
		if side_toggle == 0:
			lamp_z = -SIDEWALK_W + 0.8
		else:
			lamp_z = ROAD_WIDTH + SIDEWALK_W - 0.8
		_build_one_streetlamp(Vector3(t, 0, lamp_z))
		side_toggle = (side_toggle + 1) % 2
		t += lamp_step

func _build_one_streetlamp(pos: Vector3) -> void:
	# Pole
	_add_box(pos + Vector3(0, 2.5, 0),
		Vector3(0.15, 5.0, 0.15),
		Color(0.08, 0.07, 0.10), 0.7, 0.4)
	# Arm extending over road
	_add_box(pos + Vector3(0, 4.85, 0.6),
		Vector3(0.15, 0.15, 1.4),
		Color(0.08, 0.07, 0.10), 0.7, 0.4)
	# Bulb housing — high emission so the halo always blooms regardless of
	# camera distance (was 4.0 → 8.5 so glow threshold is comfortably hit)
	var bulb_pos := pos + Vector3(0, 4.70, 1.2)
	_add_box(bulb_pos,
		Vector3(0.55, 0.25, 0.55),
		Color(0.7, 0.5, 0.2), 0.0, 0.2,
		true, Color(1.0, 0.82, 0.35), 8.5)
	# Single OmniLight3D per lamp — no separate spot beam. Forward+ has
	# a per-cluster light limit and the city has tons of lights (15 lamps
	# × 2 lights + 4 cars × 3 lights + storefronts × 2 = ~50+ lights).
	# When the cluster cap is hit, some lights pop in and out as the
	# camera moves — that's the "lamps turn off and on" Aaron saw.
	# One light per lamp is plenty for a warm pool + bloom on the bulb.
	var lamp := OmniLight3D.new()
	lamp.position = bulb_pos + Vector3(0, -0.2, 0)
	lamp.light_color = Color(1.0, 0.82, 0.40)
	lamp.light_energy = 4.0
	lamp.omni_range = 12.0
	lamp.omni_attenuation = 1.6
	add_child(lamp)


# ─────────────────────────────────────────────────────────────────────────
# PUDDLES + MANHOLE COVERS — sidewalk + road grit detail
# ─────────────────────────────────────────────────────────────────────────

func _build_puddles_and_manholes() -> void:
	# Puddles — low-roughness, metallic-blue planes on the road and sidewalk.
	# They reflect the neon and lamps. Sized/positioned for variety.
	var puddle_spots := [
		Vector3(-62.0, 0.12, 3.5),
		Vector3(-30.0, 0.12, 5.5),
		Vector3(  8.0, 0.12, 7.0),
		Vector3( 28.0, 0.12, -2.5),
		Vector3( 50.0, 0.12, 4.0),
		Vector3(-15.0, 0.21, -SIDEWALK_W + 2.0),
		Vector3( 38.0, 0.21, -SIDEWALK_W + 2.5),
	]
	for ps in puddle_spots:
		_build_puddle(ps)

	# Manhole covers — embedded in the road, metallic-rust circles
	var manhole_xs := [-44.0, -10.0, 25.0, 56.0]
	for mx in manhole_xs:
		_build_manhole(Vector3(mx, 0.07, ROAD_WIDTH * 0.5))

func _build_puddle(pos: Vector3) -> void:
	# Puddles read as wet via dark albedo + subtle specular, NOT via
	# mirror-like reflection. Pure-mirror puddles had highlights sliding
	# across them as the camera moved — same issue as the road.
	var pmi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(randf_range(1.5, 2.8), randf_range(1.0, 2.0))
	pmi.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.04, 0.05, 0.10, 0.85)
	pmat.metallic = 0.0
	pmat.roughness = 0.45
	pmat.metallic_specular = 0.35
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmi.material_override = pmat
	pmi.position = pos
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pmi)

func _build_steam_from_manholes() -> void:
	# CPUParticles3D plumes rising from each manhole. Visible in vol fog.
	var manhole_xs := [-44.0, -10.0, 25.0, 56.0]
	for mx in manhole_xs:
		var parts := CPUParticles3D.new()
		parts.position = Vector3(mx, 0.2, ROAD_WIDTH * 0.5)
		parts.amount = 24
		parts.lifetime = 3.5
		parts.preprocess = 2.0
		parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		parts.emission_box_extents = Vector3(0.35, 0.05, 0.35)
		parts.direction = Vector3(0, 1, 0)
		parts.spread = 18.0
		parts.gravity = Vector3(0, 0.6, 0)
		parts.initial_velocity_min = 0.6
		parts.initial_velocity_max = 1.2
		parts.scale_amount_min = 0.5
		parts.scale_amount_max = 1.6
		parts.color = Color(0.85, 0.78, 0.85, 0.25)
		# Make particles soft / additive-like
		var pmesh := QuadMesh.new()
		pmesh.size = Vector2(1.0, 1.0)
		parts.mesh = pmesh
		var pmat := StandardMaterial3D.new()
		pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pmat.albedo_color = Color(0.8, 0.78, 0.85, 0.18)
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		pmat.disable_receive_shadows = true
		pmesh.material = pmat
		parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(parts)


# ─────────────────────────────────────────────────────────────────────────
# WALKING NPCS — pedestrians strolling the sidewalk
# ─────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────
# CARS — driving along the two-lane road with real headlight SpotLight3D
# ─────────────────────────────────────────────────────────────────────────

func _build_cars() -> void:
	# Mix of car colors, sizes. Each gets glow-halo headlights, brake glow,
	# real SpotLight3D beams that scatter in fog. Different headlight tints
	# per car so the road feels alive instead of all warm-yellow.
	# Cars 3× bigger per Aaron — these now read at proper scale next to
	# storefronts (was 4.5×1.4×2 → tiny dark blobs; now 13.5×4.2×6 reads
	# as a real vehicle from the 3/4 view).
	var car_specs := [
		{ "x": -BLOCK_HALF_W,        "lane_z": ROAD_WIDTH * 0.30,
		  "color": Color(0.85, 0.18, 0.20), "speed":  9.0,
		  "hl_color": Color(1.0, 0.95, 0.78), "size": Vector3(13.8, 4.2, 6.0) },
		{ "x": -BLOCK_HALF_W * 0.3,  "lane_z": ROAD_WIDTH * 0.30,
		  "color": Color(0.95, 0.80, 0.10), "speed":  7.5,
		  "hl_color": Color(0.95, 0.98, 1.0), "size": Vector3(13.2, 4.5, 6.0) },
		{ "x":  BLOCK_HALF_W * 0.4,  "lane_z": ROAD_WIDTH * 0.70,
		  "color": Color(0.15, 0.60, 0.95), "speed": -8.5,
		  "hl_color": Color(0.75, 0.90, 1.0), "size": Vector3(14.4, 3.6, 5.7) },
		{ "x":  BLOCK_HALF_W * 0.9,  "lane_z": ROAD_WIDTH * 0.70,
		  "color": Color(0.85, 0.20, 0.85), "speed": -10.0,
		  "hl_color": Color(1.0, 0.85, 0.95), "size": Vector3(12.6, 4.2, 5.7) },
	]
	for spec in car_specs:
		var car := Node3D.new()
		car.position = Vector3(spec.x, spec.size.y * 0.5, spec.lane_z)
		add_child(car)
		# Body
		_add_box_local(car, Vector3(0, 0, 0), spec.size,
			spec.color * Color(0.7, 0.7, 0.7, 1.0), 0.8, 0.25)
		# Cabin — slightly back from front + smaller
		_add_box_local(car, Vector3(0.2, spec.size.y * 0.7, 0),
			Vector3(spec.size.x * 0.55, spec.size.y * 0.55, spec.size.z * 0.85),
			spec.color * Color(0.4, 0.4, 0.4, 1.0), 0.85, 0.18)
		# Underglow strip (neon-drenched feel) — emissive line under the car
		_add_box_local(car, Vector3(0, -spec.size.y * 0.45, 0),
			Vector3(spec.size.x * 0.9, 0.06, spec.size.z * 0.95),
			spec.color * Color(0.3, 0.3, 0.3, 1.0), 0.0, 0.3,
			true, spec.color, 1.5)
		var fwd_sign: float = 1.0 if spec.speed > 0 else -1.0
		var hl_x: float = spec.size.x * 0.49 * fwd_sign
		# Headlight ASSEMBLIES — bigger emissive lens + halo glow
		for hz in [-spec.size.z * 0.30, spec.size.z * 0.30]:
			# Lens — emissive
			_add_box_local(car, Vector3(hl_x, 0.0, hz),
				Vector3(0.18, 0.28, 0.30),
				spec.hl_color * Color(0.25, 0.25, 0.25, 1.0), 0.0, 0.2,
				true, spec.hl_color, 7.0)
			# Halo block extending slightly forward (gives bloom a target)
			_add_box_local(car, Vector3(hl_x + fwd_sign * 0.12, 0.0, hz),
				Vector3(0.06, 0.16, 0.18),
				spec.hl_color, 0.0, 0.2,
				true, spec.hl_color, 4.0)
		# Brake lights — RED, smoldering glow (will be brighter when stopping)
		for tz in [-spec.size.z * 0.30, spec.size.z * 0.30]:
			_add_box_local(car, Vector3(-hl_x, 0.0, tz),
				Vector3(0.14, 0.22, 0.22),
				Color(0.40, 0.05, 0.05), 0.0, 0.2,
				true, Color(1.0, 0.18, 0.18), 4.5)
		# SpotLight3D beam — fog-scatter headlight cone (the dramatic shaft)
		var beam := SpotLight3D.new()
		beam.position = Vector3(hl_x, 0.1, 0)
		beam.rotation_degrees = Vector3(0, -90 if fwd_sign > 0 else 90, 0)
		beam.light_color = spec.hl_color
		beam.light_energy = 7.0
		beam.spot_range = 14.0
		beam.spot_angle = 26.0
		beam.spot_attenuation = 1.4
		car.add_child(beam)
		# REAL point light at the headlight — illuminates pavement +
		# pedestrians as the car drives by. Brighter + wider than before.
		var hl_pt := OmniLight3D.new()
		hl_pt.position = Vector3(hl_x, 0.0, 0)
		hl_pt.light_color = spec.hl_color
		hl_pt.light_energy = 4.0
		hl_pt.omni_range = 7.0
		hl_pt.omni_attenuation = 1.5
		car.add_child(hl_pt)
		# Red point-light at the rear so taillights paint the road behind
		var tail := OmniLight3D.new()
		tail.position = Vector3(-hl_x, 0.0, 0)
		tail.light_color = Color(1.0, 0.20, 0.18)
		tail.light_energy = 1.6
		tail.omni_range = 3.5
		tail.omni_attenuation = 1.8
		car.add_child(tail)
		_cars.append({
			"node": car,
			"speed": spec.speed,
			"side_facing": fwd_sign,
		})


func _build_walking_npcs() -> void:
	# Real variety — 8 sprite sheets (4 NPC-archetypes + 2 hacking-game
	# specials + 2 smoking-drifter variants) so no two pedestrians look
	# alike at first glance.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC177A
	var sheets := [
		"res://assets/sprites/npc-thug.png",
		"res://assets/sprites/npc-corpo.png",
		"res://assets/sprites/npc-cop.png",
		"res://assets/sprites/npc-cop2.png",
		"res://assets/sprites/npc-cyberpunk.png",
		"res://assets/sprites/npc-ninja.png",
		"res://assets/sprites/smoking_drifter.png",
		"res://assets/sprites/smoking_scrapper.png",
	]
	# 8 pedestrians along the sidewalk + a few on the south sidewalk too
	for i in 8:
		var sx := lerpf(-BLOCK_HALF_W + 12.0, BLOCK_HALF_W - 12.0, float(i) / 7.0) \
			+ rng.randf_range(-6.0, 6.0)
		# Most on north sidewalk (closer to camera), a few on the road edge
		var sz: float = -SIDEWALK_W + 2.2
		if i % 4 == 3:
			# Cross-walker — closer to road
			sz = -1.0
		var pivot := Node3D.new()
		pivot.position = Vector3(sx, 0, sz)
		add_child(pivot)
		var ab = AnimatedBillboardScript.new()
		ab.show_floor_shadow = false
		ab.pixel_size = 0.04  # match player
		ab.position = Vector3(0, 0, 0)
		pivot.add_child(ab)
		ab.load_sheet(sheets[i % sheets.size()])
		var dir: int = 1 if rng.randf() < 0.5 else -1
		ab.facing = (AnimatedBillboardScript.Facing.RIGHT if dir > 0
			else AnimatedBillboardScript.Facing.LEFT)
		ab.set_moving(true)
		_npcs.append({
			"node": pivot,
			"ab": ab,
			"dir": dir,
			"speed": rng.randf_range(1.4, 2.6),
			"x_min": -BLOCK_HALF_W + 6.0,
			"x_max":  BLOCK_HALF_W - 6.0,
		})


func _build_manhole(pos: Vector3) -> void:
	# Manhole — disc-shaped, rusty metallic
	var mmi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.55
	cm.height = 0.04
	mmi.mesh = cm
	var mmat := StandardMaterial3D.new()
	# Try rusty metal texture
	var rust_tex := load("res://assets/world/textures/metal_rust/albedo.png") as Texture2D
	var rust_norm := load("res://assets/world/textures/metal_rust/normal.png") as Texture2D
	var rust_rough := load("res://assets/world/textures/metal_rust/roughness.png") as Texture2D
	if rust_tex:
		mmat.albedo_texture = rust_tex
	else:
		mmat.albedo_color = Color(0.18, 0.10, 0.08)
	if rust_norm:
		mmat.normal_enabled = true
		mmat.normal_texture = rust_norm
	if rust_rough:
		mmat.roughness_texture = rust_rough
	mmat.metallic = 0.85
	mmat.roughness = 0.55
	mmi.material_override = mmat
	mmi.position = pos
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ─────────────────────────────────────────────────────────────────────────
# PLAYER + HUD + spawn marker
# ─────────────────────────────────────────────────────────────────────────

func _build_player() -> void:
	_player = CharacterBody3D.new()
	# Mid-block spawn for showcase captures. Real game spawns at west edge
	# via the pending-spawn marker.
	_player.position = Vector3(0.0, 0.85, -SIDEWALK_W * 0.5)
	add_child(_player)
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.7
	col.shape = shape
	_player.add_child(col)
	_player_anim = AnimatedBillboardScript.new()
	# 48×64 sheet × pixel_size 0.04 = 1.92m × 2.56m sprite — proper human
	# scale next to doors/signs (was 0.06 → 2.9m, too tall vs 2.5m doors).
	_player_anim.show_floor_shadow = false  # 3/4 view, no iso shadow trick
	# pizza-guy sprite art fills the FULL 48×64 cell (he stands tall). NPC
	# sprites (drifter/scrapper/cop/thug) draw a shorter figure INSIDE
	# their cell. So pixel_size 0.04 on player = bigger char-on-screen
	# than 0.04 on NPCs. Drop to 0.034 to compensate visually.
	_player_anim.pixel_size = 0.034
	_player_anim.position = Vector3(0, -0.85, 0)
	_player.add_child(_player_anim)
	_player_anim.load_sheet("res://assets/sprites/player-pizza.png")

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var hp := Label.new()
	hp.text = "HEALTH"
	hp.add_theme_font_size_override("font_size", 11)
	hp.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	hp.position = Vector2(20, 14)
	cl.add_child(hp)
	for i in 5:
		var heart := Label.new()
		heart.text = "♥"
		heart.add_theme_font_size_override("font_size", 18)
		heart.add_theme_color_override("font_color", Color(1.0, 0.20, 0.45))
		heart.position = Vector2(82 + i * 22, 6)
		cl.add_child(heart)
	var credits := Label.new()
	credits.text = "CREDITS"
	credits.add_theme_font_size_override("font_size", 11)
	credits.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	credits.position = Vector2(20, 42)
	cl.add_child(credits)
	var ca := Label.new()
	ca.text = "$0"
	ca.add_theme_font_size_override("font_size", 14)
	ca.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	ca.position = Vector2(82, 39)
	cl.add_child(ca)
	var title := Label.new()
	title.text = "NEO CITY · BLOCK 1"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
	title.position = Vector2(20, 70)
	cl.add_child(title)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_status_label.position = Vector2(20, 90)
	cl.add_child(_status_label)
	var hint := Label.new()
	hint.text = "WASD MOVE · R SPRINT · E INTERACT · P PHONE"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hint.anchor_left = 0.0
	hint.anchor_bottom = 1.0
	hint.anchor_top = 1.0
	hint.offset_left = 20
	hint.offset_top = -22
	hint.offset_bottom = -8
	cl.add_child(hint)

func _set_status(txt: String) -> void:
	if _status_label:
		_status_label.text = txt

func _apply_pending_spawn() -> void:
	var spawn: String = SceneTransition.consume_spawn()
	if spawn == "from_stairs" or spawn == "from_elevator":
		_player.global_position = Vector3(-BLOCK_HALF_W + 6.0, 0.85, -SIDEWALK_W * 0.5)


# ─────────────────────────────────────────────────────────────────────────
# Process — movement, camera, interact
# ─────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_tick_player(delta)
	_tick_camera(delta)
	_tick_walking_npcs(delta)
	_tick_cars(delta)

func _tick_cars(delta: float) -> void:
	for car in _cars:
		var n: Node3D = car.node
		n.position.x += car.speed * delta
		# Wrap around block extent so cars don't disappear
		if car.speed > 0 and n.position.x > BLOCK_HALF_W + 12.0:
			n.position.x = -BLOCK_HALF_W - 12.0
		elif car.speed < 0 and n.position.x < -BLOCK_HALF_W - 12.0:
			n.position.x = BLOCK_HALF_W + 12.0

func _tick_walking_npcs(delta: float) -> void:
	for npc in _npcs:
		var n: Node3D = npc.node
		n.position.x += npc.dir * npc.speed * delta
		# Turn around at edges
		if n.position.x > npc.x_max:
			npc.dir = -1
			npc.ab.facing = AnimatedBillboardScript.Facing.LEFT
		elif n.position.x < npc.x_min:
			npc.dir = 1
			npc.ab.facing = AnimatedBillboardScript.Facing.RIGHT
		npc.ab.set_moving(true)

func _tick_player(_delta: float) -> void:
	if _player == null:
		return
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up",   "move_down"),
	)
	var speed := 6.0
	if Input.is_action_pressed("sprint"):
		speed *= 1.7
	# 3/4 view: direct screen→world mapping (W → -Z, S → +Z).
	# Z motion is foreshortened by the camera angle, so multiply Z speed
	# by ~1.5 so it visually matches X movement on screen.
	var world_dir := Vector3(input.x, 0, input.y)
	_player.velocity.x = world_dir.x * speed
	_player.velocity.z = world_dir.z * speed * 1.5
	_player.velocity.y = 0.0
	_player.move_and_slide()
	if _player_anim:
		_player_anim.update_facing_from_input(input)
		_player_anim.set_moving(input.length() > 0.1)

func _tick_camera(delta: float) -> void:
	if _camera == null or _player == null:
		return
	# Only translate. Rotation stays locked to the value set in _setup_camera.
	var target := _player.global_position + CAMERA_OFFSET
	_camera.global_position = _camera.global_position.lerp(target,
		clampf(delta * CAMERA_FOLLOW_LERP, 0.0, 1.0))
	_camera.rotation = _camera_locked_rotation

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone_toggle"):
		Phone.toggle()
	elif event.is_action_pressed("interact"):
		if not _near_store.is_empty():
			_on_storefront_interact(_near_store)


# Per-store interact behavior. For now most stores stub a "not built"
# message; the PET store is special-cased to grant fish_food as the
# tutorial-quest payoff.
func _on_storefront_interact(def: Dictionary) -> void:
	var id: String = def.get("id", "")
	if id == "pet":
		if not GameState.has_item("fish_food"):
			if GameState.credits >= 20:
				GameState.add_credits(-20)
				GameState.add_item("fish_food")
				_set_status("you buy fish food. shopkeeper: 'feed your damn fish.'")
			else:
				# First-time visit: free fish food so the loop completes
				# even with no credits. The shopkeeper is generous.
				GameState.add_item("fish_food")
				_set_status("shopkeeper hands you fish food. 'on the house. and take the cat.'")
		else:
			_set_status("shopkeeper: 'go feed your fish, kid.'")
	else:
		_set_status("(" + def.get("label", "?") + " interior not built yet)")


# ─────────────────────────────────────────────────────────────────────────
# Local box helper — child of a parent Node3D (for car parts etc.)
# ─────────────────────────────────────────────────────────────────────────

func _add_box_local(parent: Node3D, pos: Vector3, sz: Vector3, col: Color,
		metallic: float = 0.0, roughness: float = 0.8,
		emissive: bool = false, emission: Color = Color.BLACK,
		emission_energy: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metallic
	mat.roughness = roughness
	if emissive:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ─────────────────────────────────────────────────────────────────────────
# Box helper
# ─────────────────────────────────────────────────────────────────────────

func _add_box(pos: Vector3, sz: Vector3, col: Color,
		metallic: float = 0.0, roughness: float = 0.8,
		emissive: bool = false, emission: Color = Color.BLACK,
		emission_energy: float = 1.0, collision: bool = true) -> Node:
	if collision:
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
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new(); s.size = sz
		cs.shape = s
		body.add_child(cs)
		add_child(body)
		return body
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col
		mat.metallic = metallic
		mat.roughness = roughness
		if emissive:
			mat.emission_enabled = true
			mat.emission = emission
			mat.emission_energy_multiplier = emission_energy
		mi.material_override = mat
		mi.position = pos
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		return mi
