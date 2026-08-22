extends Node3D

## StealthGuard — a reusable guard with a vision cone, for any 3D iso scene
## that wants a stealth layer (the Vohl office first). Drop one in, point it
## at the player, and it watches: while the player stands in its cone with a
## clear line of sight, a detection meter fills. Sneaking fills it slower;
## running fills it fast. The meter drives three states —
##
##   CALM       nothing seen, meter draining
##   SUSPICIOUS meter rising, a "?" pops up, the guard turns to look
##   ALERT      meter full, "!" — the guard trips the alarm (spotted signal)
##
## The cone is drawn on the floor as a translucent fan, tinted by state, so
## the player can read exactly where it's safe to walk (and so renders show
## the sightlines). Purely a sensor — it emits `spotted`; the scene decides
## the consequence (raise heat, sound the alarm, eject the player...).
##
##   var g := StealthGuardScript.new()
##   g.configure(player, facing_deg, {"range": 8.0, "patrol": [p0, p1]})
##   g.spotted.connect(...)
##   add_child(g)

signal spotted                        # meter hit full — the alarm trips
signal state_changed(state: int)

const AnimatedBillboardScript := preload("res://scripts/systems/animated_billboard.gd")

enum { CALM, SUSPICIOUS, ALERT }

var _player: Node3D
var _sheet := "res://assets/sprites/npc-cop2.png"
var _tint := Color(1, 1, 1)

# Vision cone
var view_range := 8.0
var view_half_angle := 0.60          # radians; ~34° to a side, 68° full cone
var _facing := Vector3(0, 0, 1)       # unit dir the guard looks, in scene space

# Patrol
var _patrol: Array = []               # Vector3 waypoints in scene space
var _patrol_i := 0
var _wait_t := 0.0
var patrol_speed := 1.6
var _home: Vector3

# Detection
var _meter := 0.0                     # 0..1
var fill_rate := 0.9                  # per second at full exposure
var drain_rate := 0.55
var _state := CALM
var _alarm_fired := false
var active := true                    # scene can freeze the guard (alarm over, etc.)

# Visuals
var _anim
var _cone: MeshInstance3D
var _cone_mat: StandardMaterial3D
var _bang: Label3D                     # ? / ! popup

func configure(player: Node3D, facing_deg: float, opts: Dictionary = {}) -> void:
	_player = player
	var a := deg_to_rad(facing_deg)
	_facing = Vector3(sin(a), 0, cos(a)).normalized()
	_sheet = opts.get("sheet", _sheet)
	_tint = opts.get("tint", _tint)
	view_range = opts.get("range", view_range)
	view_half_angle = opts.get("half_angle", view_half_angle)
	_patrol = opts.get("patrol", [])
	patrol_speed = opts.get("patrol_speed", patrol_speed)

func _ready() -> void:
	_home = position
	# Guard sprite
	_anim = AnimatedBillboardScript.new()
	_anim.show_floor_shadow = true
	_anim.pixel_size = 0.04
	_anim.position = Vector3(0, 0.9, 0)
	_anim.tint = _tint
	add_child(_anim)
	_anim.load_sheet(_sheet)
	_anim.set_moving(false)
	_face_sprite()
	# Vision cone mesh (a flat fan on the floor)
	_cone_mat = StandardMaterial3D.new()
	_cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone_mat.emission_enabled = true
	_cone = MeshInstance3D.new()
	_cone.mesh = _build_cone_mesh()
	_cone.material_override = _cone_mat
	_cone.position = Vector3(0, 0.06, 0)
	add_child(_cone)
	_orient_cone()
	_paint_cone()
	# ? / ! popup
	_bang = Label3D.new()
	_bang.text = ""
	_bang.font_size = 90
	_bang.pixel_size = 0.012
	_bang.position = Vector3(0, 2.3, 0)
	_bang.modulate = Color(1, 1, 0)
	_bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_bang)

func _build_cone_mesh() -> ArrayMesh:
	# A fan of triangles from the apex out to view_range across the cone.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 14
	var apex := Vector3.ZERO
	for i in segs:
		var t0 := -view_half_angle + (2.0 * view_half_angle) * (float(i) / segs)
		var t1 := -view_half_angle + (2.0 * view_half_angle) * (float(i + 1) / segs)
		var p0 := Vector3(sin(t0), 0, cos(t0)) * view_range
		var p1 := Vector3(sin(t1), 0, cos(t1)) * view_range
		st.add_vertex(apex)
		st.add_vertex(p0)
		st.add_vertex(p1)
	return st.commit()

func _orient_cone() -> void:
	# Rotate the local +z fan to point along _facing (in local space, since the
	# node itself isn't rotated).
	var ang := atan2(_facing.x, _facing.z)
	_cone.rotation = Vector3(0, ang, 0)

func _paint_cone() -> void:
	var base: Color
	match _state:
		CALM: base = Color(0.4, 0.9, 1.0)
		SUSPICIOUS: base = Color(1.0, 0.85, 0.2)
		ALERT: base = Color(1.0, 0.25, 0.2)
	base.a = 0.14 + 0.12 * _meter
	_cone_mat.albedo_color = base
	_cone_mat.emission = Color(base.r, base.g, base.b)
	_cone_mat.emission_energy_multiplier = 0.6 + _meter

func _face_sprite() -> void:
	# Map the look direction to the billboard's 4-way facing (iso convention:
	# screen-x ∝ (+x,-z), screen-y ∝ (+x,+z)).
	var sx := _facing.x - _facing.z
	var sy := _facing.x + _facing.z
	_anim.update_facing_from_input(Vector2(sx, sy))

func detection() -> float:
	return _meter

func state() -> int:
	return _state

func _physics_process(delta: float) -> void:
	if not active or _player == null:
		return
	_patrol_step(delta)
	var exposed := _player_exposure()
	if exposed > 0.0:
		_meter = minf(1.0, _meter + fill_rate * exposed * delta)
		# Snap-look toward the player while something's in view
		var to_p := (_player.global_position - global_position)
		to_p.y = 0
		if to_p.length() > 0.1:
			_facing = _facing.lerp(to_p.normalized(), clampf(delta * 3.0, 0, 1)).normalized()
			_orient_cone()
			_face_sprite()
	else:
		_meter = maxf(0.0, _meter - drain_rate * delta)
	_update_state()
	_paint_cone()

## How exposed the player is right now: 0 if outside the cone or behind cover,
## else a 0..1 factor scaled by distance and how fast they're moving (sneaking
## is quiet, sprinting is loud).
func _player_exposure() -> float:
	var to_p := _player.global_position - global_position
	to_p.y = 0
	var dist := to_p.length()
	if dist > view_range or dist < 0.05:
		return 0.0
	var dir := to_p.normalized()
	var cos_a := dir.dot(_facing)
	if cos_a < cos(view_half_angle):
		return 0.0
	if not _has_line_of_sight():
		return 0.0
	var close := 1.0 - (dist / view_range) * 0.6      # nearer = easier to see
	var motion := 1.0
	if GameState.sneaking:
		motion = 0.35                                  # crouched and slow
	elif _player_speed() > 9.0:
		motion = 1.6                                   # sprinting is loud
	return clampf(close * motion, 0.0, 1.5)

func _player_speed() -> float:
	if _player is CharacterBody3D:
		var v: Vector3 = (_player as CharacterBody3D).velocity
		return Vector2(v.x, v.z).length()
	return 0.0

func _has_line_of_sight() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.4, 0)
	var to := _player.global_position + Vector3(0, 1.0, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [_player.get_rid()] if _player is CollisionObject3D else []
	var hit := space.intersect_ray(q)
	# Clear if nothing solid between us and the player.
	return hit.is_empty()

func _patrol_step(delta: float) -> void:
	if _state == ALERT or _patrol.size() < 2:
		return
	var target: Vector3 = _patrol[_patrol_i]
	var to_t := target - position
	to_t.y = 0
	if to_t.length() < 0.3:
		_wait_t += delta
		_anim.set_moving(false)
		if _wait_t >= 1.8:
			_wait_t = 0.0
			_patrol_i = (_patrol_i + 1) % _patrol.size()
		return
	var step := to_t.normalized()
	position += step * patrol_speed * delta
	# Look where you walk (unless currently locking onto a suspicion)
	if _meter < 0.15:
		_facing = step
		_orient_cone()
		_face_sprite()
	_anim.set_moving(true)

func _update_state() -> void:
	var ns := _state
	if _meter >= 1.0:
		ns = ALERT
	elif _meter >= 0.25:
		ns = SUSPICIOUS
	else:
		ns = CALM
	if ns != _state:
		_state = ns
		match _state:
			CALM: _bang.text = ""
			SUSPICIOUS:
				_bang.text = "?"
				_bang.modulate = Color(1.0, 0.85, 0.2)
			ALERT:
				_bang.text = "!"
				_bang.modulate = Color(1.0, 0.25, 0.2)
		state_changed.emit(_state)
	if _state == ALERT and not _alarm_fired:
		_alarm_fired = true
		spotted.emit()

## Scene calls this once the alarm is handled (player caught/ejected or the
## coast is clear) to reset the guard back to patrol.
func reset() -> void:
	_meter = 0.0
	_state = CALM
	_alarm_fired = false
	_bang.text = ""
	position = _home
	_paint_cone()
