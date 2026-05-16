## SceneBuilder — static helpers that turn declarative Scenes.gd dicts into
## live 3D nodes. Keeps scene scripts skinny: they hand the dict + their root
## to SceneBuilder, get back walls/furniture/lights as children.
##
## Not an autoload — a plain static utility class. Call via SceneBuilder.foo().
class_name SceneBuilder
extends Object

# ═══════════════════════════════════════════════════════════════════════
# ENVIRONMENT
# ═══════════════════════════════════════════════════════════════════════

static func apply_environment(root: Node3D, def: Dictionary) -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = def.get("bg_color", Color(0.005, 0.005, 0.012))

	env.glow_enabled = true
	env.glow_intensity = def.get("glow_intensity", 0.55)
	env.glow_strength = def.get("glow_strength", 1.05)
	env.glow_bloom = def.get("glow_bloom", 0.04)
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = def.get("glow_threshold", 1.4)
	env.set("glow_levels/2", true)
	env.set("glow_levels/4", true)
	env.set("glow_levels/6", true)

	var tonemap_name: String = def.get("tonemap", "aces")
	env.tonemap_mode = (Environment.TONE_MAPPER_REINHARDT
		if tonemap_name == "reinhardt" else Environment.TONE_MAPPER_ACES)
	env.tonemap_exposure = def.get("tonemap_exposure", 1.0)

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = def.get("ambient_color", Color(0.04, 0.04, 0.07))
	env.ambient_light_energy = def.get("ambient_energy", 0.4)

	if def.get("ssao", false):
		env.ssao_enabled = true
		env.ssao_intensity = def.get("ssao_intensity", 1.0)

	if def.get("fog", false):
		env.fog_enabled = true
		env.fog_light_color = def.get("fog_color", Color(0.02, 0.015, 0.035))
		env.fog_density = def.get("fog_density", 0.015)

	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	return we

# ═══════════════════════════════════════════════════════════════════════
# CAMERA — orthographic iso or perspective
# ═══════════════════════════════════════════════════════════════════════

static func apply_camera(root: Node3D, def: Dictionary) -> Camera3D:
	var cam := Camera3D.new()
	if def.get("perspective", false):
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = def.get("fov", 45.0)
	else:
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = def.get("size", 14.0)
	cam.position = def.get("position", Vector3(8, 10, 8))
	cam.current = true
	root.add_child(cam)
	# Two ways to aim: explicit rotation OR look_at. Rotation wins if provided
	# (more reliable for canonical iso angles than reverse-engineering look_at).
	if def.has("rotation_degrees"):
		cam.rotation_degrees = def["rotation_degrees"]
	else:
		var look: Vector3 = def.get("look_at", Vector3.ZERO)
		if look != cam.position:
			cam.look_at(look, Vector3.UP)
	return cam

# ═══════════════════════════════════════════════════════════════════════
# ROOM (floor + walls)
# ═══════════════════════════════════════════════════════════════════════

static func build_room(root: Node3D, def: Dictionary) -> void:
	var size: Vector3 = def.get("size", Vector3(14, 4, 10))
	var wall_t: float = def.get("wall_thickness", 0.3)
	# Floor
	_add_box(root, Vector3(0, -0.05, 0), Vector3(size.x, 0.1, size.z),
		def.get("floor_color", Color(0.18, 0.14, 0.12)), 0.0, 0.7)
	# Walls — back (-z), front (+z), left (-x), right (+x with optional door gap)
	_add_wall(root, Vector3(0, size.y / 2.0, -size.z / 2.0),
		Vector3(size.x, size.y, wall_t),
		def.get("wall_color_back", def.get("wall_color", Color(0.2, 0.17, 0.24))))
	_add_wall(root, Vector3(0, size.y / 2.0, size.z / 2.0),
		Vector3(size.x, size.y, wall_t),
		def.get("wall_color_front", def.get("wall_color", Color(0.14, 0.12, 0.16))))
	_add_wall(root, Vector3(-size.x / 2.0, size.y / 2.0, 0),
		Vector3(wall_t, size.y, size.z),
		def.get("wall_color", Color(0.18, 0.16, 0.22)))

	# Right wall — split for door gap if specified
	var door_side: String = def.get("door_side", "")
	var gap: float = def.get("door_gap_size", 0.0)
	var gap_pos: float = def.get("door_gap_position", 0.0)
	if door_side == "right" and gap > 0:
		var seg_below_d := (size.z / 2.0) + gap_pos - gap / 2.0
		var seg_above_d := (size.z / 2.0) - gap_pos - gap / 2.0
		var seg_below_z := -size.z / 2.0 + seg_below_d / 2.0
		var seg_above_z := size.z / 2.0 - seg_above_d / 2.0
		# Below the gap
		_add_wall(root, Vector3(size.x / 2.0, size.y / 2.0, seg_below_z),
			Vector3(wall_t, size.y, seg_below_d),
			def.get("wall_color", Color(0.18, 0.16, 0.22)))
		# Above the gap (upper portion — lintel)
		_add_wall(root, Vector3(size.x / 2.0, size.y / 2.0 + 1.2, gap_pos),
			Vector3(wall_t, size.y - 2.4, gap),
			def.get("wall_color", Color(0.18, 0.16, 0.22)))
		# Far above the gap
		_add_wall(root, Vector3(size.x / 2.0, size.y / 2.0, seg_above_z),
			Vector3(wall_t, size.y, seg_above_d),
			def.get("wall_color", Color(0.18, 0.16, 0.22)))
	else:
		_add_wall(root, Vector3(size.x / 2.0, size.y / 2.0, 0),
			Vector3(wall_t, size.y, size.z),
			def.get("wall_color", Color(0.18, 0.16, 0.22)))

# ═══════════════════════════════════════════════════════════════════════
# FURNITURE — dispatches on type
# ═══════════════════════════════════════════════════════════════════════

static func build_furniture(root: Node3D, items: Array) -> void:
	for item in items:
		match item.get("type", ""):
			"desk":         _furn_desk(root, item)
			"monitor":      _furn_monitor(root, item)
			"neon_strip":   _furn_neon_strip(root, item)
			"bed":          _furn_bed(root, item)
			"window":       _furn_window(root, item)
			"ceiling_lamp": _furn_ceiling_lamp(root, item)

static func _furn_desk(root: Node3D, item: Dictionary) -> void:
	var pos: Vector3 = item["position"]
	var sz: Vector3 = item.get("size", Vector3(2.2, 0.08, 1.2))
	var col: Color = item.get("color", Color(0.18, 0.13, 0.1))
	_add_box(root, pos + Vector3(0, 0.9, 0), sz, col, 0.0, 0.7)
	# Four legs
	for dx in [-1.0, 1.0]:
		for dz in [-0.5, 0.5]:
			_add_box(root, pos + Vector3(dx, 0.45, dz), Vector3(0.08, 0.9, 0.08),
				Color(0.05, 0.05, 0.06), 0.3, 0.6)

static func _furn_monitor(root: Node3D, item: Dictionary) -> void:
	var pos: Vector3 = item["position"]
	var screen: Color = item.get("screen_color", Color(0.0, 1.0, 0.53))
	var energy: float = item.get("screen_energy", 1.8)
	# Stand + body + screen
	_add_box(root, pos + Vector3(0, -0.55, 0), Vector3(0.6, 0.12, 0.6),
		Color(0.04, 0.04, 0.05), 0.5, 0.4)
	_add_box(root, pos, Vector3(1.4, 1.0, 0.4), Color(0.03, 0.03, 0.04), 0.5, 0.4)
	_add_box(root, pos + Vector3(0, 0, 0.21), Vector3(1.2, 0.8, 0.02),
		screen * 0.4, 0.0, 0.3, true, screen, energy)

static func _furn_neon_strip(root: Node3D, item: Dictionary) -> void:
	var pos: Vector3 = item["position"]
	var sz: Vector3 = item.get("size", Vector3(2.0, 0.04, 0.08))
	var c: Color = item.get("color", Color(1.0, 0.0, 0.4))
	var e: float = item.get("energy", 4.0)
	_add_box(root, pos, sz, c, 0.0, 0.5, true, c, e)

static func _furn_bed(root: Node3D, item: Dictionary) -> void:
	var pos: Vector3 = item["position"]
	var frame_sz: Vector3 = item.get("frame_size", Vector3(2.0, 0.3, 3.0))
	var blanket: Color = item.get("blanket_color", Color(0.05, 0.18, 0.22))
	_add_box(root, pos + Vector3(0, 0.3, 0), frame_sz, Color(0.1, 0.07, 0.05), 0.0, 0.8)
	_add_box(root, pos + Vector3(0, 0.55, 0), frame_sz - Vector3(0.2, 0.05, 0.2),
		Color(0.2, 0.18, 0.25), 0.0, 0.9)
	_add_box(root, pos + Vector3(0, 0.75, -1.0), Vector3(1.4, 0.18, 0.55),
		Color(0.85, 0.85, 0.88), 0.0, 0.85)
	_add_box(root, pos + Vector3(0, 0.74, 0.4),
		Vector3(frame_sz.x - 0.3, 0.06, frame_sz.z - 1.2), blanket, 0.0, 0.85)

static func _furn_window(root: Node3D, item: Dictionary) -> void:
	var pos: Vector3 = item["position"]
	var sz: Vector3 = item.get("size", Vector3(3.5, 1.8, 0.02))
	var view: Color = item.get("view_color", Color(0.55, 0.15, 0.95))
	var energy: float = item.get("view_energy", 0.9)
	# Frame outline
	_add_box(root, pos, Vector3(sz.x + 0.15, sz.y + 0.15, 0.04),
		Color(0.02, 0.02, 0.03), 0.4, 0.6)
	# Emissive view panel
	_add_box(root, pos + Vector3(0, 0, 0.02), sz, Color(0.08, 0.05, 0.18), 0.0, 0.2,
		true, view, energy)
	# Distant lit-window pattern inside the view
	var rng := RandomNumberGenerator.new()
	rng.set_seed(7)
	var window_colors := [
		Color(1.0, 0.0, 0.4),
		Color(0.0, 1.0, 1.0),
		Color(0.27, 1.0, 0.53),
		Color(1.0, 0.67, 0.0),
	]
	for i in range(36):
		if rng.randf() > 0.6:
			continue
		var bx := pos.x + rng.randf_range(-sz.x / 2.0 + 0.1, sz.x / 2.0 - 0.1)
		var by := pos.y + rng.randf_range(-sz.y / 2.0 + 0.1, sz.y / 2.0 - 0.1)
		var color: Color = window_colors[rng.randi() % window_colors.size()]
		_add_box(root, Vector3(bx, by, pos.z + 0.04), Vector3(0.12, 0.18, 0.01),
			color * 0.5, 0.0, 0.3, true, color, 4.0)

static func _furn_ceiling_lamp(root: Node3D, item: Dictionary) -> void:
	var pos: Vector3 = item["position"]
	var bulb: Color = item.get("bulb_color", Color(1.0, 0.85, 0.55))
	_add_box(root, pos + Vector3(0, 0.15, 0), Vector3(0.6, 0.12, 0.6),
		Color(0.05, 0.05, 0.06), 0.5, 0.4)
	_add_box(root, pos, Vector3(0.25, 0.15, 0.25), bulb * 0.7, 0.0, 0.3, true, bulb, 1.4)

# ═══════════════════════════════════════════════════════════════════════
# OUTDOOR — ground, roads, sidewalks, buildings with procedural windows
# ═══════════════════════════════════════════════════════════════════════

static func build_ground(root: Node3D, def: Dictionary) -> void:
	var sz: Vector3 = def.get("size", Vector3(40, 0.1, 40))
	var col: Color = def.get("color", Color(0.015, 0.015, 0.02))
	_add_box(root, Vector3(0, -sz.y / 2.0, 0), sz, col, 0.0, 0.9)

static func build_roads(root: Node3D, items: Array) -> void:
	for r in items:
		_add_box(root, r["position"], r["size"], r["color"], 0.2, 0.5)

static func build_sidewalks(root: Node3D, items: Array) -> void:
	for s in items:
		_add_box(root, s["position"], s["size"], s.get("color", Color(0.035, 0.035, 0.04)),
			0.0, 0.85)

static func build_buildings(root: Node3D, items: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.set_seed(99)
	var window_colors := [
		Color(1.0, 0.0, 0.4),
		Color(0.0, 1.0, 1.0),
		Color(0.27, 1.0, 0.53),
		Color(1.0, 0.67, 0.0),
	]
	for b in items:
		var pos: Vector3 = b["position"]
		var sz: Vector3 = b["size"]
		var col := Color(
			rng.randf_range(0.02, 0.035),
			rng.randf_range(0.02, 0.03),
			rng.randf_range(0.025, 0.04))
		_add_box(root, pos + Vector3(0, sz.y / 2.0, 0), sz, col, 0.05, 0.85)

		# Rooftop warning light
		if b.get("rooftop_light", false):
			_add_box(root, pos + Vector3(0, sz.y + 0.15, 0), Vector3(0.15, 0.15, 0.15),
				Color(0.8, 0.05, 0.02), 0.0, 0.5,
				true, Color(0.9, 0.05, 0.02), 3.0)

		if b.get("windows", false):
			_building_windows(root, pos, sz, window_colors, rng)

static func _building_windows(root: Node3D, pos: Vector3, sz: Vector3,
		palette: Array, rng: RandomNumberGenerator) -> void:
	# Front face (+Z)
	var y_start := pos.y + 1.0
	var y_end := pos.y + sz.y - 0.5
	var y := y_start
	while y < y_end:
		var x := pos.x - sz.x / 2.0 + 0.5
		while x < pos.x + sz.x / 2.0 - 0.4:
			if rng.randf() < 0.55:
				var lit := rng.randf() < 0.5
				var color: Color = palette[rng.randi() % palette.size()] if lit else Color(0.02, 0.02, 0.03)
				var energy := rng.randf_range(2.5, 4.5) if lit else 0.0
				_add_box(root, Vector3(x, y, pos.z + sz.z / 2.0 + 0.015),
					Vector3(0.35, 0.5, 0.02),
					color * 0.4, 0.7, 0.15, lit, color, energy)
			x += 0.9
		y += 1.1
	# Side face (+X)
	y = y_start
	while y < y_end:
		var z := pos.z - sz.z / 2.0 + 0.5
		while z < pos.z + sz.z / 2.0 - 0.4:
			if rng.randf() < 0.5:
				var lit := rng.randf() < 0.45
				var color: Color = palette[rng.randi() % palette.size()] if lit else Color(0.02, 0.02, 0.03)
				var energy := rng.randf_range(2.0, 4.0) if lit else 0.0
				_add_box(root, Vector3(pos.x + sz.x / 2.0 + 0.015, y, z),
					Vector3(0.02, 0.5, 0.35),
					color * 0.4, 0.7, 0.15, lit, color, energy)
			z += 0.9
		y += 1.1

static func build_neon_signs(root: Node3D, items: Array) -> void:
	for s in items:
		var pos: Vector3 = s["position"]
		var sz: Vector3 = s["size"]
		var color: Color = s["color"]
		var energy: float = s.get("energy", 6.0)
		_add_box(root, pos, sz, Color(1, 1, 1), 0.0, 0.5, true, color, energy)
		var light := OmniLight3D.new()
		light.light_color = color
		light.light_energy = energy * 0.1
		light.omni_range = 4.0
		light.omni_attenuation = 1.7
		light.position = pos
		root.add_child(light)

static func build_streetlights(root: Node3D, positions: Array) -> void:
	for pos in positions:
		# Pole
		_add_box(root, pos + Vector3(0, 2.2, 0), Vector3(0.06, 4.4, 0.06),
			Color(0.03, 0.03, 0.035), 0.4, 0.6)
		# Arm
		_add_box(root, pos + Vector3(0.4, 4.3, 0), Vector3(0.8, 0.05, 0.05),
			Color(0.03, 0.03, 0.035), 0.4, 0.6)
		# Fixture (emissive bulb)
		_add_box(root, pos + Vector3(0.8, 4.2, 0), Vector3(0.25, 0.1, 0.25),
			Color(0.8, 0.7, 0.5), 0.0, 0.5, true, Color(1.0, 0.85, 0.6), 3.0)
		# Downward spot
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.85, 0.6)
		spot.light_energy = 2.5
		spot.spot_range = 7.0
		spot.spot_angle = 50.0
		spot.spot_attenuation = 1.3
		spot.shadow_enabled = true
		spot.position = pos + Vector3(0.8, 4.1, 0)
		spot.rotation.x = -PI / 2.0
		root.add_child(spot)

# ═══════════════════════════════════════════════════════════════════════
# LIGHTS
# ═══════════════════════════════════════════════════════════════════════

static func build_lights(root: Node3D, items: Array) -> void:
	for item in items:
		match item.get("type", "omni"):
			"omni":
				var l := OmniLight3D.new()
				l.light_color = item.get("color", Color(1, 1, 1))
				l.light_energy = item.get("energy", 1.0)
				l.omni_range = item.get("range", 5.0)
				l.omni_attenuation = item.get("attenuation", 1.5)
				l.shadow_enabled = item.get("shadow", false)
				l.position = item["position"]
				root.add_child(l)
			"spot":
				var s := SpotLight3D.new()
				s.light_color = item.get("color", Color(1, 1, 1))
				s.light_energy = item.get("energy", 1.0)
				s.spot_range = item.get("range", 7.0)
				s.spot_angle = item.get("angle", 45.0)
				s.spot_attenuation = item.get("attenuation", 1.3)
				s.shadow_enabled = item.get("shadow", false)
				s.position = item["position"]
				if item.has("rotation"):
					s.rotation = item["rotation"]
				root.add_child(s)

# ═══════════════════════════════════════════════════════════════════════
# LOW-LEVEL HELPERS
# ═══════════════════════════════════════════════════════════════════════

static func _add_box(root: Node3D, pos: Vector3, sz: Vector3, col: Color,
		metallic: float = 0.0, roughness: float = 0.8, emissive: bool = false,
		emission_col: Color = Color.BLACK, emission_energy: float = 0.0) -> MeshInstance3D:
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
	mi.position = pos
	root.add_child(mi)
	return mi

static func _add_wall(root: Node3D, pos: Vector3, sz: Vector3, col: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	mesh.material = mat
	var body := StaticBody3D.new()
	body.position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	body.add_child(mi)
	var col_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	col_shape.shape = shape
	body.add_child(col_shape)
	root.add_child(body)
