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
const DoorGlowScript            := preload("res://scripts/systems/door_glow.gd")
const CityGenSys                := preload("res://scripts/systems/city_gen.gd")

# ─── Camera: 3/4 view, lower-pitch than apartment iso ────────────────────
const CAMERA_OFFSET      := Vector3(0.0, 14.0, 24.0)
const CAMERA_AIM_OFFSET  := Vector3(0.0, 2.0, -2.0)
const CAMERA_FOLLOW_LERP := 9.0
const CAMERA_ORTHO_SIZE  := 22.0

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
var _near_manhole := false
var _near_weapon_shop := false
var _shop_layer: CanvasLayer
var _shop_open := false
var _shop_labels: Array = []
var _shop_credits_label: Label
var _near_terminal := false
var _ride_layer: CanvasLayer
var _ride_open := false
var _riding_scooter := false
var _scooter_node: Node3D
var _near_scooter_idx := -1
var _scooters: Array = []   # {node, pos}
var _gen_mats: Array = []   # cutaway shader materials (player_pos uniform)
# Dynamic culling: buildings always draw; LIGHTS, CARS, and NPCs activate
# by distance (they're the per-frame cost, not the geometry)
var _all_lights: Array = []
var _cull_t := 0.0
const LIGHT_CULL_DIST := 65.0
const CAR_CULL_DIST := 95.0
const NPC_CULL_DIST := 75.0
var _store_glows: Dictionary = {}   # def.id -> DoorGlow
var _store_zones: Array = []
var _camera_locked_rotation: Vector3 = Vector3.ZERO
var _npcs: Array = []          # walking pedestrians [{node, ab, dir, speed, x_min, x_max}]
var _cars: Array = []          # driving cars [{node, speed}]

# ─── ATM scene state ────────────────────────────────────────────────────
# Hacker drops a CyberDeck the first time the player walks near the ATM.
# After pickup, the cop+hacker sprites despawn so the scene rests.
var _atm_hacker_pivot: Node3D
var _atm_cop_pivot: Node3D
var _atm_siren: OmniLight3D
var _atm_beam: SpotLight3D
var _cyberdeck_pivot: Node3D
var _cyberdeck_glow: OmniLight3D
var _near_cyberdeck: bool = false


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
	_build_elevator_back()
	_build_arcade_entrance()
	_build_weapon_shop()
	# District generator disabled — visuals weren't at the bar (flat unlit
	# slabs). Rebuild properly with real facade detail before re-enabling.
	#_gen_mats = CityGenSys.build(self)
	_build_world_shell()
	var backwall := StaticBody3D.new()
	var bw_col := CollisionShape3D.new()
	var bw_shape := BoxShape3D.new()
	bw_shape.size = Vector3(126.0, 8.0, 1.0)
	bw_col.shape = bw_shape
	backwall.position = Vector3(0, 4.0, -13.5)
	backwall.add_child(bw_col)
	add_child(backwall)
	_build_ridenet()
	_build_scooters()
	_collect_lights(self)
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
		var bh := rng.randf_range(20.0, 34.0)
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
	# North-side towers sit behind the 9m storefront facades — windows
	# below ~10m are hidden, so start the grid above the facade line.
	var win_base: float = 10.0 if is_north_side else 2.5
	var cols: int = max(2, int((size.x - 1.0) / step_x))
	var rows: int = max(2, int((size.y - win_base - 1.0) / step_y))
	var x0 := pos.x - size.x * 0.5 + (size.x - (cols - 1) * step_x) * 0.5
	var y0 := win_base + (size.y - win_base - 0.5 - (rows - 1) * step_y) * 0.5
	# Each window = 3 nested layers giving architectural depth:
	#   1. Outer metallic frame (slightly lighter than wall)
	#   2. Recessed dark inset behind the frame
	#   3. Smaller lit pane (only if window is "lit") emitting from inside
	# This reads as a real window inset in a wall, not an LCD pixel.
	var win_w := 1.5
	var win_h := 1.9
	for cx in cols:
		for ry in rows:
			var lit := rng.randf() < 0.55
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
				lmat.emission_energy_multiplier = 2.4
				lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				lit_mi.material_override = lmat
				lit_mi.position = Vector3(wx, wy, front_face_z + 0.09)
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
						wy - win_h * 0.10, front_face_z + 0.115)
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
	# Standard DoorGlow — neon outline in the store's sign color, pulses +
	# arrow while the player stands in the interact area
	var glow := DoorGlowScript.new()
	glow.color = def.sign
	glow.opening = Vector2(1.7, 3.0)
	glow.position = Vector3(door_x, 0.05, win_z + 0.02)
	add_child(glow)
	_store_glows[def.id] = glow
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

const KATANA_PRICES := { 2: 500, 3: 1200 }
const SHOP_ITEMS := [
	{ "id": "katana", "label": "KATANA UPGRADE" },
	{ "id": "medkit", "label": "MEDKIT", "price": 40 },
	{ "id": "grenade", "label": "GRENADE", "price": 60 },
	{ "id": "stim", "label": "STIM", "price": 50 },
]

func _open_shop() -> void:
	_shop_open = true
	_shop_labels.clear()
	_shop_layer = CanvasLayer.new()
	_shop_layer.layer = 70
	add_child(_shop_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_layer.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(360, 150)
	panel.size = Vector2(560, 400)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.01, 0.01, 0.96)
	sb.border_color = Color(1.0, 0.3, 0.25)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	_shop_layer.add_child(panel)
	var title := Label.new()
	title.text = "IRON ORCHID ARMS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	title.position = Vector2(24, 18)
	panel.add_child(title)
	for i in SHOP_ITEMS.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		l.position = Vector2(24, 80 + i * 56)
		panel.add_child(l)
		_shop_labels.append(l)
	_shop_credits_label = Label.new()
	_shop_credits_label.add_theme_font_size_override("font_size", 20)
	_shop_credits_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	_shop_credits_label.position = Vector2(24, 330)
	panel.add_child(_shop_credits_label)
	var hint := Label.new()
	hint.text = "press 1-4 to buy · ESC to leave"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.6, 0.55, 0.55))
	hint.position = Vector2(24, 366)
	panel.add_child(hint)
	_refresh_shop()

func _refresh_shop() -> void:
	for i in SHOP_ITEMS.size():
		var item: Dictionary = SHOP_ITEMS[i]
		var l: Label = _shop_labels[i]
		if item.id == "katana":
			if GameState.katana_level >= 3:
				l.text = "[1]  KATANA MK-III — MAXED OUT"
				l.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
			else:
				var price: int = KATANA_PRICES[GameState.katana_level + 1]
				l.text = "[1]  KATANA MK-%d — %d cr  (more damage + reach)" 					% [GameState.katana_level + 1, price]
				l.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
		else:
			l.text = "[%d]  %s — %d cr" % [i + 1, item.label, item.price]
			l.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	if _shop_credits_label:
		_shop_credits_label.text = "your credits: $%d" % GameState.credits

func _shop_buy(idx: int) -> void:
	var item: Dictionary = SHOP_ITEMS[idx]
	if item.id == "katana":
		if GameState.katana_level >= 3:
			_set_status("shopkeep: 'that blade's already singing, kid.'")
			return
		var price: int = KATANA_PRICES[GameState.katana_level + 1]
		if GameState.credits < price:
			_set_status("shopkeep: 'come back with real money.'")
			return
		GameState.add_credits(-price)
		GameState.katana_level += 1
		_set_status("KATANA MK-%d acquired. it hums." % GameState.katana_level)
	else:
		if GameState.credits < item.price:
			_set_status("shopkeep: 'no credits, no gear.'")
			return
		GameState.add_credits(-item.price)
		GameState.add_item(item.id)
		_set_status("%s purchased." % item.label.to_lower())
	_refresh_shop()

func _close_shop() -> void:
	_shop_open = false
	if _shop_layer:
		_shop_layer.queue_free()
		_shop_layer = null
	_set_status("")


# =========================================================================
# RIDENET + SCOOTERS - getting around Signal Hollow
# =========================================================================

const RIDENET_STOPS := [
	{ "name": "HOME STREET", "pos": Vector3(0, 0.85, 2.0), "price": 0 },
	{ "name": "THE ARCADE", "pos": Vector3(46.0, 0.85, -2.0), "price": 10 },
	{ "name": "IRON ORCHID ARMS", "pos": Vector3(34.0, 0.85, -2.0), "price": 5 },
	{ "name": "WEST END", "pos": Vector3(-52.0, 0.85, -2.0), "price": 5 },
]

func _build_ridenet() -> void:
	for tpos in [Vector3(-36.0, 0, -3.0), Vector3(40.0, 0, -3.0)]:
		_build_ridenet_terminal(tpos)

func _build_ridenet_terminal(pos: Vector3) -> void:
	var cyan := Color(0.2, 1.2, 1.5)
	_add_box(pos + Vector3(0, 1.3, 0), Vector3(0.7, 2.6, 0.5),
		Color(0.05, 0.07, 0.09), 0.6, 0.3, true, cyan * Color(0.2, 0.2, 0.2, 1.0), 0.8)
	_add_box(pos + Vector3(0, 1.7, 0.27), Vector3(0.5, 0.7, 0.03),
		Color(0.04, 0.10, 0.12), 0.2, 0.2, true, cyan, 1.6)
	var label := Label3D.new()
	label.text = "RIDENET"
	label.font_size = 64
	label.pixel_size = 0.01
	label.modulate = cyan
	label.outline_size = 16
	label.outline_modulate = Color(0, 0, 0)
	label.position = pos + Vector3(0, 2.9, 0)
	add_child(label)
	var area := Area3D.new()
	area.position = pos + Vector3(0, 1.2, 0.8)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 2.4, 2.4)
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(b):
		if b is CharacterBody3D:
			_near_terminal = true
			_set_status("[E] RIDENET - ride across town"))
	area.body_exited.connect(func(b):
		if b is CharacterBody3D:
			_near_terminal = false
			_set_status(""))
	add_child(area)

func _open_ridenet() -> void:
	_ride_open = true
	_ride_layer = CanvasLayer.new()
	_ride_layer.layer = 70
	add_child(_ride_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ride_layer.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(400, 160)
	panel.size = Vector2(480, 380)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.04, 0.05, 0.96)
	sb.border_color = Color(0.2, 1.0, 1.2)
	sb.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	_ride_layer.add_child(panel)
	var title := Label.new()
	title.text = "RIDENET - where to?"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.3, 1.0, 1.1))
	title.position = Vector2(24, 16)
	panel.add_child(title)
	for i in RIDENET_STOPS.size():
		var stop: Dictionary = RIDENET_STOPS[i]
		var l := Label.new()
		var price_txt: String = "free" if stop.price == 0 else "%d cr" % stop.price
		l.text = "[%d]  %s - %s" % [i + 1, stop.name, price_txt]
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		l.position = Vector2(24, 66 + i * 46)
		panel.add_child(l)
	var credits_l := Label.new()
	credits_l.text = "credits: $%d" % GameState.credits
	credits_l.add_theme_font_size_override("font_size", 18)
	credits_l.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	credits_l.position = Vector2(24, 300)
	panel.add_child(credits_l)
	var hint := Label.new()
	hint.text = "1-4 to ride, ESC to walk away"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.65))
	hint.position = Vector2(24, 340)
	panel.add_child(hint)

func _ride_to(idx: int) -> void:
	var stop: Dictionary = RIDENET_STOPS[idx]
	if GameState.credits < stop.price:
		_set_status("RIDENET: insufficient credits, choom.")
		return
	GameState.add_credits(-stop.price)
	_close_ridenet()
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var cl := CanvasLayer.new()
	cl.layer = 90
	add_child(cl)
	cl.add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(func():
		if _riding_scooter:
			_dismount_scooter()
		_player.global_position = stop.pos
		_camera.global_position = stop.pos + CAMERA_OFFSET)
	tw.tween_interval(0.25)
	tw.tween_property(fade, "color:a", 0.0, 0.35)
	tw.tween_callback(func():
		cl.queue_free()
		_set_status("RIDENET drop-off: %s." % stop.name))

func _close_ridenet() -> void:
	_ride_open = false
	if _ride_layer:
		_ride_layer.queue_free()
		_ride_layer = null

func _build_scooters() -> void:
	for spos in [Vector3(-14.0, 0, 3.5), Vector3(52.0, 0, 3.5)]:
		var scooter := Node3D.new()
		scooter.position = spos
		add_child(scooter)
		_add_scooter_visual(scooter)
		_scooters.append({ "node": scooter })

func _add_scooter_visual(parent: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.35, 0.40)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 1.0, 1.2)
	mat.emission_energy_multiplier = 0.6
	var deck := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(1.5, 0.14, 0.5)
	deck.mesh = dm
	deck.material_override = mat
	deck.position = Vector3(0, 0.75, 0)
	parent.add_child(deck)
	var stem := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.1, 1.1, 0.1)
	stem.mesh = sm
	stem.material_override = mat
	stem.position = Vector3(0.65, 1.3, 0)
	parent.add_child(stem)
	for wx in [-0.6, 0.6]:
		var wheel := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.22
		wm.bottom_radius = 0.22
		wm.height = 0.12
		wheel.mesh = wm
		wheel.rotation.x = PI / 2.0
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(0.05, 0.05, 0.06)
		wheel.material_override = wmat
		wheel.position = Vector3(wx, 0.55, 0)
		parent.add_child(wheel)

func _check_scooter_proximity() -> void:
	_near_scooter_idx = -1
	if _riding_scooter or _player == null:
		return
	for i in _scooters.size():
		if _scooters[i].node.global_position.distance_to(_player.global_position) < 2.4:
			_near_scooter_idx = i
			_set_status("[E] ride the scooter")
			return

func _mount_scooter(idx: int) -> void:
	_riding_scooter = true
	_scooter_node = _scooters[idx].node
	_set_status("scooter humming. E to hop off.")

func _dismount_scooter() -> void:
	_riding_scooter = false
	if _scooter_node:
		_scooter_node.global_position = _player.global_position + Vector3(1.0, 0, 0.5)
		_scooter_node.global_position.y = 0.0
	_scooter_node = null
	_set_status("")


# =========================================================================
# WORLD SHELL - open-world rules: ground everywhere, a two-sided street,
# a VISIBLE southern boundary (canal), and a skyline backdrop. Never void,
# never a bare invisible wall.
# =========================================================================

func _build_world_shell() -> void:
	# 1) Ground plane under everything reachable or visible
	var ground := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(900.0, 0.08, 700.0)
	ground.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.045, 0.045, 0.06)
	gmat.roughness = 0.9
	ground.material_override = gmat
	ground.position = Vector3(0, -0.06, 0)
	add_child(ground)

	# 2) South frontage: low single-story strip across the street so the
	# road reads two-sided. Low = never blocks the iso camera.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x50F7
	var sx := -BLOCK_HALF_W
	while sx < BLOCK_HALF_W:
		var w: float = rng.randf_range(8.0, 16.0)
		var body := Color(0.10, 0.09, 0.13) * rng.randf_range(0.8, 1.2)
		_add_box(Vector3(sx + w * 0.5, 1.4, ROAD_WIDTH + 4.0),
			Vector3(w, 2.8, 6.0), body, 0.2, 0.8)
		# Rooftop edge + occasional low sign glow
		_add_box(Vector3(sx + w * 0.5, 2.9, ROAD_WIDTH + 4.0),
			Vector3(w + 0.3, 0.15, 6.3), body * 1.5, 0.2, 0.7)
		if rng.randf() < 0.4:
			var sc: Color = [Color(1.5, 0.3, 0.8), Color(0.3, 1.4, 1.5),
				Color(1.5, 1.1, 0.2)][rng.randi() % 3]
			_add_box(Vector3(sx + w * 0.5, 2.2, ROAD_WIDTH + 0.9),
				Vector3(minf(w - 3.0, 6.0), 0.5, 0.08),
				sc * Color(0.25, 0.25, 0.25, 1.0), 0.0, 0.3, true, sc, 1.6)
		sx += w + rng.randf_range(1.0, 4.0)

	# 3) The canal: visible southern boundary. Dark water with neon sheen.
	var water := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(900.0, 0.06, 26.0)
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.02, 0.05, 0.09)
	wmat.metallic = 0.9
	wmat.roughness = 0.08
	water.material_override = wmat
	water.position = Vector3(0, -0.02, ROAD_WIDTH + 21.0)
	add_child(water)
	# Canal guard rail - the readable "no further" line
	_add_box(Vector3(0, 0.55, ROAD_WIDTH + 8.2), Vector3(900.0, 0.08, 0.08),
		Color(0.1, 0.3, 0.35), 0.6, 0.3, true, Color(0.1, 0.9, 1.0), 1.2)
	for px in range(-440, 460, 20):
		_add_box(Vector3(px, 0.3, ROAD_WIDTH + 8.2), Vector3(0.1, 0.6, 0.1),
			Color(0.16, 0.16, 0.2), 0.6, 0.4)
	var rail := StaticBody3D.new()
	var rail_col := CollisionShape3D.new()
	var rail_shape := BoxShape3D.new()
	rail_shape.size = Vector3(900.0, 4.0, 0.5)
	rail_col.shape = rail_shape
	rail.position = Vector3(0, 2.0, ROAD_WIDTH + 8.4)
	rail.add_child(rail_col)
	add_child(rail)

	# 4) Skyline backdrop: emissive tower silhouettes across the canal and
	# far behind the home block. Unreachable, always drawn, kills the void.
	_build_backdrop_row(ROAD_WIDTH + 46.0, 0x51CA, 10.0, 22.0)
	_build_backdrop_row(ROAD_WIDTH + 78.0, 0x51CB, 18.0, 38.0)
	_build_backdrop_row(-46.0, 0x51CC, 16.0, 30.0)
	_build_backdrop_row(-80.0, 0x51CD, 24.0, 48.0)
	# End caps east/west so the street doesn't end in nothing
	for ex in [-BLOCK_HALF_W - 26.0, BLOCK_HALF_W + 26.0]:
		_build_backdrop_column(ex, 0x51CE + int(ex))

func _build_backdrop_row(z: float, seed_v: int, h_min: float, h_max: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	var items: Array = []
	var x := -430.0
	while x < 430.0:
		var w: float = rng.randf_range(14.0, 30.0)
		var h: float = rng.randf_range(h_min, h_max)
		items.append({ "xform": Transform3D(
			Basis.from_scale(Vector3(w, h, 12.0)),
			Vector3(x + w * 0.5, h * 0.5, z)),
			"color": Color(0.05, 0.045, 0.09) * rng.randf_range(0.7, 1.2) })
		x += w + rng.randf_range(2.0, 8.0)
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i].xform)
		mm.set_instance_color(i, items[i].color)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# Lit windows sprinkled on the row (one glow multimesh)
	var wmm := MultiMesh.new()
	wmm.transform_format = MultiMesh.TRANSFORM_3D
	wmm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.6)
	wmm.mesh = quad
	var wins: Array = []
	for it in items:
		var bx: float = it.xform.origin.x
		var bw: float = it.xform.basis.x.length()
		var bh: float = it.xform.basis.y.length()
		var count := int(bw * bh * 0.04)
		for i in count:
			wins.append({ "pos": Vector3(
				bx + rng.randf_range(-bw * 0.4, bw * 0.4),
				rng.randf_range(2.0, bh - 1.5),
				z - 6.2),
				"color": [Color(1.3, 1.0, 0.5), Color(0.5, 1.1, 1.3),
					Color(1.2, 0.5, 1.0)][rng.randi() % 3] })
	wmm.instance_count = wins.size()
	for i in wins.size():
		wmm.set_instance_transform(i, Transform3D(Basis.IDENTITY, wins[i].pos))
		wmm.set_instance_color(i, wins[i].color)
	var wmi := MultiMeshInstance3D.new()
	wmi.multimesh = wmm
	var wmat := StandardMaterial3D.new()
	wmat.vertex_color_use_as_albedo = true
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.emission_enabled = true
	wmat.emission = Color(0.9, 0.9, 0.9)
	wmat.emission_energy_multiplier = 1.2
	wmi.material_override = wmat
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wmi)

func _build_backdrop_column(x: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var z := -60.0
	while z < 60.0:
		var d: float = rng.randf_range(12.0, 22.0)
		var h: float = rng.randf_range(10.0, 30.0)
		_add_box(Vector3(x, h * 0.5, z + d * 0.5),
			Vector3(16.0, h, d),
			Color(0.05, 0.045, 0.09) * rng.randf_range(0.7, 1.2), 0.2, 0.9)
		z += d + rng.randf_range(3.0, 9.0)


func _build_weapon_shop() -> void:
	# IRON ORCHID ARMS — street hardware. Katana upgrades + consumables.
	var wx := 34.0
	var face_z := -SIDEWALK_W - 0.5
	var door_z := face_z + 0.72
	var red := Color(1.0, 0.25, 0.2)
	# Dark storefront with a barred window + weapon rack silhouettes
	_add_box(Vector3(wx, 1.6, door_z), Vector3(3.4, 3.2, 0.10),
		Color(0.06, 0.04, 0.04), 0.5, 0.3, true, red * Color(0.2, 0.2, 0.2, 1.0), 0.4)
	for bx in [-1.2, -0.6, 0.0, 0.6, 1.2]:
		_add_box(Vector3(wx + bx, 1.6, door_z + 0.06), Vector3(0.08, 2.8, 0.03),
			Color(0.12, 0.12, 0.14), 0.7, 0.3)
	# Glowing katana silhouette in the window
	_add_box(Vector3(wx - 0.5, 1.9, door_z + 0.10), Vector3(1.8, 0.10, 0.03),
		Color(0.3, 0.3, 0.35), 0.6, 0.2, true, Color(0.9, 0.95, 1.4), 1.8)
	_add_box(Vector3(wx + 0.55, 1.9, door_z + 0.10), Vector3(0.3, 0.22, 0.03),
		Color(0.2, 0.1, 0.1), 0.4, 0.3, true, red, 1.2)
	var sign_label := Label3D.new()
	sign_label.text = "IRON ORCHID ARMS"
	sign_label.font_size = 110
	sign_label.pixel_size = 0.01
	sign_label.modulate = red
	sign_label.outline_size = 22
	sign_label.outline_modulate = Color(0.2, 0.02, 0.02)
	sign_label.position = Vector3(wx, 4.0, door_z + 0.1)
	add_child(sign_label)
	var spill := OmniLight3D.new()
	spill.position = Vector3(wx, 2.4, door_z + 1.5)
	spill.light_color = red
	spill.light_energy = 1.8
	spill.omni_range = 4.5
	spill.omni_attenuation = 1.6
	add_child(spill)
	var area := Area3D.new()
	area.position = Vector3(wx, 1.2, door_z + 1.4)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.6, 2.4, 2.6)
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(b):
		if b is CharacterBody3D:
			_near_weapon_shop = true
			_set_status("[E] IRON ORCHID ARMS — buy hardware"))
	area.body_exited.connect(func(b):
		if b is CharacterBody3D:
			_near_weapon_shop = false
			_set_status(""))
	add_child(area)


func _build_arcade_entrance() -> void:
	# ARCADE — east end of the block, past the bar. Neon-soaked
	# double door + sign; leads to the arcade interior scene.
	var ax := BLOCK_HALF_W - 14.0
	var face_z := -SIDEWALK_W - 0.5
	var door_z := face_z + 0.72
	var neon := Color(1.0, 0.15, 0.7)
	# Dark recessed double doorway with a hot magenta interior spill
	_add_box(Vector3(ax, 1.6, door_z),
		Vector3(2.6, 3.2, 0.10),
		Color(0.05, 0.03, 0.07), 0.5, 0.3,
		true, neon * Color(0.3, 0.3, 0.3, 1.0), 0.5)
	_add_box(Vector3(ax, 1.5, door_z + 0.06),
		Vector3(0.05, 3.0, 0.02), Color(0.02, 0.02, 0.03), 0.0, 0.5)
	# Marquee sign above the doors
	var sign_label := Label3D.new()
	sign_label.text = "ARCADE"
	sign_label.font_size = 140
	sign_label.pixel_size = 0.01
	sign_label.modulate = neon
	sign_label.outline_size = 22
	sign_label.outline_modulate = Color(0.25, 0.0, 0.15)
	sign_label.position = Vector3(ax, 4.1, door_z + 0.1)
	add_child(sign_label)
	# Sign glow spill onto the sidewalk
	var spill := OmniLight3D.new()
	spill.position = Vector3(ax, 2.6, door_z + 1.6)
	spill.light_color = neon
	spill.light_energy = 2.2
	spill.omni_range = 5.0
	spill.omni_attenuation = 1.6
	add_child(spill)
	var door := InteractableDoorScript.new()
	door.scene_id = "city"
	door.door_id = "arcade_door"
	door.position = Vector3(ax, 1.2, door_z + 1.4)
	door.auto_collision_size = Vector3(3.0, 2.4, 2.6)
	door.glow_color = neon
	door.glow_opening = Vector2(2.6, 3.2)
	door.glow_offset = Vector3(0, -1.2, -1.38)
	door.player_entered.connect(func(): _set_status("[E] " + door.label()))
	door.player_exited.connect(func(): _set_status(""))
	add_child(door)
	# Return marker from the arcade
	var m := Node3D.new()
	m.name = "from_arcade"
	m.position = Vector3(ax, 0.0, door_z + 1.8)
	add_child(m)

func _build_elevator_back() -> void:
	# The way home — elevator entrance on the north facade at the west end,
	# right where from_elevator spawns drop the player. Was missing entirely:
	# the scene_graph door existed but nothing in the scene built it.
	var ex := -BLOCK_HALF_W + 6.0
	var face_z := -SIDEWALK_W - 0.5
	var door_z := face_z + 0.72
	# Recessed dark doorway + faint warm interior
	_add_box(Vector3(ex, 1.55, door_z),
		Vector3(1.8, 3.1, 0.10),
		Color(0.06, 0.06, 0.09), 0.6, 0.3,
		true, Color(1.0, 0.85, 0.1), 0.25)
	# Sliding-door seam
	_add_box(Vector3(ex, 1.5, door_z + 0.06),
		Vector3(0.04, 2.9, 0.02), Color(0.02, 0.02, 0.03), 0.0, 0.5)
	# "404" readout above — same yellow as the hallway elevator
	_add_box(Vector3(ex, 3.35, door_z + 0.04),
		Vector3(0.6, 0.24, 0.05),
		Color(0.3, 0.25, 0.05), 0.0, 0.3, true, Color(1.0, 0.85, 0.1), 2.0)
	var door := InteractableDoorScript.new()
	door.scene_id = "city"
	door.door_id = "elevator_back"
	door.position = Vector3(ex, 1.2, door_z + 1.4)
	door.auto_collision_size = Vector3(2.2, 2.4, 2.6)
	door.glow_color = Color(1.0, 0.85, 0.10)
	door.glow_opening = Vector2(1.8, 3.1)
	door.glow_offset = Vector3(0, -1.2, -1.38)
	door.player_entered.connect(func(): _set_status("[E] " + door.label()))
	door.player_exited.connect(func(): _set_status(""))
	add_child(door)


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
		if _store_glows.has(def.id):
			_store_glows[def.id].set_active(true)
		_set_status("[E] enter " + def.label)

func _on_store_far(def: Dictionary, body: Node) -> void:
	if body is CharacterBody3D and _near_store.get("id", "") == def.id:
		_near_store = {}
		if _store_glows.has(def.id):
			_store_glows[def.id].set_active(false)
		_set_status("")


# ─────────────────────────────────────────────────────────────────────────
# ATM scene + food cart (scripted points of interest)
# ─────────────────────────────────────────────────────────────────────────

func _build_atm_scene() -> void:
	# ATM with COP CHASING HACKER mid-action — Aaron's "first scene" hook.
	# When the player walks near, the hacker bolts and drops a CyberDeck (E to pick up).
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

	var hacker_pos := Vector3(ax + 0.9, 0, -SIDEWALK_W + 0.9)
	var cop_pos := Vector3(ax - 4.5, 0, -SIDEWALK_W + 1.5)

	# Only spawn the cop+hacker tableau if the event hasn't happened yet.
	# After atmEventDone, both have left and the cyberdeck pickup (or its
	# absence, if collected) is the only remaining trace.
	if not GameState.has_flag("atmEventDone"):
		# HACKER NPC — orange-coverall sprite, mid-action at the ATM
		_atm_hacker_pivot = Node3D.new()
		_atm_hacker_pivot.position = hacker_pos
		add_child(_atm_hacker_pivot)
		var hacker_ab = AnimatedBillboardScript.new()
		hacker_ab.show_floor_shadow = false
		hacker_ab.pixel_size = 0.04
		_atm_hacker_pivot.add_child(hacker_ab)
		hacker_ab.load_sheet("res://assets/sprites/npc-cyberpunk.png")
		hacker_ab.facing = AnimatedBillboardScript.Facing.LEFT
		hacker_ab.set_moving(false)

		# COP NPC — approaching from the west, flashlight on the hacker
		_atm_cop_pivot = Node3D.new()
		_atm_cop_pivot.position = cop_pos
		add_child(_atm_cop_pivot)
		var cop_ab = AnimatedBillboardScript.new()
		cop_ab.show_floor_shadow = false
		cop_ab.pixel_size = 0.04
		_atm_cop_pivot.add_child(cop_ab)
		cop_ab.load_sheet("res://assets/sprites/npc-cop.png")
		cop_ab.facing = AnimatedBillboardScript.Facing.RIGHT
		cop_ab.set_moving(false)

		# Cop's flashlight — cuts through fog toward the hacker
		_atm_beam = SpotLight3D.new()
		_atm_beam.position = cop_pos + Vector3(0, 1.6, 0)
		_atm_beam.look_at_from_position(_atm_beam.position,
			hacker_pos + Vector3(0, 1.0, 0), Vector3.UP)
		_atm_beam.light_color = Color(1.0, 0.95, 0.85)
		_atm_beam.light_energy = 5.0
		_atm_beam.spot_range = 7.0
		_atm_beam.spot_angle = 25.0
		_atm_beam.spot_attenuation = 1.3
		add_child(_atm_beam)

		# Red strobe at the cop's feet (siren)
		_atm_siren = OmniLight3D.new()
		_atm_siren.position = cop_pos + Vector3(0, 0.4, 0)
		_atm_siren.light_color = Color(1.0, 0.20, 0.20)
		_atm_siren.light_energy = 2.2
		_atm_siren.omni_range = 3.5
		_atm_siren.omni_attenuation = 2.0
		add_child(_atm_siren)

		# Proximity trigger — when the player enters this zone, the hacker
		# bolts and drops the CyberDeck. Centered between the ATM and the
		# street so the player triggers it from either approach direction.
		var trigger := Area3D.new()
		trigger.position = Vector3(ax + 0.5, 1.0, -SIDEWALK_W + 2.4)
		var tc := CollisionShape3D.new()
		var ts := BoxShape3D.new()
		ts.size = Vector3(7.0, 2.4, 4.0)
		tc.shape = ts
		trigger.add_child(tc)
		trigger.body_entered.connect(func(b): _on_atm_event_trigger(b, hacker_pos))
		add_child(trigger)
	elif not GameState.has_item("cyberDeck"):
		# Event already fired this session but the player wandered off
		# without grabbing the deck — keep it on the ground for them.
		_spawn_cyberdeck_pickup(hacker_pos)

# Player walked into the ATM trigger zone. Hacker bolts, cop "chases" off
# screen, leaves a CyberDeck behind. Sets atmEventDone flag (used by the
# atmWitness quest).
func _on_atm_event_trigger(body: Node, hacker_pos: Vector3) -> void:
	if not (body is CharacterBody3D):
		return
	if GameState.has_flag("atmEventDone"):
		return
	GameState.set_flag("atmEventDone")
	# Despawn the tableau — they've fled. Keep the despawn punchy: free
	# the pivots immediately rather than try a fade out (sprite billboards
	# don't tween nicely with the current shader).
	if _atm_hacker_pivot:
		_atm_hacker_pivot.queue_free()
		_atm_hacker_pivot = null
	if _atm_cop_pivot:
		_atm_cop_pivot.queue_free()
		_atm_cop_pivot = null
	if _atm_beam:
		_atm_beam.queue_free()
		_atm_beam = null
	if _atm_siren:
		_atm_siren.queue_free()
		_atm_siren = null
	_spawn_cyberdeck_pickup(hacker_pos)
	_set_status("the hacker bolted. she dropped something.")


# CyberDeck pickup — a glowing magenta deck on the sidewalk, [E] to grab.
func _spawn_cyberdeck_pickup(at: Vector3) -> void:
	if _cyberdeck_pivot:
		return
	_cyberdeck_pivot = Node3D.new()
	_cyberdeck_pivot.position = at + Vector3(0, 0.05, 0)
	add_child(_cyberdeck_pivot)
	# Deck body — thin laptop-shaped slab
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.55, 0.08, 0.40)
	body.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.04, 0.12)
	mat.metallic = 0.6
	mat.roughness = 0.3
	body.material_override = mat
	body.position = Vector3(0, 0.04, 0)
	_cyberdeck_pivot.add_child(body)
	# Screen-side glow strip (top face)
	var glow_strip := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.40, 0.02, 0.05)
	glow_strip.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.20, 0.05, 0.30)
	gmat.emission_enabled = true
	gmat.emission = Color(1.0, 0.20, 0.85)
	gmat.emission_energy_multiplier = 2.4
	glow_strip.material_override = gmat
	glow_strip.position = Vector3(0, 0.09, -0.10)
	_cyberdeck_pivot.add_child(glow_strip)
	# Soft magenta point light so the player notices it
	_cyberdeck_glow = OmniLight3D.new()
	_cyberdeck_glow.position = Vector3(0, 0.6, 0)
	_cyberdeck_glow.light_color = Color(1.0, 0.25, 0.95)
	_cyberdeck_glow.light_energy = 1.8
	_cyberdeck_glow.omni_range = 3.0
	_cyberdeck_glow.omni_attenuation = 2.0
	_cyberdeck_pivot.add_child(_cyberdeck_glow)
	# Proximity area for [E] pickup
	var area := Area3D.new()
	area.position = Vector3(0, 0.6, 0)
	var ac := CollisionShape3D.new()
	var as_ := BoxShape3D.new()
	as_.size = Vector3(2.0, 2.0, 2.0)
	ac.shape = as_
	area.add_child(ac)
	area.body_entered.connect(func(b): _on_cyberdeck_near(b))
	area.body_exited.connect(func(b): _on_cyberdeck_far(b))
	_cyberdeck_pivot.add_child(area)


func _on_cyberdeck_near(body: Node) -> void:
	if body is CharacterBody3D:
		_near_cyberdeck = true
		_set_status("[E] grab the CyberDeck")


func _on_cyberdeck_far(body: Node) -> void:
	if body is CharacterBody3D:
		_near_cyberdeck = false
		_set_status("")


func _pickup_cyberdeck() -> void:
	if _cyberdeck_pivot == null:
		return
	GameState.add_item("cyberDeck")
	GameState.set_flag("hasCyberDeck")
	_cyberdeck_pivot.queue_free()
	_cyberdeck_pivot = null
	_cyberdeck_glow = null
	_near_cyberdeck = false
	_set_status("got the CyberDeck. it pulses warm in your hand.")


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
	_build_sewer_entrance(Vector3(-10.0, 0.07, ROAD_WIDTH * 0.5))

func _build_sewer_entrance(pos: Vector3) -> void:
	# One manhole is pried half-open — sickly green light leaks out.
	# E drops you into the sewer dungeon.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.72
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.05, 0.15, 0.08)
	rmat.emission_enabled = true
	rmat.emission = Color(0.3, 1.4, 0.5)
	rmat.emission_energy_multiplier = 1.6
	ring.material_override = rmat
	ring.position = pos + Vector3(0, 0.03, 0)
	add_child(ring)
	var glow := OmniLight3D.new()
	glow.position = pos + Vector3(0, 0.8, 0)
	glow.light_color = Color(0.3, 1.2, 0.5)
	glow.light_energy = 1.4
	glow.omni_range = 3.5
	glow.omni_attenuation = 1.8
	add_child(glow)
	var area := Area3D.new()
	area.position = pos + Vector3(0, 1.0, 0)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.6, 2.4, 2.6)
	col.shape = shape
	area.add_child(col)
	area.body_entered.connect(func(b):
		if b is CharacterBody3D:
			_near_manhole = true
			_set_status("[E] pry open the manhole — something glows down there"))
	area.body_exited.connect(func(b):
		if b is CharacterBody3D:
			_near_manhole = false
			_set_status(""))
	add_child(area)
	var m := Node3D.new()
	m.name = "from_sewer"
	m.position = pos + Vector3(1.6, 0.0, 0.5)
	add_child(m)

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
	# Traffic mix per Aaron: sedans + box trucks, one pickup (fewer than
	# before). Sized down from the old 13m monsters (~2/3 scale), and every
	# vehicle is LIT: emissive cabin windows, underglow, running lights, and
	# the box trucks carry glowing ad panels on their cargo boxes.
	var specs := [
		{ "type": "sedan",    "x": -BLOCK_HALF_W,        "lane_z": ROAD_WIDTH * 0.30,
		  "color": Color(0.85, 0.18, 0.20), "speed":  9.0,
		  "hl_color": Color(1.0, 0.95, 0.78) },
		{ "type": "boxtruck", "x": -BLOCK_HALF_W * 0.4,  "lane_z": ROAD_WIDTH * 0.30,
		  "color": Color(0.20, 0.45, 0.50), "speed":  7.0,
		  "hl_color": Color(0.95, 0.98, 1.0), "ad": Color(0.2, 1.2, 1.4) },
		{ "type": "pickup",   "x":  BLOCK_HALF_W * 0.15, "lane_z": ROAD_WIDTH * 0.30,
		  "color": Color(0.95, 0.80, 0.10), "speed":  8.0,
		  "hl_color": Color(1.0, 0.90, 0.80) },
		{ "type": "sedan",    "x":  BLOCK_HALF_W * 0.4,  "lane_z": ROAD_WIDTH * 0.70,
		  "color": Color(0.15, 0.60, 0.95), "speed": -8.5,
		  "hl_color": Color(0.75, 0.90, 1.0) },
		{ "type": "boxtruck", "x":  BLOCK_HALF_W * 0.85, "lane_z": ROAD_WIDTH * 0.70,
		  "color": Color(0.55, 0.30, 0.60), "speed": -6.5,
		  "hl_color": Color(1.0, 0.85, 0.95), "ad": Color(1.5, 0.3, 1.0) },
	]
	for spec in specs:
		var car := Node3D.new()
		var fwd: float = 1.0 if spec.speed > 0 else -1.0
		var sz: Vector3
		match spec.type:
			"boxtruck": sz = Vector3(7.9, 3.4, 3.7)
			"pickup":   sz = Vector3(6.4, 2.1, 3.3)
			_:          sz = Vector3(6.1, 1.9, 3.2)
		car.position = Vector3(spec.x, 0.0, spec.lane_z)
		add_child(car)
		_build_vehicle_body(car, spec, sz, fwd)
		_add_vehicle_lights(car, spec, sz, fwd)
		var hitbox := Area3D.new()
		hitbox.position = Vector3(0, 1.0, 0)
		var hcol := CollisionShape3D.new()
		var hshape := BoxShape3D.new()
		hshape.size = Vector3(sz.x * 0.95, 2.0, sz.z * 0.95)
		hcol.shape = hshape
		hitbox.add_child(hcol)
		var car_entry := { "node": car, "speed": spec.speed, "side_facing": fwd,
			"hit_cd": 0.0 }
		hitbox.body_entered.connect(func(b): _on_car_hit(car_entry, b))
		car.add_child(hitbox)
		_cars.append(car_entry)

func _build_vehicle_body(car: Node3D, spec: Dictionary, sz: Vector3, fwd: float) -> void:
	# Local Y is up-from-road (car node sits on the road plane).
	# Camera is south (+Z), so lit windows / ad panels go on the +Z face.
	# Body shells are slightly SELF-LIT (low-energy emissive in the paint
	# color) so vehicles read as colored machines at night, not black blobs.
	var body_col: Color = spec.color * Color(0.7, 0.7, 0.7, 1.0)
	match spec.type:
		"boxtruck":
			var cab_len: float = sz.x * 0.24
			var box_len: float = sz.x * 0.72
			var cab_x: float = fwd * (sz.x * 0.5 - cab_len * 0.5)
			var box_x: float = -fwd * (sz.x * 0.5 - box_len * 0.5)
			var trim: Color = spec.get("ad", Color(0.2, 1.2, 1.4))
			# Chassis rail — dark, spans cab to tail above the wheels
			_add_box_local(car, Vector3(0, 0.55, 0),
				Vector3(sz.x * 0.98, 0.5, sz.z * 0.8),
				Color(0.05, 0.05, 0.07), 0.4, 0.5)
			# Cab — self-lit paint
			_car_shell(car, Vector3(cab_x, 1.45, 0),
				Vector3(cab_len, 1.9, sz.z * 0.9), body_col)
			# Windshield — lit band across the cab front
			_add_box_local(car, Vector3(cab_x + fwd * (cab_len * 0.5 + 0.02), 1.95, 0),
				Vector3(0.05, 0.55, sz.z * 0.62),
				Color(0.20, 0.38, 0.45), 0.2, 0.1,
				true, Color(0.45, 1.0, 1.2), 1.8)
			# Cab side window (camera side)
			_add_box_local(car, Vector3(cab_x, 1.95, sz.z * 0.45 + 0.03),
				Vector3(cab_len * 0.55, 0.5, 0.05),
				Color(0.25, 0.45, 0.55), 0.2, 0.1,
				true, Color(0.5, 1.1, 1.3), 1.8)
			# Cargo box
			_car_shell(car, Vector3(box_x, 0.8 + (sz.y - 0.8) * 0.5, 0),
				Vector3(box_len, sz.y - 0.8, sz.z), body_col * 1.25)
			# Container trim — thin neon edges frame the camera-facing side
			for tx in [box_x - box_len * 0.5 + 0.06, box_x + box_len * 0.5 - 0.06]:
				_add_box_local(car, Vector3(tx, 0.8 + (sz.y - 0.8) * 0.5, sz.z * 0.5 + 0.02),
					Vector3(0.08, sz.y - 1.0, 0.04),
					trim * Color(0.3, 0.3, 0.3, 1.0), 0.0, 0.3, true, trim, 1.6)
			_add_box_local(car, Vector3(box_x, sz.y - 0.10, sz.z * 0.5 + 0.02),
				Vector3(box_len - 0.12, 0.08, 0.04),
				trim * Color(0.3, 0.3, 0.3, 1.0), 0.0, 0.3, true, trim, 1.6)
			# Ad panel — inset between the trim
			_add_box_local(car, Vector3(box_x, 0.8 + (sz.y - 0.8) * 0.52, sz.z * 0.5 + 0.03),
				Vector3(box_len * 0.60, (sz.y - 0.8) * 0.48, 0.04),
				trim * Color(0.25, 0.25, 0.25, 1.0), 0.0, 0.3, true, trim, 0.9)
			# Roof marker lights — orange dots along the box top edge
			for i in 4:
				var mx: float = box_x + lerpf(-box_len * 0.38, box_len * 0.38, float(i) / 3.0)
				_add_box_local(car, Vector3(mx, sz.y + 0.06, sz.z * 0.44),
					Vector3(0.10, 0.10, 0.10),
					Color(0.5, 0.3, 0.05), 0.0, 0.3, true, Color(1.0, 0.55, 0.1), 3.0)
			_add_wheels(car, sz, 0.55, 0.32)
		"pickup":
			var cab_len: float = sz.x * 0.42
			var cab_x: float = fwd * sz.x * 0.12
			# Body raised on the wheels (0.4 ground clearance)
			_car_shell(car, Vector3(0, 1.0, 0), Vector3(sz.x, 1.2, sz.z), body_col)
			_car_shell(car, Vector3(cab_x, 1.6 + (sz.y - 1.6) * 0.5, 0),
				Vector3(cab_len, sz.y - 1.6, sz.z * 0.85), body_col * 0.8)
			# Cab side window — lit warm
			_add_box_local(car, Vector3(cab_x, 1.6 + (sz.y - 1.6) * 0.55, sz.z * 0.425 + 0.03),
				Vector3(cab_len * 0.7, (sz.y - 1.6) * 0.5, 0.05),
				Color(0.30, 0.50, 0.40), 0.2, 0.1,
				true, Color(1.2, 0.9, 0.5), 1.5)
			# Bed rails
			_add_box_local(car, Vector3(-fwd * sz.x * 0.28, 1.66, 0),
				Vector3(sz.x * 0.40, 0.10, sz.z * 0.9), body_col * 0.9, 0.7, 0.3)
			_add_wheels(car, sz, 0.45, 0.28)
		_:
			# Sedan — raised body + cabin + lit side windows
			_car_shell(car, Vector3(0, 0.95, 0), Vector3(sz.x, 1.2, sz.z), body_col)
			_car_shell(car, Vector3(-fwd * sz.x * 0.05, 1.55 + (sz.y - 1.55) * 0.5, 0),
				Vector3(sz.x * 0.55, sz.y - 1.55, sz.z * 0.85), body_col * 0.6)
			_add_box_local(car, Vector3(-fwd * sz.x * 0.05, 1.55 + (sz.y - 1.55) * 0.55, sz.z * 0.425 + 0.03),
				Vector3(sz.x * 0.48, (sz.y - 1.55) * 0.5, 0.05),
				Color(0.25, 0.45, 0.55), 0.2, 0.1,
				true, Color(0.5, 1.1, 1.3), 1.4)
			_add_wheels(car, sz, 0.40, 0.26)
	# Underglow strip — neon-drenched feel
	_add_box_local(car, Vector3(0, 0.18, 0),
		Vector3(sz.x * 0.9, 0.06, sz.z * 0.95),
		spec.color * Color(0.3, 0.3, 0.3, 1.0), 0.0, 0.3,
		true, spec.color, 1.8)

func _car_shell(car: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	# Paint shell — low-energy emissive so the color reads at night
	_add_box_local(car, pos, size, col, 0.3, 0.45, true, col, 0.35)

func _add_wheels(car: Node3D, sz: Vector3, radius: float, width: float) -> void:
	for wx in [-sz.x * 0.32, sz.x * 0.32]:
		for wz in [-sz.z * 0.40, sz.z * 0.40]:
			var mi := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = radius
			cyl.bottom_radius = radius
			cyl.height = width
			mi.mesh = cyl
			mi.rotation.x = PI / 2.0   # axle along Z
			mi.position = Vector3(wx, radius, wz)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.05, 0.05, 0.06)
			mat.roughness = 0.7
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			car.add_child(mi)

func _add_vehicle_lights(car: Node3D, spec: Dictionary, sz: Vector3, fwd: float) -> void:
	var hl_x: float = sz.x * 0.49 * fwd
	var hl_col: Color = spec.hl_color
	for hz in [-sz.z * 0.30, sz.z * 0.30]:
		# Headlight lens + halo block (bloom target)
		_add_box_local(car, Vector3(hl_x, 0.9, hz), Vector3(0.16, 0.24, 0.26),
			hl_col * Color(0.25, 0.25, 0.25, 1.0), 0.0, 0.2, true, hl_col, 7.0)
		_add_box_local(car, Vector3(hl_x + fwd * 0.10, 0.9, hz), Vector3(0.05, 0.14, 0.16),
			hl_col, 0.0, 0.2, true, hl_col, 4.0)
		# Brake lights — red smolder
		_add_box_local(car, Vector3(-hl_x, 0.9, hz), Vector3(0.12, 0.20, 0.20),
			Color(0.40, 0.05, 0.05), 0.0, 0.2, true, Color(1.0, 0.18, 0.18), 4.5)
	# SpotLight3D beam — fog-scatter headlight cone
	var beam := SpotLight3D.new()
	beam.position = Vector3(hl_x, 0.9, 0)
	beam.rotation_degrees = Vector3(0, -90 if fwd > 0 else 90, 0)
	beam.light_color = hl_col
	beam.light_energy = 7.0
	beam.spot_range = 12.0
	beam.spot_angle = 24.0
	beam.spot_attenuation = 1.4
	car.add_child(beam)
	# Point light at the headlights — paints pavement + pedestrians
	var hl_pt := OmniLight3D.new()
	hl_pt.position = Vector3(hl_x, 0.9, 0)
	hl_pt.light_color = hl_col
	hl_pt.light_energy = 3.5
	hl_pt.omni_range = 6.0
	hl_pt.omni_attenuation = 1.5
	car.add_child(hl_pt)
	# Red point light at the rear
	var tail := OmniLight3D.new()
	tail.position = Vector3(-hl_x, 0.9, 0)
	tail.light_color = Color(1.0, 0.20, 0.18)
	tail.light_energy = 1.4
	tail.omni_range = 3.0
	tail.omni_attenuation = 1.8
	car.add_child(tail)


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
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	_status_label.position = Vector2(20, 92)
	cl.add_child(_status_label)
	var hint := Label.new()
	hint.text = "WASD MOVE · R SPRINT · E INTERACT · I PHONE"
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

func _collect_lights(node: Node) -> void:
	for child in node.get_children():
		if child is Light3D:
			_all_lights.append(child)
		_collect_lights(child)

func _tick_dynamic_culling(delta: float) -> void:
	_cull_t -= delta
	if _cull_t > 0.0 or _player == null:
		return
	_cull_t = 0.3
	var pp: Vector3 = _player.global_position
	for l in _all_lights:
		l.visible = l.global_position.distance_to(pp) < LIGHT_CULL_DIST
	for car in _cars:
		var n: Node3D = car.node
		n.visible = n.global_position.distance_to(pp) < CAR_CULL_DIST
	for npc in _npcs:
		var n: Node3D = npc.node
		npc["culled"] = n.global_position.distance_to(pp) > NPC_CULL_DIST
		n.visible = not npc.culled

func _process(delta: float) -> void:
	_tick_player(delta)
	_tick_dynamic_culling(delta)
	_check_scooter_proximity()

	_tick_camera(delta)
	_tick_walking_npcs(delta)
	_tick_cars(delta)

func _on_car_hit(car_entry: Dictionary, body: Node3D) -> void:
	if not (body is CharacterBody3D) or car_entry.hit_cd > 0.0:
		return
	car_entry.hit_cd = 1.2
	GameState.hp = maxi(1, GameState.hp - 8)
	# Shove the player off the bumper
	var away: float = signf(body.global_position.z - car_entry.node.global_position.z)
	if away == 0.0:
		away = 1.0
	body.global_position.z += away * 2.2
	_set_status("clipped by traffic! watch the road. (-8 HP)")

func _tick_cars(delta: float) -> void:
	for car in _cars:
		car.hit_cd = maxf(0.0, car.hit_cd - delta)
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
		if npc.get("culled", false):
			continue
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
	if _riding_scooter:
		speed = 19.0
	elif Input.is_action_pressed("sprint"):
		speed *= 1.7
	# 3/4 view: direct screen→world mapping (W → -Z, S → +Z).
	# Z motion is foreshortened by the camera angle, so multiply Z speed
	# by ~1.5 so it visually matches X movement on screen.
	var world_dir := Vector3(input.x, 0, input.y)
	_player.velocity.x = world_dir.x * speed
	_player.velocity.z = world_dir.z * speed * 1.5
	_player.velocity.y = 0.0
	_player.move_and_slide()
	if _riding_scooter and _scooter_node:
		_scooter_node.global_position = _player.global_position + Vector3(0, -0.7, 0.15)
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
	# phone_toggle is handled by the Phone autoload — toggling here too made
	# one keypress open+close the phone in the same frame.
	if _ride_open:
		for i in RIDENET_STOPS.size():
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				_ride_to(i)
				return
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
			_close_ridenet()
		return
	if _shop_open:
		if event.is_action_pressed("hotbar_1"):
			_shop_buy(0)
		elif event.is_action_pressed("hotbar_2"):
			_shop_buy(1)
		elif event.is_action_pressed("hotbar_3"):
			_shop_buy(2)
		elif event.is_action_pressed("hotbar_4"):
			_shop_buy(3)
		elif event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
			_close_shop()
		return
	if event.is_action_pressed("interact"):
		if _riding_scooter:
			_dismount_scooter()
			return
		if _near_scooter_idx >= 0:
			_mount_scooter(_near_scooter_idx)
			return
		if _near_terminal:
			_open_ridenet()
			return
		if _near_weapon_shop:
			_open_shop()
			return
		if _near_manhole:
			GameState.pending_dungeon = "sewer"
			SceneTransition.go("dungeon", "from_city")
			return
		# CyberDeck pickup wins over storefronts — they overlap geographically
		# at the ATM end of the block.
		if _near_cyberdeck:
			_pickup_cyberdeck()
		elif not _near_store.is_empty():
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
