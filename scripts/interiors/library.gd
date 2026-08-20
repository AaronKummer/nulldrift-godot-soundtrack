## THE LIBRARY — downtown's quietest building. Laura runs the desk, Brian
## fights the "IT" system, and the back alcove shelf has one empty slot.
## Port of the Phaser MagesGuildScene discovery: find the spellbook someone
## keeps reshelving in fiction, place it in the empty slot, and the shelf
## swings open on the guild.
extends "res://scripts/interiors/interior_base.gd"

var _guild_door_built := false

func _ready() -> void:
	room_w = 30.0
	room_d = 20.0
	interior_name = "PUBLIC LIBRARY"
	exit_scene = "street_downtown"
	exit_spawn = "from_library"
	super._ready()
	Music.play_category("apartment")
	if GameState.has_flag("guildDiscovered"):
		_build_guild_door()

func _ambient() -> Color:
	return Color(0.30, 0.27, 0.22)

func _wall_color() -> Color:
	return Color(0.15, 0.13, 0.11)

func _floor_color() -> Color:
	return Color(0.16, 0.12, 0.09)

func _build_interior() -> void:
	_build_stacks()
	_build_desk()
	_build_reading_tables()
	_build_fiction_shelf()
	_build_alcove_shelf()
	_build_people()
	_build_lamps()

# ── rows of book stacks ──────────────────────────────────────────────────
func _build_stacks() -> void:
	var spine_cols := [Color(0.7, 0.25, 0.2), Color(0.25, 0.5, 0.8),
		Color(0.75, 0.6, 0.25), Color(0.35, 0.6, 0.35), Color(0.5, 0.35, 0.6)]
	for row in 3:
		var sz := -5.0 + row * 4.5
		for side in 2:
			var sx := -8.0 if side == 0 else 2.0
			_add_box(Vector3(sx, 1.1, sz), Vector3(7.0, 2.2, 0.9),
				Color(0.22, 0.15, 0.10), 0.1, 0.6)
			# spines
			for i in 16:
				var bx := sx - 3.2 + i * 0.42
				var bh := 0.35 + fmod(float(i * 7 + row * 3), 0.25)
				var bc: Color = spine_cols[(i + row) % spine_cols.size()]
				_add_box(Vector3(bx, 1.75 + bh * 0.5 - 0.35, sz + 0.48),
					Vector3(0.3, bh, 0.06), bc * 0.75, 0.0, 0.5)

# ── circulation desk + Laura ─────────────────────────────────────────────
func _build_desk() -> void:
	_add_box(Vector3(10.5, 0.6, -6.5), Vector3(5.0, 1.2, 1.6),
		Color(0.24, 0.17, 0.11), 0.1, 0.5)
	_add_box(Vector3(10.5, 1.25, -6.5), Vector3(5.3, 0.08, 1.9),
		Color(0.12, 0.10, 0.09), 0.5, 0.3)
	# Terminal that runs on "literal magic"
	_add_box(Vector3(9.3, 1.65, -6.6), Vector3(0.9, 0.7, 0.1),
		Color(0.2, 0.6, 0.9) * 0.4, 0.0, 0.4, true, Color(0.3, 0.8, 1.2), 1.2)
	add_npc("res://assets/sprites/cyberGirl.png", Vector3(10.5, 0.9, -7.9), 0)
	add_interact(Vector3(10.5, 1.2, -4.8), Vector3(4.4, 2.4, 2.4),
		"talk to laura (librarian)", func(): DialogueOverlay.play("laura"))

# ── reading tables + Brian ───────────────────────────────────────────────
func _build_reading_tables() -> void:
	for spot in [Vector3(-3.0, 0, 6.0), Vector3(7.0, 0, 5.0)]:
		_add_box(spot + Vector3(0, 0.72, 0), Vector3(2.6, 0.1, 1.4),
			Color(0.24, 0.17, 0.11), 0.1, 0.5)
		_add_box(spot + Vector3(0, 0.35, 0), Vector3(0.2, 0.7, 0.2),
			Color(0.15, 0.15, 0.17), 0.6, 0.4)
		# Green banker's lamp
		_add_box(spot + Vector3(0.7, 0.95, 0), Vector3(0.5, 0.18, 0.25),
			Color(0.1, 0.5, 0.25) * 0.5, 0.2, 0.4, true, Color(0.2, 1.1, 0.45), 1.4)
	add_npc("res://assets/sprites/npc-cyberpunk.png", Vector3(7.0, 0.9, 6.4), 3)
	add_interact(Vector3(7.0, 1.2, 6.8), Vector3(2.4, 2.4, 2.4),
		"talk to brian (it guy)", func(): DialogueOverlay.play("brian"))

# ── fiction section: the spellbook that keeps reshelving itself ─────────
func _build_fiction_shelf() -> void:
	_add_box(Vector3(-13.2, 1.4, 3.0), Vector3(0.9, 2.8, 5.0),
		Color(0.22, 0.15, 0.10), 0.1, 0.6)
	var sign := Label3D.new()
	sign.text = "FICTION"
	sign.font_size = 60
	sign.pixel_size = 0.01
	sign.modulate = Color(0.9, 0.8, 0.6)
	sign.position = Vector3(-12.6, 3.2, 3.0)
	sign.rotation.y = PI / 2.0
	add_child(sign)
	# The one glowing spine
	_add_box(Vector3(-12.7, 1.6, 2.2), Vector3(0.12, 0.5, 0.34),
		Color(0.5, 0.3, 0.8), 0.0, 0.3, true, Color(0.8, 0.4, 1.6), 1.6)
	add_interact(Vector3(-11.8, 1.2, 3.0), Vector3(2.2, 2.4, 5.2),
		"browse fiction", _browse_fiction)

func _browse_fiction() -> void:
	if GameState.has_item("spellbook") or GameState.has_flag("spellbookPlaced"):
		_set_status("paperbacks, mostly. whatever kept reshelving itself is gone.")
		return
	GameState.add_item("spellbook")
	DialogueOverlay.play_lines([
		{ "speaker": "", "text": "wedged between two paperbacks: a heavy book with glowing runes. it hums against your hands.", "color": Color(0.8, 0.6, 1.0) },
		{ "speaker": "", "text": "the return label says RARE BOOKS. there is no rare books section.", "color": Color(0.6, 0.6, 0.7) },
	], "spellbook")

# ── the back alcove: a shelf of old books, one slot empty ───────────────
func _build_alcove_shelf() -> void:
	_add_box(Vector3(-4.0, 1.5, -9.4), Vector3(6.0, 3.0, 0.7),
		Color(0.20, 0.14, 0.09), 0.1, 0.6)
	for i in 12:
		if i == 7:
			continue   # the empty slot
		var bx := -6.6 + i * 0.46
		_add_box(Vector3(bx, 1.9, -9.0), Vector3(0.34, 0.6, 0.1),
			Color(0.35, 0.28, 0.18) * (0.8 + 0.05 * (i % 4)), 0.0, 0.6)
	add_interact(Vector3(-4.0, 1.2, -8.2), Vector3(6.4, 2.4, 2.2),
		"a shelf of old books", _try_shelf)

func _try_shelf() -> void:
	if GameState.has_flag("guildDiscovered"):
		_set_status("the shelf stands ajar. cold air drifts out.")
		return
	if GameState.has_item("spellbook"):
		GameState.inventory.erase("spellbook")
		GameState.set_flag("spellbookPlaced")
		GameState.set_flag("guildDiscovered")
		DialogueOverlay.play_lines([
			{ "speaker": "", "text": "you slide the spellbook into the empty slot. a perfect fit.", "color": Color(0.8, 0.6, 1.0) },
			{ "speaker": "", "text": "somewhere inside the wall, tumblers turn. the shelf swings inward on silent hinges.", "color": Color(0.8, 0.6, 1.0) },
			{ "speaker": "", "text": "purple light. a smell like ozone and old paper.", "color": Color(0.7, 0.4, 1.2) },
		], "guild_open")
		_build_guild_door()
	else:
		_set_status("a shelf of old books. one slot is empty...")

func _build_guild_door() -> void:
	if _guild_door_built:
		return
	_guild_door_built = true
	# The shelf stands ajar — purple doorway into the dark
	_add_box(Vector3(0.2, 1.5, -9.5), Vector3(2.0, 3.0, 0.5),
		Color(0.03, 0.02, 0.05), 0.2, 0.4, true, Color(0.5, 0.2, 1.0), 0.4)
	var glow := DoorGlowScript.new()
	glow.color = Color(0.7, 0.35, 1.5)
	glow.opening = Vector2(2.0, 3.0)
	glow.position = Vector3(0.2, 0.0, -9.2)
	add_child(glow)
	glow.set_active(true)
	add_interact(Vector3(0.2, 1.2, -8.4), Vector3(2.6, 2.4, 2.0),
		"the rare books section", func():
			SceneTransition.go("mages_guild", "from_library"))

func _build_people() -> void:
	# A patron lost in the stacks
	add_npc("res://assets/sprites/npc-corpo.png", Vector3(-6.0, 0.9, 0.2), 1)

func _build_lamps() -> void:
	for spot in [Vector3(0.0, 3.6, -4.0), Vector3(8.0, 3.4, 4.0), Vector3(-8.0, 3.4, 4.0)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.85, 0.6)
		lamp.light_energy = 1.5
		lamp.omni_range = 10.0
		lamp.shadow_enabled = true
		lamp.position = spot
		add_child(lamp)
		_add_box(spot + Vector3(0, 0.3, 0), Vector3(0.6, 0.25, 0.6),
			Color(0.12, 0.10, 0.08), 0.3, 0.5, true, Color(1.0, 0.75, 0.45), 1.0)
