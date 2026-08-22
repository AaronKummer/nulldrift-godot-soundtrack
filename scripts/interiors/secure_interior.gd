## SecureInterior — interior_base + a security layer. Any building you can
## sneak, talk, or shoot your way through extends this: it wires up
## patrolling guards with vision cones (the stealth threat), the caught-and-
## ejected consequence, and the Siege "going loud" combat director with its
## location-specific backup ladder.
##
## Subclass contract:
##   • set _posture_id (a data/security_defs.gd posture) before super._ready()
##   • in _build_interior(): build rooms, place guards/turrets via add_guard()/
##     add_turret(), register fleeing civilians via register_worker(), then
##     call _init_security() LAST
##   • override _entrances(), _sec_floor(), _sec_exit(), _reset_floor(),
##     and optionally _caught_lines()
extends "res://scripts/interiors/interior_base.gd"

const StealthGuardScript := preload("res://scripts/systems/stealth_guard.gd")
const SiegeScript := preload("res://scripts/systems/siege.gd")
const SecurityDefsData := preload("res://data/security_defs.gd")

var _posture_id := "vohl"
var _guards: Array = []
var _sec_workers: Array = []
var _caught := false
var _alarm_label: Label
var _siege = null

# ── subclass hooks ─────────────────────────────────────────────────────────
func _entrances() -> Array:
	return []                                   # Vector3 backup-spawn / flee points

func _sec_floor() -> int:
	return 1

func _sec_exit() -> Array:
	return ["city", "from_street"]              # [scene_id, spawn_marker]

func _reset_floor() -> void:
	pass                                        # e.g. GameState.<building>_floor = 1

func _caught_lines() -> Array:
	return [
		{ "speaker": "SECURITY", "text": "That's far enough. You're leaving — now.", "color": Color(1.0, 0.4, 0.35) },
		{ "speaker": "", "text": "They walk you out and make it clear you're not welcome back today.", "color": Color(0.6, 0.6, 0.66) },
	]

# ── placement helpers ──────────────────────────────────────────────────────
## A patrolling guard with a vision cone. patrol = [] means it stands post.
func add_guard(pos: Vector3, facing_deg: float, patrol: Array = [],
		unit_id: String = "guard") -> Node3D:
	var ud: Dictionary = SecurityDefsData.unit(unit_id)
	var sheet: String = ud.get("sheet", "")
	if sheet == "":
		sheet = "res://assets/sprites/npc-cop2.png"
	var g = StealthGuardScript.new()
	g.position = pos
	g.configure(_player, facing_deg, {
		"sheet": sheet, "tint": ud.get("tint", Color(1, 1, 1)),
		"range": ud.get("range", 7.5), "patrol": patrol,
		"patrol_speed": 1.8,
	})
	g.unit_id = unit_id
	g.spotted.connect(_on_spotted)
	add_child(g)
	_guards.append(g)
	return g

## A wall/ceiling auto-turret — static, no sprite, a mounted box body. Reads as
## a sensor too: cross its cone unseen at your peril.
func add_turret(pos: Vector3, facing_deg: float) -> Node3D:
	var g := add_guard(pos, facing_deg, [], "turret")
	g.hide_sprite()
	_build_turret_body(g, facing_deg)
	return g

func _build_turret_body(parent: Node3D, facing_deg: float) -> void:
	var mount := Node3D.new()
	mount.rotation.y = deg_to_rad(facing_deg)
	parent.add_child(mount)
	_sec_box(mount, Vector3(0, 2.7, 0), Vector3(0.5, 0.4, 0.5), Color(0.2, 0.22, 0.26), 0.8, 0.3)
	_sec_box(mount, Vector3(0, 2.55, 0), Vector3(0.7, 0.25, 0.7), Color(0.14, 0.15, 0.18), 0.8, 0.3)
	# twin barrels pointing along facing (+z local)
	for bx in [-0.12, 0.12]:
		_sec_box(mount, Vector3(bx, 2.6, 0.45), Vector3(0.08, 0.08, 0.7),
			Color(0.1, 0.1, 0.12), 0.9, 0.3)
	# red sensor eye
	_sec_box(mount, Vector3(0, 2.62, 0.28), Vector3(0.18, 0.1, 0.05),
		Color(1.4, 0.2, 0.2), 0.0, 0.3, Color(1.6, 0.2, 0.2), 3.0)

func register_worker(node: Node3D) -> Node3D:
	if node != null:
		_sec_workers.append(node)
	return node

## Call LAST in _build_interior — spins up the Siege director and hands it the
## guards, turrets, workers, and this building's posture.
func _init_security() -> void:
	_build_alarm_hud()
	_siege = SiegeScript.new()
	add_child(_siege)
	_siege.configure(_player, _posture_id, _sec_floor(), _entrances(), _eject)
	for g in _guards:
		g.make_combatant(g.unit_id, _siege)
		_siege.register_guard(g)
	for w in _sec_workers:
		_siege.register_worker(w)

# ── stealth alarm / caught ─────────────────────────────────────────────────
func _build_alarm_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 40
	add_child(cl)
	_alarm_label = Label.new()
	_alarm_label.add_theme_font_size_override("font_size", 22)
	_alarm_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	_alarm_label.anchor_left = 0.5
	_alarm_label.anchor_right = 0.5
	_alarm_label.anchor_top = 0.14
	_alarm_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.add_child(_alarm_label)

func _process(_dt: float) -> void:
	if _caught or _alarm_label == null or _guards.is_empty():
		return
	if _siege != null and _siege.armed:
		_alarm_label.text = ""      # the Siege HUD owns the screen once it's loud
		return
	var worst := 0.0
	for g in _guards:
		if is_instance_valid(g):
			worst = maxf(worst, g.detection())
	if worst >= 0.85:
		_alarm_label.text = "! SPOTTED !"
	elif worst >= 0.25:
		_alarm_label.text = "· noticed · SHIFT to sneak ·"
	else:
		_alarm_label.text = ""

## Full stealth detection (while holstered) → grabbed and thrown out + heat.
func _on_spotted() -> void:
	if _caught or (_siege != null and _siege.armed):
		return
	_caught = true
	_menu_open = true
	for g in _guards:
		if is_instance_valid(g):
			g.active = false
	GameState.add_heat(30.0)
	if _alarm_label:
		_alarm_label.text = "!! SECURITY !!"
	DialogueOverlay.play_lines(_caught_lines(), "sec_caught")
	if not DialogueOverlay.finished.is_connected(_after_caught):
		DialogueOverlay.finished.connect(_after_caught, CONNECT_ONE_SHOT)

func _after_caught(_tree := "") -> void:
	_eject()

func _eject() -> void:
	_reset_floor()
	var e: Array = _sec_exit()
	SceneTransition.go(e[0], e[1])

## Draw / holster — drawing near security is going loud.
func _input(event: InputEvent) -> void:
	if _caught or _menu_open or DialogueOverlay.is_active():
		return
	if event.is_action_pressed("draw_weapon") and _siege != null and _siege.holstered():
		_siege.go_loud()
		_set_status("WEAPON DRAWN — going loud. F to survive, not to reconsider.")

func _sec_box(parent: Node3D, pos: Vector3, sz: Vector3, col: Color, metal := 0.0,
		rough := 0.6, emis := Color.BLACK, energy := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metal
	mat.roughness = rough
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emis
		mat.emission_energy_multiplier = energy
	mi.material_override = mat
	parent.add_child(mi)
