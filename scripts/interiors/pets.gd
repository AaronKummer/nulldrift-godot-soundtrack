## PAWS+ — the home-street pet store, upgraded from a doorway transaction
## to a real interior. Tank wall, terrarium shelves, live animals, and Gus
## behind the counter selling the canon Phaser roster (fish food + eight
## pets). Owned pets appear in the player's apartment (apartment.gd reads
## the same item ids).
extends "res://scripts/interiors/interior_base.gd"

const ListMenuScript := preload("res://scripts/systems/list_menu.gd")

# The Phaser itemDatabase petshop roster, prices canon
const STOCK := [
	{ "id": "fish_food",  "name": "FISH FOOD",  "price": 5,
	  "desc": "keep your fish happy" },
	{ "id": "nano_fish",  "name": "NANO FISH",  "price": 500,
	  "desc": "a fourth fish for your tank" },
	{ "id": "mutant_rat", "name": "MUTANT RAT", "price": 650,
	  "desc": "ugly, loyal, hard to kill" },
	{ "id": "glow_gecko", "name": "GLOW GECKO", "price": 900,
	  "desc": "lights dark spaces" },
	{ "id": "cyber_cat",  "name": "CYBER CAT",  "price": 1500,
	  "desc": "detects enemies. ignores you" },
	{ "id": "splice_cat", "name": "SPLICE CAT", "price": 1800,
	  "desc": "a gene-hacked hunter" },
	{ "id": "drone_bird", "name": "DRONE BIRD", "price": 2000,
	  "desc": "scouts ahead" },
	{ "id": "bio_drone",  "name": "BIO DRONE",  "price": 2400,
	  "desc": "organic scout drone" },
	{ "id": "robo_dog",   "name": "ROBO DOG",   "price": 3000,
	  "desc": "combat buddy" },
]

var _shop_menu

func _ready() -> void:
	room_w = 26.0
	room_d = 18.0
	interior_name = "PAWS+"
	exit_scene = "city"
	exit_spawn = "from_pet"
	super._ready()
	Music.play_category("shops")

func _ambient() -> Color:
	return Color(0.22, 0.30, 0.26)

func _floor_color() -> Color:
	return Color(0.11, 0.13, 0.12)

func _build_interior() -> void:
	_build_tank_wall()
	_build_terrarium_shelves()
	_build_counter_and_gus()
	_build_floor_stock()
	_build_lamps()

# ── aquarium wall along the back — the store's signature glow ────────────
func _build_tank_wall() -> void:
	var wz := -room_d / 2.0 + 1.0
	var fish_colors := [Color(1.0, 0.55, 0.10), Color(0.4, 0.85, 1.0),
		Color(0.95, 0.30, 0.80), Color(0.4, 1.0, 0.5)]
	for i in 3:
		var tx := -8.0 + i * 6.0
		# Stand + water + hood, same language as the apartment tank
		_add_box(Vector3(tx, 0.55, wz), Vector3(3.4, 1.1, 1.0),
			Color(0.10, 0.08, 0.06), 0.0, 0.8)
		_add_box(Vector3(tx, 1.65, wz), Vector3(3.2, 1.0, 0.9),
			Color(0.08, 0.30, 0.34), 0.2, 0.2, true,
			Color(0.15, 0.55, 0.60), 1.3)
		_add_box(Vector3(tx, 2.22, wz), Vector3(3.3, 0.10, 1.0),
			Color(0.6, 0.5, 0.28), 0.0, 0.4, true, Color(1.0, 0.85, 0.5), 1.4)
		# Fish silhouettes
		for f in 3:
			_add_box(Vector3(tx - 1.0 + f * 0.9, 1.45 + (f % 2) * 0.35, wz + 0.1),
				Vector3(0.22, 0.12, 0.06),
				fish_colors[(i + f) % fish_colors.size()] * Color(0.4, 0.4, 0.4, 1.0),
				0.0, 0.4, true, fish_colors[(i + f) % fish_colors.size()], 1.3)
		# Cyan spill
		var tl := OmniLight3D.new()
		tl.position = Vector3(tx, 1.8, wz + 1.2)
		tl.light_color = Color(0.35, 0.8, 0.9)
		tl.light_energy = 1.3
		tl.omni_range = 4.0
		tl.omni_attenuation = 1.8
		add_child(tl)

# ── terrarium shelves on the west wall ───────────────────────────────────
func _build_terrarium_shelves() -> void:
	var wx := -room_w / 2.0 + 1.0
	for i in 2:
		var sy := 0.9 + i * 1.3
		_add_box(Vector3(wx, sy, 0.0), Vector3(1.2, 0.08, 9.0),
			Color(0.16, 0.12, 0.09), 0.1, 0.7)
	# Glow gecko terrarium — green, don't ask
	_add_box(Vector3(wx, 1.35, -2.8), Vector3(1.0, 0.8, 1.6),
		Color(0.05, 0.20, 0.10), 0.2, 0.3, true, Color(0.2, 1.2, 0.4), 1.6)
	# Mutant rat cage — the rat is real, and it sits ON the cage. the cage
	# is more of a suggestion
	_add_box(Vector3(wx, 1.35, 0.6), Vector3(1.0, 0.8, 1.6),
		Color(0.12, 0.10, 0.08), 0.4, 0.5)
	var rat := add_npc("res://assets/sprites/sewerRat.png", Vector3(wx + 0.2, 2.0, 0.6), 1)
	rat.scale = Vector3(0.8, 0.8, 0.8)
	# Heat lamp over the top shelf
	_add_box(Vector3(wx, 2.75, 2.9), Vector3(0.9, 0.10, 0.9),
		Color(0.5, 0.2, 0.1), 0.0, 0.4, true, Color(1.3, 0.4, 0.15), 2.0)

# ── counter, Gus, and the shop cat ───────────────────────────────────────
func _build_counter_and_gus() -> void:
	var cz := 4.5
	var cx := 5.5
	_add_box(Vector3(cx, 0.55, cz), Vector3(7.0, 1.1, 1.3),
		Color(0.16, 0.13, 0.10), 0.1, 0.6)
	_add_box(Vector3(cx, 1.12, cz), Vector3(7.4, 0.08, 1.6),
		Color(0.09, 0.09, 0.10), 0.6, 0.3)
	# Register — little green screen
	_add_box(Vector3(cx - 2.4, 1.42, cz), Vector3(0.5, 0.5, 0.35),
		Color(0.06, 0.07, 0.06), 0.3, 0.4, true, Color(0.2, 1.0, 0.4), 1.2)
	# Gus behind the counter (south side, facing the room) — civ-a01, the
	# grey-haired working man (a05 is a green-haired woman; audited)
	add_npc("res://assets/sprites/civ/civ-a01.png", Vector3(cx, 0.9, cz + 1.4), 3)
	# The shop cat owns the counter
	add_npc("res://assets/sprites/whiteCat.png", Vector3(cx + 2.6, 1.45, cz), 1,
		Color(0.85, 0.95, 1.1))
	add_interact(Vector3(cx, 1.2, cz - 1.4), Vector3(6.0, 2.4, 2.4),
		"talk to gus / browse the animals", _open_shop_menu)

# ── floor stock: robo dog demo unit + drone bird perch ───────────────────
func _build_floor_stock() -> void:
	# ROBO DOG demo — boxy hound, glowing eyes, slightly menacing tail
	var dx := -3.5
	var dz := 3.0
	_add_box(Vector3(dx, 0.55, dz), Vector3(1.3, 0.6, 0.6),
		Color(0.25, 0.26, 0.30), 0.8, 0.3)
	_add_box(Vector3(dx + 0.75, 0.85, dz), Vector3(0.5, 0.4, 0.45),
		Color(0.22, 0.23, 0.27), 0.8, 0.3)
	for ez in [-0.12, 0.12]:
		_add_box(Vector3(dx + 1.02, 0.90, dz + ez), Vector3(0.03, 0.06, 0.06),
			Color(1.0, 0.2, 0.1), 0.0, 0.3, true, Color(1.5, 0.25, 0.1), 2.5)
	for lx in [-0.45, 0.45]:
		for lz in [-0.2, 0.2]:
			_add_box(Vector3(dx + lx, 0.15, dz + lz), Vector3(0.14, 0.35, 0.14),
				Color(0.18, 0.19, 0.22), 0.8, 0.4)
	# Drone bird perch — it hovers, wings out
	var px := 1.5
	var pz := -1.5
	_add_box(Vector3(px, 0.9, pz), Vector3(0.10, 1.8, 0.10),
		Color(0.15, 0.15, 0.17), 0.7, 0.4)
	_add_box(Vector3(px, 1.85, pz), Vector3(0.7, 0.05, 0.12),
		Color(0.16, 0.13, 0.09), 0.1, 0.7)
	var bird := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 0.22, 0.2)
	bird.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.15, 0.3, 0.25)
	bmat.emission_enabled = true
	bmat.emission = Color(0.3, 1.0, 0.7)
	bmat.emission_energy_multiplier = 1.0
	bird.material_override = bmat
	bird.position = Vector3(px, 2.25, pz)
	add_child(bird)
	var tw := create_tween().set_loops()
	tw.tween_property(bird, "position:y", 2.45, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bird, "position:y", 2.25, 1.1).set_trans(Tween.TRANS_SINE)

func _build_lamps() -> void:
	for spot in [Vector3(-4.0, 3.6, 0.0), Vector3(5.0, 3.6, 3.0)]:
		_add_box(spot, Vector3(0.5, 0.15, 0.5),
			Color(0.9, 0.85, 0.7), 0.0, 0.4, true, Color(1.0, 0.9, 0.7), 1.5)
		var l := OmniLight3D.new()
		l.position = spot - Vector3(0, 0.4, 0)
		l.light_color = Color(1.0, 0.92, 0.75)
		l.light_energy = 1.8
		l.omni_range = 9.0
		l.omni_attenuation = 1.3
		add_child(l)

# ── the shop ─────────────────────────────────────────────────────────────
func _open_shop_menu() -> void:
	_menu_open = true
	_shop_menu = ListMenuScript.new()
	add_child(_shop_menu)
	var entries: Array = [{ "label": "talk to gus", "dim": false }]
	var first_food: bool = not GameState.has_item("fish_food") \
			and not GameState.has_flag("petshopFreebie")
	for it in STOCK:
		var owned: bool = it.id != "fish_food" and GameState.has_item(it.id)
		var label: String
		if owned:
			label = "%s · sold" % it.name
		elif it.id == "fish_food" and first_food:
			label = "%s · on the house" % it.name
		else:
			label = "%s · %d cr — %s" % [it.name, it.price, it.desc]
		entries.append({ "label": label, "dim": owned })
	_shop_menu.picked.connect(_on_shop_pick)
	_shop_menu.closed.connect(func():
		_menu_open = false
		_shop_menu = null)
	_shop_menu.open("PAWS+ · gus is watching", entries, Color(0.55, 0.95, 0.6),
		"credits: $%d" % GameState.credits)

func _on_shop_pick(idx: int) -> void:
	if idx == 0:
		if _shop_menu:
			_shop_menu.close_menu()
		DialogueOverlay.play("gus")
		return
	var it: Dictionary = STOCK[idx - 1]
	if it.id != "fish_food" and GameState.has_item(it.id):
		_shop_menu.set_footer("gus: 'you already got one. they get jealous.'")
		return
	# First fish food is free — Gus keeps the tutorial kindness
	if it.id == "fish_food" and not GameState.has_item("fish_food") \
			and not GameState.has_flag("petshopFreebie"):
		GameState.set_flag("petshopFreebie")
		GameState.add_item("fish_food")
		_shop_menu.set_footer("gus: 'on the house. now go feed your damn fish.'")
		return
	if GameState.credits < it.price:
		_shop_menu.set_footer("gus: 'register says no.'")
		return
	GameState.add_credits(-it.price)
	GameState.add_item(it.id)
	var bark: String
	match it.id:
		"fish_food":
			bark = "gus: 'feed your damn fish.'"
		"robo_dog":
			bark = "gus: 'no refunds. it remembers faces.'"
		"glow_gecko":
			bark = "gus: 'told you not to ask. enjoy.'"
		_:
			bark = "gus: 'it'll find its own way to your place. they always do.'"
	# Rebuild the menu so the row shows sold, then land the bark on it
	if _shop_menu:
		_shop_menu.close_menu()
	_open_shop_menu()
	if _shop_menu:
		_shop_menu.set_footer(bark)
