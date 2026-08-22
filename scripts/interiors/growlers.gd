## GROWLERS — the open-air bar on the sand. Andy works the taps; his stool
## is the one nobody sits on. Cheap cold drinks that heal. Exits to the beach.
extends "res://scripts/interiors/interior_base.gd"

const ListMenuScript := preload("res://scripts/systems/list_menu.gd")

const DRINKS := [
	{ "name": "COLD ONE", "price": 6, "heal": 8,
	  "bark": "andy cracks it on the counter edge. classic." },
	{ "name": "SALT & RUST IPA", "price": 12, "heal": 18,
	  "bark": "tastes like the pier smells. in a good way. mostly." },
	{ "name": "THE GROWLER", "price": 22, "heal": 36,
	  "bark": "a full growler. andy raises an eyebrow. respect." },
]

var _menu

func _ready() -> void:
	room_w = 26.0
	room_d = 16.0
	interior_name = "GROWLERS"
	exit_scene = "beach"
	exit_spawn = "from_growlers"
	super._ready()
	Music.play_category("shops")

func _ambient() -> Color:
	return Color(0.22, 0.24, 0.28)

func _floor_color() -> Color:
	return Color(0.16, 0.13, 0.09)   # boardwalk planks

func _build_interior() -> void:
	_build_bar_and_andy()
	_build_deck()

func _build_bar_and_andy() -> void:
	var cz := -5.0
	_add_box(Vector3(0, 0.6, cz), Vector3(11.0, 1.2, 1.4),
		Color(0.24, 0.16, 0.10), 0.1, 0.5)
	_add_box(Vector3(0, 1.14, cz), Vector3(11.4, 0.08, 1.7),
		Color(0.12, 0.10, 0.08), 0.5, 0.3)
	# Tap tower
	_add_box(Vector3(-3.0, 1.5, cz), Vector3(0.5, 0.7, 0.3),
		Color(0.6, 0.6, 0.65), 0.8, 0.2, true, Color(0.9, 0.9, 1.0), 0.3)
	# Warm string of bulbs over the bar
	for i in 8:
		_add_box(Vector3(-4.5 + i * 1.3, 2.6, cz + 0.4), Vector3(0.12, 0.12, 0.12),
			Color(1.0, 0.8, 0.4), 0.0, 0.3, true, Color(1.0, 0.8, 0.4), 2.0)
	# Andy behind the taps + his reserved stool
	add_npc("res://assets/sprites/npc-corpo.png", Vector3(0, 0.9, cz - 1.2), 0,
		Color(1.1, 0.9, 0.7))
	_add_box(Vector3(4.5, 0.55, cz + 1.9), Vector3(0.6, 0.9, 0.6),
		Color(0.3, 0.2, 0.12), 0.2, 0.5)   # Andy's stool
	add_interact(Vector3(0, 1.2, cz + 1.7), Vector3(7.0, 2.4, 2.4),
		"talk to andy / order a drink", _open_menu)

func _build_deck() -> void:
	# Open railing looking out at the water (the beach beyond)
	_add_box(Vector3(0, 0.9, room_d / 2.0 - 1.0), Vector3(room_w - 2.0, 0.1, 0.15),
		Color(0.3, 0.6, 0.7), 0.4, 0.3, true, Color(0.3, 0.9, 1.0), 0.8)
	for spot in [Vector3(-6.0, 3.4, 0.0), Vector3(6.0, 3.4, 2.0)]:
		var l := OmniLight3D.new()
		l.position = spot
		l.light_color = Color(1.0, 0.8, 0.5)
		l.light_energy = 1.5
		l.omni_range = 9.0
		add_child(l)

func _open_menu() -> void:
	_menu_open = true
	_menu = ListMenuScript.new()
	add_child(_menu)
	var entries: Array = [{ "label": "talk to andy" }]
	for d in DRINKS:
		entries.append({ "label": "%s · %d cr (+%d hp)" % [d.name, d.price, d.heal] })
	_menu.picked.connect(_on_pick)
	_menu.closed.connect(func():
		_menu_open = false
		_menu = null)
	_menu.open("GROWLERS · on the sand", entries, Color(1.0, 0.7, 0.4),
		"credits: $%d · hp: %d/%d" % [GameState.credits, GameState.hp, GameState.hp_max])

func _on_pick(idx: int) -> void:
	if idx == 0:
		if _menu:
			_menu.close_menu()
		DialogueOverlay.play("andy")
		return
	var d: Dictionary = DRINKS[idx - 1]
	if GameState.credits < d.price:
		_menu.set_footer("andy: 'tab's cash only, and empty.'")
		return
	if GameState.hp >= GameState.hp_max:
		_menu.set_footer("andy: 'you're fine. drink for fun, not first aid.'")
		return
	GameState.add_credits(-d.price)
	GameState.hp = mini(GameState.hp_max, GameState.hp + d.heal)
	_menu.set_footer(d.bark)
