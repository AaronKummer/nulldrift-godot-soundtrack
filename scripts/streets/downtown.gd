## DOWNTOWN — Signal Hollow's clean-money strip. Casino, live music,
## sushi, cafe culture, and the public library (which is more than it
## looks). Cops actually patrol here. Stops from the Uber canon.
## Storefronts use the shared home-street recipe (StreetBase.build_storefront).
extends "res://scripts/streets/street_base.gd"

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

# Anchored storefronts — same def shape the home street uses, plus the
# scene each door leads to. Textured neon signs generated to match.
const STORES := [
	{ "id": "casino",   "x": -48.0, "label": "LUCKY CHROME", "scene": "casino",
	  "tex": "res://assets/world/signs/casino.png",
	  "sign": Color(1.0, 0.78, 0.15), "awning": Color(0.40, 0.12, 0.10),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "cathode",  "x": -34.0, "label": "THE CATHODE", "scene": "cathode",
	  "tex": "res://assets/world/signs/cathode.png",
	  "sign": Color(1.0, 0.25, 0.85), "awning": Color(0.28, 0.08, 0.30),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "growlers", "x": -20.0, "label": "GROWLER'S",
	  "tex": "res://assets/world/signs/growlers.png",
	  "sign": Color(1.0, 0.65, 0.20), "awning": Color(0.35, 0.20, 0.08),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "noodle",   "x": -6.0, "label": "NOODLE", "scene": "noodle",
	  "tex": "res://assets/world/signs/noodle.png",
	  "sign": Color(1.0, 0.45, 0.12), "awning": Color(0.40, 0.10, 0.08),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "sushi",    "x": 8.0, "label": "SUSHI", "scene": "sushi",
	  "tex": "res://assets/world/signs/sushi.png",
	  "sign": Color(1.0, 0.25, 0.20), "awning": Color(0.35, 0.08, 0.08),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "cafe",     "x": 22.0, "label": "CAFE", "scene": "cafe",
	  "tex": "res://assets/world/signs/cafe.png",
	  "sign": Color(1.0, 0.55, 0.20), "awning": Color(0.30, 0.18, 0.10),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "tech",     "x": 36.0, "label": "TECH SHOP",
	  "tex": "res://assets/world/signs/tech.png",
	  "sign": Color(0.25, 0.85, 1.0), "awning": Color(0.08, 0.25, 0.30),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "library",  "x": 50.0, "label": "LIBRARY", "scene": "library",
	  "tex": "res://assets/world/signs/library.png",
	  "sign": Color(0.70, 0.45, 1.0), "awning": Color(0.20, 0.10, 0.38),
	  "sign_w": 6.6, "sign_h": 4.4 },
]

# Narrow filler frontages between the anchors — canon signs from the
# Phaser downtown zone list, hung as vertical neon boards
const FILLERS := [
	{ "x": -41.0, "w": 4.0, "sign": "BAKERS",  "col": Color(1.3, 0.8, 0.3) },
	{ "x": -27.0, "w": 3.6, "sign": "MEDS",    "col": Color(0.3, 1.3, 0.7) },
	{ "x": -13.0, "w": 3.6, "sign": "BUDDYS",  "col": Color(0.9, 0.5, 1.4) },
	{ "x": 1.0,   "w": 3.2, "sign": "PAWN",    "col": Color(1.4, 0.9, 0.2) },
	{ "x": 15.0,  "w": 3.6, "sign": "HUDSONS", "col": Color(0.4, 0.9, 1.4) },
	{ "x": 29.0,  "w": 3.0, "sign": "8 MILE",  "col": Color(1.2, 0.4, 0.4) },
	{ "x": 43.0,  "w": 3.6, "sign": "VACANT",  "col": Color(0.5, 0.55, 0.65) },
]

func _build_street() -> void:
	Music.play_category("city")
	build_streetlamps(20.0)
	build_traffic(9)
	for st in STORES:
		build_storefront(st)
	_build_fillers()
	_build_dressing()
	_build_crowd()
	build_ridenet_terminal(Vector3(-2.0, 0, -3.0))
	var m := Node3D.new()
	m.name = "from_ridenet"
	m.position = Vector3(2.0, 0.0, -2.5)
	add_child(m)
	for mk in [["from_casino", -48.0], ["from_cathode", -34.0],
			["from_noodle", -6.0], ["from_sushi", 8.0],
			["from_cafe", 22.0], ["from_library", 50.0]]:
		var mm := Node3D.new()
		mm.name = mk[0]
		mm.position = Vector3(mk[1] + 2.4, 0.0, -2.2)   # in front of each door
		add_child(mm)

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
			vert += txt[i] + ("\n" if i < txt.length() - 1 else "")
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

func _build_dressing() -> void:
	# Benches + glowing planters along the sidewalk
	for bx in [-44.0, -16.0, 12.0, 32.0, 46.0]:
		_add_box(Vector3(bx, 0.35, -4.3), Vector3(2.4, 0.12, 0.6),
			Color(0.2, 0.16, 0.12), 0.1, 0.7)
		_add_box(Vector3(bx, 0.18, -4.3), Vector3(2.0, 0.24, 0.4),
			Color(0.12, 0.12, 0.14), 0.5, 0.5)
	for px in [-30.0, -2.5, 26.0, 40.0]:
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
	panel.position = Vector3(-48.0, 15.5, -8.0)
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
	bl.position = Vector3(-48.0, 15.5, -7.85)
	add_child(bl)

func _build_crowd() -> void:
	# Downtown crowd actually goes places: suits commuting, cops on beat
	add_walker("res://assets/sprites/npc-corpo.png", -50.0, -10.0, -2.4, 2.4)
	add_walker("res://assets/sprites/lady.png", -20.0, 30.0, -2.7, 2.1)
	add_walker("res://assets/sprites/npc-cop.png", -30.0, 20.0, -2.2, 1.6)
	add_walker("res://assets/sprites/Yakuza2.png", 0.0, 50.0, -2.5, 2.6)
	add_walker("res://assets/sprites/npc-cyberpunk.png", 10.0, 54.0, -2.3, 2.9)
	add_walker("res://assets/sprites/npc-cop2.png", -54.0, -20.0, -2.6, 1.9)
	# Standing figures (converted sheets have no real walk cycle — they
	# pose, they don't commute): suit loitering under the neon, window shopper
	add_npc("res://assets/sprites/civ/civ-a08.png", Vector3(-22.5, 0.9, -3.2), 0)
	add_npc("res://assets/sprites/civ/civ-b11.png", Vector3(16.2, 0.9, -3.8), 3)
	# And a couple of fixtures: door cop at the casino, dealer by the venue
	add_npc("res://assets/sprites/npc-cop2.png", Vector3(-44.0, 0.9, -3.6), 0)
	add_npc("res://assets/sprites/npc-cyberpunk.png", Vector3(-31.0, 0.9, -3.6), 0)
