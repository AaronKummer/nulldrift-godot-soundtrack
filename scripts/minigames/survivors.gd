## NEON SURVIVORS — Akane x Vampire Survivors. The arcade's main attraction.
##
## You get ported INTO the game as yourself (same sprite as the overworld).
## The arena is neon city streets — solid buildings carve the map into
## boulevards and alleys, Akane-style. You start with a katana that auto
## slashes the swarm; level-ups add plasma / orbit blades / nova and passives.
## Hordes are ninjas, thugs, and cops (real character sheets, not shapes),
## with red elite variants late. Outscore CHAD's 3000 to set chadBeaten.
extends Node2D
const ListMenuScript := preload("res://scripts/systems/list_menu.gd")

const WORLD := 2600.0
const PLAYER_SPEED := 170.0
const PLAYER_MAX_HP := 5
const INVULN := 0.45
const CONTACT_CD := 0.6
const MAX_ENEMIES := 110
const XP_BASE_RADIUS := 70.0
const CHAD_SCORE := 3000
const GAME_DURATION := 600.0

const FRAME_W := 48.0
const FRAME_H := 64.0
enum Facing { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

# Enemy roster — real sprite sheets. Elites are tinted red + buffed.
const ENEMY_TYPES := {
	"ninja": { "sheet": "ninja", "hp": 2, "speed": 92.0, "size": 16.0,
		"pts": 15, "xp": 1, "unlock": 0.0, "tint": Color(1, 1, 1) },
	"thug":  { "sheet": "thug", "hp": 5, "speed": 55.0, "size": 18.0,
		"pts": 25, "xp": 2, "unlock": 45.0, "tint": Color(1, 1, 1) },
	"cop":   { "sheet": "cop", "hp": 3, "speed": 85.0, "size": 17.0,
		"pts": 20, "xp": 2, "unlock": 120.0, "tint": Color(1, 1, 1) },
	"elite_ninja": { "sheet": "ninja", "hp": 6, "speed": 150.0, "size": 16.0,
		"pts": 50, "xp": 3, "unlock": 240.0, "tint": Color(1.6, 0.45, 0.45) },
	"elite_thug": { "sheet": "thug", "hp": 14, "speed": 65.0, "size": 19.0,
		"pts": 80, "xp": 5, "unlock": 360.0, "tint": Color(1.6, 0.45, 0.45) },
}

var _sheets := {}
var _player_sheet: Texture2D

var _pos := Vector2(WORLD * 0.5, WORLD * 0.5)
var _hp := PLAYER_MAX_HP
var _invuln := 0.0
var _score := 0
var _kills := 0
var _time := 0.0
var _level := 1
var _xp := 0
var _xp_next := 5
var _magnet := XP_BASE_RADIUS
var _speed_mult := 1.0
var _dmg_bonus := 0
var _game_over := false
var _won := false
var _picking := false
var _choices: Array = []
var _facing := Vector2.DOWN
var _face_row := Facing.DOWN
var _moving := false
var _anim_t := 0.0

# Weapons — katana is the Akane starter; the rest unlock via level-ups
var _weapons := { "katana": 1, "plasma": 0, "orbit": 0, "nova": 0 }
var _katana_t := 0.0
var _slash: Dictionary = {}    # active slash flash {angle, life}
var _plasma_t := 0.0
var _orbit_angle := 0.0
var _nova_t := 0.0
var _nova_flash := 0.0

var _enemies: Array = []
var _gems: Array = []
var _shots: Array = []
var _spawn_t := 0.0

# City layout — building rects (collision + drawing), lamps, signs
var _buildings: Array = []     # Rect2
var _lamps: Array = []         # Vector2
var _signs: Array = []         # {rect, color, vertical}

var _cam: Camera2D
var _board: Node2D
var _hud: Dictionary = {}
var _over_layer: CanvasLayer
var _pick_menu

func _ready() -> void:
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_sheets = {
		"ninja": load("res://assets/sprites/npc-ninja.png"),
		"thug": load("res://assets/sprites/npc-thug.png"),
		"cop": load("res://assets/sprites/npc-cop.png"),
	}
	_player_sheet = load("res://assets/sprites/player-pizza.png")
	_cam = Camera2D.new()
	_cam.zoom = Vector2(1.35, 1.35)
	add_child(_cam)
	_cam.make_current()
	_board = _Board.new()
	_board.game = self
	add_child(_board)
	_build_hud()
	_show_sector_select()

func _show_sector_select() -> void:
	_selecting = true
	_select_layer = CanvasLayer.new()
	add_child(_select_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.005, 0.015)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_select_layer.add_child(dim)
	_sector_menu = ListMenuScript.new()
	add_child(_sector_menu)
	_sector_menu.picked.connect(_on_sector_pick)
	_sector_menu.closed.connect(func():
		_sector_menu = null
		if _selecting:
			_exit_to_arcade())
	var entries: Array = []
	for i in LEVELS.size():
		var def: Dictionary = LEVELS[i]
		var locked := _level_locked(i)
		var label := ""
		if locked:
			label = "%s · LOCKED · clear the previous sector" % def.name
		else:
			var best: int = GameState.arcade_best("survivors_" + def.id)
			var cleared := " · CLEARED" if _level_cleared(def.id) else ""
			label = "%s · %d:%02d run · best %d%s" % [def.name,
				int(def.duration) / 60, int(def.duration) % 60, best, cleared]
		entries.append({ "label": label, "dim": locked })
	_sector_menu.open("NEON SURVIVORS · select sector", entries,
		Color(1.0, 0.25, 0.6), "beat CHAD's 3000")

func _on_sector_pick(idx: int) -> void:
	if _level_locked(idx):
		_sector_menu.set_footer("locked. clear the previous sector first.")
		return
	_selecting = false
	_sector_menu.close_menu()
	_start_level(idx)

func _start_level(idx: int) -> void:
	_level_def = LEVELS[idx]
	_level_id = _level_def.id
	_build_city(_level_def)
	_pos = _spawn_point
	_cam.position = _pos
	_selecting = false
	if _select_layer:
		_select_layer.queue_free()
		_select_layer = null
	_refresh_hud()

class _Board extends Node2D:
	var game
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		game._draw_world(self)


# ═══════════════════════════════════════════════════════════════════════
# LEVELS — hand-designed sectors. 13x13 ASCII maps, cell = 200px:
#   '#' solid block   '.' street/tunnel   'P' player spawn
# Clearing a sector (surviving its duration) unlocks the next.
# ═══════════════════════════════════════════════════════════════════════

const CELL := 200.0

const LEVELS := [
	{
		"id": "downtown", "name": "SECTOR 01 — DOWNTOWN",
		"desc": "ninja gangs own these streets",
		"duration": 300.0,
		"roster": { "ninja": 0.0, "thug": 45.0, "cop": 120.0, "elite_ninja": 220.0 },
		"spawn_start": 1.5, "spawn_ramp": 0.0021,
		"pal": {
			"ground": Color(0.016, 0.016, 0.032), "block": Color(0.045, 0.035, 0.07),
			"rim": Color(0.09, 0.07, 0.13), "lamp": Color(1.7, 1.5, 1.0),
			"dash": Color(0.35, 0.28, 0.05),
			"signs": [Color(1.8, 0.2, 0.9), Color(0.2, 1.7, 1.8), Color(1.8, 1.3, 0.2)],
		},
		"map": [
			"#############",
			"#...##...##.#",
			"#.#.##.#..#.#",
			"#.#....#....#",
			"#...##...##.#",
			"##.#......#.#",
			"#..#..P...###",
			"#.##....#...#",
			"#....##.##..#",
			"#.##.##.....#",
			"#.....#..##.#",
			"#..##....##.#",
			"#############",
		],
	},
	{
		"id": "docks", "name": "SECTOR 02 — THE DOCKS",
		"desc": "container maze. the muscle unloads here",
		"duration": 420.0,
		"roster": { "thug": 0.0, "ninja": 30.0, "cop": 90.0,
			"elite_ninja": 180.0, "elite_thug": 300.0 },
		"spawn_start": 1.4, "spawn_ramp": 0.0023,
		"pal": {
			"ground": Color(0.012, 0.020, 0.026), "block": Color(0.05, 0.045, 0.045),
			"rim": Color(0.10, 0.085, 0.06), "lamp": Color(1.7, 1.2, 0.5),
			"dash": Color(0.30, 0.30, 0.08),
			"signs": [Color(1.8, 0.7, 0.1), Color(0.2, 1.7, 1.8), Color(1.6, 0.3, 0.3)],
		},
		"map": [
			"#############",
			"#...........#",
			"#.####.####.#",
			"#...........#",
			"#.######.##.#",
			"#...P.......#",
			"#.##.######.#",
			"#...........#",
			"#.####.####.#",
			"#..........##",
			"#.##.###.##.#",
			"#...........#",
			"#############",
		],
	},
	{
		"id": "oldtown", "name": "SECTOR 03 — OLD TOWN",
		"desc": "narrow alleys. everything hunts here",
		"duration": 600.0,
		"roster": { "ninja": 0.0, "cop": 60.0, "thug": 120.0,
			"elite_ninja": 220.0, "elite_thug": 340.0 },
		"spawn_start": 1.3, "spawn_ramp": 0.0025,
		"pal": {
			"ground": Color(0.022, 0.014, 0.010), "block": Color(0.055, 0.038, 0.028),
			"rim": Color(0.11, 0.075, 0.05), "lamp": Color(1.7, 1.1, 0.4),
			"dash": Color(0.35, 0.22, 0.05),
			"signs": [Color(1.8, 0.6, 0.15), Color(1.7, 0.2, 0.3), Color(1.6, 1.2, 0.2)],
		},
		"map": [
			"#############",
			"#..#...#...##",
			"##.#.#.#.#..#",
			"#....#...##.#",
			"#.##...#....#",
			"#..#.#.#.#.##",
			"##...#P..#..#",
			"#.#.#...#.#.#",
			"#.#...#.....#",
			"#...#.#.##.##",
			"##.#..#.....#",
			"#....#...#..#",
			"#############",
		],
	},
]

var _level_def: Dictionary = {}
var _level_id := ""
var _selecting := true
var _select_layer: CanvasLayer
var _sector_menu
var _spawn_point := Vector2(WORLD * 0.5, WORLD * 0.5)

func _level_cleared(id: String) -> bool:
	return GameState.has_flag("survivorsCleared_" + id)

func _level_locked(idx: int) -> bool:
	return idx > 0 and not _level_cleared(LEVELS[idx - 1].id)

func _build_city(def: Dictionary) -> void:
	_buildings.clear()
	_signs.clear()
	_lamps.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(def.id)
	var map: Array = def.map
	var pal: Dictionary = def.pal
	for row in map.size():
		var line: String = map[row]
		var col := 0
		while col < line.length():
			if line[col] == "P":
				_spawn_point = Vector2((col + 0.5) * CELL, (row + 0.5) * CELL)
			if line[col] == "#":
				# Merge horizontal runs of '#' into one building rect
				var run_start := col
				while col < line.length() and line[col] == "#":
					col += 1
				_buildings.append(Rect2(run_start * CELL, row * CELL,
					(col - run_start) * CELL, CELL))
			else:
				col += 1
	# Neon signage on some south faces + lamps on open cells
	for r in _buildings:
		if rng.randf() < 0.5 and r.size.x >= CELL:
			var col_c: Color = pal.signs[rng.randi() % pal.signs.size()]
			var sw: float = rng.randf_range(50.0, minf(140.0, r.size.x - 30.0))
			var sx: float = r.position.x + rng.randf_range(10.0, r.size.x - sw - 10.0)
			_signs.append({ "rect": Rect2(sx, r.end.y - 8.0, sw, 10.0),
				"color": col_c, "vertical": false })
	for row in map.size():
		var line: String = map[row]
		for col in line.length():
			if line[col] != "#" and (row % 3 == 1 and col % 3 == 1):
				_lamps.append(Vector2((col + 0.5) * CELL, (row + 0.5) * CELL))

func _collide_world(p: Vector2, radius: float) -> Vector2:
	# Push a circle out of buildings + world bounds (axis pushout)
	p.x = clampf(p.x, radius, WORLD - radius)
	p.y = clampf(p.y, radius, WORLD - radius)
	for r in _buildings:
		var grown: Rect2 = r.grow(radius)
		if grown.has_point(p):
			# Push out along the shallowest axis
			var left: float = p.x - grown.position.x
			var right: float = grown.end.x - p.x
			var top: float = p.y - grown.position.y
			var bottom: float = grown.end.y - p.y
			var m: float = minf(minf(left, right), minf(top, bottom))
			if m == left: p.x = grown.position.x
			elif m == right: p.x = grown.end.x
			elif m == top: p.y = grown.position.y
			else: p.y = grown.end.y
	return p

func _in_building(p: Vector2, margin: float = 0.0) -> bool:
	for r in _buildings:
		if r.grow(margin).has_point(p):
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if _game_over or _picking or _selecting:
		return
	_time += delta
	_anim_t += delta
	if _time >= _level_def.duration and not _won:
		_won = true
		_score += 1000
		_finish(true)
		return
	_tick_player(delta)
	_tick_weapons(delta)
	_tick_shots(delta)
	_tick_enemies(delta)
	_tick_gems(delta)
	_tick_spawner(delta)
	_cam.position = _pos
	_refresh_hud()

func _tick_player(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_moving = input.length() > 0.1
	if _moving:
		_facing = input.normalized()
		if absf(input.x) >= absf(input.y):
			_face_row = Facing.RIGHT if input.x > 0 else Facing.LEFT
		else:
			_face_row = Facing.DOWN if input.y > 0 else Facing.UP
	_pos = _collide_world(_pos + input * PLAYER_SPEED * _speed_mult * delta, 14.0)
	_invuln = maxf(0.0, _invuln - delta)

func _nearest_enemy(from: Vector2, max_d: float = 620.0) -> Dictionary:
	var best: Dictionary = {}
	var bd := max_d * max_d
	for e in _enemies:
		var d: float = from.distance_squared_to(e.pos)
		if d < bd:
			bd = d
			best = e
	return best

func _tick_weapons(delta: float) -> void:
	# KATANA — Akane slash: auto-aims at the nearest threat in reach so
	# flankers get cut too (facing-only coverage made spawn camps lethal)
	if _weapons.katana > 0:
		_katana_t -= delta
		if not _slash.is_empty():
			_slash.life -= delta
			if _slash.life <= 0.0:
				_slash = {}
		if _katana_t <= 0.0:
			var reach: float = 78.0 + _weapons.katana * 6.0
			var target := _nearest_enemy(_pos, reach + 24.0)
			if not target.is_empty():
				var slash_dir: Vector2 = (target.pos - _pos).normalized()
				var dmg: int = 3 + _dmg_bonus + _weapons.katana
				for e in _enemies:
					var to: Vector2 = e.pos - _pos
					if to.length() <= reach + ENEMY_TYPES[e.type].size \
							and absf(to.angle_to(slash_dir)) < deg_to_rad(60.0):
						_damage_enemy(e, dmg)
				_katana_t = maxf(0.35, 0.8 - _weapons.katana * 0.06)
				_slash = { "angle": slash_dir.angle(), "life": 0.12, "reach": reach }
	# PLASMA — straight shot at nearest
	if _weapons.plasma > 0:
		_plasma_t -= delta
		if _plasma_t <= 0.0:
			_plasma_t = maxf(0.35, 0.95 - _weapons.plasma * 0.1)
			var target := _nearest_enemy(_pos)
			if not target.is_empty():
				var dir: Vector2 = (target.pos - _pos).normalized()
				var count: int = 1 + int(_weapons.plasma / 3)
				for i in count:
					var spread := (float(i) - (count - 1) * 0.5) * 0.18
					_shots.append({ "pos": _pos, "vel": dir.rotated(spread) * 420.0,
						"dmg": 2 + _dmg_bonus + int(_weapons.plasma / 2), "life": 1.4 })
	# ORBIT BLADES
	if _weapons.orbit > 0:
		_orbit_angle += delta * (2.6 + _weapons.orbit * 0.3)
	# NOVA PULSE
	if _weapons.nova > 0:
		_nova_t -= delta
		_nova_flash = maxf(0.0, _nova_flash - delta * 3.0)
		if _nova_t <= 0.0:
			_nova_t = maxf(1.6, 4.2 - _weapons.nova * 0.4)
			_nova_flash = 1.0
			for e in _enemies:
				if _pos.distance_to(e.pos) <= _nova_radius():
					_damage_enemy(e, 2 + _dmg_bonus + _weapons.nova)

func _nova_radius() -> float:
	return 130.0 + _weapons.nova * 25.0

func _orbit_blades() -> Array:
	var out: Array = []
	var count: int = 1 + _weapons.orbit
	for i in count:
		var a := _orbit_angle + TAU * float(i) / float(count)
		out.append(_pos + Vector2(cos(a), sin(a)) * 72.0)
	return out

func _tick_shots(delta: float) -> void:
	var dead: Array = []
	for sh in _shots:
		sh.pos += sh.vel * delta
		sh.life -= delta
		if sh.life <= 0.0 or _in_building(sh.pos):
			dead.append(sh)
			continue
		for e in _enemies:
			if sh.pos.distance_to(e.pos) < ENEMY_TYPES[e.type].size + 6.0:
				_damage_enemy(e, sh.dmg)
				dead.append(sh)
				break
	for d in dead:
		_shots.erase(d)

func _tick_enemies(delta: float) -> void:
	var blades := _orbit_blades() if _weapons.orbit > 0 else []
	var blade_dmg: int = 1 + _dmg_bonus + int(_weapons.orbit / 2)
	var dead: Array = []
	for e in _enemies:
		var def: Dictionary = ENEMY_TYPES[e.type]
		var dir: Vector2 = (_pos - e.pos).normalized()
		e.pos = _collide_world(e.pos + dir * def.speed * delta, def.size * 0.7)
		e.contact_t = maxf(0.0, e.contact_t - delta)
		for bp in blades:
			if bp.distance_to(e.pos) < def.size + 12.0 and e.blade_t <= 0.0:
				e.blade_t = 0.35
				_damage_enemy(e, blade_dmg)
				break
		e.blade_t = maxf(0.0, e.blade_t - delta)
		if e.hp <= 0:
			dead.append(e)
			continue
		if e.contact_t <= 0.0 and _invuln <= 0.0 \
				and e.pos.distance_to(_pos) < def.size + 14.0:
			e.contact_t = CONTACT_CD
			_invuln = INVULN
			_hp -= 1
			# Knock the attacker back so it can't shred point-blank
			e.pos = _collide_world(e.pos + (e.pos - _pos).normalized() * 55.0,
				def.size * 0.7)
			if _hp <= 0:
				_finish(false)
				return
	for e in dead:
		_enemies.erase(e)

func _damage_enemy(e: Dictionary, dmg: int) -> void:
	e.hp -= dmg
	e.flash = 0.12
	if e.hp <= 0 and not e.get("scored", false):
		e.scored = true
		var def: Dictionary = ENEMY_TYPES[e.type]
		_score += def.pts
		_kills += 1
		_gems.append({ "pos": e.pos, "xp": def.xp })

func _tick_gems(delta: float) -> void:
	var got: Array = []
	for g in _gems:
		var d: float = g.pos.distance_to(_pos)
		if d < _magnet:
			g.pos = g.pos.move_toward(_pos, 420.0 * delta)
		if d < 18.0:
			got.append(g)
	for g in got:
		_gems.erase(g)
		_xp += g.xp
		if _xp >= _xp_next:
			_level_up()

func _tick_spawner(delta: float) -> void:
	_spawn_t -= delta
	var interval: float = maxf(0.22,
		_level_def.spawn_start - _time * _level_def.spawn_ramp)
	if _spawn_t <= 0.0 and _enemies.size() < MAX_ENEMIES:
		_spawn_t = interval
		# Level roster, weighted toward the newest unlocked type
		var pool: Array = []
		var roster: Dictionary = _level_def.roster
		for key in roster:
			if _time >= roster[key]:
				pool.append(key)
				if roster[key] > _time - 60.0:
					pool.append(key)   # freshly unlocked = double weight
		if pool.is_empty():
			pool.append(roster.keys()[0])
		var kind: String = pool[randi() % pool.size()]
		# Spawn on a street just off-camera (never inside a building)
		for attempt in 12:
			var a := randf() * TAU
			var sp: Vector2 = _pos + Vector2(cos(a), sin(a)) * randf_range(560.0, 700.0)
			sp.x = clampf(sp.x, 20.0, WORLD - 20.0)
			sp.y = clampf(sp.y, 20.0, WORLD - 20.0)
			if not _in_building(sp, 10.0):
				_enemies.append({ "pos": sp, "hp": ENEMY_TYPES[kind].hp,
					"type": kind, "contact_t": 0.0, "blade_t": 0.0, "flash": 0.0 })
				break


# ═══════════════════════════════════════════════════════════════════════
# LEVEL-UP
# ═══════════════════════════════════════════════════════════════════════

func _level_up() -> void:
	_level += 1
	_xp = 0
	_xp_next = int(5.0 * _level * pow(1.15, _level))
	_choices = _roll_choices()
	_picking = true
	_show_picker()

func _weapon_choice(id: String, title: String, desc: String) -> Dictionary:
	return { "id": id, "label": "%s %s" % [title,
		("LV %d" % (_weapons[id] + 1)) if _weapons[id] > 0 else "— NEW"],
		"desc": desc }

func _roll_choices() -> Array:
	var pool: Array = []
	if _weapons.katana < 6:
		pool.append(_weapon_choice("katana", "KATANA", "wider, faster slash"))
	if _weapons.plasma < 6:
		pool.append(_weapon_choice("plasma", "PLASMA BOLT", "auto-shot at nearest"))
	if _weapons.orbit < 6:
		pool.append(_weapon_choice("orbit", "ORBIT BLADE", "blades circle you"))
	if _weapons.nova < 6:
		pool.append(_weapon_choice("nova", "NOVA PULSE", "periodic shockwave"))
	pool.append({ "id": "speed", "label": "CHROME LEGS", "desc": "+10% move speed" })
	pool.append({ "id": "magnet", "label": "MAGNET AURA", "desc": "+40% pickup radius" })
	pool.append({ "id": "razor", "label": "RAZOR EDGE", "desc": "+1 all weapon damage" })
	pool.append({ "id": "heal", "label": "NANO PATCH", "desc": "restore 2 HP" })
	pool.shuffle()
	return pool.slice(0, 3)

func _apply_choice(choice: Dictionary) -> void:
	match choice.id:
		"katana": _weapons.katana += 1
		"plasma": _weapons.plasma += 1
		"orbit": _weapons.orbit += 1
		"nova": _weapons.nova += 1
		"speed": _speed_mult += 0.10
		"magnet": _magnet *= 1.4
		"razor": _dmg_bonus += 1
		"heal": _hp = mini(PLAYER_MAX_HP, _hp + 2)
	_picking = false

func _show_picker() -> void:
	_pick_menu = ListMenuScript.new()
	add_child(_pick_menu)
	_pick_menu.picked.connect(func(idx):
		if idx < _choices.size():
			_apply_choice(_choices[idx])
			_pick_menu.close_menu())
	_pick_menu.closed.connect(func():
		_pick_menu = null
		if _picking:
			_show_picker())   # no skipping upgrades: ESC reopens
	var entries: Array = []
	for ch in _choices:
		entries.append({ "label": "%s · %s" % [ch.label, ch.desc] })
	_pick_menu.open("LEVEL %d · choose upgrade" % _level, entries,
		Color(0.3, 1.0, 0.9))


# ═══════════════════════════════════════════════════════════════════════
# END + INPUT
# ═══════════════════════════════════════════════════════════════════════

func _finish(won: bool) -> void:
	_game_over = true
	if won:
		GameState.set_flag("survivorsCleared_" + _level_id)
	GameState.submit_arcade_score("survivors_" + _level_id, _score)
	var new_best := GameState.submit_arcade_score("survivors", _score)
	var beat_chad: bool = _score > CHAD_SCORE and not GameState.has_flag("chadBeaten")
	if _score > CHAD_SCORE:
		GameState.set_flag("chadBeaten")
	_over_layer = CanvasLayer.new()
	add_child(_over_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.position = Vector2(640 - 220, 250)
	_over_layer.add_child(box)
	var l1 := Label.new()
	l1.text = ("SECTOR CLEARED — NEXT SECTOR UNLOCKED" if _level_id != "oldtown" else "ALL SECTORS CLEARED") if won else "FLATLINED"
	l1.add_theme_font_size_override("font_size", 40)
	l1.add_theme_color_override("font_color",
		Color(0.3, 1.0, 0.6) if won else Color(1.0, 0.2, 0.5))
	box.add_child(l1)
	var l2 := Label.new()
	l2.text = "SCORE: %d   ·   KILLS: %d   ·   %d:%02d%s" % [_score, _kills,
		int(_time) / 60, int(_time) % 60, "   ★ NEW BEST" if new_best else ""]
	l2.add_theme_font_size_override("font_size", 22)
	l2.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
	box.add_child(l2)
	if beat_chad:
		var l4 := Label.new()
		l4.text = "you beat CHAD's 3000. he saw the whole thing."
		l4.add_theme_font_size_override("font_size", 20)
		l4.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		box.add_child(l4)
	var l3 := Label.new()
	l3.text = "[E] run it back   ·   ESC exit"
	l3.add_theme_font_size_override("font_size", 18)
	l3.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	box.add_child(l3)

func _exit_to_arcade() -> void:
	SceneTransition.go("arcade", "from_game_survivors")

func _unhandled_input(event: InputEvent) -> void:
	if _selecting or _picking:
		return   # ListMenu owns input while a menu is up
	if event.is_action_pressed("ui_cancel"):
		_exit_to_arcade()
		return
	if _game_over and (event.is_action_pressed("interact") \
			or event.is_action_pressed("ui_accept")):
		get_tree().reload_current_scene()


# ═══════════════════════════════════════════════════════════════════════
# DRAW — streets, buildings, neon, sprite hordes, weapons
# ═══════════════════════════════════════════════════════════════════════

func _sprite_frame(moving: bool) -> int:
	return (int(_anim_t * 8.0) % 3) if moving else 0

func _draw_sheet(b: Node2D, tex: Texture2D, at: Vector2, row: int,
		frame: int, tint: Color = Color(1, 1, 1)) -> void:
	b.draw_texture_rect_region(tex,
		Rect2(at - Vector2(FRAME_W * 0.5, FRAME_H - 12.0), Vector2(FRAME_W, FRAME_H)),
		Rect2(frame * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H), tint)

func _draw_world(b: Node2D) -> void:
	# Asphalt base
	b.draw_rect(Rect2(Vector2.ZERO, Vector2(WORLD, WORLD)), Color(0.016, 0.016, 0.032), true)
	# Street center dashes along the grid
	var pitch := 360.0
	var n := int(WORLD / pitch)
	for i in n + 1:
		var y := 8.0
		while y < WORLD:
			b.draw_rect(Rect2(Vector2(i * pitch - 2.0, y), Vector2(4.0, 22.0)),
				Color(0.35, 0.28, 0.05), true)
			b.draw_rect(Rect2(Vector2(y, i * pitch - 2.0), Vector2(22.0, 4.0)),
				Color(0.35, 0.28, 0.05), true)
			y += 60.0
	# Lamp light pools (under everything else)
	for lp in _lamps:
		b.draw_circle(lp, 85.0, Color(0.10, 0.08, 0.14, 0.5))
		b.draw_circle(lp, 40.0, Color(0.16, 0.13, 0.20, 0.5))
	# Buildings — dark slab + rim + windows + neon signs
	for r in _buildings:
		b.draw_rect(r, Color(0.045, 0.035, 0.07), true)
		b.draw_rect(Rect2(r.position, Vector2(r.size.x, 4.0)), Color(0.09, 0.07, 0.13), true)
		b.draw_rect(Rect2(r.position, Vector2(4.0, r.size.y)), Color(0.075, 0.06, 0.11), true)
		# Rooftop windows / vents grid (sparse dots)
		var wx: float = r.position.x + 18.0
		while wx < r.end.x - 18.0:
			var wy: float = r.position.y + 18.0
			while wy < r.end.y - 18.0:
				if int(wx * 0.13 + wy * 0.31) % 5 == 0:
					b.draw_rect(Rect2(Vector2(wx, wy), Vector2(6.0, 6.0)),
						Color(0.55, 0.45, 0.25), true)
				wy += 46.0
			wx += 46.0
	for s in _signs:
		b.draw_rect(s.rect, s.color, true)
	# Street lamps — posts + hot heads
	for lp in _lamps:
		b.draw_rect(Rect2(lp - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(0.3, 0.3, 0.35), true)
		b.draw_circle(lp, 4.5, Color(1.7, 1.5, 1.0))
	# World edge
	var t := 10.0
	for r in [Rect2(-t, -t, WORLD + t * 2, t), Rect2(-t, WORLD, WORLD + t * 2, t),
			Rect2(-t, 0, t, WORLD), Rect2(WORLD, 0, t, WORLD)]:
		b.draw_rect(r, Color(1.4, 0.0, 1.4), true)
	# Gems
	for g in _gems:
		b.draw_colored_polygon(PackedVector2Array([
			g.pos + Vector2(0, -7), g.pos + Vector2(6, 0),
			g.pos + Vector2(0, 7), g.pos + Vector2(-6, 0)]), Color(0.2, 1.7, 0.9))
	# Enemies — real sprites, facing their movement, flashing when hit
	for e in _enemies:
		var def: Dictionary = ENEMY_TYPES[e.type]
		var to: Vector2 = _pos - e.pos
		var row := Facing.DOWN
		if absf(to.x) >= absf(to.y):
			row = Facing.RIGHT if to.x > 0 else Facing.LEFT
		else:
			row = Facing.DOWN if to.y > 0 else Facing.UP
		e.flash = maxf(0.0, e.flash - 0.016)
		var tint: Color = def.tint
		if e.flash > 0.0:
			tint = Color(2.2, 2.2, 2.2)
		_draw_sheet(b, _sheets[def.sheet], e.pos, row, int(_anim_t * 7.0 + e.pos.x) % 3, tint)
	# Shots
	for sh in _shots:
		b.draw_circle(sh.pos, 5.0, Color(0.2, 1.7, 1.7))
	# Orbit blades
	if _weapons.orbit > 0:
		for bp in _orbit_blades():
			b.draw_colored_polygon(PackedVector2Array([
				bp + Vector2(0, -10), bp + Vector2(8, 0),
				bp + Vector2(0, 10), bp + Vector2(-8, 0)]), Color(1.7, 1.4, 0.2))
	# Katana slash flash — a small tight crescent, not a giant ring
	if not _slash.is_empty():
		var alpha: float = _slash.life / 0.12
		var slash_r: float = _slash.reach * 0.62 * (1.15 - alpha * 0.15)
		b.draw_arc(_pos, slash_r,
			_slash.angle - deg_to_rad(42.0), _slash.angle + deg_to_rad(42.0),
			14, Color(1.8, 1.8, 2.0, alpha), 4.0)
		b.draw_arc(_pos, slash_r - 5.0,
			_slash.angle - deg_to_rad(32.0), _slash.angle + deg_to_rad(32.0),
			12, Color(1.6, 0.3, 1.2, alpha * 0.6), 2.5)
	# Nova ring
	if _nova_flash > 0.0:
		b.draw_arc(_pos, _nova_radius() * (1.0 - _nova_flash * 0.3), 0, TAU, 48,
			Color(0.3, 1.6, 1.0, _nova_flash), 6.0)
	# Player — YOUR sprite, ported into the game
	var tint := Color(1, 1, 1) if _invuln <= 0.0 else Color(2.0, 2.0, 2.0)
	b.draw_circle(_pos + Vector2(0, 8.0), 12.0, Color(0.0, 0.0, 0.0, 0.4))
	_draw_sheet(b, _player_sheet, _pos, _face_row, _sprite_frame(_moving), tint)


# ═══════════════════════════════════════════════════════════════════════
# HUD
# ═══════════════════════════════════════════════════════════════════════

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	# HBox so nothing overlaps no matter how long the sector name gets
	var bar := HBoxContainer.new()
	bar.anchor_right = 1.0
	bar.offset_left = 30
	bar.offset_top = 8
	bar.offset_right = -160
	bar.add_theme_constant_override("separation", 30)
	cl.add_child(bar)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.6))
	bar.add_child(title)
	_hud["title"] = title
	for key in ["score", "best", "hp", "lvl", "time"]:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		l.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
		bar.add_child(l)
		_hud[key] = l
	_hud.best.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_hud.hp.add_theme_color_override("font_color", Color(1.0, 0.3, 0.5))
	_hud.lvl.add_theme_color_override("font_color", Color(0.7, 0.6, 1.0))
	var exit_btn := Button.new()
	exit_btn.text = "EXIT GAME"
	exit_btn.anchor_left = 1.0
	exit_btn.anchor_right = 1.0
	exit_btn.offset_left = -140
	exit_btn.offset_right = -30
	exit_btn.offset_top = 8
	exit_btn.offset_bottom = 40
	exit_btn.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.02, 0.04, 0.9)
	sb.border_color = Color(1.0, 0.25, 0.5)
	sb.set_border_width_all(2)
	exit_btn.add_theme_stylebox_override("normal", sb)
	exit_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.7))
	exit_btn.pressed.connect(_exit_to_arcade)
	cl.add_child(exit_btn)
	var hint := Label.new()
	hint.text = "WASD move · weapons auto-fire · beat CHAD's 3000 · ESC exit"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 30
	hint.offset_top = -26
	hint.offset_bottom = -8
	cl.add_child(hint)
	_refresh_hud()

func _refresh_hud() -> void:
	if _level_def.is_empty():
		return
	_hud.title.text = _level_def.name
	_hud.score.text = "SCORE %d" % _score
	_hud.best.text = "BEST %d" % GameState.arcade_best("survivors")
	_hud.hp.text = "♥ %d/%d" % [_hp, PLAYER_MAX_HP]
	_hud.lvl.text = "LVL %d  XP %d/%d" % [_level, _xp, _xp_next]
	_hud.time.text = "%d:%02d" % [int(_time) / 60, int(_time) % 60]
