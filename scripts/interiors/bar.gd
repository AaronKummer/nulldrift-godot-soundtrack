## THE BLACKOUT — dive bar on the home street. First real interior.
## Roz tends bar (drinks heal, she talks), patrons drop rumors that point
## at real content, the jukebox actually changes the music, the pool
## table waits for a minigame someday.
extends "res://scripts/interiors/interior_base.gd"

const RumorData := preload("res://data/rumors.gd")
const ListMenuScript := preload("res://scripts/systems/list_menu.gd")

const DRINKS := [
	{ "id": "volt_cola", "name": "VOLT COLA", "price": 5, "heal": 5,
	  "bark": "roz slides a can down the counter. it fizzes like a shorting fuse." },
	{ "id": "synth_lager", "name": "SYNTH LAGER", "price": 8, "heal": 10,
	  "bark": "tastes like beer that read about beer once. it works." },
	{ "id": "circuit_breaker", "name": "CIRCUIT BREAKER", "price": 20, "heal": 30,
	  "bark": "it glows. roz says that's normal. your headache disagrees, then surrenders." },
]

var _rumor_bag: Array = []
var _bar_menu
var _juke_idx := 0
var _juke_cats: Array = []

func _ready() -> void:
	room_w = 30.0
	room_d = 20.0
	interior_name = "THE BLACKOUT"
	exit_scene = "city"
	exit_spawn = "from_bar"
	super._ready()
	Music.play_category("city")

func _ambient() -> Color:
	return Color(0.32, 0.20, 0.16)

func _floor_color() -> Color:
	return Color(0.13, 0.10, 0.09)

func _build_interior() -> void:
	_build_counter_and_roz()
	_build_bottle_wall()
	_build_neon_sign()
	_build_booths()
	_build_jukebox()
	_build_pool_table()
	_build_patrons()
	_build_hightops()
	_build_lamps()

# ── hightop tables on the open floor ─────────────────────────────────────
func _build_hightops() -> void:
	for spot in [Vector3(-0.5, 0, 2.5), Vector3(-5.5, 0, 4.5)]:
		_add_box(spot + Vector3(0, 1.05, 0), Vector3(1.1, 0.08, 1.1),
			Color(0.18, 0.12, 0.09), 0.2, 0.4)
		_add_box(spot + Vector3(0, 0.5, 0), Vector3(0.14, 1.0, 0.14),
			Color(0.15, 0.15, 0.17), 0.7, 0.4)
		# Abandoned glowing drink
		_add_box(spot + Vector3(0.25, 1.19, 0.1), Vector3(0.12, 0.22, 0.12),
			Color(0.3, 0.9, 0.5), 0.0, 0.3, true, Color(0.3, 0.95, 0.5), 1.4)

# ── the bar counter, stools, Roz ─────────────────────────────────────────
func _build_counter_and_roz() -> void:
	var cz := -6.0
	_add_box(Vector3(0, 0.55, cz), Vector3(16.0, 1.1, 1.4),
		Color(0.22, 0.12, 0.08), 0.1, 0.5)                      # wood body
	_add_box(Vector3(0, 1.12, cz), Vector3(16.4, 0.08, 1.7),
		Color(0.10, 0.09, 0.10), 0.7, 0.25)                     # dark top
	_add_box(Vector3(0, 1.16, cz + 0.92), Vector3(16.4, 0.05, 0.05),
		Color(0.8, 0.6, 0.3), 0.9, 0.2, true, Color(1.0, 0.75, 0.35), 0.4)  # brass rail
	# Under-counter neon strip — the signature glow
	_add_box(Vector3(0, 0.18, cz + 0.74), Vector3(16.0, 0.06, 0.04),
		Color(1.0, 0.35, 0.15), 0.0, 0.5, true, Color(1.0, 0.35, 0.12), 2.4)
	# Stools
	for i in 6:
		var sx := -6.5 + i * 2.6
		var stool := Node3D.new()
		stool.position = Vector3(sx, 0, cz + 1.9)
		add_child(stool)
		var seat := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.32
		cyl.bottom_radius = 0.28
		cyl.height = 0.12
		seat.mesh = cyl
		seat.position = Vector3(0, 0.72, 0)
		var smat := StandardMaterial3D.new()
		smat.albedo_color = Color(0.45, 0.12, 0.10)
		seat.material_override = smat
		stool.add_child(seat)
		var leg := MeshInstance3D.new()
		var lcyl := CylinderMesh.new()
		lcyl.top_radius = 0.06
		lcyl.bottom_radius = 0.16
		lcyl.height = 0.7
		leg.mesh = lcyl
		leg.position = Vector3(0, 0.35, 0)
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.2, 0.2, 0.22)
		lmat.metallic = 0.8
		leg.material_override = lmat
		stool.add_child(leg)
	# Roz behind the counter
	add_npc("res://assets/sprites/cyberGirl.png", Vector3(-1.0, 0.9, -7.6), 0)
	add_interact(Vector3(-1.0, 1.2, -4.4), Vector3(5.0, 2.4, 2.6),
		"talk to roz / order a drink", _open_bar_menu)
	# The bar cat, asleep at the counter's end
	add_npc("res://assets/sprites/blackCat.png", Vector3(7.0, 1.45, -6.0), 1)

# ── glowing bottle wall behind Roz ───────────────────────────────────────
func _build_bottle_wall() -> void:
	var bz := -9.55
	for row in 3:
		var sy := 1.3 + row * 0.72
		_add_box(Vector3(-1.0, sy - 0.06, bz), Vector3(13.0, 0.07, 0.5),
			Color(0.15, 0.10, 0.08), 0.2, 0.6)                  # shelf
		_add_box(Vector3(-1.0, sy - 0.10, bz + 0.05), Vector3(13.0, 0.03, 0.03),
			Color(0.3, 0.8, 1.0), 0.0, 0.5, true, Color(0.25, 0.7, 1.0), 1.8)  # shelf light
		var bottle_colors := [Color(1.0, 0.5, 0.15), Color(0.3, 0.9, 0.5),
			Color(0.9, 0.25, 0.5), Color(0.4, 0.6, 1.0), Color(0.95, 0.85, 0.3)]
		for i in 11:
			var bx := -6.4 + i * 1.1 + fmod(float(row * 7 + i * 3), 0.5)
			var bh := 0.45 + fmod(float(i * 13 + row * 5), 0.3)
			var bc: Color = bottle_colors[(i + row * 2) % bottle_colors.size()]
			_add_box(Vector3(bx, sy + bh / 2.0, bz), Vector3(0.16, bh, 0.16),
				bc * 0.4, 0.1, 0.2, true, bc, 0.9)

# ── neon name on the north wall ──────────────────────────────────────────
func _build_neon_sign() -> void:
	var sign := Label3D.new()
	sign.text = "THE BLACKOUT"
	sign.font_size = 120
	sign.pixel_size = 0.012
	sign.modulate = Color(1.0, 0.30, 0.12)
	sign.outline_modulate = Color(0.4, 0.05, 0.0)
	sign.position = Vector3(-1.0, 4.0, -9.55)
	add_child(sign)
	var tube := _add_box(Vector3(-1.0, 3.55, -9.55), Vector3(9.5, 0.05, 0.05),
		Color(1.0, 0.3, 0.1), 0.0, 0.5, true, Color(1.0, 0.3, 0.1), 3.0)
	# Flicker the tube like a dying neon
	var tw := create_tween().set_loops()
	var tube_mesh := tube.get_child(0) as MeshInstance3D
	var mat := tube_mesh.material_override as StandardMaterial3D
	tw.tween_property(mat, "emission_energy_multiplier", 0.6, 0.06).set_delay(2.3)
	tw.tween_property(mat, "emission_energy_multiplier", 3.0, 0.05)
	tw.tween_property(mat, "emission_energy_multiplier", 1.2, 0.04).set_delay(0.9)
	tw.tween_property(mat, "emission_energy_multiplier", 3.0, 0.05)

# ── booths along the west wall ───────────────────────────────────────────
func _build_booths() -> void:
	for b in 2:
		var bz := -1.5 + b * 5.5
		_add_box(Vector3(-13.2, 0.9, bz), Vector3(0.5, 1.8, 3.6),
			Color(0.35, 0.10, 0.10), 0.0, 0.6)                  # high back
		_add_box(Vector3(-12.4, 0.35, bz), Vector3(1.2, 0.7, 3.6),
			Color(0.45, 0.13, 0.12), 0.0, 0.5)                  # bench
		_add_box(Vector3(-10.6, 0.48, bz), Vector3(1.6, 0.10, 2.6),
			Color(0.18, 0.12, 0.09), 0.2, 0.4)                  # table
		_add_box(Vector3(-10.6, 0.24, bz), Vector3(0.18, 0.48, 0.18),
			Color(0.15, 0.15, 0.17), 0.7, 0.4)                  # table leg
		# Candle bulb on each table
		_add_box(Vector3(-10.6, 0.60, bz), Vector3(0.10, 0.14, 0.10),
			Color(1.0, 0.7, 0.3), 0.0, 0.5, true, Color(1.0, 0.55, 0.2), 2.0)

# ── jukebox (actually changes the music) ─────────────────────────────────
func _build_jukebox() -> void:
	var jx := -13.6
	var jz := -7.5
	_add_box(Vector3(jx, 0.9, jz), Vector3(1.4, 1.8, 1.0),
		Color(0.25, 0.15, 0.30), 0.2, 0.4)
	_add_box(Vector3(jx + 0.55, 1.75, jz), Vector3(0.3, 0.5, 0.8),
		Color(0.9, 0.4, 1.0), 0.0, 0.5, true, Color(0.85, 0.35, 1.0), 1.6)  # glowing arch
	_add_box(Vector3(jx + 0.62, 0.9, jz), Vector3(0.08, 0.9, 0.7),
		Color(0.3, 0.9, 1.0), 0.0, 0.5, true, Color(0.25, 0.8, 1.0), 1.2)   # face panel
	_juke_cats = Music.CATEGORIES.keys()
	add_interact(Vector3(jx + 1.4, 1.2, jz), Vector3(2.2, 2.4, 2.4),
		"jukebox · change the music", _punch_jukebox)

func _punch_jukebox() -> void:
	if _juke_cats.is_empty():
		return
	_juke_idx = (_juke_idx + 1) % _juke_cats.size()
	var cat: String = _juke_cats[_juke_idx]
	Music.play_category(cat)
	_set_status("jukebox: " + cat.to_upper() + " set. someone at the bar nods.")

# ── pool table ───────────────────────────────────────────────────────────
func _build_pool_table() -> void:
	var px := 6.0
	var pz := 1.5
	_add_box(Vector3(px, 0.75, pz), Vector3(3.6, 0.16, 2.0),
		Color(0.05, 0.35, 0.18), 0.0, 0.9)                      # felt
	_add_box(Vector3(px, 0.66, pz), Vector3(4.0, 0.3, 2.4),
		Color(0.20, 0.11, 0.07), 0.1, 0.5)                      # frame
	for corner in [[-1.7, -0.9], [1.7, -0.9], [-1.7, 0.9], [1.7, 0.9]]:
		_add_box(Vector3(px + corner[0], 0.35, pz + corner[1]),
			Vector3(0.25, 0.7, 0.25), Color(0.16, 0.09, 0.06))
	var ball_cols := [Color(1, 1, 0.9), Color(0.9, 0.2, 0.2), Color(0.2, 0.4, 0.9),
		Color(0.9, 0.8, 0.2), Color(0.1, 0.1, 0.1)]
	for i in 5:
		var offs := [[-0.8, 0.2], [0.3, -0.4], [0.9, 0.3], [-0.2, 0.5], [0.5, 0.1]]
		_add_box(Vector3(px + offs[i][0], 0.88, pz + offs[i][1]),
			Vector3(0.14, 0.14, 0.14), ball_cols[i], 0.0, 0.3,
			true, ball_cols[i], 0.25)
	add_interact(Vector3(px, 1.0, pz + 2.2), Vector3(4.4, 2.0, 1.6),
		"pool table", func():
			_set_status("the felt is torn where somebody lost badly. rack 'em someday."))

# ── patrons with rumors ──────────────────────────────────────────────────
func _build_patrons() -> void:
	var patrons := [
		{ "sheet": "res://assets/sprites/npc-corpo.png", "pos": Vector3(-4.0, 0.9, -3.4),
		  "facing": 3, "name": "SUIT", "color": Color(0.55, 0.75, 1.0) },
		{ "sheet": "res://assets/sprites/npc-cyberpunk.png", "pos": Vector3(-11.0, 0.9, 4.0),
		  "facing": 2, "name": "REGULAR", "color": Color(1.0, 0.6, 0.85) },
		{ "sheet": "res://assets/sprites/civ/civ-b05.png", "pos": Vector3(8.6, 0.9, 3.6),
		  "facing": 1, "name": "POOL SHARK", "color": Color(1.0, 0.75, 0.4) },
	]
	patrons.append({ "sheet": "res://assets/sprites/floozy-red.png",
		"pos": Vector3(-0.5, 0.9, 3.4), "facing": 0,
		"name": "DANCER", "color": Color(1.0, 0.5, 0.5) })
	patrons.append({ "sheet": "res://assets/sprites/princess-rose.png",
		"pos": Vector3(-11.0, 0.9, -1.3), "facing": 0,
		"name": "REGRETS", "color": Color(1.0, 0.7, 0.85) })
	for p in patrons:
		add_npc(p.sheet, p.pos, p.facing)
		var pname: String = p.name
		var pcol: Color = p.color
		add_interact(p.pos + Vector3(0, 0.3, 0.4), Vector3(2.0, 2.2, 2.2),
			"listen in (" + pname.to_lower() + ")", func():
				_tell_rumor(pname, pcol))

func _tell_rumor(speaker: String, color: Color) -> void:
	if _rumor_bag.is_empty():
		_rumor_bag = RumorData.eligible(GameState.flags, GameState.katana_level)
		_rumor_bag.shuffle()
	if _rumor_bag.is_empty():
		return
	var text: String = _rumor_bag.pop_back()
	DialogueOverlay.play_lines([
		{ "speaker": speaker, "text": text, "color": color },
	], "rumor")

# ── warm hanging lamps ───────────────────────────────────────────────────
func _build_lamps() -> void:
	for spot in [Vector3(-3.0, 3.4, -5.0), Vector3(6.0, 3.0, 1.5), Vector3(-11.0, 3.2, 1.0)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.72, 0.45)
		lamp.light_energy = 1.6
		lamp.omni_range = 9.0
		lamp.shadow_enabled = true
		lamp.position = spot
		add_child(lamp)
		_add_box(spot + Vector3(0, 0.35, 0), Vector3(0.5, 0.3, 0.5),
			Color(0.12, 0.10, 0.08), 0.3, 0.5, true, Color(1.0, 0.7, 0.4), 1.2)

# ── Roz's menu: drinks + talk ────────────────────────────────────────────
func _open_bar_menu() -> void:
	_menu_open = true
	_bar_menu = ListMenuScript.new()
	add_child(_bar_menu)
	_bar_menu.picked.connect(_on_bar_pick)
	_bar_menu.closed.connect(func():
		_menu_open = false
		_bar_menu = null)
	_bar_menu.open("THE BLACKOUT · roz is listening", _bar_entries(),
		Color(1.0, 0.5, 0.25), _bar_footer())

func _bar_entries() -> Array:
	var out: Array = []
	for d in DRINKS:
		out.append({ "label": "%s · %dcr (+%d hp)" % [d.name, d.price, d.heal] })
	out.append({ "label": "talk to roz" })
	return out

func _bar_footer() -> String:
	return "credits: %d   hp: %d/%d" % [GameState.credits, GameState.hp, GameState.hp_max]

func _on_bar_pick(idx: int) -> void:
	if idx >= DRINKS.size():
		_bar_menu.close_menu()
		DialogueOverlay.play("roz")
		return
	var d: Dictionary = DRINKS[idx]
	if GameState.credits < int(d.price):
		_bar_menu.set_footer("roz: 'credits first, sad story second.'")
		return
	GameState.add_credits(-int(d.price))
	GameState.hp = mini(GameState.hp + int(d.heal), GameState.hp_max)
	_bar_menu.refresh(_bar_entries(), _bar_footer())
	_set_status(d.bark)
