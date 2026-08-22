## FINANCIAL DISTRICT — cold money and colder security. Glass banks and
## corporate spires: NEXUS BANK (locked vault), PLATINUM ARMS (the high-end
## arms dealer, walk-in), VOHL PHARMACEUTICALS (sealed — the Act 2 dungeon
## when it's built), and NEXUS TOWER (abandoned; the office dungeon relocated
## here from Packard Rows). The VVS TOWER looms over all of it — the finale.
extends "res://scripts/streets/street_base.gd"

func _init() -> void:
	street_id = "financial"
	block_half_w = 62.0

func _ambient_color() -> Color:
	return Color(0.16, 0.20, 0.30)

func _fog_color() -> Color:
	return Color(0.08, 0.12, 0.26)

func _moon_color() -> Color:
	return Color(0.6, 0.7, 1.1)

func _moon_energy() -> float:
	return 0.8

func _lamp_color() -> Color:
	return Color(0.8, 0.9, 1.2)

func _lamp_broken_chance() -> float:
	return 0.0

const STORES := [
	{ "id": "nexusbank", "x": -44.0, "label": "NEXUS BANK",
	  "tex": "res://assets/world/signs/nexusbank.png",
	  "sign": Color(1.0, 0.82, 0.3), "awning": Color(0.30, 0.24, 0.06),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "platinum", "x": -15.0, "label": "PLATINUM ARMS", "scene": "platinum_arms",
	  "tex": "res://assets/world/signs/platinum.png",
	  "sign": Color(0.8, 0.85, 0.95), "awning": Color(0.22, 0.24, 0.30),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "vohl", "x": 15.0, "label": "VOHL PHARMA",
	  "tex": "res://assets/world/signs/vohl.png",
	  "sign": Color(0.45, 0.9, 0.45), "awning": Color(0.10, 0.24, 0.10),
	  "sign_w": 6.6, "sign_h": 4.4 },
	{ "id": "nexustower", "x": 44.0, "label": "NEXUS TOWER",
	  "tex": "res://assets/world/signs/nexus.png",
	  "sign": Color(0.55, 0.52, 0.72), "awning": Color(0.14, 0.13, 0.20),
	  "sign_w": 6.6, "sign_h": 4.4 },
]

const FILLERS := [
	{ "x": -54.0, "w": 3.6, "sign": "VAULTCORP", "col": Color(1.2, 0.9, 0.3) },
	{ "x": -30.0, "w": 3.6, "sign": "CRED EXCHANGE", "col": Color(0.4, 1.0, 0.7) },
	{ "x": -2.0,  "w": 3.6, "sign": "QUANTRADE", "col": Color(0.5, 0.7, 1.4) },
	{ "x": 28.0,  "w": 3.2, "sign": "APEX CAPITAL", "col": Color(1.3, 0.8, 0.4) },
	{ "x": 54.0,  "w": 3.6, "sign": "PRISM CORP", "col": Color(0.9, 0.5, 1.4) },
]

func _build_street() -> void:
	Music.play_category("city")
	build_streetlamps(20.0)
	build_traffic(9, [Color(0.1, 0.1, 0.14), Color(0.85, 0.85, 0.9),
		Color(0.5, 0.55, 0.7), Color(0.15, 0.2, 0.35)],
		["sedan", "sedan", "sedan", "boxtruck"])
	for st in STORES:
		build_storefront(st)
	_build_towers()
	_build_vvs_tower()
	_build_fillers()
	_build_crowd()
	build_ridenet_terminal(Vector3(-2.0, 0, -3.0))
	_build_vvs_entrance()
	for mk in [["from_ridenet", 2.0], ["from_platinum", -15.0], ["from_nexus", 44.0],
			["from_vohl", 15.0], ["from_bank", -44.0], ["from_vvs", 6.0]]:
		var m := Node3D.new()
		m.name = mk[0]
		m.position = Vector3(mk[1], 0.0, -2.2)
		add_child(m)

## Anchor entries: PLATINUM ARMS walks in, NEXUS TOWER is the office dungeon
## (relocated), VOHL is sealed until its dungeon is built, the bank is locked.
func _on_storefront_interact(def: Dictionary) -> void:
	match def.get("id", ""):
		"platinum":
			SceneTransition.go("platinum_arms", "from_street")
		"nexustower":
			GameState.pending_dungeon = "office"
			SceneTransition.go("dungeon", "from_city")
		"vohl":
			# Sealed until you've got the lead (Nyx's Vohl tip once Kerry's sick).
			# Enter the lit office tower — the lab is in the basement below it.
			if GameState.has_flag("vohlClueFound") and not GameState.has_flag("vohlDefeated"):
				GameState.vohl_floor = 1
				SceneTransition.go("vohl_office", "from_street")
			elif GameState.has_flag("vohlDefeated"):
				DialogueOverlay.play_lines([
					{ "speaker": "", "text": "the lobby's crawling with hazmat crews now. whatever Vohl was growing, it dies with him.", "color": Color(0.53, 0.53, 0.53) },
				], "vohl_cleared")
			else:
				DialogueOverlay.play_lines([
					{ "speaker": "", "text": "VOHL PHARMACEUTICALS. the lobby doors are sealed with a biohazard seal that wasn't there last week.", "color": Color(0.5, 0.9, 0.5) },
					{ "speaker": "", "text": "something is very wrong in there. you'll be back — when you have a reason, and a way in.", "color": Color(0.53, 0.53, 0.53) },
				], "vohl_sealed")
		"nexusbank":
			# The bank is a heist waiting to happen: walk in, case it, and sneak
			# / hack / shoot your way to the floor-3 vault. In-house security,
			# no cops (posture "nexusbank").
			GameState.bank_floor = 1
			SceneTransition.go("nexus_bank", "from_street")
		_:
			super._on_storefront_interact(def)

func _build_towers() -> void:
	var base_y := 9.0
	var face_z := -SIDEWALK_W - 0.5
	for anchor in [[-44.0, 30.0, Color(1.0, 0.82, 0.3)], [-15.0, 26.0, Color(0.8, 0.85, 0.95)],
			[15.0, 24.0, Color(0.45, 0.9, 0.45)], [44.0, 30.0, Color(0.30, 0.28, 0.42)]]:
		var tz := face_z - 5.2
		_add_box(Vector3(anchor[0], base_y + anchor[1] * 0.5, tz),
			Vector3(10.0, anchor[1], 8.0), Color(0.09, 0.10, 0.15), 0.3, 0.6)
		for sx in [-3.2, 0.0, 3.2]:
			_add_box(Vector3(anchor[0] + sx, base_y + anchor[1] * 0.5, tz + 4.05),
				Vector3(0.5, anchor[1] - 4.0, 0.05),
				(anchor[2] as Color) * Color(0.25, 0.25, 0.25, 1.0), 0.0, 0.4, true,
				(anchor[2] as Color) * 0.8, 1.0)

## The tower's ground entrance — the way into the finale gauntlet. Sealed
## until you've dealt with Vohl (Act 2); after that, this is the endgame.
func _build_vvs_entrance() -> void:
	var ez := -SIDEWALK_W - 1.2
	# A lit violet doorway at the base of the spire
	_add_box(Vector3(6.0, 1.6, ez), Vector3(2.6, 3.2, 0.4),
		Color(0.10, 0.05, 0.16), 0.5, 0.3, true, Color(0.9, 0.3, 1.4), 1.2)
	var sign := Label3D.new()
	sign.text = "VVS"
	sign.font_size = 90
	sign.pixel_size = 0.012
	sign.modulate = Color(1.2, 0.5, 1.6)
	sign.position = Vector3(6.0, 3.4, ez)
	add_child(sign)
	add_interact(Vector3(6.0, 1.2, ez + 1.6), Vector3(2.8, 2.4, 2.4),
		"enter VVS TOWER", func():
			if not GameState.has_flag("vohlDefeated"):
				DialogueOverlay.play_lines([
					{ "speaker": "LOBBY AI", "text": "VVS Tower access is by executive appointment only. You don't have one.", "color": Color(1.0, 0.5, 1.4) },
					{ "speaker": "", "text": "The spire waits. When you've finished what Vohl started, come back — the top floor is where this ends.", "color": Color(0.55, 0.55, 0.62) },
				], "vvs_sealed")
				return
			if GameState.has_flag("vvsTowerCleared"):
				DialogueOverlay.play_lines([
					{ "speaker": "", "text": "The tower is quiet now. Whatever you decided up there, it's done.", "color": Color(0.6, 0.6, 0.7) },
				], "vvs_done")
				return
			GameState.pending_dungeon = "vvs"
			GameState.dungeon_floor = 0
			SceneTransition.go("dungeon", "from_city"))

## The VVS TOWER — the finale, a violet spire that dominates the skyline.
func _build_vvs_tower() -> void:
	var vx := 0.0
	var vz := -SIDEWALK_W - 26.0
	_add_box(Vector3(vx, 40.0, vz), Vector3(16.0, 80.0, 12.0),
		Color(0.10, 0.06, 0.16), 0.4, 0.5)
	for sy in range(6, 78, 6):
		_add_box(Vector3(vx, float(sy), vz + 6.1), Vector3(12.0, 0.5, 0.05),
			Color(0.5, 0.25, 0.9) * 0.3, 0.0, 0.4, true, Color(0.7, 0.35, 1.2), 0.9)
	# Crowning beacon
	_add_box(Vector3(vx, 82.0, vz), Vector3(2.0, 4.0, 2.0),
		Color(0.6, 0.3, 1.0), 0.0, 0.3, true, Color(1.0, 0.4, 1.4), 2.4)
	build_textured_sign(Vector3(vx, 24.0, vz + 6.2), Vector2(9.0, 6.0),
		"res://assets/world/signs/vvs.png")

func _build_fillers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xF1AC
	for f in FILLERS:
		var cx: float = f.x
		var w: float = f.w
		var h: float = rng.randf_range(9.0, 14.0)
		var col: Color = f.col
		_add_box(Vector3(cx, h * 0.5, -9.0), Vector3(w, h, 8.0),
			Color(0.10, 0.11, 0.17) * rng.randf_range(0.85, 1.1), 0.3, 0.6)
		var txt: String = f.sign
		var board_h: float = txt.length() * 0.5 + 0.8
		var by: float = h - 0.6 - board_h * 0.5
		var label := Label3D.new()
		var vert := ""
		for i in txt.length():
			vert += txt[i] + ("\n" if i < txt.length() - 1 else "")
		label.text = vert
		label.font_size = 46
		label.pixel_size = 0.011
		label.modulate = col * 1.15
		label.outline_size = 10
		label.outline_modulate = Color(0, 0, 0)
		label.position = Vector3(cx, by, -4.72)
		add_child(label)
		var fl := OmniLight3D.new()
		fl.light_color = Color(clampf(col.r, 0, 1), clampf(col.g, 0, 1), clampf(col.b, 0, 1))
		fl.light_energy = 0.8
		fl.omni_range = 7.0
		fl.position = Vector3(cx, 3.0, -3.4)
		add_child(fl)

func _build_crowd() -> void:
	add_walker("res://assets/sprites/npc-corpo.png", -54.0, -10.0, -2.4, 2.5)
	add_walker("res://assets/sprites/npc-corpo.png", -8.0, 34.0, -2.7, 2.3)
	add_walker("res://assets/sprites/npc-cop.png", -50.0, 50.0, -2.6, 1.7)
	add_walker("res://assets/sprites/npc-cop2.png", 10.0, 56.0, -2.3, 1.9)
	add_walker("res://assets/sprites/lady.png", -20.0, 24.0, -2.5, 2.2)
	# Bank guards flanking the vault door
	add_npc("res://assets/sprites/npc-cop2.png", Vector3(-42.5, 0.9, -3.4), 0)
	add_npc("res://assets/sprites/npc-cop2.png", Vector3(-40.0, 0.9, -3.4), 0)
