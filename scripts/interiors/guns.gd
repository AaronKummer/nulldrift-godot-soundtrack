## GUNS+ — the home-street weapons dealer, now a walk-in interior instead
## of a doorway popup. Racks on the wall, a dealer at the counter, and a
## categorized shop: MELEE / BALLISTIC / ENERGY / MISC / AMMO. Prices and
## stats come straight from data/equipment.gd; the exotic god-tier is
## reserved for PLATINUM ARMS (financial district) via a price cap.
extends "res://scripts/interiors/interior_base.gd"

const ListMenuScript := preload("res://scripts/systems/list_menu.gd")
const Equip := preload("res://data/equipment.gd")

const PRICE_CAP := 60000   # anything dearer is Platinum Arms' business

const CONSUMABLES := {
	"medkit":   { "name": "MEDKIT",   "price": 40 },
	"stim":     { "name": "STIM",     "price": 50 },
	"grenade":  { "name": "GRENADE",  "price": 60 },
	"headlamp": { "name": "HEADLAMP", "price": 120 },
}
const AMMO := [
	{ "id": "ballistic", "name": "9MM ROUNDS x30", "price": 60, "amount": 30 },
	{ "id": "energy",    "name": "ENERGY CELLS x20", "price": 120, "amount": 20 },
]

var _menu
var _rows: Array = []   # parallel to menu entries: action dicts

func _ready() -> void:
	room_w = 28.0
	room_d = 18.0
	interior_name = "GUNS+"
	exit_scene = "city"
	exit_spawn = "from_guns"
	super._ready()
	Music.play_category("shops")

func _ambient() -> Color:
	return Color(0.22, 0.20, 0.24)

func _floor_color() -> Color:
	return Color(0.12, 0.11, 0.12)

func _build_interior() -> void:
	_build_weapon_wall()
	_build_counter_and_dealer()
	_build_lamps()

# ── weapon racks on the back wall ────────────────────────────────────────
func _build_weapon_wall() -> void:
	var wz := -room_d / 2.0 + 0.9
	for i in 3:
		var rx := -8.0 + i * 6.0
		_add_box(Vector3(rx, 2.2, wz), Vector3(5.2, 2.6, 0.4),
			Color(0.10, 0.09, 0.11), 0.3, 0.5)
		# Mounted weapon silhouettes — angled bars + glowing sights
		for j in 4:
			var wy := 1.3 + j * 0.55
			var col: Color = [Color(0.5, 0.55, 0.65), Color(1.0, 0.4, 0.3),
				Color(0.4, 0.9, 1.1), Color(1.0, 0.8, 0.35)][j]
			_add_box(Vector3(rx - 1.6 + (j % 2) * 3.0, wy, wz + 0.24),
				Vector3(2.2, 0.16, 0.06),
				col * Color(0.4, 0.4, 0.4, 1.0), 0.6, 0.3, true, col, 0.8)
	var sign := Label3D.new()
	sign.text = "GUNS+"
	sign.font_size = 120
	sign.pixel_size = 0.012
	sign.modulate = Color(1.4, 0.35, 0.3)
	sign.outline_size = 16
	sign.outline_modulate = Color(0, 0, 0)
	sign.position = Vector3(0, 3.7, wz + 0.3)
	add_child(sign)

func _build_counter_and_dealer() -> void:
	var cz := 3.0
	_add_box(Vector3(0, 0.6, cz), Vector3(9.0, 1.2, 1.6),
		Color(0.16, 0.13, 0.14), 0.2, 0.5)
	_add_box(Vector3(0, 1.25, cz), Vector3(9.4, 0.08, 1.9),
		Color(0.09, 0.09, 0.10), 0.6, 0.3)
	# Glass display case glow
	_add_box(Vector3(0, 0.75, cz + 0.2), Vector3(8.4, 0.5, 0.05),
		Color(0.2, 0.5, 0.7) * 0.3, 0.0, 0.2, true, Color(0.3, 0.7, 1.0), 0.7)
	# The dealer (a tough thug sheet), behind the counter
	add_npc("res://assets/sprites/npc-thug.png", Vector3(0, 0.9, cz - 1.3), 0)
	add_interact(Vector3(0, 1.2, cz + 1.6), Vector3(8.0, 2.4, 2.6),
		"browse the arsenal", _open_categories)

func _build_lamps() -> void:
	for spot in [Vector3(-6.0, 3.6, 0.0), Vector3(6.0, 3.6, 1.5)]:
		_add_box(spot, Vector3(0.5, 0.15, 0.5),
			Color(0.9, 0.6, 0.5), 0.0, 0.4, true, Color(1.0, 0.55, 0.45), 1.2)
		var l := OmniLight3D.new()
		l.position = spot - Vector3(0, 0.4, 0)
		l.light_color = Color(1.0, 0.7, 0.6)
		l.light_energy = 1.7
		l.omni_range = 9.0
		add_child(l)

# ── the categorized shop ─────────────────────────────────────────────────
func _open_categories() -> void:
	_menu_open = true
	if _menu == null:
		_menu = ListMenuScript.new()
		add_child(_menu)
		_menu.picked.connect(_on_pick)
		_menu.closed.connect(func():
			_menu_open = false
			_menu = null)
	_rows = [
		{ "act": "talk" },
		{ "act": "cat", "cat": "MELEE" },
		{ "act": "cat", "cat": "BALLISTIC" },
		{ "act": "cat", "cat": "ENERGY" },
		{ "act": "cat", "cat": "MISC" },
		{ "act": "cat", "cat": "AMMO" },
	]
	var entries := [{ "label": "talk to the dealer" }]
	for c in ["MELEE", "BALLISTIC", "ENERGY", "MISC", "AMMO"]:
		entries.append({ "label": c + "  ▸" })
	_menu.open("GUNS+ · street hardware", entries, Color(1.0, 0.4, 0.35),
		"credits: $%d" % GameState.credits)

func _open_category(cat: String) -> void:
	_rows = [{ "act": "back" }]
	var entries := [{ "label": "‹ back" }]
	for row in _category_items(cat):
		_rows.append(row)
		entries.append({ "label": row.label, "dim": row.get("dim", false) })
	_menu.refresh(entries, "credits: $%d" % GameState.credits)

## Build {id, label, buy, dim} rows for a category
func _category_items(cat: String) -> Array:
	var out: Array = []
	if cat == "AMMO":
		for a in AMMO:
			out.append({ "act": "ammo", "id": a.id, "amount": a.amount, "price": a.price,
				"label": "%s · %d cr" % [a.name, a.price] })
		return out
	if cat == "MISC":
		for gid in Equip.GEAR:
			var g: Dictionary = Equip.GEAR[gid]
			if not g.has("price"):
				continue
			var owned: bool = GameState.has_item(gid)
			out.append({ "act": "gear", "id": gid, "price": g.price,
				"label": ("%s · OWNED" % g.name) if owned
					else "%s · %d cr" % [g.name, g.price], "dim": owned })
		for cid in CONSUMABLES:
			var c: Dictionary = CONSUMABLES[cid]
			var owned2: bool = cid == "headlamp" and GameState.has_item("headlamp")
			out.append({ "act": "consumable", "id": cid, "price": c.price,
				"label": ("%s · OWNED" % c.name) if owned2
					else "%s · %d cr" % [c.name, c.price], "dim": owned2 })
		return out
	# Weapon categories
	for wid in Equip.WEAPONS:
		var w: Dictionary = Equip.WEAPONS[wid]
		if not w.has("price") or int(w.price) > PRICE_CAP:
			continue
		var slot: String = ""
		if w.type == "melee":
			slot = "MELEE"
		else:
			slot = "ENERGY" if Equip.ammo_type(wid) == "energy" else "BALLISTIC"
		if slot != cat:
			continue
		var owned3: bool = GameState.has_item(wid)
		var stat := "dmg %d · spd %dms" % [w.damage, w.speed]
		out.append({ "act": "weapon", "id": wid, "price": w.price,
			"label": ("%s · OWNED" % w.name) if owned3
				else "%s · %d cr (%s)" % [w.name, w.price, stat], "dim": owned3 })
	return out

func _on_pick(idx: int) -> void:
	if idx < 0 or idx >= _rows.size():
		return
	var row: Dictionary = _rows[idx]
	match row.act:
		"talk":
			if _menu:
				_menu.close_menu()
			DialogueOverlay.play_lines([
				{ "speaker": "DEALER", "text": "everything on the wall is legal. mostly. depends on the wall.", "color": Color(1.0, 0.6, 0.5) },
				{ "speaker": "DEALER", "text": "melee never runs dry. guns need rounds — grab ammo before you go under.", "color": Color(1.0, 0.6, 0.5) },
			], "guns_dealer")
		"cat":
			_open_category(row.cat)
		"back":
			_open_categories()
		"weapon", "gear":
			_buy_item(row)
		"consumable":
			_buy_consumable(row)
		"ammo":
			_buy_ammo(row)

func _buy_item(row: Dictionary) -> void:
	if GameState.has_item(row.id):
		_menu.set_footer("dealer: 'you're holding one already.'")
		return
	if GameState.credits < int(row.price):
		_menu.set_footer("dealer: 'come back with real money.'")
		return
	GameState.add_credits(-int(row.price))
	GameState.add_item(row.id)
	_reopen_current(row)
	_menu.set_footer("bought. equip it in the phone GEAR app.")

func _buy_consumable(row: Dictionary) -> void:
	if row.id == "headlamp" and GameState.has_item("headlamp"):
		_menu.set_footer("dealer: 'one head, one lamp.'")
		return
	if GameState.credits < int(row.price):
		_menu.set_footer("dealer: 'no credits, no gear.'")
		return
	GameState.add_credits(-int(row.price))
	GameState.add_item(row.id)
	_reopen_current(row)
	_menu.set_footer("%s bought." % row.id)

func _buy_ammo(row: Dictionary) -> void:
	if GameState.credits < int(row.price):
		_menu.set_footer("dealer: 'no credits, no rounds.'")
		return
	GameState.add_credits(-int(row.price))
	GameState.add_ammo(row.id, int(row.amount))
	_menu.set_footer("+%d %s to reserve." % [row.amount, row.id])

## Rebuild the current category list so OWNED/credits update after a buy
func _reopen_current(row: Dictionary) -> void:
	var cat := "MISC"
	match row.act:
		"weapon":
			cat = "MELEE" if Equip.WEAPONS[row.id].type == "melee" \
				else ("ENERGY" if Equip.ammo_type(row.id) == "energy" else "BALLISTIC")
		_:
			cat = "MISC"
	_open_category(cat)
