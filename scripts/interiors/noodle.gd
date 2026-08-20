## NOODLE — six-seat ramen counter off the downtown strip. The cook has
## two moods and one pot that never empties. A bowl fixes most things.
extends "res://scripts/interiors/interior_base.gd"

const RAMEN_COST := 15

var _steam: Array = []

func _ready() -> void:
	room_w = 18.0
	room_d = 12.0
	interior_name = "NOODLE"
	exit_scene = "street_downtown"
	exit_spawn = "from_noodle"
	super._ready()
	Music.play_category("apartment")

func _ambient() -> Color:
	return Color(0.34, 0.26, 0.18)

func _floor_color() -> Color:
	return Color(0.17, 0.13, 0.09)

func _build_interior() -> void:
	# Counter along the kitchen side — leaves the east walkway open so the
	# door isn't blocked
	_add_box(Vector3(-2.5, 0.6, -2.0), Vector3(9.0, 1.2, 1.2),
		Color(0.24, 0.17, 0.11), 0.1, 0.5)
	_add_box(Vector3(-2.5, 1.24, -2.0), Vector3(9.3, 0.08, 1.5),
		Color(0.55, 0.42, 0.26), 0.1, 0.4)
	# The pot — big, steel, glowing faintly from the burner beneath
	_add_box(Vector3(-2.0, 1.7, -4.0), Vector3(2.0, 1.0, 1.6),
		Color(0.45, 0.46, 0.5), 0.8, 0.3)
	_add_box(Vector3(-2.0, 1.15, -4.0), Vector3(1.6, 0.15, 1.2),
		Color(1.2, 0.5, 0.15), 0.0, 0.5, true, Color(1.5, 0.55, 0.15), 2.0)
	# Steam plumes (bobbed in _physics_process)
	for i in 3:
		var puff := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.18 + i * 0.06
		sph.height = 0.3 + i * 0.1
		puff.mesh = sph
		puff.position = Vector3(-2.0 + (i - 1) * 0.3, 2.4 + i * 0.45, -4.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.92, 0.95, 0.16)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		puff.material_override = mat
		add_child(puff)
		_steam.append({ "n": puff, "ph": i * 2.1, "base": puff.position.y })
	# Hanging menu banners
	for i in 3:
		var bx := -3.5 + i * 3.5
		_add_box(Vector3(bx, 3.2, -5.6), Vector3(1.4, 1.8, 0.06),
			[Color(0.8, 0.2, 0.15), Color(0.9, 0.75, 0.2), Color(0.2, 0.5, 0.8)][i] * 0.7,
			0.0, 0.8)
	# Stools
	for i in 4:
		var sx := -5.5 + i * 2.4
		_add_box(Vector3(sx, 0.4, 0.2), Vector3(0.7, 0.8, 0.7),
			Color(0.30, 0.14, 0.10), 0.1, 0.6)
	# A regular slurping at the end seat
	add_npc("res://assets/sprites/npc-cop.png", Vector3(1.7, 0.9, 0.2), 3)
	# The cook
	add_npc("res://assets/sprites/npc-thug.png", Vector3(0.0, 0.9, -3.6), 0)
	add_interact(Vector3(-2.5, 1.2, -0.6), Vector3(9.0, 2.4, 2.2),
		"ramen · %dcr" % RAMEN_COST, _eat_ramen)
	# Warm kitchen light
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.75, 0.45)
	lamp.light_energy = 1.8
	lamp.omni_range = 11.0
	lamp.shadow_enabled = true
	lamp.position = Vector3(0, 3.4, -2.5)
	add_child(lamp)

func _eat_ramen() -> void:
	if GameState.credits < RAMEN_COST:
		_set_status("cook: 'no credits, no noodles. them's the physics.'")
		return
	GameState.add_credits(-RAMEN_COST)
	GameState.hp = GameState.hp_max
	DialogueOverlay.play_lines([
		{ "speaker": "COOK", "text": "sit. eat. questions after.", "color": Color(1.0, 0.7, 0.4) },
		{ "speaker": "", "text": "The bowl arrives before you finish sitting. Broth like liquid neon, noodles with structural integrity.", "color": Color(0.53, 0.53, 0.53) },
		{ "speaker": "", "text": "You eat all of it. HP fully restored. The world seems briefly fixable.", "color": Color(0.6, 1.0, 0.7) },
	], "ramen")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var t := Time.get_ticks_msec() / 1000.0
	for s in _steam:
		var n: MeshInstance3D = s.n
		n.position.y = s.base + fmod(t * 0.5 + s.ph, 1.2) * 0.5
