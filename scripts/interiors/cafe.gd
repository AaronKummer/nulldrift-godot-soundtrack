## CAFE — coffee, wifi, and a bulletin board of the city's finest chaos.
## If you matched with Kerry on the dating app, she's waiting at the
## window table. The date is canon (ported from the Phaser CafeScene).
extends "res://scripts/interiors/interior_base.gd"

const COFFEE_COST := 8

func _ready() -> void:
	room_w = 20.0
	room_d = 14.0
	interior_name = "CAFE"
	exit_scene = "street_downtown"
	exit_spawn = "from_cafe"
	super._ready()
	Music.play_category("apartment")

func _ambient() -> Color:
	return Color(0.34, 0.29, 0.22)

func _floor_color() -> Color:
	return Color(0.18, 0.14, 0.10)

func _build_interior() -> void:
	# Counter + espresso machine
	_add_box(Vector3(-4.0, 0.6, -4.5), Vector3(7.0, 1.2, 1.4),
		Color(0.26, 0.19, 0.12), 0.1, 0.5)
	_add_box(Vector3(-5.5, 1.6, -4.8), Vector3(1.4, 0.8, 0.9),
		Color(0.5, 0.5, 0.55), 0.8, 0.3)
	_add_box(Vector3(-5.5, 1.35, -4.3), Vector3(0.5, 0.2, 0.2),
		Color(1.0, 0.7, 0.3) * 0.5, 0.0, 0.5, true, Color(1.2, 0.8, 0.35), 1.2)
	# Pastry case
	_add_box(Vector3(-1.5, 1.4, -4.5), Vector3(1.8, 0.5, 1.0),
		Color(0.5, 0.7, 0.8, 0.3), 0.6, 0.1)
	for i in 3:
		_add_box(Vector3(-2.1 + i * 0.6, 1.32, -4.5), Vector3(0.4, 0.2, 0.5),
			[Color(0.8, 0.6, 0.35), Color(0.7, 0.4, 0.25), Color(0.85, 0.75, 0.6)][i],
			0.0, 0.6)
	# Barista
	add_npc("res://assets/sprites/npc-cyberpunk.png", Vector3(-4.0, 0.9, -5.6), 0)
	add_interact(Vector3(-4.0, 1.2, -3.0), Vector3(6.5, 2.4, 2.0),
		"coffee · %dcr" % COFFEE_COST, _buy_coffee)
	# Tables
	for spot in [Vector3(-5.0, 0, 2.5), Vector3(0.5, 0, 3.5)]:
		_add_box(spot + Vector3(0, 0.7, 0), Vector3(1.6, 0.08, 1.6),
			Color(0.24, 0.18, 0.12), 0.1, 0.5)
		_add_box(spot + Vector3(0, 0.35, 0), Vector3(0.16, 0.7, 0.16),
			Color(0.15, 0.15, 0.17), 0.6, 0.4)
	# A laptop nomad who never leaves
	add_npc("res://assets/sprites/npc-corpo.png", Vector3(0.5, 0.9, 2.8), 0)
	# Bulletin board — canon chaos
	_add_box(Vector3(4.0, 2.0, -6.4), Vector3(3.4, 2.2, 0.15),
		Color(0.35, 0.24, 0.14), 0.0, 0.8)
	for i in 5:
		_add_box(Vector3(2.9 + (i % 3) * 1.1, 2.4 - (i / 3) * 0.9, -6.30),
			Vector3(0.7, 0.6, 0.03),
			[Color(0.9, 0.9, 0.8), Color(0.8, 0.9, 0.7), Color(0.95, 0.8, 0.75)][i % 3],
			0.0, 0.9)
	add_interact(Vector3(4.0, 1.2, -5.2), Vector3(3.8, 2.4, 2.0),
		"the bulletin board", func(): DialogueOverlay.play("bulletin_board"))
	# Warm hanging lights
	for spot in [Vector3(-3.0, 3.0, -1.0), Vector3(3.0, 3.0, 1.5)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.8, 0.55)
		lamp.light_energy = 1.5
		lamp.omni_range = 9.0
		lamp.shadow_enabled = true
		lamp.position = spot
		add_child(lamp)
	# Kerry at the window table, if you matched and haven't had the date
	if GameState.has_flag("kerryMatched") and not GameState.has_flag("kerryDated"):
		_add_box(Vector3(6.5, 0.7, 3.0), Vector3(1.6, 0.08, 1.6),
			Color(0.24, 0.18, 0.12), 0.1, 0.5)
		_add_box(Vector3(6.5, 0.35, 3.0), Vector3(0.16, 0.7, 0.16),
			Color(0.15, 0.15, 0.17), 0.6, 0.4)
		# Two cups. She got you one already.
		_add_box(Vector3(6.2, 0.82, 2.8), Vector3(0.15, 0.18, 0.15),
			Color(0.9, 0.88, 0.85), 0.0, 0.5)
		_add_box(Vector3(6.8, 0.82, 3.2), Vector3(0.15, 0.18, 0.15),
			Color(0.9, 0.88, 0.85), 0.0, 0.5)
		add_npc("res://assets/sprites/player-hacker.png", Vector3(7.4, 0.9, 3.0), 1)
		add_interact(Vector3(5.6, 1.2, 3.0), Vector3(2.6, 2.4, 3.0),
			"kerry · your match", _kerry_date)
	elif GameState.has_flag("kerryDated"):
		_set_status("the window table is 'your' table now. kerry texted: 'same time thursday.'")

func _buy_coffee() -> void:
	if GameState.credits < COFFEE_COST:
		_set_status("barista: 'we take credits, tears, or art. you got any art?'")
		return
	GameState.add_credits(-COFFEE_COST)
	GameState.hp = mini(GameState.hp + 10, GameState.hp_max)
	_set_status("synthetic oat-foam flat white. it's perfect and you hate that. +10 HP")

func _kerry_date() -> void:
	GameState.set_flag("kerryDated")
	DialogueOverlay.play("kerry_date")
