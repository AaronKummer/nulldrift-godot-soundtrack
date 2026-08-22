extends Node3D

## Siege — the "going loud" director for a building. Drop it in an iso
## interior, hand it the player + a security posture, and it runs the whole
## firefight: player auto-fire, enemy + player projectiles, the BACKUP LADDER
## (an alerted guard radios reinforcements; waves escalate SECURITY → ELITE →
## cops, per the location's posture and calls_police), workers fleeing (each
## witness spikes heat), and player death.
##
## Guards themselves are StealthGuard nodes flipped hostile (they own their own
## movement/attack AI); Siege owns everything shared. The stealth path and the
## loud path share the same guards — holster and sneak, or draw and fight.
##
##   var s := SiegeScript.new(); add_child(s)
##   s.configure(player, "vohl", floor, entrances, exit_on_death)
##   for g in my_guards: s.register_guard(g)     # garrison
##   ...on draw-weapon: s.go_loud()

const SecurityDefsData := preload("res://data/security_defs.gd")
const StealthGuardScript := preload("res://scripts/systems/stealth_guard.gd")
const AnimatedBillboardScript := preload("res://scripts/systems/animated_billboard.gd")

signal cleared                        # all hostiles down and no more backup
signal player_downed

var _player: Node3D
var _posture: Dictionary = {}
var _floor := 1
var _entrances: Array = []             # Vector3 spawn points for backup waves
var _exit_on_death: Callable

var armed := false                     # weapon drawn — going loud
var _guards: Array = []                # live StealthGuard combatants
var _bullets: Array = []               # player shots  { pos, dir, dmg, left, mesh }
var _ebullets: Array = []              # enemy shots    { pos, dir, dmg, left, mesh }
var _workers: Array = []               # panicking civilians { node, fled }
var _ladder: Array = []
var _ladder_i := 0
var _ladder_t := 0.0
var _fire_t := 0.0
var _hurt_cd := 0.0

var _hud: CanvasLayer
var _alert_label: Label
var _boss_label: Label
var _boss_bar: Panel
var _boss_fill: Panel
var _boss = null                       # the laser_bot, when present

# ── game feel ──────────────────────────────────────────────────────────────
var _cam: Camera3D
var _cam_base := Vector3.ZERO
var _shake := 0.0
var _hurt_flash: ColorRect
var _muzzle_flash := 0.0
var _muzzle_pos := Vector3.ZERO
var _muzzle_light: OmniLight3D
var _rng := RandomNumberGenerator.new()

const MELEE_REACH := 2.6
const RANGED_RANGE := 18.0
const BULLET_SPD := 26.0

func _ready() -> void:
	_build_hud()

func configure(player: Node3D, posture_id: String, floor: int,
		entrances: Array, exit_on_death: Callable) -> void:
	_player = player
	_posture = SecurityDefsData.posture(posture_id)
	_floor = floor
	_entrances = entrances
	_exit_on_death = exit_on_death
	_rng.randomize()
	_cam = get_viewport().get_camera_3d()
	if _cam:
		_cam_base = _cam.position
	# A muzzle-flash light that flicks on for a frame or two when you fire
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.9, 0.6)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 6.0
	add_child(_muzzle_light)
	# Build the backup ladder, dropping the cop rung if this place handles it
	# in-house (banks) rather than calling the law.
	_ladder = []
	for rung in _posture.get("ladder", []):
		var is_cops: bool = rung.wave.has("cop")
		if is_cops and not _posture.get("calls_police", false):
			continue
		_ladder.append(rung)

## Register a guard the scene already placed (garrison). Siege makes it a
## combatant of its roster type but leaves it neutral until you go loud.
func register_guard(g) -> void:
	if not _guards.has(g):
		_guards.append(g)
		g.died.connect(_on_guard_died)
		if g.is_boss:
			_boss = g

## Register a civilian who will bolt for the exit (and report you) once it's loud.
func register_worker(node: Node3D) -> void:
	_workers.append({ "node": node, "fled": false })

func go_loud() -> void:
	if armed:
		return
	armed = true
	# Drawing on a room full of people is instantly, loudly criminal.
	GameState.add_heat(20.0)
	for g in _guards:
		g.go_hostile()
	for w in _workers:
		w.fled = false

func holstered() -> bool:
	return not armed

# ── firing (player) ────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if _player == null:
		return
	_hurt_cd = maxf(0.0, _hurt_cd - delta)
	if armed:
		_auto_fire(delta)
		_tick_ladder(delta)
		_tick_workers(delta)
	_tick_bullets(delta)
	_tick_feel(delta)
	_refresh_hud()

## Screen shake + muzzle flash decay. Shake offsets the (otherwise static) iso
## camera around its base spot, so fights kick without the view drifting.
func _tick_feel(delta: float) -> void:
	if _cam:
		if _shake > 0.01:
			_cam.position = _cam_base + Vector3(
				_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0),
				_rng.randf_range(-1.0, 1.0)) * _shake
			_shake = maxf(0.0, _shake - delta * 3.2)
		else:
			_cam.position = _cam_base
	if _muzzle_light:
		if _muzzle_flash > 0.0:
			_muzzle_flash = maxf(0.0, _muzzle_flash - delta)
			_muzzle_light.position = _muzzle_pos
			_muzzle_light.light_energy = _muzzle_flash * 24.0
		else:
			_muzzle_light.light_energy = 0.0

func _add_shake(amt: float) -> void:
	_shake = minf(0.6, _shake + amt)

func _nearest_hostile(max_d: float) -> Node3D:
	var best: Node3D = null
	var bd := max_d
	for g in _guards:
		if not is_instance_valid(g):
			continue
		var d: float = g.global_position.distance_to(_player.global_position)
		if d < bd:
			bd = d
			best = g
	return best

func _auto_fire(delta: float) -> void:
	_fire_t = maxf(0.0, _fire_t - delta)
	if _fire_t > 0.0:
		return
	var w: Dictionary = GameState.weapon_def()
	var cd: float = float(w.get("speed", 280)) / 1000.0
	var dmg: int = maxi(1, roundi(float(w.get("damage", 6)) * (1.0 + GameState.damage_bonus())))
	var melee: bool = w.get("type", "melee") == "melee"
	var reach: float = MELEE_REACH if melee else RANGED_RANGE
	var target := _nearest_hostile(reach)
	if target == null:
		return
	var dir := target.global_position - _player.global_position
	dir.y = 0.0
	dir = dir.normalized()
	if _player.has_method("update_facing"):
		pass
	if melee:
		# Arc: hit every hostile inside the swing
		var landed := false
		for g in _guards:
			if not is_instance_valid(g):
				continue
			var to: Vector3 = g.global_position - _player.global_position
			to.y = 0.0
			if to.length() <= reach and to.normalized().dot(dir) > 0.35:
				g.take_hit(dmg)
				_damage_number(g.global_position, dmg)
				landed = true
		_slash_fx(dir, reach)
		if landed:
			_add_shake(0.14)
		_fire_t = cd
	else:
		var wid: String = GameState.equipped_weapon
		var ammo: int = GameState.ammo_left(wid) if GameState.has_method("ammo_left") else 1
		if ammo <= 0:
			var loaded: int = GameState.reload_from_reserve(wid) if GameState.has_method("reload_from_reserve") else 0
			if loaded <= 0:
				return
			_fire_t = 1.2
			return
		var muzzle := _player.global_position + Vector3(0, 1.0, 0) + dir * 0.6
		_spawn_bullet(muzzle, dir, dmg)
		_muzzle_flash = 0.06
		_muzzle_pos = muzzle
		_add_shake(0.05)
		_fire_t = cd
		if GameState.has_method("set_ammo"):
			GameState.set_ammo(wid, ammo - 1)

func _spawn_bullet(pos: Vector3, dir: Vector3, dmg: int) -> void:
	var m := _tracer(Color(0.4, 1.0, 1.2))
	m.position = pos
	add_child(m)
	_bullets.append({ "pos": pos, "dir": dir, "dmg": dmg, "left": RANGED_RANGE + 4.0, "mesh": m })

## Enemy fire — guards call this so Siege owns the projectile + hit.
func enemy_fire(pos: Vector3, dir: Vector3, dmg: int, burst: int = 1) -> void:
	for i in maxi(1, burst):
		var jitter := dir.rotated(Vector3.UP, (i - (burst - 1) * 0.5) * 0.06)
		var m := _tracer(Color(1.3, 0.4, 0.2))
		m.position = pos
		add_child(m)
		_ebullets.append({ "pos": pos, "dir": jitter, "dmg": dmg, "left": 22.0, "mesh": m })

## Melee/charge hit straight onto the player (elites, ninjas at range).
func hit_player(dmg: int) -> void:
	_damage_player(dmg)

func _tick_bullets(delta: float) -> void:
	for b in _bullets:
		var step: Vector3 = b.dir * BULLET_SPD * delta
		b.pos += step
		b.mesh.position = b.pos
		b.left -= BULLET_SPD * delta
		var gone: bool = b.left <= 0.0
		if not gone:
			for g in _guards:
				if is_instance_valid(g) and g.global_position.distance_to(b.pos) < 1.0:
					g.take_hit(b.dmg)
					_damage_number(g.global_position, b.dmg)
					_add_shake(0.04)
					gone = true
					break
		if gone:
			b.mesh.queue_free()
	_bullets = _bullets.filter(func(b): return b.left > 0.0 and is_instance_valid(b.mesh))
	for e in _ebullets:
		var step: Vector3 = e.dir * BULLET_SPD * delta
		e.pos += step
		e.mesh.position = e.pos
		e.left -= BULLET_SPD * delta
		var gone: bool = e.left <= 0.0
		if not gone and e.pos.distance_to(_player.global_position + Vector3(0, 1.0, 0)) < 1.0:
			_damage_player(e.dmg)
			gone = true
		if gone:
			e.mesh.queue_free()
	_ebullets = _ebullets.filter(func(e): return e.left > 0.0 and is_instance_valid(e.mesh))

func _damage_player(dmg: int) -> void:
	if _hurt_cd > 0.0:
		return
	_hurt_cd = 0.12
	if GameState.has_method("take_damage"):
		GameState.take_damage(dmg)
	else:
		GameState.hp = maxi(0, GameState.hp - dmg)
	_add_shake(0.28)
	_flash_hurt()
	if GameState.hp <= 0:
		_down()

func _flash_hurt() -> void:
	if _hurt_flash == null:
		return
	_hurt_flash.color = Color(0.8, 0.05, 0.05, 0.42)
	var tw := create_tween()
	tw.tween_property(_hurt_flash, "color:a", 0.0, 0.35)

func _down() -> void:
	set_process(false)
	GameState.hp = 30
	GameState.add_heat(40.0)
	player_downed.emit()
	DialogueOverlay.play_lines([
		{ "speaker": "", "text": "You go down under a wall of fire. Everything whites out. You come to on the pavement outside, patched up by a street medic who took your credits for the trouble.", "color": Color(0.9, 0.5, 0.5) },
	], "siege_down")
	if _exit_on_death.is_valid():
		if not DialogueOverlay.finished.is_connected(_exit_after_down):
			DialogueOverlay.finished.connect(_exit_after_down, CONNECT_ONE_SHOT)

func _exit_after_down(_t := "") -> void:
	_exit_on_death.call()

# ── the backup ladder ────────────────────────────────────────────────────
func _tick_ladder(delta: float) -> void:
	if _ladder_i >= _ladder.size():
		if _live_count() == 0:
			cleared.emit()
		return
	# A rung only gets radioed if someone's alive to make the call.
	if _live_count() == 0:
		return
	_ladder_t += delta
	if _ladder_t >= float(_ladder[_ladder_i].delay):
		_dispatch(_ladder[_ladder_i])
		_ladder_i += 1
		_ladder_t = 0.0

func _dispatch(rung: Dictionary) -> void:
	for uid in rung.wave:
		var from: Vector3 = _entrances[randi() % _entrances.size()] if not _entrances.is_empty() else Vector3.ZERO
		var g = StealthGuardScript.new()
		g.position = from + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0))
		var ud: Dictionary = SecurityDefsData.unit(uid)
		var sheet: String = ud.get("sheet", "")
		if sheet == "":
			sheet = "res://assets/sprites/npc-cop2.png"   # placeholder; hidden for box units
		g.configure(_player, 180.0, {
			"sheet": sheet,
			"tint": ud.get("tint", Color(1, 1, 1)),
			"range": ud.get("range", 14.0),
		})
		g.make_combatant(uid, self)
		get_parent().add_child(g)
		g.go_hostile()
		register_guard(g)
		if ud.get("boss", false):
			g.hide_sprite()
			_spawn_laser_bot_visual(g)

## Debug/testing: spawn a specific unit at a position and go loud (render harness).
func debug_spawn(uid: String, at: Vector3) -> void:
	_dispatch({ "call": "TEST", "wave": [uid], "delay": 0.0 })
	if not _guards.is_empty():
		_guards[-1].global_position = at

func _live_count() -> int:
	var n := 0
	for g in _guards:
		if is_instance_valid(g):
			n += 1
	return n

func _on_guard_died(g) -> void:
	_guards.erase(g)
	var ud: Dictionary = SecurityDefsData.unit(g.unit_id)
	_death_burst(g.global_position, ud.get("boss", false))
	_add_shake(0.35 if ud.get("boss", false) else 0.16)
	if ud.get("drops", false) and ud.get("credits", 0) > 0:
		GameState.add_credits(ud.credits)
	if g == _boss:
		_boss = null
	GameState.add_heat(6.0)   # bodies pile up, the law notices

## A quick shower of glowing debris when something dies.
func _death_burst(pos: Vector3, big: bool) -> void:
	var col := Color(1.4, 0.4, 1.4) if big else Color(1.3, 0.5, 0.3)
	var n := 10 if big else 6
	for i in n:
		var chunk := _tracer(col)
		(chunk.mesh as BoxMesh).size = Vector3(0.18, 0.18, 0.18)
		chunk.position = pos + Vector3(0, 1.0, 0)
		add_child(chunk)
		var vel := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(0.5, 1.5),
			_rng.randf_range(-1, 1)).normalized() * _rng.randf_range(2.0, 5.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(chunk, "position", chunk.position + vel, 0.5)
		tw.tween_property(chunk, "scale", Vector3.ZERO, 0.5)
		tw.chain().tween_callback(func():
			if is_instance_valid(chunk): chunk.queue_free())

# ── workers flee ───────────────────────────────────────────────────────────
func _tick_workers(delta: float) -> void:
	for w in _workers:
		if not is_instance_valid(w.node) or w.fled:
			continue
		var exit: Vector3 = _entrances[0] if not _entrances.is_empty() else Vector3(0, 0, 6)
		var to: Vector3 = exit - w.node.position
		to.y = 0.0
		if to.length() < 1.2:
			w.fled = true
			w.node.visible = false
			GameState.add_heat(5.0)   # another witness out the door, on the phone to security
			continue
		w.node.position += to.normalized() * 5.5 * delta

# ── the laser-katana bot's body (box-built; StealthGuard drives it) ────────
func _spawn_laser_bot_visual(g) -> void:
	# Hide the default billboard, build a chunky chrome frame + a glowing blade
	if g.has_node("."):
		pass
	var body := Node3D.new()
	g.add_child(body)
	_box(body, Vector3(0, 1.2, 0), Vector3(0.9, 1.8, 0.6), Color(0.22, 0.24, 0.30), 0.9, 0.3)
	_box(body, Vector3(0, 2.3, 0), Vector3(0.6, 0.5, 0.5), Color(0.15, 0.16, 0.2), 0.9, 0.3)
	_box(body, Vector3(0.1, 2.35, 0.28), Vector3(0.3, 0.12, 0.05),
		Color(1.4, 0.2, 0.2), 0.0, 0.3, Color(1.6, 0.2, 0.2), 3.0)   # red visor
	# The laser katana — a long emissive blade
	_box(body, Vector3(0.7, 1.5, 0.4), Vector3(0.08, 0.08, 1.8),
		Color(1.4, 0.3, 1.4), 0.0, 0.2, Color(1.6, 0.4, 1.8), 4.0)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.4, 0.3, 1.4)
	glow.light_energy = 2.2
	glow.omni_range = 4.0
	glow.position = Vector3(0.7, 1.5, 0.4)
	body.add_child(glow)

func _box(parent: Node3D, pos: Vector3, sz: Vector3, col: Color, metal := 0.0,
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

func _tracer(col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.12, 0.5)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 4.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	return mi

## Floating damage number that pops up off the hit and fades.
func _damage_number(pos: Vector3, amount: int) -> void:
	var lbl := Label3D.new()
	lbl.text = str(amount)
	lbl.font_size = 64
	lbl.pixel_size = 0.012
	lbl.modulate = Color(1.0, 0.95, 0.5)
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = pos + Vector3(_rng.randf_range(-0.3, 0.3), 1.9, 0)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 1.2, 0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.6).set_delay(0.15)
	tw.chain().tween_callback(func():
		if is_instance_valid(lbl): lbl.queue_free())

func _slash_fx(dir: Vector3, reach: float) -> void:
	var mi := _tracer(Color(1.2, 1.2, 1.4))
	(mi.mesh as BoxMesh).size = Vector3(reach, 0.1, reach)
	mi.position = _player.global_position + dir * reach * 0.4 + Vector3(0, 1.0, 0)
	add_child(mi)
	get_tree().create_timer(0.09).timeout.connect(func():
		if is_instance_valid(mi): mi.queue_free())

# ── HUD ────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 42
	add_child(_hud)
	# Full-screen red flash when you take a hit
	_hurt_flash = ColorRect.new()
	_hurt_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_flash.color = Color(0.8, 0.05, 0.05, 0.0)
	_hurt_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hurt_flash)
	_alert_label = Label.new()
	_alert_label.add_theme_font_size_override("font_size", 22)
	_alert_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_alert_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_alert_label.add_theme_constant_override("outline_size", 4)
	_alert_label.anchor_left = 0.5
	_alert_label.anchor_right = 0.5
	_alert_label.anchor_top = 0.07
	_alert_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_alert_label)
	_boss_label = Label.new()
	_boss_label.add_theme_font_size_override("font_size", 16)
	_boss_label.add_theme_color_override("font_color", Color(1.0, 0.4, 1.1))
	_boss_label.anchor_left = 0.5
	_boss_label.anchor_right = 0.5
	_boss_label.anchor_top = 0.87
	_boss_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_boss_label)
	_boss_bar = Panel.new()
	_boss_bar.anchor_left = 0.5
	_boss_bar.anchor_right = 0.5
	_boss_bar.anchor_top = 0.90
	_boss_bar.offset_left = -180
	_boss_bar.offset_right = 180
	_boss_bar.offset_top = 0
	_boss_bar.offset_bottom = 16
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.02, 0.08, 0.9)
	_boss_bar.add_theme_stylebox_override("panel", bg)
	_hud.add_child(_boss_bar)
	_boss_fill = Panel.new()
	_boss_fill.anchor_top = 0.0
	_boss_fill.anchor_bottom = 1.0
	_boss_fill.anchor_left = 0.0
	var ff := StyleBoxFlat.new()
	ff.bg_color = Color(1.0, 0.3, 1.0)
	_boss_fill.add_theme_stylebox_override("panel", ff)
	_boss_bar.add_child(_boss_fill)
	_boss_bar.visible = false
	_boss_label.visible = false

func _refresh_hud() -> void:
	if not armed:
		_alert_label.text = ""
		_boss_bar.visible = false
		_boss_label.visible = false
		return
	var msg := "◆ SECURITY ENGAGED ◆"
	if _ladder_i > 0 and _ladder_i - 1 < _ladder.size():
		msg = "◆ %s CALLED ◆" % _ladder[_ladder_i - 1].call
	if _ladder_i < _ladder.size():
		msg += "   (more incoming)"
	elif _live_count() == 0:
		msg = "◆ BUILDING CLEARED ◆"
	_alert_label.text = msg
	if _boss != null and is_instance_valid(_boss):
		_boss_bar.visible = true
		_boss_label.visible = true
		_boss_label.text = "KATANA UNIT"
		_boss_fill.anchor_right = clampf(float(_boss.hp) / float(_boss.hp_max), 0.0, 1.0)
	else:
		_boss_bar.visible = false
		_boss_label.visible = false
