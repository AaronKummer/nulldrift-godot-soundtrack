## THE STACK — Signal Hollow's corpo spine. Three megacorp towers over a
## boulevard of cold light: OMNICORP (locked lobby, security drones),
## NEXUS TOWER (abandoned — the front is chained; squatters get in through
## the dump), and CORTEX HQ (front door of the corpo dungeon). Stops from
## the Uber canon. Filler signs from the Phaser corpo zone pool.
extends "res://scripts/streets/street_base.gd"

func _init() -> void:
	street_id = "stack"
	block_half_w = 60.0

func _ambient_color() -> Color:
	return Color(0.18, 0.22, 0.32)

func _fog_color() -> Color:
	return Color(0.10, 0.16, 0.32)

func _moon_color() -> Color:
	return Color(0.60, 0.70, 1.05)

func _moon_energy() -> float:
	return 0.85

func _lamp_color() -> Color:
	return Color(0.85, 0.95, 1.25)

func _lamp_broken_chance() -> float:
	return 0.0   # corpo never lets a light die

# Anchored storefronts — the shared recipe; each anchor gets a tower mass
# rising behind it (_build_towers)
const STORES := [
	{ "id": "omnicorp", "x": -40.0, "label": "OMNICORP",
	  "tex": "res://assets/world/signs/omnicorp.png",
	  "sign": Color(0.35, 0.75, 1.0), "awning": Color(0.08, 0.18, 0.32),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "nexus",    "x": 0.0, "label": "NEXUS TOWER",
	  "tex": "res://assets/world/signs/nexus.png",
	  "sign": Color(0.55, 0.52, 0.72), "awning": Color(0.14, 0.13, 0.20),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "cortex",   "x": 40.0, "label": "CORTEX HQ",
	  "tex": "res://assets/world/signs/cortex.png",
	  "sign": Color(1.0, 0.25, 0.80), "awning": Color(0.30, 0.06, 0.24),
	  "sign_w": 6.6, "sign_h": 4.4 },
]

# Narrow filler frontages — canon signs from the Phaser corpo zone pool,
# hung as vertical neon boards (the downtown pattern, colder colors)
const FILLERS := [
	{ "x": -54.0, "w": 3.6, "sign": "SYNAPSE",  "col": Color(0.4, 0.9, 1.4) },
	{ "x": -30.0, "w": 3.6, "sign": "QUANTIX",  "col": Color(0.9, 0.5, 1.4) },
	{ "x": -18.0, "w": 4.0, "sign": "DATAFLOW", "col": Color(0.3, 1.2, 0.9) },
	{ "x": -10.0, "w": 3.2, "sign": "KURONEX",  "col": Color(1.2, 0.4, 0.5) },
	{ "x": 10.0,  "w": 3.6, "sign": "DEEPMIND", "col": Color(0.5, 0.6, 1.4) },
	{ "x": 18.0,  "w": 3.2, "sign": "ALGO",     "col": Color(0.3, 1.3, 0.7) },
	{ "x": 28.0,  "w": 3.6, "sign": "NEURAL",   "col": Color(1.4, 0.5, 1.0) },
	{ "x": 54.0,  "w": 3.6, "sign": "ITERION",  "col": Color(1.3, 0.9, 0.3) },
]

var _omni_bark := 0

func _build_street() -> void:
	Music.play_category("city")
	build_streetlamps(20.0)
	build_traffic(10, [Color(0.12, 0.12, 0.16), Color(0.85, 0.85, 0.9),
		Color(0.55, 0.6, 0.7), Color(0.2, 0.25, 0.4), Color(0.1, 0.1, 0.12)],
		["sedan", "sedan", "sedan", "sedan", "boxtruck"])
	for st in STORES:
		build_storefront(st)
	_build_towers()
	_build_fillers()
	_build_dressing()
	_build_crowd()
	build_ridenet_terminal(Vector3(-2.0, 0, -3.0))
	var m := Node3D.new()
	m.name = "from_ridenet"
	m.position = Vector3(2.0, 0.0, -2.5)
	add_child(m)
	# Loading-dock extraction from the CORTEX HQ dungeon
	var mc := Node3D.new()
	mc.name = "from_corpo"
	mc.position = Vector3(46.0, 0.0, -2.2)
	add_child(mc)

## Anchor doors: CORTEX HQ is the corpo dungeon's front door; OMNICORP and
## NEXUS TOWER are flavor-locked (nexus points at the dump way in).
func _on_storefront_interact(def: Dictionary) -> void:
	match def.get("id", ""):
		"cortex":
			GameState.pending_dungeon = "corpo"
			SceneTransition.go("dungeon", "from_city")
		"omnicorp":
			var barks := [
				"'no appointment on file. move along, citizen.'",
				"'this lobby is for OMNICORP personnel and their betters.'",
				"'your credit rating has been noted. move along.'",
			]
			DialogueOverlay.play_lines([
				{ "speaker": "SECURITY DRONE", "text": barks[_omni_bark % barks.size()],
				  "color": Color(0.4, 0.8, 1.0) },
			], "omni_security")
			_omni_bark += 1
		"nexus":
			DialogueOverlay.play_lines([
				{ "speaker": "", "text": "chained shut. dust on the glass, dead " +
				  "terminals inside. someone's scratched into the door: " +
				  "'squatters use the dump.'", "color": Color(0.7, 0.68, 0.85) },
			], "nexus_front")
		_:
			super._on_storefront_interact(def)

## Tower masses rising behind the three anchors — visual weight only, well
## above the walkable frontage. Lit window strips for the living corps, a
## dead dark shaft for Nexus.
func _build_towers() -> void:
	_build_tower(-40.0, 34.0, Color(0.35, 0.75, 1.0), true)
	_build_tower(0.0, 30.0, Color(0.30, 0.28, 0.40), false)   # abandoned
	_build_tower(40.0, 38.0, Color(1.0, 0.25, 0.80), true)

func _build_tower(x: float, h: float, accent: Color, alive: bool) -> void:
	var base_y := 9.0   # storefront facade height; the shaft starts above it
	var face_z := -SIDEWALK_W - 0.5
	# Set back from the facade line so the shaft never occludes the neon sign
	var tz := face_z - 5.2
	_add_box(Vector3(x, base_y + h * 0.5, tz), Vector3(10.0, h, 8.0),
		Color(0.10, 0.11, 0.15) * (1.0 if alive else 0.7), 0.3, 0.6)
	if alive:
		# Vertical lit strips up the face
		for sx in [-3.2, 0.0, 3.2]:
			_add_box(Vector3(x + sx, base_y + h * 0.5, tz + 4.05),
				Vector3(0.5, h - 4.0, 0.05),
				accent * Color(0.25, 0.25, 0.25, 1.0), 0.0, 0.4, true,
				accent * 0.8, 1.1)
		# Aircraft beacon, slow red pulse
		var beacon := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.5, 0.5)
		beacon.mesh = bm
		beacon.position = Vector3(x, base_y + h + 0.5, tz)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.05, 0.05)
		mat.emission_enabled = true
		mat.emission = Color(1.5, 0.15, 0.1)
		mat.emission_energy_multiplier = 2.0
		beacon.material_override = mat
		add_child(beacon)
		var tw := create_tween().set_loops()
		tw.tween_property(mat, "emission_energy_multiplier", 0.2, 1.1)
		tw.tween_property(mat, "emission_energy_multiplier", 2.0, 1.1)
	else:
		# One dying floor of light and a dead antenna
		_add_box(Vector3(x, base_y + h - 4.0, tz + 4.05),
			Vector3(6.0, 0.6, 0.05),
			Color(0.10, 0.10, 0.08), 0.0, 0.5, true, Color(0.5, 0.5, 0.35), 0.35)
		_add_box(Vector3(x, base_y + h + 1.2, tz),
			Vector3(0.15, 2.4, 0.15), Color(0.08, 0.08, 0.09), 0.6, 0.5)

func _build_fillers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x57AC
	for f in FILLERS:
		var cx: float = f.x
		var w: float = f.w
		var h: float = rng.randf_range(8.0, 13.0)
		var col: Color = f.col
		_add_box(Vector3(cx, h * 0.5, -9.0), Vector3(w, h, 8.0),
			Color(0.11, 0.12, 0.17) * rng.randf_range(0.85, 1.1), 0.3, 0.6)
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
		var fl := OmniLight3D.new()
		fl.light_color = Color(clampf(col.r, 0, 1), clampf(col.g, 0, 1),
			clampf(col.b, 0, 1))
		fl.light_energy = 0.9
		fl.omni_range = 7.0
		fl.position = Vector3(cx, 3.0, -3.4)
		add_child(fl)

func _build_dressing() -> void:
	# Corporate plaza: squared hedges in steel planters, no benches — the
	# Stack doesn't want you comfortable
	for px in [-48.0, -24.0, 24.0, 48.0]:
		_add_box(Vector3(px, 0.3, -4.4), Vector3(1.2, 0.6, 1.2),
			Color(0.16, 0.17, 0.20), 0.5, 0.4)
		_add_box(Vector3(px, 0.63, -4.4), Vector3(1.26, 0.05, 1.26),
			Color(0.3, 0.8, 1.2) * 0.4, 0.0, 0.5, true, Color(0.35, 0.9, 1.3), 1.2)
		_add_box(Vector3(px, 0.95, -4.4), Vector3(0.9, 0.7, 0.9),
			Color(0.08, 0.22, 0.12), 0.0, 0.9)
	# Stock ticker on the OmniCorp tower face — the Stack's heartbeat
	var panel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(14.0, 1.6, 0.2)
	panel.mesh = bm
	panel.position = Vector3(-40.0, 12.5, -6.55)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.03, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(0.05, 0.10, 0.15)
	mat.emission_energy_multiplier = 0.8
	panel.material_override = mat
	add_child(panel)
	var tick := Label3D.new()
	tick.text = "OMNI +2.4   CRTX +6.1   QNTX -0.8   NRL +1.2   KRNX -3.5   SYN +0.4"
	tick.font_size = 40
	tick.pixel_size = 0.012
	tick.modulate = Color(0.3, 1.2, 0.7)
	tick.outline_size = 8
	tick.outline_modulate = Color(0, 0, 0)
	tick.position = Vector3(-40.0, 12.5, -6.4)
	add_child(tick)
	var tw := create_tween().set_loops()
	tw.tween_property(tick, "modulate", Color(0.3, 1.2, 0.7) * 0.55, 1.6)
	tw.tween_property(tick, "modulate", Color(0.3, 1.2, 0.7), 1.6)
	# Holo billboard on the Cortex face — recruiting, of course
	var bl := Label3D.new()
	bl.text = "CORTEX: BUILD WHAT'S NEXT"
	bl.font_size = 56
	bl.pixel_size = 0.012
	bl.modulate = Color(1.4, 0.4, 1.0)
	bl.outline_size = 12
	bl.outline_modulate = Color(0, 0, 0)
	bl.position = Vector3(40.0, 14.5, -6.4)
	add_child(bl)

func _build_crowd() -> void:
	# Suits commute, cops patrol; nobody loiters in the Stack
	add_walker("res://assets/sprites/npc-corpo.png", -54.0, -12.0, -2.4, 2.6)
	add_walker("res://assets/sprites/npc-corpo.png", -8.0, 34.0, -2.7, 2.4)
	add_walker("res://assets/sprites/lady.png", -30.0, 26.0, -2.2, 2.2)
	add_walker("res://assets/sprites/npc-cop.png", -50.0, 50.0, -2.6, 1.7)
	add_walker("res://assets/sprites/npc-cop2.png", 10.0, 56.0, -2.3, 1.9)
	add_walker("res://assets/sprites/npc-cyberpunk.png", -20.0, 20.0, -2.5, 2.9)
	# Security fixtures: drone-jockey guards flanking the OmniCorp door,
	# a corpo suit having a bad cigarette outside Cortex
	add_npc("res://assets/sprites/npc-cop2.png", Vector3(-38.8, 0.9, -3.4), 0)
	add_npc("res://assets/sprites/npc-cop2.png", Vector3(-36.2, 0.9, -3.4), 0)
	add_npc("res://assets/sprites/npc-corpo.png", Vector3(44.5, 0.9, -3.2), 3)
	# Static faces on the sidewalk — window shopper, someone waiting for a car
	add_npc("res://assets/sprites/civ/civ-a03.png", Vector3(-16.4, 0.9, -3.6), 0)
	add_npc("res://assets/sprites/civ/civ-b05.png", Vector3(14.8, 0.9, -2.0), 0)
