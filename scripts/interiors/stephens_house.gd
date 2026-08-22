## STEPHEN'S HOUSE — the crew's beach-house party pad. Stephen holds court,
## there's a bar, loud speakers, string lights. Exits back to the beach.
extends "res://scripts/interiors/interior_base.gd"

func _ready() -> void:
	room_w = 26.0
	room_d = 18.0
	interior_name = "STEPHEN'S PLACE"
	exit_scene = "beach"
	exit_spawn = "from_stephens"
	super._ready()
	Music.play_category("live_band")

func _ambient() -> Color:
	return Color(0.28, 0.20, 0.30)

func _floor_color() -> Color:
	return Color(0.14, 0.10, 0.13)

func _build_interior() -> void:
	_build_bar()
	_build_speakers()
	_build_string_lights()
	_build_people()

func _build_bar() -> void:
	var cz := -5.5
	_add_box(Vector3(6.0, 0.6, cz), Vector3(8.0, 1.2, 1.4),
		Color(0.20, 0.13, 0.10), 0.1, 0.5)
	_add_box(Vector3(6.0, 1.14, cz), Vector3(8.3, 0.08, 1.7),
		Color(0.10, 0.09, 0.10), 0.6, 0.25)
	# Bottle shelf glow
	_add_box(Vector3(6.0, 1.9, cz - 0.6), Vector3(7.0, 1.2, 0.3),
		Color(0.3, 0.15, 0.35) * 0.4, 0.0, 0.4, true, Color(0.9, 0.4, 1.0), 0.9)
	add_npc("res://assets/sprites/civ/civ-b08.png", Vector3(6.0, 0.9, cz - 1.2), 0)
	add_interact(Vector3(6.0, 1.2, cz + 1.6), Vector3(6.0, 2.4, 2.4),
		"grab a drink (+15 hp)", func():
			if GameState.hp >= GameState.hp_max:
				_set_status("you're good. save it for later.")
			else:
				GameState.hp = mini(GameState.hp_max, GameState.hp + 15)
				_set_status("cold one. the party approves."))

func _build_speakers() -> void:
	for sx in [-9.0, 9.0]:
		_add_box(Vector3(sx, 1.4, 4.0), Vector3(1.4, 2.8, 1.2),
			Color(0.08, 0.08, 0.10), 0.3, 0.6)
		_add_box(Vector3(sx, 1.9, 4.62), Vector3(0.9, 0.9, 0.05),
			Color(0.2, 0.1, 0.25), 0.0, 0.3, true, Color(1.0, 0.3, 0.9), 0.8)
		var pulse := OmniLight3D.new()
		pulse.position = Vector3(sx, 2.0, 3.0)
		pulse.light_color = Color(1.0, 0.3, 0.9)
		pulse.light_energy = 1.4
		pulse.omni_range = 7.0
		add_child(pulse)
		var tw := create_tween().set_loops()
		tw.tween_property(pulse, "light_energy", 2.4, 0.4)
		tw.tween_property(pulse, "light_energy", 1.0, 0.4)

func _build_string_lights() -> void:
	for i in 10:
		var t: float = i / 9.0
		var lx := -11.0 + t * 22.0
		var ly := 3.6 - sin(t * PI) * 0.6
		_add_box(Vector3(lx, ly, -8.5), Vector3(0.14, 0.14, 0.14),
			Color(1.0, 0.85, 0.4), 0.0, 0.3, true, Color(1.0, 0.85, 0.4), 2.0)

func _build_people() -> void:
	# Stephen center-stage; a couple of partygoers
	add_npc("res://assets/sprites/npc-cyberpunk.png", Vector3(-1.0, 0.9, 1.0), 0)
	add_interact(Vector3(-1.0, 1.2, 2.4), Vector3(2.6, 2.4, 2.6),
		"talk to stephen", func(): DialogueOverlay.play("stephen"))
	add_npc("res://assets/sprites/civ/civ-a04.png", Vector3(-7.0, 0.9, 2.0), 2)
	add_npc("res://assets/sprites/civ/civ-b11.png", Vector3(3.0, 0.9, 3.5), 3)
