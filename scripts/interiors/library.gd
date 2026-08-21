## THE LIBRARY — downtown's quietest building. Laura runs the desk, Brian
## fights the "IT" system, and the back alcove holds a matched set with
## one missing volume. The missing book is on YOUR shelf at home (it came
## with the apartment). Bring it to Laura: she knows who you are, and the
## brass key she hands you opens the cellar door. The cellar is the guild.
extends "res://scripts/interiors/interior_base.gd"

var _cellar_glow

func _ready() -> void:
	room_w = 30.0
	room_d = 20.0
	interior_name = "PUBLIC LIBRARY"
	exit_scene = "street_downtown"
	exit_spawn = "from_library"
	super._ready()
	Music.play_category("shops")

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
	_build_cellar_door()
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
		"talk to laura (librarian)", _talk_laura)

func _talk_laura() -> void:
	if GameState.has_item("spellbook") and not GameState.has_flag("guildDiscovered"):
		GameState.inventory.erase("spellbook")
		GameState.set_flag("spellbookPlaced")
		GameState.set_flag("guildDiscovered")
		GameState.add_item("cellar_key")
		DialogueOverlay.play_lines([
			{ "speaker": "LAURA", "text": "...that's volume seven. we've been looking for that for six years.", "color": Color(0.75, 0.6, 1.0) },
			{ "speaker": "LAURA", "text": "and it was in YOUR apartment. of course it was.", "color": Color(0.75, 0.6, 1.0) },
			{ "speaker": "", "text": "She studies you for a long moment. Something behind her eyes recalibrates.", "color": Color(0.53, 0.53, 0.53) },
			{ "speaker": "LAURA", "text": "we know who you are, ghost. we've known since you moved in.", "color": Color(0.9, 0.7, 1.2) },
			{ "speaker": "", "text": "She reshelves the book without looking and presses a heavy brass key into your hand.", "color": Color(0.53, 0.53, 0.53) },
			{ "speaker": "LAURA", "text": "the cellar. mind the circle. and QUIET, please.", "color": Color(0.75, 0.6, 1.0) },
		], "laura_key")
		if _cellar_glow:
			_cellar_glow.set_active(true)
		return
	DialogueOverlay.play("laura")

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

# ── fiction section ──────────────────────────────────────────────────────
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
	add_interact(Vector3(-11.8, 1.2, 3.0), Vector3(2.2, 2.4, 5.2),
		"browse fiction", func():
			_set_status("paperbacks. someone has dog-eared every single mystery."))

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
		"a matched set of old books", _try_shelf)

func _try_shelf() -> void:
	if GameState.has_flag("guildDiscovered"):
		_set_status("the set is whole again. the books look smug about it.")
		return
	if GameState.has_item("spellbook"):
		_set_status("the empty slot matches your book exactly. but this isn't yours to shelve. show the librarian.")
		return
	GameState.set_flag("librarySetSeen")
	DialogueOverlay.play_lines([
		{ "speaker": "", "text": "a matched set of old rune-bound volumes. one slot stands empty.", "color": Color(0.8, 0.6, 1.0) },
		{ "speaker": "", "text": "wait. you KNOW this binding. the heavy book on your shelf at home. the one that came with the apartment.", "color": Color(0.9, 0.8, 1.0) },
		{ "speaker": "", "text": "you have the missing book to this set. at home.", "color": Color(0.7, 0.4, 1.2) },
	], "set_seen")

func _build_cellar_door() -> void:
	# The cellar door is always there — most people never wonder about it
	_add_box(Vector3(0.2, 1.5, -9.5), Vector3(2.0, 3.0, 0.5),
		Color(0.03, 0.02, 0.05), 0.2, 0.4, true, Color(0.5, 0.2, 1.0), 0.25)
	_add_box(Vector3(0.85, 1.4, -9.2), Vector3(0.10, 0.22, 0.08),
		Color(0.7, 0.55, 0.2), 0.7, 0.3, true, Color(1.0, 0.8, 0.35), 0.9)   # keyhole plate
	_cellar_glow = DoorGlowScript.new()
	_cellar_glow.color = Color(0.7, 0.35, 1.5)
	_cellar_glow.opening = Vector2(2.0, 3.0)
	_cellar_glow.position = Vector3(0.2, 0.0, -9.2)
	add_child(_cellar_glow)
	_cellar_glow.set_active(GameState.has_flag("guildDiscovered"))
	add_interact(Vector3(0.2, 1.2, -8.4), Vector3(2.6, 2.4, 2.0),
		"the cellar door", func():
			if GameState.has_flag("guildDiscovered"):
				SceneTransition.go("mages_guild", "from_library")
			else:
				_set_status("locked. the keyhole is shaped like a book spine."))

func _build_people() -> void:
	# A patron lost in the stacks, and the library cat on the desk
	add_npc("res://assets/sprites/civ/civ-a07.png", Vector3(-6.0, 0.9, 0.2), 1)
	add_npc("res://assets/sprites/whiteCat.png", Vector3(12.4, 1.45, -6.5), 1)

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
