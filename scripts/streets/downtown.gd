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
	_build_storefronts()
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
		# Neon sign + underline tube
		var label := Label3D.new()
		label.text = st.sign
		label.font_size = 120
		label.pixel_size = 0.012
		label.modulate = col
		label.outline_size = 18
		label.outline_modulate = Color(0, 0, 0)
		label.position = Vector3(cx, h + 1.6, -4.8)
		add_child(label)
		_add_box(Vector3(cx, h + 0.6, -4.85), Vector3(w * 0.7, 0.08, 0.08),
			col * 0.4, 0.0, 0.4, true, col, 2.2)
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
	# Different crowd: suits, cops on patrol, a street musician by the venue
	var crowd := [
		["res://assets/sprites/npc-corpo.png", Vector3(-38.0, 0.9, -2.4), 2],
		["res://assets/sprites/npc-corpo.png", Vector3(12.0, 0.9, -2.6), 1],
		["res://assets/sprites/npc-cop.png", Vector3(-16.0, 0.9, -2.2), 0],
		["res://assets/sprites/npc-cop2.png", Vector3(36.0, 0.9, -2.5), 0],
		["res://assets/sprites/cyberGirl.png", Vector3(-26.0, 0.9, -2.7), 0],
		["res://assets/sprites/npc-cyberpunk.png", Vector3(44.0, 0.9, -2.3), 3],
	]
	for c in crowd:
		add_npc(c[0], c[1], c[2])
