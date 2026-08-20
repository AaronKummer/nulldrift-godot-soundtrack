## THE MAGES GUILD — the rare books section that doesn't exist. Behind the
## library's alcove shelf. Arcane circle, a crystal that hums off-key, and
## the Archmage, who has been expecting you for a technically infinite
## amount of time. Talking to him installs the GRIMOIRE app.
extends "res://scripts/interiors/interior_base.gd"

func _ready() -> void:
	room_w = 22.0
	room_d = 16.0
	interior_name = "RARE BOOKS"
	exit_scene = "library"
	exit_spawn = "from_guild"
	super._ready()
	Music.play_category("story")

func _ambient() -> Color:
	return Color(0.22, 0.16, 0.32)

func _wall_color() -> Color:
	return Color(0.11, 0.07, 0.16)

func _floor_color() -> Color:
	return Color(0.10, 0.07, 0.13)

func _build_interior() -> void:
	_build_circle()
	_build_crystal()
	_build_shelves()
	_build_candles()
	_build_archmage()

# ── arcane circle inlaid in the floor ────────────────────────────────────
func _build_circle() -> void:
	var center := Vector3(-2.0, 0.02, 0.0)
	for ring in [[3.4, 0.14], [2.6, 0.09], [1.4, 0.09]]:
		var torus := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = ring[0] - ring[1]
		tm.outer_radius = ring[0]
		torus.mesh = tm
		torus.position = center
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.2, 0.7)
		mat.emission_enabled = true
		mat.emission = Color(0.7, 0.3, 1.4)
		mat.emission_energy_multiplier = 1.6
		torus.material_override = mat
		add_child(torus)
	# Rune nodes on the outer ring
	for i in 6:
		var a := TAU * i / 6.0
		_add_box(center + Vector3(cos(a) * 3.4, 0.06, sin(a) * 3.4),
			Vector3(0.3, 0.08, 0.3), Color(0.5, 0.25, 0.9), 0.0, 0.4,
			true, Color(0.9, 0.4, 1.8), 2.0)
	add_interact(center + Vector3(0, 1.0, 0), Vector3(3.0, 2.0, 3.0),
		"the arcane circle", func():
			_set_status("the circle hums. standing here feels like being compiled."))

# ── the crystal ──────────────────────────────────────────────────────────
func _build_crystal() -> void:
	_add_box(Vector3(6.5, 0.5, -4.5), Vector3(1.2, 1.0, 1.2),
		Color(0.15, 0.10, 0.22), 0.3, 0.5)                       # pedestal
	var crystal := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.8, 1.6, 0.8)
	crystal.mesh = prism
	crystal.position = Vector3(6.5, 1.9, -4.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.3, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.35, 1.6)
	mat.emission_energy_multiplier = 2.2
	crystal.material_override = mat
	add_child(crystal)
	var tw := create_tween().set_loops()
	tw.tween_property(crystal, "rotation:y", TAU, 6.0).from(0.0)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.8, 0.4, 1.4)
	lamp.light_energy = 2.0
	lamp.omni_range = 9.0
	lamp.position = Vector3(6.5, 2.4, -4.5)
	add_child(lamp)
	add_interact(Vector3(6.5, 1.2, -3.2), Vector3(2.4, 2.4, 2.0),
		"the crystal", func():
			_set_status("it hums a chord that isn't in any tuning you know."))

# ── spell tomes ──────────────────────────────────────────────────────────
func _build_shelves() -> void:
	for sx in [-8.5, -4.5]:
		_add_box(Vector3(sx, 1.4, -7.4), Vector3(3.2, 2.8, 0.7),
			Color(0.16, 0.10, 0.20), 0.1, 0.6)
		for i in 7:
			var bx: float = sx - 1.3 + i * 0.44
			var glow_i := i % 3 == 0
			_add_box(Vector3(bx, 1.9, -7.0), Vector3(0.32, 0.55, 0.1),
				Color(0.35, 0.2, 0.5), 0.0, 0.5, glow_i, Color(0.8, 0.4, 1.4), 0.9)

# ── floating candles (on wall sconce stands, they float in spirit) ──────
func _build_candles() -> void:
	for spot in [Vector3(-9.5, 2.6, -3.0), Vector3(-9.5, 2.6, 3.0),
			Vector3(2.0, 2.8, -7.0), Vector3(9.5, 2.6, 1.0)]:
		_add_box(spot, Vector3(0.14, 0.5, 0.14), Color(0.9, 0.85, 0.7), 0.0, 0.6)
		_add_box(spot + Vector3(0, 0.35, 0), Vector3(0.1, 0.16, 0.1),
			Color(1.2, 0.8, 0.3), 0.0, 0.5, true, Color(1.6, 0.9, 0.3), 2.4)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.7, 0.35)
		lamp.light_energy = 0.9
		lamp.omni_range = 6.0
		lamp.position = spot + Vector3(0, 0.4, 0)
		add_child(lamp)

# ── the Archmage ─────────────────────────────────────────────────────────
func _build_archmage() -> void:
	add_npc("res://assets/sprites/smoking_scrapper.png", Vector3(-2.0, 0.9, -5.5), 0)
	add_interact(Vector3(-2.0, 1.2, -4.2), Vector3(2.8, 2.4, 2.4),
		"talk to the archmage", _talk_archmage)

func _talk_archmage() -> void:
	var first: bool = not GameState.has_flag("grimoire")
	DialogueOverlay.play("archmage")
	if first:
		GameState.set_flag("grimoire")
		_set_status("GRIMOIRE installed on your phone. don't ask how.")
