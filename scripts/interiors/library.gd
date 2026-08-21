## THE LIBRARY — downtown's quietest building, and its biggest. A
## dungeon-sized cathedral of books: rows and rows of stacks on the ground
## floor and an upper gallery ringing the hall above. Laura runs the desk,
## Brian fights the "IT" system, the back alcove holds a matched set with
## one missing volume (volume seven is on YOUR shelf at home). Bring it to
## Laura for the brass cellar key — the cellar is the mages guild.
##
## Secrets beyond the guild: a hidden compartment behind a glowing spine, a
## RESTRICTED SECTION nobody's supposed to read, the card catalog, and the
## RARE BOOKS cage up on the gallery.
##
## The room is far too big for a static frame, so this interior overrides
## the base camera to follow the player (iso, locked angle).
extends "res://scripts/interiors/interior_base.gd"

const CAM_OFFSET := Vector3(17.0, 21.0, 17.0)
const CAM_ORTHO := 20.0
const CAM_LERP := 8.0

var _cellar_glow
var _cam_locked_rot: Vector3

func _ready() -> void:
	room_w = 58.0
	room_d = 42.0
	room_h = 9.5
	interior_name = "PUBLIC LIBRARY"
	exit_scene = "street_downtown"
	exit_spawn = "from_library"
	super._ready()
	Music.play_category("shops")

func _ambient() -> Color:
	return Color(0.28, 0.25, 0.20)

func _wall_color() -> Color:
	return Color(0.15, 0.13, 0.11)

func _floor_color() -> Color:
	return Color(0.16, 0.12, 0.09)

# Follow-cam — the hall is dungeon-sized; a static frame can't hold it
func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAM_ORTHO
	_camera.near = 0.05
	_camera.far = 600.0
	_camera.position = CAM_OFFSET
	_camera.current = true
	add_child(_camera)
	# Must be in-tree before look_at; lock the iso angle for the follow-cam
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_cam_locked_rot = _camera.rotation

func _process(delta: float) -> void:
	if _camera == null or _player == null:
		return
	var target := _player.global_position + CAM_OFFSET
	_camera.global_position = _camera.global_position.lerp(target,
		clampf(delta * CAM_LERP, 0.0, 1.0))
	_camera.rotation = _cam_locked_rot

func _build_interior() -> void:
	_build_stacks()
	_build_gallery()
	_build_desk()
	_build_reading_tables()
	_build_fiction_shelf()
	_build_alcove_shelf()
	_build_cellar_door()
	_build_card_catalog()
	_build_restricted_section()
	_build_hidden_compartment()
	_build_people()
	_build_lamps()

# Spine colors reused across every shelf
const SPINES := [
	Color(0.7, 0.25, 0.2), Color(0.25, 0.5, 0.8), Color(0.75, 0.6, 0.25),
	Color(0.35, 0.6, 0.35), Color(0.5, 0.35, 0.6), Color(0.6, 0.5, 0.3),
]

## A double-sided shelf running along Z, packed with book spines both faces.
func _shelf_run(cx: float, cz: float, length: float, height: float = 2.4,
		top_y: float = 1.3) -> void:
	_add_box(Vector3(cx, top_y, cz), Vector3(1.0, height, length),
		Color(0.22, 0.15, 0.10), 0.1, 0.6)
	var books := int(length / 0.42)
	for face in [-1.0, 1.0]:
		for i in books:
			var bz := cz - length * 0.5 + 0.3 + i * 0.42
			var bh: float = 0.4 + fmod(float(i * 7), 3.0) * 0.12
			var bc: Color = SPINES[(i + int(cx)) % SPINES.size()]
			_add_box(Vector3(cx + face * 0.52, top_y + height * 0.5 - 0.55 + bh * 0.5,
				bz), Vector3(0.06, bh, 0.3), bc * 0.75, 0.0, 0.5)

# ── rows and rows: the main stacks (ground floor) ────────────────────────
func _build_stacks() -> void:
	# Parallel shelf runs down the hall with walkable aisles between them
	for x in [-24.0, -18.0, -12.0, -6.0, 0.0, 6.0]:
		_shelf_run(x, -3.0, 24.0)
	# A cross-section of shorter shelves near the front
	for x in [-24.0, -18.0, -12.0, -6.0, 0.0, 6.0]:
		_shelf_run(x, 13.0, 8.0)
	# Section letter signs hung over the aisles
	for pair in [[-21.0, "A-D"], [-15.0, "E-H"], [-9.0, "I-M"],
			[-3.0, "N-R"], [3.0, "S-V"], [9.0, "W-Z"]]:
		var s := Label3D.new()
		s.text = pair[1]
		s.font_size = 44
		s.pixel_size = 0.01
		s.modulate = Color(0.9, 0.8, 0.55)
		s.outline_size = 8
		s.outline_modulate = Color(0, 0, 0)
		s.position = Vector3(pair[0], 3.2, 9.6)
		add_child(s)

# ── the upper gallery: a second tier of shelves ringing the hall ─────────
func _build_gallery() -> void:
	var gy := 4.7   # gallery deck height
	# Back-wall gallery deck (visual second floor)
	_add_box(Vector3(-9.0, gy, -18.0), Vector3(38.0, 0.4, 4.0),
		Color(0.20, 0.15, 0.11), 0.1, 0.6, false)
	# West-wall gallery deck
	_add_box(Vector3(-27.0, gy, -2.0), Vector3(4.0, 0.4, 32.0),
		Color(0.20, 0.15, 0.11), 0.1, 0.6, false)
	# Railings — glowing brass rail posts + top rail
	for x in range(-27, 10, 3):
		_add_box(Vector3(float(x), gy + 0.6, -16.2), Vector3(0.08, 1.1, 0.08),
			Color(0.5, 0.4, 0.2), 0.7, 0.3)
	_add_box(Vector3(-9.0, gy + 1.15, -16.2), Vector3(37.0, 0.08, 0.08),
		Color(0.8, 0.6, 0.3), 0.8, 0.2, true, Color(1.0, 0.8, 0.35), 0.7)
	for z in range(-17, 14, 3):
		_add_box(Vector3(-25.2, gy + 0.6, float(z)), Vector3(0.08, 1.1, 0.08),
			Color(0.5, 0.4, 0.2), 0.7, 0.3)
	_add_box(Vector3(-25.2, gy + 1.15, -2.0), Vector3(0.08, 0.08, 31.0),
		Color(0.8, 0.6, 0.3), 0.8, 0.2, true, Color(1.0, 0.8, 0.35), 0.7)
	# Second-tier shelves against the walls up there
	for x in [-22.0, -14.0, -6.0, 2.0]:
		_add_box(Vector3(x, gy + 1.4, -19.2), Vector3(6.0, 2.6, 0.8),
			Color(0.22, 0.15, 0.10), 0.1, 0.6)
		for i in 13:
			_add_box(Vector3(x - 2.7 + i * 0.44, gy + 1.9, -18.85),
				Vector3(0.32, 0.7, 0.08),
				SPINES[i % SPINES.size()] * 0.7, 0.0, 0.5)
	# Grand staircase up to the gallery (set dressing — the hall reads as
	# two storeys even though the action stays on the ground floor)
	for step in 10:
		var sy := 0.3 + step * 0.44
		_add_box(Vector3(11.0, sy * 0.5, -14.0 + step * 0.6),
			Vector3(3.5, sy, 0.7), Color(0.24, 0.17, 0.11), 0.1, 0.5)
	# RARE BOOKS cage up on the gallery — a locked mesh box, always visible
	_add_box(Vector3(-14.0, gy + 1.6, -17.6), Vector3(4.0, 2.8, 1.2),
		Color(0.10, 0.08, 0.14), 0.3, 0.4, true, Color(0.6, 0.3, 1.1), 0.4)
	var rare := Label3D.new()
	rare.text = "RARE BOOKS"
	rare.font_size = 40
	rare.pixel_size = 0.009
	rare.modulate = Color(0.85, 0.6, 1.2)
	rare.outline_size = 8
	rare.outline_modulate = Color(0, 0, 0)
	rare.position = Vector3(-14.0, gy + 3.3, -17.4)
	add_child(rare)

# ── circulation desk + Laura ─────────────────────────────────────────────
func _build_desk() -> void:
	_add_box(Vector3(20.0, 0.6, -8.0), Vector3(6.0, 1.2, 1.8),
		Color(0.24, 0.17, 0.11), 0.1, 0.5)
	_add_box(Vector3(20.0, 1.25, -8.0), Vector3(6.3, 0.08, 2.1),
		Color(0.12, 0.10, 0.09), 0.5, 0.3)
	# Terminal that runs on "literal magic"
	_add_box(Vector3(18.3, 1.65, -8.1), Vector3(0.9, 0.7, 0.1),
		Color(0.2, 0.6, 0.9) * 0.4, 0.0, 0.4, true, Color(0.3, 0.8, 1.2), 1.2)
	add_npc("res://assets/sprites/cyberGirl.png", Vector3(20.0, 0.9, -9.3), 0)
	add_interact(Vector3(20.0, 1.2, -6.2), Vector3(5.2, 2.4, 2.6),
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
	for spot in [Vector3(14.0, 0, 10.0), Vector3(14.0, 0, 15.0),
			Vector3(19.0, 0, 12.5)]:
		_add_box(spot + Vector3(0, 0.72, 0), Vector3(3.0, 0.1, 1.5),
			Color(0.24, 0.17, 0.11), 0.1, 0.5)
		_add_box(spot + Vector3(0, 0.35, 0), Vector3(0.2, 0.7, 0.2),
			Color(0.15, 0.15, 0.17), 0.6, 0.4)
		# Green banker's lamp
		_add_box(spot + Vector3(0.9, 0.95, 0), Vector3(0.5, 0.18, 0.25),
			Color(0.1, 0.5, 0.25) * 0.5, 0.2, 0.4, true, Color(0.2, 1.1, 0.45), 1.4)
	add_npc("res://assets/sprites/npc-cyberpunk.png", Vector3(16.5, 0.9, 12.5), 2)
	add_interact(Vector3(17.5, 1.2, 12.5), Vector3(2.6, 2.4, 2.4),
		"talk to brian (it guy)", func(): DialogueOverlay.play("brian"))

# ── fiction section ──────────────────────────────────────────────────────
func _build_fiction_shelf() -> void:
	_add_box(Vector3(-27.4, 1.4, 8.0), Vector3(0.9, 2.8, 6.0),
		Color(0.22, 0.15, 0.10), 0.1, 0.6)
	var sign := Label3D.new()
	sign.text = "FICTION"
	sign.font_size = 56
	sign.pixel_size = 0.01
	sign.modulate = Color(0.9, 0.8, 0.6)
	sign.position = Vector3(-26.8, 3.2, 8.0)
	sign.rotation.y = PI / 2.0
	add_child(sign)
	add_interact(Vector3(-26.0, 1.2, 8.0), Vector3(2.4, 2.4, 6.2),
		"browse fiction", func():
			_set_status("paperbacks. someone has dog-eared every single mystery."))

# ── the back alcove: a shelf of old books, one slot empty ───────────────
func _build_alcove_shelf() -> void:
	_add_box(Vector3(-6.0, 1.5, -19.4), Vector3(6.0, 3.0, 0.7),
		Color(0.20, 0.14, 0.09), 0.1, 0.6)
	for i in 12:
		if i == 7:
			continue   # the empty slot
		var bx := -8.6 + i * 0.46
		_add_box(Vector3(bx, 1.9, -19.0), Vector3(0.34, 0.6, 0.1),
			Color(0.35, 0.28, 0.18) * (0.8 + 0.05 * (i % 4)), 0.0, 0.6)
	add_interact(Vector3(-6.0, 1.2, -18.2), Vector3(6.4, 2.4, 2.2),
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
	_add_box(Vector3(-1.5, 1.5, -20.3), Vector3(2.0, 3.0, 0.5),
		Color(0.03, 0.02, 0.05), 0.2, 0.4, true, Color(0.5, 0.2, 1.0), 0.25)
	_add_box(Vector3(-0.85, 1.4, -20.0), Vector3(0.10, 0.22, 0.08),
		Color(0.7, 0.55, 0.2), 0.7, 0.3, true, Color(1.0, 0.8, 0.35), 0.9)   # keyhole plate
	_cellar_glow = DoorGlowScript.new()
	_cellar_glow.color = Color(0.7, 0.35, 1.5)
	_cellar_glow.opening = Vector2(2.0, 3.0)
	_cellar_glow.position = Vector3(-1.5, 0.0, -20.0)
	add_child(_cellar_glow)
	_cellar_glow.set_active(GameState.has_flag("guildDiscovered"))
	add_interact(Vector3(-1.5, 1.2, -19.2), Vector3(2.6, 2.4, 2.0),
		"the cellar door", func():
			if GameState.has_flag("guildDiscovered"):
				SceneTransition.go("mages_guild", "from_library")
			else:
				_set_status("locked. the keyhole is shaped like a book spine."))

# ── SECRET 1: the card catalog — look up a name ──────────────────────────
func _build_card_catalog() -> void:
	var cx := 15.0
	var cz := -3.0
	_add_box(Vector3(cx, 0.7, cz), Vector3(3.0, 1.4, 1.2),
		Color(0.26, 0.18, 0.11), 0.1, 0.5)
	for r in 3:
		for c in 4:
			_add_box(Vector3(cx - 1.2 + c * 0.8, 0.5 + r * 0.4, cz + 0.62),
				Vector3(0.6, 0.3, 0.05), Color(0.18, 0.13, 0.09), 0.2, 0.5)
			_add_box(Vector3(cx - 1.2 + c * 0.8, 0.5 + r * 0.4, cz + 0.66),
				Vector3(0.06, 0.06, 0.02), Color(0.7, 0.6, 0.3), 0.6, 0.3)
	add_interact(Vector3(cx, 1.2, cz + 1.3), Vector3(3.2, 2.4, 1.8),
		"the card catalog", func():
			var cards := [
				"you thumb the drawers. half the cards are handwritten in the same violet ink.",
				"under V: a single card. no title, no author. just a call number that isn't a call number.",
				"under your own name: a card. it predates you moving here. you close the drawer.",
			]
			GameState.set_flag("cardCatalogRead")
			_set_status(cards[randi() % cards.size()]))

# ── SECRET 2: RESTRICTED SECTION — gated nook behind the stacks ──────────
func _build_restricted_section() -> void:
	var rx := -24.0
	var rz := -14.0
	# A caged-off shelf with a chain across it
	_add_box(Vector3(rx, 1.4, rz), Vector3(4.5, 2.8, 0.7),
		Color(0.10, 0.08, 0.12), 0.2, 0.5, true, Color(0.6, 0.15, 0.3), 0.3)
	_add_box(Vector3(rx, 1.1, rz + 0.9), Vector3(4.5, 0.06, 0.06),
		Color(0.5, 0.1, 0.15), 0.3, 0.4, true, Color(1.1, 0.2, 0.3), 0.8)   # chain
	var sign := Label3D.new()
	sign.text = "RESTRICTED"
	sign.font_size = 38
	sign.pixel_size = 0.009
	sign.modulate = Color(1.1, 0.3, 0.4)
	sign.outline_size = 8
	sign.outline_modulate = Color(0, 0, 0)
	sign.position = Vector3(rx, 3.0, rz + 0.2)
	add_child(sign)
	add_interact(Vector3(rx, 1.2, rz + 1.5), Vector3(4.8, 2.4, 2.0),
		"the restricted section", func():
			if GameState.has_flag("guildDiscovered"):
				GameState.set_flag("restrictedRead")
				_set_status("the chain is unlocked now, since Laura let you in. the titles read like threats. one is about a dragon.")
			else:
				_set_status("chained shut. the titles behind the bars are in no alphabet you know."))

# ── SECRET 3: a hidden compartment behind a glowing spine ────────────────
func _build_hidden_compartment() -> void:
	# One book on the -12 stack glows faintly wrong — pull it once for a stash
	var gx := -12.55
	var gz := 2.0
	_add_box(Vector3(gx, 1.65, gz), Vector3(0.08, 0.5, 0.32),
		Color(0.4, 0.2, 0.6), 0.0, 0.4, true, Color(0.7, 0.35, 1.2), 0.9)
	add_interact(Vector3(gx - 0.6, 1.4, gz), Vector3(1.6, 2.0, 1.4),
		"a book shelved spine-in", func():
			if GameState.has_flag("libraryStashFound"):
				_set_status("the hollow behind the shelf is empty now. just dust and a ring where a tin sat.")
				return
			GameState.set_flag("libraryStashFound")
			GameState.add_credits(250)
			DialogueOverlay.play_lines([
				{ "speaker": "", "text": "the spine is fake. it hinges. behind it: a hollow in the shelf.", "color": Color(0.8, 0.6, 1.0) },
				{ "speaker": "", "text": "a tin of 250 credits and a note: 'for whoever finally reads this far. - B'", "color": Color(0.6, 0.9, 0.6) },
			], "library_stash"))

func _build_people() -> void:
	# Patrons scattered through the huge hall, and the library cat on the desk
	add_npc("res://assets/sprites/civ/civ-a07.png", Vector3(-9.0, 0.9, 4.0), 1)
	add_npc("res://assets/sprites/civ/civ-b03.png", Vector3(-3.0, 0.9, -8.0), 3)
	add_npc("res://assets/sprites/civ/civ-a10.png", Vector3(2.0, 0.9, 6.0), 0)
	add_npc("res://assets/sprites/whiteCat.png", Vector3(22.4, 1.45, -8.0), 1)

func _build_lamps() -> void:
	# Two tiers of hanging lamps — ground aisles + gallery
	for spot in [Vector3(-16.0, 4.2, 0.0), Vector3(-4.0, 4.2, 0.0),
			Vector3(8.0, 4.2, 0.0), Vector3(18.0, 4.0, 4.0),
			Vector3(-20.0, 7.6, -16.0), Vector3(-6.0, 7.6, -16.0)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.85, 0.6)
		lamp.light_energy = 1.6
		lamp.omni_range = 14.0
		lamp.position = spot
		add_child(lamp)
		_add_box(spot + Vector3(0, 0.3, 0), Vector3(0.7, 0.25, 0.7),
			Color(0.12, 0.10, 0.08), 0.3, 0.5, true, Color(1.0, 0.75, 0.45), 1.0)
	# A cool shaft of light from a high window over the stacks
	var shaft := OmniLight3D.new()
	shaft.light_color = Color(0.5, 0.6, 0.9)
	shaft.light_energy = 1.2
	shaft.omni_range = 22.0
	shaft.position = Vector3(-10.0, 8.5, -8.0)
	add_child(shaft)
