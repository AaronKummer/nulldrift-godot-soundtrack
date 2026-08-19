## DoorGlow — reusable neon outline + proximity highlight for any doorway.
##
## Every enterable door in the game gets this by default: an always-on neon
## outline, and — while the player stands in the door's interact area — a
## pulsing frame plus a bobbing down-arrow above the opening.
##
## Place it at the CENTER-BOTTOM of the door opening, facing +Z. Rotate the
## node for doors on other walls (e.g. rotation.y = PI/2 for an east-wall
## door). Wire an Area3D's enter/exit to set_active().
##
##     var g := DoorGlowScript.new()
##     g.color = Color(0.0, 1.0, 1.0)
##     g.opening = Vector2(1.7, 2.5)          # doorway width, height
##     g.position = Vector3(x, 0.0, wall_face_z)
##     add_child(g)
##     area.body_entered.connect(func(_b): g.set_active(true))
##     area.body_exited.connect(func(_b): g.set_active(false))
class_name DoorGlow
extends Node3D

const TUBE := 0.12          # tube thickness — thinner vanishes at camera distance
const DEPTH := 0.08
const ENERGY_IDLE := 2.8
const ENERGY_ACTIVE := 3.6  # pulse midpoint — a full flare washes out cyan
const PULSE_AMP := 0.9
const ARROW_BOB := 0.10

@export var color: Color = Color(0.0, 1.0, 1.0)
@export var opening: Vector2 = Vector2(1.7, 2.5)   # doorway width, height
@export var arrow_gap: float = 0.55                # arrow height above top tube

var _mats: Array = []
var _arrow: MeshInstance3D
var _arrow_base_y: float
var _active := false
var _t := 0.0

func _ready() -> void:
	var w := opening.x
	var h := opening.y
	# Horizontal rails (bottom, top) — overhang the uprights so corners close
	for fy in [TUBE * 0.5, h + TUBE * 0.5]:
		_add_tube(Vector3(0, fy, 0), Vector3(w + TUBE * 2.0, TUBE, DEPTH))
	# Vertical uprights
	for fx in [-(w * 0.5 + TUBE * 0.5), w * 0.5 + TUBE * 0.5]:
		_add_tube(Vector3(fx, (h + TUBE) * 0.5, 0), Vector3(TUBE, h + TUBE, DEPTH))
	# Bobbing down-arrow — hidden until the player is in the interact area
	_arrow = MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.55, 0.40, 0.12)
	_arrow.mesh = prism
	_arrow.rotation.z = PI   # apex points down at the door
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color * Color(0.3, 0.3, 0.3, 1.0)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.5
	_arrow.material_override = mat
	_arrow_base_y = h + arrow_gap
	_arrow.position = Vector3(0, _arrow_base_y, 0)
	_arrow.visible = false
	add_child(_arrow)

func _add_tube(pos: Vector3, sz: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color * Color(0.4, 0.4, 0.4, 1.0)
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = ENERGY_IDLE
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	_mats.append(mat)

func set_active(on: bool) -> void:
	_active = on
	if _arrow:
		_arrow.visible = on
	if not on:
		for m in _mats:
			m.emission_energy_multiplier = ENERGY_IDLE

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	_arrow.position.y = _arrow_base_y + sin(_t * 4.5) * ARROW_BOB
	var e := ENERGY_ACTIVE + sin(_t * 5.0) * PULSE_AMP
	for m in _mats:
		m.emission_energy_multiplier = e
