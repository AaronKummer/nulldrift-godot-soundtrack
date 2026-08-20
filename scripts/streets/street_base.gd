## StreetBase — shared plumbing for every street in Signal Hollow.
##
## The city is a roster of authored east-west streets connected by RIDENET
## (streets as stages, Yakuza-style — no generated filler). Each street
## scene extends this and implements _build_street(). The base provides:
## camera + environment, player + movement (with car-clip damage hooks),
## two-sided street shell (road, sidewalks, canal-or-rubble south edge,
## skyline backdrop), HUD, interact zones, and the RIDENET travel menu.
##
## The hand-built home street (city.gd) predates this and stays as-is.
extends Node3D

const StreetDefsData := preload("res://data/street_defs.gd")
const AnimatedBillboardScript := preload("res://scripts/systems/animated_billboard.gd")
const ListMenuScript := preload("res://scripts/systems/list_menu.gd")

const ROAD_WIDTH := 22.0
const SIDEWALK_W := 5.0
const CAMERA_OFFSET := Vector3(0.0, 14.0, 24.0)
const CAMERA_AIM_OFFSET := Vector3(0.0, 2.0, -2.0)
const CAMERA_ORTHO_SIZE := 22.0
const CAMERA_FOLLOW_LERP := 9.0

var street_id := ""                 # set by the subclass before super._ready()
var block_half_w := 60.0
var _camera: Camera3D
var _camera_locked_rotation: Vector3
var _env: Environment
var _player: CharacterBody3D
var _player_anim
var _status_label: Label
var _title_label: Label
var _near_terminal := false
var _ride_menu
var _ride_open := false
var _interact_zones: Array = []     # {area, prompt, callback}
var _near_zone: Dictionary = {}

func _ready() -> void:
	_setup_camera()
	_setup_environment()
	_build_shell()
	_build_street()          # subclass content
	_build_player()
	_build_hud()
	_apply_pending_spawn()

## Subclasses override: build storefronts, NPCs, props between
## x = -block_half_w .. block_half_w, buildings north of z = -SIDEWALK_W.
func _build_street() -> void:
	pass

## Subclass hooks
func _street_name() -> String:
	return StreetDefsData.STREETS.get(street_id, {}).get("name", "???")

func _ambient_color() -> Color:
	return Color(0.10, 0.09, 0.14)

func _fog_color() -> Color:
	return Color(0.18, 0.08, 0.28)

func _moon_color() -> Color:
	return Color(0.50, 0.55, 0.85)

func _moon_energy() -> float:
	return 0.35


# ═══════════════════════════════════════════════════════════════════════
# CAMERA / ENV / SHELL
# ═══════════════════════════════════════════════════════════════════════

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_ORTHO_SIZE
	_camera.near = 0.05
	_camera.far = 400.0
	_camera.current = true
	add_child(_camera)
	_camera.position = CAMERA_OFFSET
	_camera.look_at(CAMERA_AIM_OFFSET, Vector3.UP)
	_camera_locked_rotation = _camera.rotation

func _setup_environment() -> void:
	# Matches the home street's proven recipe: dusk sky, ACES, dark ambient
	# (real lights carry the look), SSAO, volumetric fog for the lamp cones.
	_env = Environment.new()
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
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = _ambient_color()
	_env.ambient_light_energy = 0.75
	_env.ssao_enabled = true
	_env.ssao_radius = 1.4
	_env.ssao_intensity = 1.6
	_env.fog_enabled = true
	_env.fog_density = 0.003
	_env.fog_light_color = _fog_color()
	_env.fog_light_energy = 0.6
	_env.fog_aerial_perspective = 0.35
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.035
	_env.volumetric_fog_albedo = _fog_color() * 2.0
	_env.volumetric_fog_anisotropy = 0.3
	_env.volumetric_fog_length = 60.0
	_env.volumetric_fog_ambient_inject = 0.4
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	# Moonlight — the base illumination every night street needs (the home
	# street has one too; scenes without it render pitch black)
	var moon := DirectionalLight3D.new()
	moon.light_color = _moon_color()
	moon.light_energy = _moon_energy()
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-55, -20, 0)
	add_child(moon)

## Streetlamps — themed by subclass via _lamp_color() / _lamp_broken_chance()
func _lamp_color() -> Color:
	return Color(1.0, 0.85, 0.55)

func _lamp_broken_chance() -> float:
	return 0.0

func build_streetlamps(spacing: float = 22.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(street_id) + 99
	var lx := -block_half_w + 8.0
	while lx < block_half_w:
		var broken: bool = rng.randf() < _lamp_broken_chance()
		_add_box(Vector3(lx, 2.6, -1.0), Vector3(0.14, 5.2, 0.14),
			Color(0.15, 0.15, 0.18), 0.7, 0.4)
		_add_box(Vector3(lx, 5.15, -0.6), Vector3(0.12, 0.12, 0.9),
			Color(0.15, 0.15, 0.18), 0.7, 0.4)
		if broken:
			_add_box(Vector3(lx, 5.0, -0.2), Vector3(0.3, 0.18, 0.3),
				Color(0.10, 0.10, 0.11), 0.5, 0.6)
		else:
			_add_box(Vector3(lx, 5.0, -0.2), Vector3(0.3, 0.18, 0.3),
				_lamp_color() * Color(0.3, 0.3, 0.3, 1.0), 0.0, 0.3,
				true, _lamp_color(), 2.5)
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(lx, 4.6, -0.2)
			lamp.light_color = _lamp_color()
			lamp.light_energy = 2.2
			lamp.omni_range = 9.0
			lamp.omni_attenuation = 1.6
			add_child(lamp)
		lx += spacing + rng.randf_range(-3.0, 3.0)

func _build_shell() -> void:
	# Ground everywhere — never void
	_add_box(Vector3(0, -0.06, 0), Vector3(900.0, 0.08, 700.0),
		Color(0.045, 0.045, 0.06), 0.0, 0.9)
	# Road + sidewalks
	_add_box(Vector3(0, -0.02, ROAD_WIDTH * 0.5),
		Vector3(block_half_w * 2.0 + 60.0, 0.1, ROAD_WIDTH),
		Color(0.05, 0.05, 0.07), 0.0, 0.85)
	_add_box(Vector3(0, -0.01, -SIDEWALK_W * 0.5),
		Vector3(block_half_w * 2.0 + 60.0, 0.14, SIDEWALK_W),
		Color(0.13, 0.13, 0.15), 0.0, 0.9)
	# Center dashes
	var dx := -block_half_w - 20.0
	while dx < block_half_w + 20.0:
		_add_box(Vector3(dx, 0.06, ROAD_WIDTH * 0.5), Vector3(4.0, 0.04, 0.45),
			Color(0.7, 0.55, 0.08), 0.0, 0.4, true, Color(1.0, 0.85, 0.18), 2.0)
		dx += 11.0
	# South frontage: low strip so the street is two-sided (camera-safe)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(street_id) + 7
	var sx := -block_half_w
	while sx < block_half_w:
		var w: float = rng.randf_range(8.0, 16.0)
		var body := Color(0.17, 0.15, 0.20) * rng.randf_range(0.8, 1.2)
		_add_box(Vector3(sx + w * 0.5, 1.4, ROAD_WIDTH + 4.0),
			Vector3(w, 2.8, 6.0), body, 0.2, 0.8)
		_add_box(Vector3(sx + w * 0.5, 2.9, ROAD_WIDTH + 4.0),
			Vector3(w + 0.3, 0.15, 6.3), body * 1.5, 0.2, 0.7)
		sx += w + rng.randf_range(1.0, 4.0)
	# South boundary rail + collider
	_add_box(Vector3(0, 0.55, ROAD_WIDTH + 8.2),
		Vector3(block_half_w * 2.0 + 60.0, 0.08, 0.08),
		Color(0.1, 0.3, 0.35), 0.6, 0.3, true, Color(0.1, 0.9, 1.0), 1.2)
	var rail := StaticBody3D.new()
	var rc := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	rs.size = Vector3(900.0, 4.0, 0.5)
	rc.shape = rs
	rail.position = Vector3(0, 2.0, ROAD_WIDTH + 8.4)
	rail.add_child(rc)
	add_child(rail)
	# East/west end walls (subclass dresses them)
	for ex in [-block_half_w - 2.0, block_half_w + 2.0]:
		var wall := StaticBody3D.new()
		var wc := CollisionShape3D.new()
		var wsh := BoxShape3D.new()
		wsh.size = Vector3(1.0, 6.0, 60.0)
		wc.shape = wsh
		wall.position = Vector3(ex, 3.0, 8.0)
		wall.add_child(wc)
		add_child(wall)
	# Skyline backdrop rows north + south
	_build_backdrop_row(ROAD_WIDTH + 46.0, hash(street_id) + 11, 10.0, 22.0)
	_build_backdrop_row(-46.0, hash(street_id) + 12, 16.0, 34.0)

func _build_backdrop_row(z: float, seed_v: int, h_min: float, h_max: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	var items: Array = []
	var x := -420.0
	while x < 420.0:
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


# ═══════════════════════════════════════════════════════════════════════
# PLAYER / CAMERA TICK / HUD
# ═══════════════════════════════════════════════════════════════════════

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.position = Vector3(0, 0.85, -2.5)
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

func _apply_pending_spawn() -> void:
	var spawn: String = SceneTransition.consume_spawn()
	if spawn == "" or _player == null:
		return
	var marker := find_child(spawn, true, false)
	if marker and marker is Node3D:
		_player.global_position = (marker as Node3D).global_position + Vector3(0, 0.85, 0)

func _process(delta: float) -> void:
	_tick_player(delta)
	_tick_camera(delta)
	_tick_traffic(delta)
	_tick_walkers(delta)
	_street_process(delta)

## Subclass per-frame hook
func _street_process(_delta: float) -> void:
	pass


# ═══════════════════════════════════════════════════════════════════════
# TRAFFIC — self-lit cars, two lanes, follow-the-leader (shared by all
# streets; the home street has its own hand-built system)
# ═══════════════════════════════════════════════════════════════════════

var _cars: Array = []

func build_traffic(count: int = 8, palette: Array = []) -> void:
	if palette.is_empty():
		palette = [Color(0.7, 0.2, 0.25), Color(0.2, 0.5, 0.8),
			Color(0.75, 0.7, 0.65), Color(0.25, 0.6, 0.4),
			Color(0.5, 0.3, 0.7), Color(0.85, 0.6, 0.2)]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(street_id) + 99
	for i in count:
		var east := i % 2 == 0
		var lane_z: float = ROAD_WIDTH * (0.72 if east else 0.30)
		var node := Node3D.new()
		node.position = Vector3(rng.randf_range(-block_half_w, block_half_w),
			0, lane_z + rng.randf_range(-0.4, 0.4))
		add_child(node)
		_build_car_visual(node, palette[rng.randi() % palette.size()], east)
		_cars.append({ "node": node, "lane": lane_z,
			"speed": (1.0 if east else -1.0) * rng.randf_range(7.0, 11.0) })

func _build_car_visual(parent: Node3D, col: Color, east: bool) -> void:
	var dir := 1.0 if east else -1.0
	# Self-lit paint so cars read at night
	_add_part(parent, Vector3(0, 0.55, 0), Vector3(4.6, 0.9, 2.0),
		col * 0.55, 0.4, 0.4, true, col * 0.5, 0.35)
	_add_part(parent, Vector3(-dir * 0.3, 1.25, 0), Vector3(2.4, 0.6, 1.8),
		col * 0.35, 0.4, 0.3, true, col * 0.35, 0.3)
	_add_part(parent, Vector3(dir * 0.95, 1.25, 0), Vector3(0.1, 0.5, 1.6),
		Color(0.1, 0.15, 0.2), 0.8, 0.2)
	for zz in [-0.7, 0.7]:
		_add_part(parent, Vector3(dir * 2.32, 0.6, zz), Vector3(0.08, 0.22, 0.3),
			Color(1, 1, 0.9), 0.0, 0.4, true, Color(1.3, 1.25, 1.0), 3.0)
		_add_part(parent, Vector3(-dir * 2.32, 0.6, zz), Vector3(0.08, 0.2, 0.3),
			Color(0.8, 0.1, 0.1), 0.0, 0.4, true, Color(1.5, 0.15, 0.1), 2.2)
	for wx in [-1.5, 1.5]:
		for wz in [-1.0, 1.0]:
			_add_part(parent, Vector3(wx, 0.32, wz), Vector3(0.62, 0.62, 0.22),
				Color(0.05, 0.05, 0.06), 0.2, 0.8)

## Visual-only box parented to a node (no collision — traffic is set dressing)
func _add_part(parent: Node3D, pos: Vector3, sz: Vector3, col: Color,
		metallic: float = 0.0, roughness: float = 0.8, emissive: bool = false,
		emission: Color = Color.BLACK, energy: float = 1.0) -> void:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mesh.mesh = bm
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metallic
	mat.roughness = roughness
	if emissive:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	mesh.material_override = mat
	parent.add_child(mesh)

func _tick_traffic(delta: float) -> void:
	for car in _cars:
		var n: Node3D = car.node
		var gap := 999.0
		var lead_speed: float = absf(car.speed)
		for other in _cars:
			if other == car or signf(other.speed) != signf(car.speed):
				continue
			if absf(other.node.position.z - n.position.z) > 2.5:
				continue
			var ahead: float = (other.node.position.x - n.position.x) * signf(car.speed)
			if ahead > 0.0 and ahead < gap:
				gap = ahead
				lead_speed = absf(other.speed)
		var eff: float = absf(car.speed)
		if gap < 7.0:
			eff = 0.0
		elif gap < 13.0:
			eff = minf(eff, lead_speed)
		n.position.x += signf(car.speed) * eff * delta
		if car.speed > 0 and n.position.x > block_half_w + 14.0:
			n.position.x = -block_half_w - 14.0
		elif car.speed < 0 and n.position.x < -block_half_w - 14.0:
			n.position.x = block_half_w + 14.0


# ═══════════════════════════════════════════════════════════════════════
# WALKERS — sidewalk NPCs that actually walk
# ═══════════════════════════════════════════════════════════════════════

var _walkers: Array = []

func add_walker(sheet: String, x_min: float, x_max: float, z: float,
		speed: float = 2.0) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(randf_range(x_min, x_max), 0.9, z)
	add_child(pivot)
	var ab = AnimatedBillboardScript.new()
	ab.show_floor_shadow = false
	ab.pixel_size = 0.04
	pivot.add_child(ab)
	ab.load_sheet(sheet)
	ab.set_moving(true)
	var dir := 1 if randf() < 0.5 else -1
	ab.facing = AnimatedBillboardScript.Facing.RIGHT if dir > 0 		else AnimatedBillboardScript.Facing.LEFT
	_walkers.append({ "node": pivot, "ab": ab, "dir": dir,
		"x_min": x_min, "x_max": x_max, "speed": speed })

func _tick_walkers(delta: float) -> void:
	for w in _walkers:
		var n: Node3D = w.node
		n.position.x += w.dir * w.speed * delta
		if n.position.x > w.x_max:
			w.dir = -1
			w.ab.facing = AnimatedBillboardScript.Facing.LEFT
		elif n.position.x < w.x_min:
			w.dir = 1
			w.ab.facing = AnimatedBillboardScript.Facing.RIGHT

func _tick_player(_delta: float) -> void:
	if _player == null or _ride_open:
		return
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	var speed := 6.0
	if Input.is_action_pressed("sprint"):
		speed *= 1.7
	_player.velocity.x = input.x * speed
	_player.velocity.z = input.y * speed * 1.5
	_player.velocity.y = 0.0
	_player.move_and_slide()
	if _player_anim:
		_player_anim.update_facing_from_input(input)
		_player_anim.set_moving(input.length() > 0.1)

func _tick_camera(delta: float) -> void:
	if _camera == null or _player == null:
		return
	var target := _player.global_position + CAMERA_OFFSET
	_camera.global_position = _camera.global_position.lerp(target,
		clampf(delta * CAMERA_FOLLOW_LERP, 0.0, 1.0))
	_camera.rotation = _camera_locked_rotation

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_title_label = Label.new()
	_title_label.text = _street_name()
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", Color(0.2, 1.0, 1.0))
	_title_label.position = Vector2(20, 14)
	cl.add_child(_title_label)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_status_label.add_theme_constant_override("shadow_offset_y", 2)
	_status_label.position = Vector2(20, 38)
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

func _set_status(t: String) -> void:
	if _status_label:
		_status_label.text = t


# ═══════════════════════════════════════════════════════════════════════
# INTERACT ZONES + RIDENET
# ═══════════════════════════════════════════════════════════════════════

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

func build_ridenet_terminal(pos: Vector3) -> void:
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
	add_interact(pos + Vector3(0, 1.2, 0.8), Vector3(2.4, 2.4, 2.4),
		"RIDENET — ride across town", _open_ridenet)

func _open_ridenet() -> void:
	_ride_open = true
	_ride_menu = ListMenuScript.new()
	add_child(_ride_menu)
	_ride_menu.picked.connect(_ride_to_street)
	_ride_menu.closed.connect(func():
		_ride_open = false
		_ride_menu = null)
	var entries: Array = []
	for st in StreetDefsData.street_list():
		var here: bool = st.id == street_id
		var built: bool = st.get("scene", "") != ""
		var tag := ""
		if here:
			tag = " · you are here"
		elif not built:
			tag = " · [SOON]"
		else:
			tag = " · %d cr" % st.cost
		entries.append({ "label": st.name + tag, "dim": here or not built })
	_ride_menu.open("RIDENET · where to?", entries, Color(0.2, 1.0, 1.2),
		"credits: $%d" % GameState.credits)

func _close_ridenet() -> void:
	if _ride_menu:
		_ride_menu.close_menu()

func _ride_to_street(idx: int) -> void:
	var streets: Array = StreetDefsData.street_list()
	if idx >= streets.size():
		return
	var st: Dictionary = streets[idx]
	if st.id == street_id:
		if _ride_menu:
			_ride_menu.set_footer("RIDENET: 'you're already here, choom.'")
		return
	if st.get("scene", "") == "":
		if _ride_menu:
			_ride_menu.set_footer("RIDENET: 'that route's closed for construction.'")
		return
	if GameState.credits < st.cost:
		if _ride_menu:
			_ride_menu.set_footer("RIDENET: 'insufficient credits.'")
		return
	GameState.add_credits(-st.cost)
	_close_ridenet()
	SceneTransition.ride_to(st.scene, "from_ridenet", st.name)


# ═══════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if _ride_open:
		return   # ListMenu owns input while a menu is up
	if event.is_action_pressed("interact") and not _near_zone.is_empty():
		_near_zone.callback.call()


# ═══════════════════════════════════════════════════════════════════════
# Helpers
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

func add_npc(sheet: String, pos: Vector3, facing: int = 0) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var ab = AnimatedBillboardScript.new()
	ab.show_floor_shadow = false
	ab.pixel_size = 0.04
	pivot.add_child(ab)
	ab.load_sheet(sheet)
	ab.facing = facing
	ab.set_moving(false)
