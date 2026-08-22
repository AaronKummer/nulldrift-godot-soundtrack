## PACKARD ROWS — a condemned district, Chrome Jackals turf. (Internal id stays "warzone".)
##
## Burnt-out lots, barrel fires, dead neon, wrecked cars. Stops from the
## Uber canon: THE DUMP (a dungeon), the CHOP SHOP (buy grenades/stims
## cheap, no questions), and Jackals loitering who talk if you dare.
extends "res://scripts/streets/street_base.gd"

const DungeonEntranceColor := Color(1.2, 0.5, 0.15)

var _chop_menu

func _init() -> void:
	street_id = "warzone"
	block_half_w = 60.0

func _ambient_color() -> Color:
	return Color(0.30, 0.24, 0.19)

func _fog_color() -> Color:
	return Color(0.20, 0.10, 0.05)

func _moon_color() -> Color:
	return Color(0.72, 0.58, 0.42)

func _moon_energy() -> float:
	return 0.9

func _lamp_color() -> Color:
	return Color(1.0, 0.65, 0.3)

func _lamp_broken_chance() -> float:
	return 0.45

func _build_street() -> void:
	Music.play_category("city")
	build_streetlamps(26.0)
	build_traffic(3, [Color(0.35, 0.3, 0.25), Color(0.3, 0.25, 0.2),
		Color(0.4, 0.35, 0.28)], ["sedan", "pickup"])
	_build_ruins()
	_build_chop_shop()
	# (THE DUMP / Nexus Tower moved to the Financial District)
	_build_garage_entrance()
	_build_scrapyard_entrance()
	_build_jackals()
	_build_barrel_fires()
	_build_wrecks()
	build_ridenet_terminal(Vector3(-8.0, 0, -3.0))
	# Arrival marker
	var m := Node3D.new()
	m.name = "from_ridenet"
	m.position = Vector3(-4.0, 0.0, -2.5)
	add_child(m)

const RESERVED_LOTS := [[-45.0, -22.0], [14.0, 30.0], [36.0, 54.0]]   # dump, chop shop, garage

func _lot_reserved(x0: float, x1: float) -> bool:
	for lot in RESERVED_LOTS:
		if x1 > lot[0] and x0 < lot[1]:
			return true
	return false

func _build_ruins() -> void:
	# North side: burnt husks — varied heights, broken rooflines, boarded
	# windows, one collapsed lot with rubble. Skips the reserved lots so
	# nothing generates on top of the chop shop or the dump.
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xDEAD1
	var x := -block_half_w + 2.0
	while x < block_half_w - 10.0:
		var w: float = rng.randf_range(9.0, 16.0)
		if _lot_reserved(x, x + w):
			x += 3.0
			continue
		var h: float = rng.randf_range(6.0, 13.0)
		var cx := x + w * 0.5
		if rng.randf() < 0.18:
			# Collapsed lot: rubble mounds instead of a building
			for i in 5:
				var rx := cx + rng.randf_range(-w * 0.4, w * 0.4)
				_add_box(Vector3(rx, rng.randf_range(0.3, 0.9), -9.0 + rng.randf_range(-2, 2)),
					Vector3(rng.randf_range(1.0, 2.6), rng.randf_range(0.6, 1.8),
						rng.randf_range(1.0, 2.4)),
					Color(0.16, 0.15, 0.13) * rng.randf_range(0.7, 1.2), 0.1, 0.9)
			x += w + rng.randf_range(1.0, 3.0)
			continue
		var body := Color(0.19, 0.17, 0.15) * rng.randf_range(0.7, 1.15)
		_add_box(Vector3(cx, h * 0.5, -9.0), Vector3(w, h, 8.0), body, 0.1, 0.9)
		# Broken roofline: a few jagged top chunks
		for i in 3:
			var jx := cx + rng.randf_range(-w * 0.35, w * 0.35)
			_add_box(Vector3(jx, h + rng.randf_range(0.2, 0.9), -9.0),
				Vector3(rng.randf_range(0.8, 2.0), rng.randf_range(0.5, 1.6), 7.6),
				body * 0.85, 0.1, 0.9)
		# Windows: mostly boarded (dark planks), a few lit sickly orange
		var wy := 2.0
		while wy < h - 1.2:
			var wx := cx - w * 0.5 + 1.4
			while wx < cx + w * 0.5 - 1.4:
				if rng.randf() < 0.75:
					_add_box(Vector3(wx, wy, -4.92), Vector3(1.1, 1.5, 0.06),
						Color(0.07, 0.055, 0.04), 0.0, 0.9)
				else:
					_add_box(Vector3(wx, wy, -4.92), Vector3(1.1, 1.5, 0.06),
						Color(0.25, 0.10, 0.03), 0.0, 0.4,
						true, Color(1.2, 0.45, 0.15), rng.randf_range(0.6, 1.4))
				wx += 2.6
			wy += 2.8
		# Dead sign: unlit letters, one flickering handled as dim emissive
		if rng.randf() < 0.4:
			var label := Label3D.new()
			label.text = ["CONDEMNED", "FLOPHOUSE", "PACKARD", "SCRAPYARD",
				"TATTOO", "RUINS", "VACANT"][rng.randi() % 7]
			label.font_size = 84
			label.pixel_size = 0.01
			label.modulate = Color(0.45, 0.25, 0.15) if rng.randf() < 0.6 \
				else Color(1.2, 0.5, 0.2)
			label.outline_size = 16
			label.outline_modulate = Color(0, 0, 0)
			label.position = Vector3(cx, h + 1.4, -4.8)
			add_child(label)
		x += w + rng.randf_range(1.0, 3.0)

func _build_chop_shop() -> void:
	# CHOP SHOP — rolling steel door, tools, cheap consumables
	var cx := 22.0
	_add_box(Vector3(cx, 2.4, -5.4), Vector3(12.0, 4.8, 1.2),
		Color(0.12, 0.10, 0.09), 0.3, 0.7)
	# Rolling door: ribbed metal
	for i in 6:
		_add_box(Vector3(cx, 0.5 + i * 0.62, -4.7), Vector3(6.0, 0.5, 0.08),
			Color(0.16, 0.15, 0.14) * (1.0 - float(i) * 0.05), 0.7, 0.4)
	var label := Label3D.new()
	label.text = "CHOP SHOP"
	label.font_size = 110
	label.pixel_size = 0.01
	label.modulate = Color(1.4, 0.7, 0.1)
	label.outline_size = 20
	label.outline_modulate = Color(0.15, 0.06, 0.0)
	label.position = Vector3(cx, 5.6, -4.6)
	add_child(label)
	var glow := OmniLight3D.new()
	glow.position = Vector3(cx, 2.5, -2.5)
	glow.light_color = Color(1.2, 0.6, 0.15)
	glow.light_energy = 1.8
	glow.omni_range = 5.0
	add_child(glow)
	add_interact(Vector3(cx, 1.2, -3.2), Vector3(7.0, 2.4, 2.6),
		"CHOP SHOP — cheap gear, no questions", _open_chop_shop)

func _build_dump_entrance() -> void:
	# THE DUMP — dungeon gate: torn fence, trash mountain silhouette,
	# a gap you squeeze through
	var cx := -34.0
	for fx in [-8.0, -5.0, 5.0, 8.0]:
		_add_box(Vector3(cx + fx, 1.5, -5.0), Vector3(0.15, 3.0, 0.15),
			Color(0.2, 0.18, 0.16), 0.7, 0.4)
	_add_box(Vector3(cx - 6.5, 1.6, -5.0), Vector3(3.2, 2.4, 0.06),
		Color(0.13, 0.12, 0.11), 0.5, 0.6)
	_add_box(Vector3(cx + 6.5, 1.6, -5.0), Vector3(3.2, 2.4, 0.06),
		Color(0.13, 0.12, 0.11), 0.5, 0.6)
	# Trash mountain behind the fence
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xDEAD2
	for i in 14:
		_add_box(Vector3(cx + rng.randf_range(-9.0, 9.0),
			rng.randf_range(0.5, 3.4), -9.5 + rng.randf_range(-2.0, 2.0)),
			Vector3(rng.randf_range(1.2, 3.2), rng.randf_range(0.8, 2.4),
				rng.randf_range(1.2, 3.0)),
			Color(0.17, 0.16, 0.14) * rng.randf_range(0.6, 1.3), 0.3, 0.85)
	var label := Label3D.new()
	label.text = "THE DUMP"
	label.font_size = 96
	label.pixel_size = 0.01
	label.modulate = Color(0.9, 0.8, 0.3)
	label.outline_size = 18
	label.outline_modulate = Color(0, 0, 0)
	label.position = Vector3(cx, 4.6, -4.6)
	add_child(label)
	var glow := OmniLight3D.new()
	glow.position = Vector3(cx, 1.6, -3.0)
	glow.light_color = DungeonEntranceColor
	glow.light_energy = 1.4
	glow.omni_range = 4.5
	add_child(glow)
	add_interact(Vector3(cx, 1.2, -3.4), Vector3(4.0, 2.4, 2.4),
		"squeeze through the fence — THE DUMP", func():
			GameState.pending_dungeon = "office"
			SceneTransition.go("dungeon", "from_city"))

# A gap in the chain-link into THE SCRAPYARD (grind dungeon) — jackal
# chop-shop overflow, dogs, a safe to crack.
func _build_scrapyard_entrance() -> void:
	var sx := 8.0
	# Chain-link fence panels with a peeled-back gap
	for fx in [sx - 3.0, sx + 3.0]:
		_add_box(Vector3(fx, 2.0, -5.4), Vector3(2.2, 4.0, 0.12),
			Color(0.18, 0.18, 0.20), 0.6, 0.5, true, Color(0.35, 0.35, 0.4), 0.15)
	# Crushed-car stack behind the fence
	for i in 3:
		_add_box(Vector3(sx, 0.8 + i * 1.0, -7.5), Vector3(3.4, 0.9, 2.0),
			Color(0.22, 0.16, 0.12) * (1.0 - i * 0.12), 0.5, 0.6)
	var label := Label3D.new()
	label.text = "SCRAPYARD"
	label.font_size = 80
	label.pixel_size = 0.011
	label.modulate = Color(1.4, 0.7, 0.25)
	label.outline_size = 14
	label.outline_modulate = Color(0, 0, 0)
	label.position = Vector3(sx, 5.0, -5.2)
	add_child(label)
	var gl := OmniLight3D.new()
	gl.position = Vector3(sx, 1.6, -3.2)
	gl.light_color = Color(1.3, 0.7, 0.3)
	gl.light_energy = 1.3
	gl.omni_range = 4.5
	add_child(gl)
	add_interact(Vector3(sx, 1.2, -3.6), Vector3(3.6, 2.4, 2.6),
		"through the fence — THE SCRAPYARD", func():
			GameState.pending_dungeon = "scrapyard"
			SceneTransition.go("dungeon", "from_city"))
	var mm := Node3D.new()
	mm.name = "from_scrapyard"
	mm.position = Vector3(sx, 0.0, -2.4)
	add_child(mm)

func _build_garage_entrance() -> void:
	# THE GARAGE — Chrome Jackals' clubhouse. They took the chop shop
	# mechanic's apprentice. Kick the door in.
	var gx := 45.0
	_add_box(Vector3(gx, 3.0, -5.6), Vector3(16.0, 6.0, 1.4),
		Color(0.13, 0.11, 0.10), 0.2, 0.7)
	for i in 7:
		_add_box(Vector3(gx, 0.5 + i * 0.66, -4.85), Vector3(8.0, 0.55, 0.08),
			Color(0.15, 0.14, 0.13) * (1.0 - float(i) * 0.04), 0.7, 0.4)
	# Jackals tag over the door
	var label := Label3D.new()
	label.text = "GARAGE"
	label.font_size = 110
	label.pixel_size = 0.011
	label.modulate = Color(1.4, 0.6, 0.2)
	label.outline_size = 16
	label.outline_modulate = Color(0, 0, 0)
	label.position = Vector3(gx, 6.9, -4.8)
	add_child(label)
	var tag := Label3D.new()
	tag.text = "JACKALS ONLY"
	tag.font_size = 54
	tag.pixel_size = 0.01
	tag.modulate = Color(1.2, 0.35, 0.15)
	tag.position = Vector3(gx, 5.6, -4.8)
	tag.rotation.z = 0.06
	add_child(tag)
	# Bikes out front
	for bx in [gx - 5.0, gx - 3.2, gx + 4.0]:
		_add_box(Vector3(bx, 0.5, -3.2), Vector3(1.8, 0.7, 0.5),
			Color(0.12, 0.10, 0.10), 0.5, 0.5)
		_add_box(Vector3(bx, 0.35, -3.2), Vector3(0.5, 0.5, 0.15),
			Color(1.2, 0.5, 0.2) * 0.4, 0.0, 0.5, true, Color(1.3, 0.55, 0.2), 0.8)
	add_interact(Vector3(gx, 1.2, -3.6), Vector3(6.0, 2.4, 2.6),
		"the garage — jackals only", func():
			GameState.pending_dungeon = "garage"
			SceneTransition.go("dungeon", "from_city"))
	# Return markers for the garage and the dump
	var mg := Node3D.new()
	mg.name = "from_garage"
	mg.position = Vector3(gx, 0.0, -2.4)
	add_child(mg)
	var md := Node3D.new()
	md.name = "from_dump"
	md.position = Vector3(-34.0, 0.0, -2.4)
	add_child(md)

func _build_jackals() -> void:
	# Chrome Jackals loitering — thug sprites with red accents
	add_npc("res://assets/sprites/Yakuza1.png", Vector3(8.0, 0, -2.0), 0)
	add_npc("res://assets/sprites/Yakuza2.png", Vector3(11.0, 0, -3.2), 1)
	add_npc("res://assets/sprites/civ/civ-b02.png", Vector3(-18.0, 0, -2.6), 0)
	for jpos in [Vector3(9.5, 0, -2.6), Vector3(-18.0, 0, -2.6)]:
		var light := OmniLight3D.new()
		light.position = jpos + Vector3(0, 1.0, 0.6)
		light.light_color = Color(1.0, 0.3, 0.2)
		light.light_energy = 0.7
		light.omni_range = 2.4
		add_child(light)
	add_interact(Vector3(9.5, 1.2, -2.4), Vector3(4.5, 2.4, 2.6),
		"JACKALS — talk (carefully)", func():
			_set_status("jackal: 'wrong street, pizza boy. the garage settles debts... soon.'"))
	add_interact(Vector3(-18.0, 1.2, -2.2), Vector3(2.4, 2.4, 2.6),
		"stranger by the fire", func():
			_set_status("stranger: 'the dump eats people. it also pays. your call.'"))

func _build_barrel_fires() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xF17E
	for bx in [-46.0, -18.5, 9.0, 40.0]:
		_add_box(Vector3(bx, 0.5, -1.8), Vector3(0.8, 1.0, 0.8),
			Color(0.12, 0.10, 0.09), 0.6, 0.5)
		_add_box(Vector3(bx, 1.05, -1.8), Vector3(0.5, 0.3, 0.5),
			Color(0.5, 0.22, 0.05), 0.0, 0.4, true, Color(1.6, 0.7, 0.15), 2.2)
		var fire := OmniLight3D.new()
		fire.position = Vector3(bx, 1.4, -1.8)
		fire.light_color = Color(1.0, 0.55, 0.15)
		fire.light_energy = 1.6
		fire.omni_range = 5.0
		fire.omni_attenuation = 1.6
		add_child(fire)

func _build_wrecks() -> void:
	# Burnt car husks on the road — dark shells, no lights, no wheels
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x312EC
	var lane_picks := [0.3, 0.62, 0.42, 0.68]
	var widx := 0
	for wx in [-54.0, -6.0, 35.0, 52.0]:
		var wreck := Node3D.new()
		wreck.position = Vector3(wx, 0, ROAD_WIDTH * lane_picks[widx])
		widx += 1
		wreck.rotation.y = rng.randf_range(-0.4, 0.4)
		add_child(wreck)
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(5.6, 1.5, 3.0)
		body.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.07, 0.065, 0.06)
		mat.roughness = 0.95
		body.material_override = mat
		body.position = Vector3(0, 0.75, 0)
		wreck.add_child(body)
		var cabin := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(3.0, 0.9, 2.6)
		cabin.mesh = cm
		cabin.material_override = mat
		cabin.position = Vector3(-0.3, 1.8, 0)
		wreck.add_child(cabin)
		var col := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.6, 2.4, 3.0)
		cs.shape = shape
		cs.position = Vector3(0, 1.2, 0)
		col.add_child(cs)
		wreck.add_child(col)


# ── Chop shop menu (cheap consumables) ──

const CHOP_ITEMS := [
	{ "id": "medkit", "label": "MEDKIT (dented)", "price": 25 },
	{ "id": "grenade", "label": "GRENADE (scratch-built)", "price": 40 },
	{ "id": "stim", "label": "STIM (unlabeled)", "price": 30 },
]

func _open_chop_shop() -> void:
	_ride_open = true   # base menu flag: freezes movement + base interacts
	_chop_menu = ListMenuScript.new()
	add_child(_chop_menu)
	_chop_menu.picked.connect(_chop_buy)
	_chop_menu.closed.connect(func():
		_ride_open = false
		_chop_menu = null)
	var entries: Array = []
	for item in CHOP_ITEMS:
		entries.append({ "label": "%s · %d cr" % [item.label, item.price] })
	_chop_menu.open("CHOP SHOP · no receipts", entries,
		Color(1.0, 0.65, 0.2), "credits: $%d" % GameState.credits)

func _chop_buy(idx: int) -> void:
	var item: Dictionary = CHOP_ITEMS[idx]
	if GameState.credits < item.price:
		_chop_menu.set_footer("mechanic: 'credits first.'")
		return
	GameState.add_credits(-item.price)
	GameState.add_item(item.id)
	_chop_menu.set_footer("credits: $%d · %s acquired"
		% [GameState.credits, String(item.label).to_lower()])
