## SUSHI — the downtown sushi lounge. Chef Tatsu runs the counter. In the
## corner booth: MIKO, ex-OmniCorp compliance, drinking sake alone and
## done pretending she misses the tower. Keep coming back and buying her
## sake, and things progress the old-fashioned way: slowly, then suddenly.
extends "res://scripts/interiors/interior_base.gd"

const SUSHI_COST := 20
const SAKE_COST := 30

func _ready() -> void:
	room_w = 24.0
	room_d = 16.0
	interior_name = "SUSHI"
	exit_scene = "street_downtown"
	exit_spawn = "from_sushi"
	super._ready()
	Music.play_category("shops")

func _ambient() -> Color:
	return Color(0.26, 0.22, 0.24)

func _wall_color() -> Color:
	return Color(0.14, 0.10, 0.10)

func _floor_color() -> Color:
	return Color(0.12, 0.11, 0.10)

func _build_interior() -> void:
	# Sushi counter with glass case
	_add_box(Vector3(-2.0, 0.6, -5.0), Vector3(12.0, 1.2, 1.4),
		Color(0.20, 0.16, 0.12), 0.1, 0.5)
	_add_box(Vector3(-2.0, 1.45, -5.0), Vector3(11.6, 0.5, 1.0),
		Color(0.4, 0.7, 0.8, 0.35), 0.6, 0.1)   # glass case
	# Fish in the case — little colored slabs
	for i in 8:
		var fx := -6.8 + i * 1.4
		_add_box(Vector3(fx, 1.4, -5.0), Vector3(0.9, 0.2, 0.6),
			[Color(0.95, 0.45, 0.4), Color(0.95, 0.7, 0.5), Color(0.9, 0.9, 0.85),
				Color(0.9, 0.5, 0.2)][i % 4], 0.0, 0.4)
	# Red lantern row
	for i in 4:
		var lx := -7.0 + i * 4.0
		_add_box(Vector3(lx, 3.3, -4.4), Vector3(0.5, 0.8, 0.5),
			Color(0.9, 0.15, 0.1) * 0.5, 0.0, 0.5, true, Color(1.4, 0.25, 0.15), 1.6)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.4, 0.3)
		lamp.light_energy = 0.9
		lamp.omni_range = 7.0
		lamp.position = Vector3(lx, 3.0, -4.0)
		add_child(lamp)
	add_npc("res://assets/sprites/civ/civ-b03.png", Vector3(2.5, 0.9, -3.4), 3)
	# Chef Tatsu
	add_npc("res://assets/sprites/npc-thug.png", Vector3(-2.0, 0.9, -6.4), 0)
	add_interact(Vector3(-2.0, 1.2, -3.6), Vector3(11.0, 2.4, 2.0),
		"omakase · %dcr" % SUSHI_COST, _eat_sushi)
	# Miko's corner booth
	_add_box(Vector3(9.5, 0.9, 4.5), Vector3(0.5, 1.8, 4.0),
		Color(0.35, 0.10, 0.12), 0.0, 0.6)
	_add_box(Vector3(8.6, 0.35, 4.5), Vector3(1.2, 0.7, 4.0),
		Color(0.45, 0.13, 0.14), 0.0, 0.5)
	_add_box(Vector3(7.0, 0.48, 4.5), Vector3(1.6, 0.10, 2.6),
		Color(0.18, 0.12, 0.09), 0.2, 0.4)
	# Sake bottle + cup, warm little table light
	_add_box(Vector3(7.0, 0.72, 4.2), Vector3(0.16, 0.4, 0.16),
		Color(0.85, 0.88, 0.9), 0.0, 0.3)
	_add_box(Vector3(7.2, 0.58, 4.7), Vector3(0.12, 0.12, 0.12),
		Color(0.9, 0.85, 0.8), 0.0, 0.4)
	var tl := OmniLight3D.new()
	tl.light_color = Color(1.0, 0.7, 0.5)
	tl.light_energy = 0.8
	tl.omni_range = 5.0
	tl.position = Vector3(7.5, 1.8, 4.5)
	add_child(tl)
	add_npc("res://assets/sprites/npc-corpo.png", Vector3(7.4, 0.9, 6.6), 0)
	add_interact(Vector3(6.8, 1.2, 5.6), Vector3(3.2, 2.4, 3.4),
		"the woman by the corner booth", _talk_miko)

func _eat_sushi() -> void:
	if GameState.credits < SUSHI_COST:
		_set_status("tatsu doesn't even look up. the message is clear.")
		return
	GameState.add_credits(-SUSHI_COST)
	GameState.hp = mini(GameState.hp + 40, GameState.hp_max)
	_set_status("omakase. tatsu says nothing. the fish says everything. +40 HP")

## Miko's arc advances one stage per conversation (sake required for the
## later stages — she's not talking to someone with empty hands).
func _talk_miko() -> void:
	if GameState.has_flag("mikoHome"):
		DialogueOverlay.play("miko")
		return
	if not GameState.has_flag("mikoMet"):
		GameState.set_flag("mikoMet")
		DialogueOverlay.play("miko")
		return
	# Stages past the first cost a round of sake
	if GameState.credits < SAKE_COST:
		_set_status("she glances at your empty hands. buy sake first. %dcr." % SAKE_COST)
		return
	GameState.add_credits(-SAKE_COST)
	if not GameState.has_flag("mikoWarm"):
		GameState.set_flag("mikoWarm")
		DialogueOverlay.play("miko")
	else:
		GameState.set_flag("mikoHome")
		DialogueOverlay.play("miko")
		_fade_to_morning()

func _fade_to_morning() -> void:
	# Fade to black; what happens in the corner booth's apartment stays there
	var cl := CanvasLayer.new()
	cl.layer = 80
	add_child(cl)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(fade)
	var tw := create_tween()
	tw.tween_interval(4.0)   # let the dialogue land first
	tw.tween_property(fade, "color:a", 1.0, 1.2)
	tw.tween_interval(1.6)
	tw.tween_property(fade, "color:a", 0.0, 1.2)
	tw.tween_callback(func():
		cl.queue_free()
		_set_status("morning. she left a note: 'the tower took years. you can have the weekends.'"))
