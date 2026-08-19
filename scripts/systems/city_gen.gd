## CityGen — Signal Hollow grows up. Expands the hand-built home block into
## a district city, re-imagining the Phaser zoneConfigs (6x8 grid, corpo /
## suburban / downtown / warzone bands) with real 3D depth.
##
## Rendering is MULTIMESH-BATCHED: every generated building is one instance
## of a unit cube, every lit window one instance of a quad, lamps and road
## dashes likewise — whole districts cost a handful of draw calls, which is
## what makes a 20x+ city affordable (the old per-window nodes could not).
## Generated bands use emissive-only lighting; real OmniLights stay on the
## home band. Collision is invisible boxes, so blocks stay solid.
##
## Layout: horizontal bands stacked along Z at BAND_PITCH, the home block
## at band 0 untouched. Two vertical avenues cut through every band so you
## can walk (or ride) between districts.
class_name CityGen
extends Object

const BAND_PITCH := 60.0
const X_EXTENT := 180.0
const AVENUE_XS := [-69.0, 69.0]    # vertical cross streets (centers)
const AVENUE_W := 14.0
const ROAD_W := 22.0
const SIDEWALK_W := 5.0

# District bands, north to south. Band 0 is the hand-built home block.
const BANDS := [
	{ "k": -3, "district": "corpo" },
	{ "k": -2, "district": "corpo" },
	{ "k": -1, "district": "suburban" },
	{ "k": 1, "district": "downtown" },
	{ "k": 2, "district": "warzone" },
	{ "k": 3, "district": "warzone" },
]

# Sign pools straight from the Phaser zoneConfigs — they're canon.
const DISTRICTS := {
	"corpo": {
		"heights": [26.0, 44.0], "widths": [16.0, 26.0], "gap": [2.0, 6.0],
		"bodies": [Color(0.10, 0.10, 0.18), Color(0.09, 0.13, 0.24),
			Color(0.06, 0.20, 0.38), Color(0.10, 0.10, 0.24)],
		"win_colors": [Color(0.45, 0.85, 1.3), Color(0.55, 0.7, 1.2), Color(0.8, 0.9, 1.3)],
		"lit": 0.55, "win_pitch": Vector2(3.2, 3.4),
		"signs": ["SYNAPSE", "QUANTIX", "AUTOMATE", "PREDICT", "DATAFLOW",
			"OMNICORP", "CORTEX", "KURONEX", "DEEPMIND", "ITERION", "ALGO", "NEURAL"],
		"sign_colors": [Color(0.3, 1.4, 1.8), Color(0.5, 0.8, 1.8), Color(1.2, 1.2, 1.8)],
		"lamp": Color(0.7, 0.9, 1.6),
	},
	"suburban": {
		"heights": [5.0, 9.0], "widths": [9.0, 14.0], "gap": [4.0, 10.0],
		"bodies": [Color(0.16, 0.13, 0.09), Color(0.10, 0.22, 0.10),
			Color(0.16, 0.18, 0.12), Color(0.22, 0.18, 0.12)],
		"win_colors": [Color(1.4, 1.1, 0.5), Color(1.3, 0.9, 0.4), Color(1.2, 1.2, 0.7)],
		"lit": 0.45, "win_pitch": Vector2(3.4, 2.8),
		"signs": ["CONEYS", "VERNORS", "BAKERS", "GARDEN", "LODGE", "INN", "CABIN"],
		"sign_colors": [Color(1.6, 1.0, 0.3), Color(1.4, 0.6, 0.3)],
		"lamp": Color(1.5, 1.1, 0.5),
	},
	"downtown": {
		"heights": [12.0, 26.0], "widths": [12.0, 22.0], "gap": [2.0, 7.0],
		"bodies": [Color(0.20, 0.40, 0.67), Color(0.27, 0.47, 0.73),
			Color(0.26, 0.33, 0.40), Color(0.20, 0.27, 0.33)],
		"win_colors": [Color(1.4, 1.1, 0.5), Color(0.5, 1.1, 1.4), Color(1.3, 0.5, 1.1)],
		"lit": 0.50, "win_pitch": Vector2(3.0, 3.2),
		"signs": ["APTS", "SUBWAY", "GUNS", "GARAGE", "MEDS", "BUDDYS", "CATHODE",
			"CASINO", "PIZZA", "NOODLE", "HUDSONS", "TACO", "PETS", "MOTOWN",
			"LIBRARY", "GAS", "LOFTS", "OFFICE"],
		"sign_colors": [Color(1.8, 0.3, 0.9), Color(0.3, 1.7, 1.8),
			Color(1.8, 1.3, 0.2), Color(0.5, 1.8, 0.6)],
		"lamp": Color(1.5, 1.3, 0.8),
	},
	"warzone": {
		"heights": [4.0, 11.0], "widths": [10.0, 20.0], "gap": [5.0, 14.0],
		"bodies": [Color(0.10, 0.10, 0.10), Color(0.055, 0.055, 0.055),
			Color(0.08, 0.08, 0.08), Color(0.11, 0.10, 0.09)],
		"win_colors": [Color(1.2, 0.35, 0.2), Color(0.9, 0.6, 0.3), Color(0.4, 0.4, 0.5)],
		"lit": 0.10, "win_pitch": Vector2(3.6, 3.0),
		"signs": ["CONDEMNED", "ABANDONED", "FLOPHOUSE", "THE DUMP", "SCRAPYARD",
			"CHOP SHOP", "JUNKYARD", "TATTOO", "PACKARD", "JACKALS", "RUINS"],
		"sign_colors": [Color(1.4, 0.4, 0.2), Color(1.0, 0.9, 0.4)],
		"lamp": Color(1.2, 0.6, 0.3),
	},
}

const BODY_SHADER := "
shader_type spatial;
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}
"

const GLOW_SHADER := "
shader_type spatial;
render_mode unshaded;
void fragment() {
	ALBEDO = COLOR.rgb * 0.2;
	EMISSION = COLOR.rgb;
}
"

static func build(parent: Node3D, rng_seed: int = 0xC177B16) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var body_mat := ShaderMaterial.new()
	var body_sh := Shader.new()
	body_sh.code = BODY_SHADER
	body_mat.shader = body_sh
	var glow_mat := ShaderMaterial.new()
	var glow_sh := Shader.new()
	glow_sh.code = GLOW_SHADER
	glow_mat.shader = glow_sh

	var bodies: Array = []      # {xform: Transform3D, color: Color}
	var windows: Array = []
	var glows: Array = []       # lamps, dashes, barrel fires (emissive quads/boxes)
	var collision_parent := StaticBody3D.new()
	collision_parent.name = "CityGenCollision"
	parent.add_child(collision_parent)

	for band in BANDS:
		var district: Dictionary = DISTRICTS[band.district]
		var z0: float = band.k * BAND_PITCH
		_build_band_ground(parent, band, z0)
		_build_band_buildings(parent, collision_parent, band, district, z0,
			rng, bodies, windows, glows)
	_build_avenues(parent, glows)
	_build_void_fences(collision_parent)

	# Bake the batches — three draw calls for the entire generated city
	_bake_multimesh(parent, bodies, BoxMesh.new(), body_mat, "GenBodies")
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	_bake_multimesh(parent, windows, quad, glow_mat, "GenWindows")
	_bake_multimesh(parent, glows, BoxMesh.new(), glow_mat, "GenGlows")
	return [body_mat, glow_mat]

static func _build_void_fences(col_parent: StaticBody3D) -> void:
	# Seal the dead strips between a band's road and the NEXT band's
	# building backs, so the player can never stand south-adjacent to tall
	# geometry. The walkable network = each band's sidewalk + road, plus
	# the two avenues. Avenue crossings stay open, with side rails along
	# the sealed strips so you can't sidestep into them.
	var ks: Array = [-3, -2, -1, 0, 1, 2, 3]
	for k in ks:
		var z0: float = k * BAND_PITCH
		var road_south: float = z0 + ROAD_W + 1.0        # south edge of this road
		var next_backs: float = z0 + BAND_PITCH - SIDEWALK_W * 2.0 - 0.5 - 14.0
		# Long fences (with avenue gaps) on both sides of the dead strip
		for fence_z in [road_south, next_backs - 1.0]:
			var seg_start: float = -X_EXTENT
			var spans: Array = []
			for ax in AVENUE_XS:
				spans.append([seg_start, ax - AVENUE_W * 0.5])
				seg_start = ax + AVENUE_W * 0.5
			spans.append([seg_start, X_EXTENT])
			for span in spans:
				var length: float = span[1] - span[0]
				if length <= 1.0:
					continue
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(length, 8.0, 1.0)
				cs.shape = box
				cs.position = Vector3((span[0] + span[1]) * 0.5, 4.0, fence_z)
				col_parent.add_child(cs)
		# Avenue side rails across the dead strip
		var strip_len: float = (next_backs - 1.0) - road_south
		if strip_len > 1.0:
			for ax in AVENUE_XS:
				for side in [-1.0, 1.0]:
					var cs2 := CollisionShape3D.new()
					var box2 := BoxShape3D.new()
					box2.size = Vector3(1.0, 8.0, strip_len)
					cs2.shape = box2
					cs2.position = Vector3(ax + side * (AVENUE_W * 0.5),
						4.0, (road_south + next_backs - 1.0) * 0.5)
					col_parent.add_child(cs2)

static func _build_band_ground(parent: Node3D, band: Dictionary, z0: float) -> void:
	# Road + sidewalks for this band (home band already has its own)
	var road := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(X_EXTENT * 2.0, 0.1, ROAD_W)
	road.mesh = rm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.07)
	mat.roughness = 0.85
	road.material_override = mat
	road.position = Vector3(0, -0.02, z0 + ROAD_W * 0.5)
	parent.add_child(road)
	var walk := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(X_EXTENT * 2.0, 0.14, SIDEWALK_W * 2.0)
	walk.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.13, 0.13, 0.15)
	wmat.roughness = 0.9
	walk.material_override = wmat
	walk.position = Vector3(0, -0.01, z0 - SIDEWALK_W)
	parent.add_child(walk)

static func _in_avenue(x: float, half_w: float) -> bool:
	for ax in AVENUE_XS:
		if absf(x - ax) < AVENUE_W * 0.5 + half_w + 1.0:
			return true
	return false

static func _build_band_buildings(parent: Node3D, col_parent: StaticBody3D,
		band: Dictionary, district: Dictionary, z0: float,
		rng: RandomNumberGenerator, bodies: Array, windows: Array,
		glows: Array) -> void:
	var x := -X_EXTENT + 4.0
	var sign_budget := 7
	var face_z: float = z0 - SIDEWALK_W * 2.0 - 0.5   # buildings north of sidewalk
	while x < X_EXTENT - 12.0:
		var w: float = rng.randf_range(district.widths[0], district.widths[1])
		if _in_avenue(x + w * 0.5, w * 0.5):
			x += 6.0
			continue
		var h: float = rng.randf_range(district.heights[0], district.heights[1])
		var near_avenue := false
		for ax in AVENUE_XS:
			if absf((x + w * 0.5) - ax) < 30.0:
				near_avenue = true
				break
		if near_avenue:
			h = minf(h, 5.5)
		var depth := 14.0
		var cx: float = x + w * 0.5
		var body_color: Color = district.bodies[rng.randi() % district.bodies.size()]
		body_color = body_color * rng.randf_range(0.8, 1.15)
		var xf := Transform3D(Basis.from_scale(Vector3(w, h, depth)),
			Vector3(cx, h * 0.5, face_z - depth * 0.5))
		bodies.append({ "xform": xf, "color": body_color })
		# Collision
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w, h, depth)
		cs.shape = box
		cs.position = Vector3(cx, h * 0.5, face_z - depth * 0.5)
		col_parent.add_child(cs)
		# Windows on the street face
		var pitch: Vector2 = district.win_pitch
		var cols: int = maxi(1, int((w - 2.0) / pitch.x))
		var rows: int = maxi(1, int((h - 3.0) / pitch.y))
		var wx0: float = cx - (cols - 1) * pitch.x * 0.5
		for c in cols:
			for r in rows:
				if rng.randf() < district.lit:
					var wc: Color = district.win_colors[rng.randi() % district.win_colors.size()]
					wc = wc * rng.randf_range(0.7, 1.1)
					var wxf := Transform3D(
						Basis.from_scale(Vector3(1.5, 1.9, 1.0)),
						Vector3(wx0 + c * pitch.x, 2.4 + r * pitch.y, face_z + 0.06))
					windows.append({ "xform": wxf, "color": wc })
		# Neon sign on some buildings
		if sign_budget > 0 and rng.randf() < 0.30:
			sign_budget -= 1
			var label := Label3D.new()
			label.text = district.signs[rng.randi() % district.signs.size()]
			label.font_size = 120
			label.pixel_size = 0.012
			var sc: Color = district.sign_colors[rng.randi() % district.sign_colors.size()]
			label.modulate = sc
			label.outline_size = 20
			label.outline_modulate = Color(0, 0, 0)
			label.position = Vector3(cx, minf(h + 1.5, h * 0.8 + 4.0), face_z + 0.3)
			parent.add_child(label)
		# Warzone dressing: barrel fires + rubble
		if band.district == "warzone" and rng.randf() < 0.35:
			var fx: float = cx + rng.randf_range(-w * 0.3, w * 0.3)
			glows.append({ "xform": Transform3D(
				Basis.from_scale(Vector3(0.8, 1.0, 0.8)),
				Vector3(fx, 0.5, z0 - 2.0)),
				"color": Color(1.6, 0.7, 0.15) })
		x += w + rng.randf_range(district.gap[0], district.gap[1])
	# Street lamps — emissive heads only (no dynamic lights out here)
	var lx := -X_EXTENT + 12.0
	while lx < X_EXTENT:
		if not _in_avenue(lx, 1.0):
			glows.append({ "xform": Transform3D(
				Basis.from_scale(Vector3(0.25, 0.25, 0.25)),
				Vector3(lx, 4.6, z0 - 1.2)),
				"color": district.lamp * 1.4 })
			bodies.append({ "xform": Transform3D(
				Basis.from_scale(Vector3(0.12, 4.6, 0.12)),
				Vector3(lx, 2.3, z0 - 1.2)),
				"color": Color(0.10, 0.10, 0.12) })
		lx += 26.0
	# Road center dashes
	var dx := -X_EXTENT
	while dx < X_EXTENT:
		glows.append({ "xform": Transform3D(
			Basis.from_scale(Vector3(3.2, 0.04, 0.4)),
			Vector3(dx, 0.06, z0 + ROAD_W * 0.5)),
			"color": Color(0.9, 0.75, 0.15) })
		dx += 12.0

static func _build_avenues(parent: Node3D, glows: Array) -> void:
	# Vertical cross streets connecting every band
	var z_min: float = (BANDS[0].k as float) * BAND_PITCH - 30.0
	var z_max: float = (BANDS[BANDS.size() - 1].k as float) * BAND_PITCH + 50.0
	for ax in AVENUE_XS:
		var road := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(AVENUE_W, 0.1, z_max - z_min)
		road.mesh = rm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.05, 0.07)
		mat.roughness = 0.85
		road.material_override = mat
		road.position = Vector3(ax, -0.02, (z_min + z_max) * 0.5)
		parent.add_child(road)
		var dz := z_min
		while dz < z_max:
			glows.append({ "xform": Transform3D(
				Basis.from_scale(Vector3(0.4, 0.04, 3.2)),
				Vector3(ax, 0.06, dz)),
				"color": Color(0.9, 0.75, 0.15) })
			dz += 12.0

static func _bake_multimesh(parent: Node3D, items: Array, mesh: Mesh,
		mat: Material, node_name: String) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i].xform)
		mm.set_instance_color(i, items[i].color)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.name = node_name
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
