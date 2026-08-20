## DOWNTOWN — Signal Hollow's clean-money strip. Casino, live music,
## sushi, cafe culture, and the public library (which is more than it
## looks). Cops actually patrol here. Stops from the Uber canon.
extends "res://scripts/streets/street_base.gd"

const DoorGlowScript := preload("res://scripts/systems/door_glow.gd")

func _init() -> void:
	street_id = "downtown"
	block_half_w = 60.0

func _ambient_color() -> Color:
	return Color(0.24, 0.26, 0.34)

func _moon_color() -> Color:
	return Color(0.55, 0.62, 0.95)

func _moon_energy() -> float:
	return 0.75

func _lamp_color() -> Color:
	return Color(0.80, 0.95, 1.15)

func _lamp_broken_chance() -> float:
	return 0.05   # downtown pays its power bill

# Anchored storefronts: x center, width, sign, neon color, id
const STORES := [
	{ "id": "casino",  "x": -46.0, "w": 16.0, "sign": "CASINO",     "col": Color(1.6, 1.2, 0.2) },
	{ "id": "cathode", "x": -26.0, "w": 12.0, "sign": "THE CATHODE", "col": Color(1.5, 0.25, 0.9) },
	{ "id": "growlers","x": -10.0, "w": 10.0, "sign": "GROWLER'S",  "col": Color(1.4, 0.8, 0.2) },
	{ "id": "sushi",   "x":  4.0,  "w": 10.0, "sign": "SUSHI",      "col": Color(1.6, 0.3, 0.25) },
	{ "id": "cafe",    "x":  17.0, "w": 9.0,  "sign": "CAFE",       "col": Color(1.2, 0.7, 0.35) },
	{ "id": "tech",    "x":  30.0, "w": 11.0, "sign": "TECH SHOP",  "col": Color(0.25, 1.3, 1.5) },
	{ "id": "library", "x":  47.0, "w": 14.0, "sign": "LIBRARY",    "col": Color(0.75, 0.5, 1.6) },
]

func _build_street() -> void:
	Music.play_category("city")
	build_streetlamps(20.0)
	build_traffic(9)
	_build_storefronts()
	_build_fillers()
	_build_dressing()
	_build_walkers()
	build_ridenet_terminal(Vector3(-2.0, 0, -3.0))
	var m := Node3D.new()
	m.name = "from_ridenet"
	m.position = Vector3(2.0, 0.0, -2.5)
	add_child(m)
	var ml := Node3D.new()
	ml.name = "from_library"
	ml.position = Vector3(47.0, 0.0, -2.2)
	add_child(ml)
	var mc := Node3D.new()
	mc.name = "from_cathode"
	mc.position = Vector3(-26.0, 0.0, -2.2)
	add_child(mc)

func _build_storefronts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xD0DA
	# Anchored stores with big neon; filler towers between them
	for st in STORES:
		var cx: float = st.x
		var w: float = st.w
		var h: float = rng.randf_range(11.0, 17.0)
		var col: Color = st.col
		var body := Color(0.16, 0.17, 0.22) * rng.randf_range(0.9, 1.1)
		_add_box(Vector3(cx, h * 0.5, -9.0), Vector3(w, h, 8.0), body, 0.25, 0.6)
		# Lit window grid — downtown is awake
		var wy := 2.2
		while wy < h - 1.4:
			var wx := cx - w * 0.5 + 1.5
			while wx < cx + w * 0.5 - 1.5:
				if rng.randf() < 0.5:
					var wc: Color = [Color(0.9, 0.95, 1.1), Color(0.4, 0.9, 1.1),
						Color(1.1, 0.7, 0.9)][rng.randi() % 3]
					_add_box(Vector3(wx, wy, -4.90), Vector3(1.0, 1.3, 0.06),
						wc * 0.3, 0.0, 0.4, true, wc, rng.randf_range(0.5, 1.1))
				else:
					_add_box(Vector3(wx, wy, -4.90), Vector3(1.0, 1.3, 0.06),
						Color(0.05, 0.06, 0.09), 0.3, 0.3)
				wx += 2.4
			wy += 2.6
		# Backed neon signboard: dark panel, tube border, glowing text
		var board_w: float = minf(w * 0.92, st.sign.length() * 1.35 + 1.6)
		_add_box(Vector3(cx, h + 1.5, -4.92), Vector3(board_w, 2.4, 0.18),
			Color(0.04, 0.04, 0.06), 0.2, 0.5)
		for edge in [[Vector3(0, 1.2, 0), Vector3(board_w, 0.09, 0.09)],
				[Vector3(0, -1.2, 0), Vector3(board_w, 0.09, 0.09)],
				[Vector3(-board_w * 0.5, 0, 0), Vector3(0.09, 2.4, 0.09)],
				[Vector3(board_w * 0.5, 0, 0), Vector3(0.09, 2.4, 0.09)]]:
			_add_box(Vector3(cx, h + 1.5, -4.80) + edge[0], edge[1],
				col * 0.4, 0.0, 0.4, true, col, 2.4)
		var label := Label3D.new()
		label.text = st.sign
		label.font_size = 110
		label.pixel_size = 0.012
		label.modulate = col * 1.15
		label.outline_size = 14
		label.outline_modulate = Color(0, 0, 0)
		label.position = Vector3(cx, h + 1.5, -4.72)
		add_child(label)
		# The sign actually lights the sidewalk below it
		var sign_light := OmniLight3D.new()
		sign_light.light_color = Color(clampf(col.r, 0, 1), clampf(col.g, 0, 1),
			clampf(col.b, 0, 1))
		sign_light.light_energy = 1.6
		sign_light.omni_range = 11.0
		sign_light.position = Vector3(cx, 4.0, -3.2)
		add_child(sign_light)
		# Doorway + glow
		_add_box(Vector3(cx, 1.5, -4.88), Vector3(2.2, 3.0, 0.1),
			Color(0.05, 0.05, 0.08), 0.4, 0.3)
		var glow := DoorGlowScript.new()
		glow.color = col
		glow.opening = Vector2(2.2, 3.0)
		glow.position = Vector3(cx, 0.0, -4.80)
		add_child(glow)
		glow.set_active(true)
		var sid: String = st.id
		var sname: String = st.sign
		add_interact(Vector3(cx, 1.2, -3.4), Vector3(3.0, 2.4, 2.6),
			sname.to_lower(), func(): _enter_store(sid, sname))

func _enter_store(id: String, sign_name: String) -> void:
	if id == "library":
		SceneTransition.go("library", "from_street")
		return
	if id == "cathode":
		SceneTransition.go("cathode", "from_street")
		return
	_set_status("(" + sign_name + " interior not built yet)")

func _build_walkers() -> void:
	# Downtown crowd actually goes places: suits commuting, cops on beat
	add_walker("res://assets/sprites/npc-corpo.png", -50.0, -10.0, -2.4, 2.4)
	add_walker("res://assets/sprites/npc-corpo.png", -20.0, 30.0, -2.7, 2.1)
	add_walker("res://assets/sprites/npc-cop.png", -30.0, 20.0, -2.2, 1.6)
	add_walker("res://assets/sprites/cyberGirl.png", 0.0, 50.0, -2.5, 2.6)
	add_walker("res://assets/sprites/npc-cyberpunk.png", 10.0, 54.0, -2.3, 2.9)
	add_walker("res://assets/sprites/npc-thug.png", -54.0, -20.0, -2.6, 1.9)
	# And a couple of fixtures: door cop at the casino, dealer by the venue
	add_npc("res://assets/sprites/npc-cop2.png", Vector3(-42.0, 0.9, -3.4), 0)
	add_npc("res://assets/sprites/smoking_drifter.png", Vector3(-23.0, 0.9, -3.4), 0)

# Narrow filler frontages between the anchors — canon signs from the
# Phaser downtown zone list, hung as vertical neon
const FILLERS := [
	{ "x": -35.0, "w": 4.5, "sign": "BAKERS",  "col": Color(1.3, 0.8, 0.3) },
	{ "x": -17.5, "w": 4.0, "sign": "NOODLE",  "col": Color(1.5, 0.4, 0.3) },
	{ "x": -3.0,  "w": 3.4, "sign": "MEDS",    "col": Color(0.3, 1.3, 0.7) },
	{ "x": 10.8,  "w": 3.0, "sign": "BUDDYS",  "col": Color(0.9, 0.5, 1.4) },
	{ "x": 23.0,  "w": 2.6, "sign": "8 MILE",  "col": Color(0.4, 0.9, 1.4) },
	{ "x": 37.8,  "w": 3.8, "sign": "HUDSONS", "col": Color(1.4, 0.9, 0.2) },
]

func _build_fillers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xF177
	for f in FILLERS:
		var cx: float = f.x
		var w: float = f.w
		var h: float = rng.randf_range(7.0, 12.0)
		var col: Color = f.col
		_add_box(Vector3(cx, h * 0.5, -9.0), Vector3(w, h, 8.0),
			Color(0.13, 0.14, 0.18) * rng.randf_range(0.85, 1.1), 0.2, 0.7)
		# Vertical neon: narrow backed board hanging off the frontage
		var txt: String = f.sign
		var board_h: float = txt.length() * 0.72 + 0.8
		var by: float = h - 0.6 - board_h * 0.5
		_add_box(Vector3(cx, by, -4.92), Vector3(1.5, board_h, 0.18),
			Color(0.04, 0.04, 0.06), 0.2, 0.5)
		for edge in [[Vector3(-0.78, 0, 0), Vector3(0.08, board_h, 0.08)],
				[Vector3(0.78, 0, 0), Vector3(0.08, board_h, 0.08)],
				[Vector3(0, board_h * 0.5, 0), Vector3(1.5, 0.08, 0.08)],
				[Vector3(0, -board_h * 0.5, 0), Vector3(1.5, 0.08, 0.08)]]:
			_add_box(Vector3(cx, by, -4.82) + edge[0], edge[1],
				col * 0.4, 0.0, 0.4, true, col, 2.2)
		var vert := ""
		for i in txt.length():
			vert += txt[i] + ("
" if i < txt.length() - 1 else "")
		var label := Label3D.new()
		label.text = vert
		label.font_size = 52
		label.pixel_size = 0.011
		label.modulate = col * 1.15
		label.outline_size = 10
		label.outline_modulate = Color(0, 0, 0)
		label.position = Vector3(cx, by, -4.72)
		add_child(label)
		# Small colored spill on the sidewalk
		var fl := OmniLight3D.new()
		fl.light_color = Color(clampf(col.r, 0, 1), clampf(col.g, 0, 1),
			clampf(col.b, 0, 1))
		fl.light_energy = 0.9
		fl.omni_range = 7.0
		fl.position = Vector3(cx, 3.0, -3.4)
		add_child(fl)
		# A lit doorway so it reads inhabited
		_add_box(Vector3(cx, 1.4, -4.9), Vector3(1.6, 2.8, 0.08),
			col * 0.25, 0.0, 0.5, true, col * 0.7, 0.5)

func _build_dressing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xD0D2
	# Benches + glowing planters along the sidewalk
	for bx in [-44.0, -12.0, 8.0, 33.0, 51.0]:
		_add_box(Vector3(bx, 0.35, -4.3), Vector3(2.4, 0.12, 0.6),
			Color(0.2, 0.16, 0.12), 0.1, 0.7)
		_add_box(Vector3(bx, 0.18, -4.3), Vector3(2.0, 0.24, 0.4),
			Color(0.12, 0.12, 0.14), 0.5, 0.5)
	for px in [-30.0, -1.0, 26.0, 43.0]:
		_add_box(Vector3(px, 0.3, -4.4), Vector3(1.2, 0.6, 1.2),
			Color(0.14, 0.15, 0.18), 0.3, 0.6)
		_add_box(Vector3(px, 0.63, -4.4), Vector3(1.26, 0.05, 1.26),
			Color(0.2, 1.0, 1.2) * 0.4, 0.0, 0.5, true, Color(0.25, 1.1, 1.3), 1.2)
		_add_box(Vector3(px, 0.85, -4.4), Vector3(0.8, 0.5, 0.8),
			Color(0.10, 0.30, 0.14), 0.0, 0.9)
	# Rooftop holo billboard over the casino — slow color pulse
	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(10.0, 4.5, 0.2)
	panel.mesh = bm
	panel.position = Vector3(-46.0, 19.5, -8.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.05, 0.15)
	mat.emission_enabled = true
	mat.emission = Color(1.2, 0.3, 1.0)
	mat.emission_energy_multiplier = 1.2
	panel.material_override = mat
	add_child(panel)
	var tw := create_tween().set_loops()
	tw.tween_property(mat, "emission", Color(0.2, 0.9, 1.4), 2.4)
	tw.tween_property(mat, "emission", Color(1.2, 0.3, 1.0), 2.4)
	var bl := Label3D.new()
	bl.text = "LUCKY CHROME CASINO"
	bl.font_size = 72
	bl.pixel_size = 0.012
	bl.modulate = Color(1.5, 1.3, 0.4)
	bl.outline_size = 12
	bl.outline_modulate = Color(0, 0, 0)
	bl.position = Vector3(-46.0, 19.5, -7.85)
	add_child(bl)
