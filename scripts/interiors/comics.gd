## PAGE ZERO — the home-street comic shop. Browseable racks whose issues
## are in-world lore (King Croc, the Silver Samurai, the band), a glowing
## poster wall, and Dex at the register selling three collectible issues.
## Collect all three → comicsCollector flag (Dex notices).
extends "res://scripts/interiors/interior_base.gd"

const ListMenuScript := preload("res://scripts/systems/list_menu.gd")

const ISSUES := [
	{ "id": "comic_croc",    "name": "KING CROC #1",
	  "blurb": "a crocodile. in the sewer. based on a true story." },
	{ "id": "comic_samurai", "name": "SILVER SAMURAI",
	  "blurb": "chrome men guard the tower. nobody draws floor 12." },
	{ "id": "comic_tommy",   "name": "PERFECT TOMMY: THE ZINE",
	  "blurb": "unofficial. the band pretends to hate it. brian owns nine." },
]
const ISSUE_PRICE := 15

# What's on the racks — browse flavor, pools rotate per interact
const RACK_BLURBS := [
	[
		"NEON SURVIVORS #12 — the arcade hero fights the horde. again. it sells.",
		"THE DUMP — a scavenger romance. surprisingly tender. do not tell anyone you cried.",
		"CHROME JACKAL QUARTERLY — mostly motorcycle centerfolds.",
	],
	[
		"GRID GHOSTS — hackers who never log off. the ending is the same every issue: they never log off.",
		"VIOLET — a limited run about an AI in a cage. out of print. dex won't say why.",
		"COMPLIANCE — corpo horror. the officer always gets his form signed.",
	],
]

var _register_menu
var _rack_idx := [0, 0]

func _ready() -> void:
	room_w = 24.0
	room_d = 16.0
	interior_name = "PAGE ZERO"
	exit_scene = "city"
	exit_spawn = "from_comics"
	super._ready()
	Music.play_category("shops")

func _ambient() -> Color:
	return Color(0.24, 0.24, 0.34)

func _floor_color() -> Color:
	return Color(0.12, 0.11, 0.14)

func _build_interior() -> void:
	_build_racks()
	_build_poster_wall()
	_build_counter_and_dex()
	_build_spinner()
	_build_lamps()

# ── two browsing aisles ──────────────────────────────────────────────────
func _build_racks() -> void:
	for i in 2:
		var rz := -2.0 + i * 4.5
		_add_box(Vector3(-2.0, 0.7, rz), Vector3(9.0, 1.4, 0.9),
			Color(0.15, 0.13, 0.18), 0.1, 0.6)
		# Sloped display rows of comic covers — little emissive rectangles
		for c in 7:
			var cx := -5.6 + c * 1.2
			var col: Color = [Color(1.0, 0.4, 0.4), Color(0.4, 0.8, 1.0),
				Color(1.0, 0.8, 0.3), Color(0.7, 0.5, 1.0),
				Color(0.4, 1.0, 0.6)][c % 5]
			_add_box(Vector3(cx, 1.5, rz), Vector3(0.7, 0.9, 0.06),
				col * Color(0.3, 0.3, 0.3, 1.0), 0.0, 0.4, true, col, 0.7)
		var rack_i := i
		add_interact(Vector3(-2.0, 1.0, rz + 1.3), Vector3(9.0, 2.2, 1.4),
			"browse the rack", func(): _browse_rack(rack_i))

func _browse_rack(i: int) -> void:
	var pool: Array = RACK_BLURBS[i]
	var blurb: String = pool[_rack_idx[i] % pool.size()]
	_rack_idx[i] += 1
	DialogueOverlay.play_lines([
		{ "speaker": "", "text": blurb, "color": Color(0.75, 0.78, 0.9) },
	], "rack")

# ── glowing poster wall on the back ──────────────────────────────────────
func _build_poster_wall() -> void:
	var wz := -room_d / 2.0 + 0.6
	var posters := [
		{ "x": -7.0, "col": Color(1.0, 0.3, 0.7), "txt": "NEON\nSURVIVORS" },
		{ "x": -2.5, "col": Color(0.3, 1.0, 0.6), "txt": "KING\nCROC" },
		{ "x": 2.0, "col": Color(0.5, 0.6, 1.4), "txt": "GRID\nGHOSTS" },
		{ "x": 6.5, "col": Color(1.2, 0.9, 0.3), "txt": "PERFECT\nTOMMY" },
	]
	for p in posters:
		_add_box(Vector3(p.x, 2.2, wz), Vector3(2.2, 3.0, 0.08),
			p.col * Color(0.18, 0.18, 0.18, 1.0), 0.0, 0.5, true, p.col, 0.5)
		var t := Label3D.new()
		t.text = p.txt
		t.font_size = 40
		t.pixel_size = 0.01
		t.modulate = p.col * 1.2
		t.outline_size = 10
		t.outline_modulate = Color(0, 0, 0)
		t.position = Vector3(p.x, 2.2, wz + 0.1)
		add_child(t)

# ── register + Dex ───────────────────────────────────────────────────────
func _build_counter_and_dex() -> void:
	var cx := 7.5
	var cz := 3.0
	_add_box(Vector3(cx, 0.55, cz), Vector3(1.4, 1.1, 4.5),
		Color(0.14, 0.12, 0.17), 0.1, 0.6)
	_add_box(Vector3(cx, 1.12, cz), Vector3(1.7, 0.08, 4.9),
		Color(0.09, 0.09, 0.11), 0.6, 0.3)
	# Longbox of back issues on the counter
	_add_box(Vector3(cx, 1.35, cz + 1.4), Vector3(1.0, 0.4, 1.4),
		Color(0.8, 0.78, 0.7), 0.0, 0.7)
	add_npc("res://assets/sprites/hacker-classic.png", Vector3(cx + 1.3, 0.9, cz), 2)
	add_interact(Vector3(cx - 1.4, 1.1, cz), Vector3(2.0, 2.4, 4.5),
		"talk to dex / buy this week's pulls", _open_register)

# ── spinner rack near the door ───────────────────────────────────────────
func _build_spinner() -> void:
	var sx := 4.0
	var sz := -2.5
	_add_box(Vector3(sx, 0.9, sz), Vector3(0.10, 1.8, 0.10),
		Color(0.3, 0.3, 0.33), 0.7, 0.4)
	var spinner := Node3D.new()
	spinner.position = Vector3(sx, 1.3, sz)
	add_child(spinner)
	for a in 4:
		var ang := a * PI / 2.0
		var card := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.7, 0.04)
		card.mesh = bm
		var col: Color = [Color(1.0, 0.5, 0.3), Color(0.4, 0.9, 1.0),
			Color(0.9, 0.4, 1.0), Color(0.5, 1.0, 0.5)][a]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = col * 0.3
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 0.8
		card.material_override = mat
		card.position = Vector3(cos(ang) * 0.35, 0, sin(ang) * 0.35)
		card.rotation.y = -ang
		spinner.add_child(card)
	var tw := create_tween().set_loops()
	tw.tween_property(spinner, "rotation:y", TAU, 12.0)

func _build_lamps() -> void:
	for spot in [Vector3(-2.0, 3.6, 0.5), Vector3(6.0, 3.6, 2.0)]:
		_add_box(spot, Vector3(0.5, 0.15, 0.5),
			Color(0.85, 0.85, 0.95), 0.0, 0.4, true, Color(0.9, 0.9, 1.0), 1.4)
		var l := OmniLight3D.new()
		l.position = spot - Vector3(0, 0.4, 0)
		l.light_color = Color(0.95, 0.95, 1.0)
		l.light_energy = 1.7
		l.omni_range = 9.0
		l.omni_attenuation = 1.3
		add_child(l)

# ── the register ─────────────────────────────────────────────────────────
func _open_register() -> void:
	_menu_open = true
	_register_menu = ListMenuScript.new()
	add_child(_register_menu)
	var entries: Array = [{ "label": "talk to dex", "dim": false }]
	for it in ISSUES:
		var owned: bool = GameState.has_item(it.id)
		entries.append({
			"label": ("%s · in your longbox" % it.name) if owned
				else "%s · %d cr — %s" % [it.name, ISSUE_PRICE, it.blurb],
			"dim": owned })
	_register_menu.picked.connect(_on_register_pick)
	_register_menu.closed.connect(func():
		_menu_open = false
		_register_menu = null)
	_register_menu.open("PAGE ZERO · this week's pulls", entries,
		Color(0.45, 0.85, 1.0), "credits: $%d" % GameState.credits)

func _on_register_pick(idx: int) -> void:
	if idx == 0:
		if _register_menu:
			_register_menu.close_menu()
		DialogueOverlay.play("dex")
		return
	var it: Dictionary = ISSUES[idx - 1]
	if GameState.has_item(it.id):
		_register_menu.set_footer("dex: 'you own it. want to buy a bag and board?'")
		return
	if GameState.credits < ISSUE_PRICE:
		_register_menu.set_footer("dex: 'i take credits, not exposure.'")
		return
	GameState.add_credits(-ISSUE_PRICE)
	GameState.add_item(it.id)
	var bark := "dex: 'good pull.'"
	var all_owned := true
	for i2 in ISSUES:
		if not GameState.has_item(i2.id):
			all_owned = false
			break
	if all_owned and not GameState.has_flag("comicsCollector"):
		GameState.set_flag("comicsCollector")
		bark = "dex: 'that's the full set. respect.'"
	if _register_menu:
		_register_menu.close_menu()
	_open_register()
	if _register_menu:
		_register_menu.set_footer(bark)
