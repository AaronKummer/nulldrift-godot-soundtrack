## Dungeon — the REUSABLE dungeon runtime. Which dungeon you're in comes
## from GameState.pending_dungeon (set by the entrance: city manhole =
## "sewer"; office towers and corpo complexes plug in the same way).
##
## The maze is PROCEDURAL — DungeonGen rolls a fresh layout every visit:
## rooms, corridors, flooded halls with plank bridges, flavor rooms (moss /
## servers / labs), spawner grates, rat holes, randomized pickups.
##
## Combat is the NEON SURVIVORS style with real stakes: GameState HP,
## credit drops, items (1 medkit / 2 grenade / 3 stim), SPACE dash, F nova.
## Every lock runs through the reusable PuzzleOverlay: grates spawn forever
## until you solve the PIPE VALVE puzzle at them (mouse, while the horde
## closes in — damage kicks you off), chests take a LOCKPICK, and the relay
## node takes a WIRE-MATCH hack. Seal every grate for a payout.
extends Node2D

const DungeonDefsData := preload("res://data/dungeon_defs.gd")
const DungeonGenSys := preload("res://scripts/systems/dungeon_gen.gd")
const PuzzleOverlayScript := preload("res://scripts/systems/puzzle_overlay.gd")

const CELL := 180.0
const PLAYER_SPEED := 175.0
const INVULN := 0.5
const CONTACT_CD := 0.7
const DASH_TIME := 0.16
const DASH_SPEED := 3.4
const DASH_CD := 2.5
const NOVA_CD := 8.0
const NOVA_RADIUS := 140.0
const NOVA_DMG := 10
const KATANA_REACH := 84.0
const KATANA_DMG := 4
const KATANA_CD := 0.55
const MEDKIT_HEAL := 35
const MEDKIT_DROP_CHANCE := 0.08
# Pipe puzzle (grate seal): rotate tiles to reconnect the flow
const PIPE_COLS := 4
const PIPE_ROWS := 3
const PIPE_TILE := 96.0
const GRENADE_RADIUS := 170.0
const GRENADE_DMG := 12
const STIM_DURATION := 5.0
const STIM_MULT := 1.6
const ELITE_CHANCE := 0.10

const FRAME_W := 48.0
const FRAME_H := 64.0
enum Facing { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

var _def: Dictionary = {}
var _pal: Dictionary = {}
var _gen: Dictionary = {}
var _sheets := {}
var _player_sheet: Texture2D
var _floor_board
var _water_board
var _blackout_board
var _blackouts: Array = []
var _torch: PointLight2D
var _relay_light: PointLight2D
var _light_tex: GradientTexture2D
var _flickers: Array = []
var _low_lights := false
const TEX_FLOOR := preload("res://assets/world/textures/concrete/albedo.png")
const TEX_WALL := preload("res://assets/world/textures/metal_brushed/albedo.png")

var _walls: Array = []         # Rect2 (collision + draw)
var _waters: Array = []        # Rect2 (collision, drawn as water)
var _grates: Array = []        # {pos, sealed, t}
var _chests: Array = []        # {pos, opened}
var _holes: Array = []         # {pos, t}
var _pickups: Array = []       # {pos, kind}
var _relay_pos := Vector2.ZERO
var _spawn_point := Vector2.ZERO

var _pos := Vector2.ZERO
var _facing := Vector2.DOWN
var _face_row := Facing.DOWN
var _moving := false
var _anim_t := 0.0
var _invuln := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.ZERO
var _nova_cd := 0.0
var _nova_flash := 0.0
var _katana_t := 0.0
var _slash: Dictionary = {}
var _enemies: Array = []
var _coins: Array = []
var _puzzle: Dictionary = {}   # active grate-seal pipe puzzle
var _puzzle_ui: Control
var _stim_t := 0.0
var _dead := false

var _cam: Camera2D
var _board: Node2D
var _hud := {}
var _status_label: Label

func _ready() -> void:
	_def = DungeonDefsData.get_def(GameState.pending_dungeon)
	_pal = _def.pal
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.15
	env.glow_strength = 1.15
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
		"cat": load("res://assets/sprites/cyberCat.png"),
		"cyberGirl": load("res://assets/sprites/cyberGirl.png"),
		"rat": load("res://assets/sprites/sewerRat.png"),
		"gator": load("res://assets/sprites/kingCroc.png"),
		"mutant": load("res://assets/sprites/sewerCroc.png"),
		"troll": load("res://assets/sprites/sewerTroll.png"),
		"yak1": load("res://assets/sprites/Yakuza1.png"),
		"yak2": load("res://assets/sprites/Yakuza2.png"),
		"yak3": load("res://assets/sprites/Yakuza3.png"),
		"yakboss": load("res://assets/sprites/YakuzaBoss.png"),
	}
	_player_sheet = load("res://assets/sprites/player-pizza.png")
	# Fresh maze every visit
	# Layout seed persists per save: the maze is stable when you come back
	# in, but a fresh playthrough rolls new dungeons. Enemies and chest
	# contents use the global RNG at runtime, so every visit is reinhabited.
	var did: String = GameState.pending_dungeon
	if not GameState.dungeon_seeds.has(did):
		GameState.dungeon_seeds[did] = randi()
	if _def.has("layout"):
		_gen = DungeonGenSys.from_layout(_def)   # authored — never random
	else:
		_gen = DungeonGenSys.generate(_def, GameState.dungeon_seeds[did])
	_bake_geometry()
	_pos = _cell_center(_gen.entrance)
	_spawn_point = _pos
	_cam = Camera2D.new()
	_cam.zoom = Vector2(1.35, 1.35)
	_cam.position = _pos
	add_child(_cam)
	_cam.make_current()
	_floor_board = _FloorBoard.new()
	_floor_board.game = self
	_floor_board.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_floor_board)
	_water_board = _WaterBoard.new()
	_water_board.game = self
	var wmat := ShaderMaterial.new()
	wmat.shader = load("res://assets/world/sewer_water.gdshader")
	wmat.set_shader_parameter("deep", _pal.water * 0.32)
	wmat.set_shader_parameter("shallow", _pal.water * 0.95)
	wmat.set_shader_parameter("glint", _pal.water_shine * 1.5)
	wmat.set_shader_parameter("scum", _pal.floor_flavor * 0.8)
	_water_board.material = wmat
	add_child(_water_board)
	_board = _Board.new()
	_board.game = self
	_board.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	add_child(_board)
	_blackout_board = _BlackoutBoard.new()
	_blackout_board.game = self
	add_child(_blackout_board)
	_build_lights()
	_build_hud()
	SceneTransition.consume_spawn()
	if not GameState.has_item("headlamp"):
		_set_status("pitch black down here. GUNS+ sells headlamps.")
	Music.play_category("dungeon")

class _Board extends Node2D:
	var game
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		game._draw_world(self)

class _FloorBoard extends Node2D:
	var game
	func _draw() -> void:
		game._draw_floor(self)

class _WaterBoard extends Node2D:
	var game
	func _draw() -> void:
		game._draw_water(self)

class _BlackoutBoard extends Node2D:
	var game
	func _draw() -> void:
		# Heavy murk over blackout rooms. Lights still add on top, so a
		# headlamp carves visibility into it.
		for bo in game._blackouts:
			draw_rect(bo.rect, Color(0, 0, 0, 0.62), true)

func _cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * CELL, (c.y + 0.5) * CELL)

func _bake_geometry() -> void:
	# Merge horizontal runs of wall/water tiles into rects
	var tiles: Array = _gen.tiles
	for y in _gen.h:
		var x := 0
		while x < _gen.w:
			var t: int = tiles[y][x]
			if t == DungeonGenSys.T_WALL or t == DungeonGenSys.T_WATER:
				var run_start := x
				while x < _gen.w and tiles[y][x] == t:
					x += 1
				var rect := Rect2(run_start * CELL, y * CELL, (x - run_start) * CELL, CELL)
				if t == DungeonGenSys.T_WALL:
					_walls.append(rect)
				else:
					_waters.append(rect)
			else:
				x += 1
	for g in _gen.grates:
		_grates.append({ "pos": _cell_center(g), "sealed": false, "t": randf() * 2.0 })
	for hcell in _gen.holes:
		_holes.append({ "pos": _cell_center(hcell), "t": randf() * 3.0 })
	for m in _gen.medkits:
		_pickups.append({ "pos": _cell_center(m), "kind": "medkit" })
	for ch in _gen.chests:
		_chests.append({ "pos": _cell_center(ch), "opened": false })
	_pickups.append({ "pos": _cell_center(_gen.stash), "kind": "stash" })
	_relay_pos = _cell_center(_gen.objective)
	# Boss arena in the farthest room — skipped once its flag is earned
	# (Rezz fled; the rematch is its own encounter later)
	if _def.has("boss") and not GameState.has_flag(str(_def.boss.get("flag", ""))):
		var br: Rect2i = _gen.boss_room
		_boss = {
			"pos": _cell_center(_gen.boss_pos),
			"room": Rect2(br.position.x * CELL, br.position.y * CELL,
				br.size.x * CELL, br.size.y * CELL).grow(CELL * 0.4),
			"hp": _def.boss.hp, "hp_max": _def.boss.hp,
			"active": false, "done": false,
			"state": "chase", "state_t": 0.0, "charge_dir": Vector2.RIGHT,
			"spray_cd": 3.0, "summon_cd": 4.0, "charge_cd": 5.5,
			"contact_t": 0.0, "flash": 0.0, "flee_t": 0.0,
		}
	# Blackout rooms — no fixtures, near-zero visibility. Selection is
	# seeded off the layout seed so the same rooms are dark every re-entry.
	var brng := RandomNumberGenerator.new()
	brng.seed = int(GameState.dungeon_seeds.get(GameState.pending_dungeon, 0)) + 777
	for i in range(1, _gen.rooms.size()):
		var room: Rect2i = _gen.rooms[i]
		var wr := Rect2(room.position.x * CELL, room.position.y * CELL,
			room.size.x * CELL, room.size.y * CELL)
		if wr.has_point(_relay_pos) or wr.has_point(_cell_center(_gen.stash)):
			continue
		if brng.randf() < 0.30:
			_blackouts.append({ "rect": wr, "cells": room, "warned": false })

func _world_size() -> Vector2:
	return Vector2(_gen.w * CELL, _gen.h * CELL)

func _collide(p: Vector2, radius: float) -> Vector2:
	var ws := _world_size()
	p.x = clampf(p.x, radius, ws.x - radius)
	p.y = clampf(p.y, radius, ws.y - radius)
	for solids in [_walls, _waters]:
		for r in solids:
			var grown: Rect2 = r.grow(radius)
			if grown.has_point(p):
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


# ═══════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ═══════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if _dead:
		return
	_anim_t += delta
	_tick_player(delta)
	_tick_katana(delta)
	_tick_bullets(delta)
	_tick_boss(delta)
	_tick_ebullets(delta)
	_tick_gear(delta)
	_tick_skills(delta)
	_tick_enemies(delta)
	_tick_spawners(delta)
	_tick_loot(delta)
	_tick_lights()
	_tick_blackout_warning()
	_cam.position = _pos
	_refresh_hud()

func _tick_player(delta: float) -> void:
	# Locked in place while working a lock — hands are busy
	if not _puzzle.is_empty():
		# Self-heal: never leave movement stuck if the overlay closed oddly
		if _overlay == null or not _overlay.active:
			_puzzle = {}
			_puzzle_ctx = {}
		else:
			_invuln = maxf(0.0, _invuln - delta)
			_set_status("hands busy — solve it or ESC to step back")
			return
	_stim_t = maxf(0.0, _stim_t - delta)
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_moving = input.length() > 0.1
	if _moving:
		_facing = input.normalized()
		if absf(input.x) >= absf(input.y):
			_face_row = Facing.RIGHT if input.x > 0 else Facing.LEFT
		else:
			_face_row = Facing.DOWN if input.y > 0 else Facing.UP
	var vel := input * PLAYER_SPEED * (STIM_MULT if _stim_t > 0.0 else 1.0)
	if _dash_t > 0.0:
		_dash_t -= delta
		vel = _dash_dir * PLAYER_SPEED * DASH_SPEED
	_pos = _collide(_pos + vel * delta, 14.0)
	_invuln = maxf(0.0, _invuln - delta)
	# Context prompts
	if _pos.distance_to(_spawn_point) < 60.0:
		_set_status("[E] " + _def.exit_label)
	elif _pos.distance_to(_relay_pos) < 70.0:
		if _def.get("objective_kind", "relay") == "rescue":
			if GameState.has_flag(_def.objective_flag):
				_set_status("the cage hangs open. she's long gone. good.")
			else:
				_set_status("[E] break the cage open")
		elif GameState.has_flag(_def.objective_flag):
			_set_status("the relay node hums. encrypted traffic.")
		else:
			_set_status("[E] jack into the relay node")
	elif _nearby_grate() != null:
		_set_status("[E] seal the grate valve")
	elif _nearby_chest() != null:
		_set_status("[E] locked chest — pick it")
	else:
		_set_status("")

func _nearby_grate() -> Variant:
	for g in _grates:
		if not g.sealed and g.pos.distance_to(_pos) < 80.0:
			return g
	return null

func _nearby_chest() -> Variant:
	for ch in _chests:
		if not ch.opened and ch.pos.distance_to(_pos) < 70.0:
			return ch
	return null

# ── Equipped-weapon combat — the Phaser SharedCombat port. Melee honors
# weapon.speed/range/damage; ranged weapons auto-aim with ammo + reload;
# specials (pierce, pellets, burst, chain, double strike, life steal,
# status effects) are canon. Phaser px → dungeon px via WEAPON_SCALE.
const WEAPON_SCALE := 3.5
const BULLET_SPEED := 950.0
const RELOAD_TIME := 1.5

var _bullets: Array = []
var _reload_t := 0.0
var _regen_acc := 0.0
var _boss: Dictionary = {}     # boss encounter state (empty = no boss here)
var _ebullets: Array = []      # enemy + boss projectiles

func _tick_katana(delta: float) -> void:
	_katana_t -= delta
	_reload_t = maxf(0.0, _reload_t - delta)
	if not _slash.is_empty():
		_slash.life -= delta
		if _slash.life <= 0.0:
			_slash = {}
	var w: Dictionary = GameState.weapon_def()
	var cd: float = float(w.get("speed", 280)) / 1000.0
	var dmg: int = maxi(1, roundi(float(w.get("damage", 1)) * (1.0 + GameState.damage_bonus())))
	if w.get("type", "melee") == "melee":
		if _katana_t > 0.0:
			return
		var reach: float = float(w.get("range", 24)) * WEAPON_SCALE + 12.0
		var target := _acquire_target(reach + 24.0)
		if target.is_empty():
			return
		var dir: Vector2 = (target.pos - _pos).normalized()
		var strikes: int = 2 if w.get("double_strike", false) else 1
		var hit_any := false
		for s in strikes:
			for e in _enemies:
				var to: Vector2 = e.pos - _pos
				if to.length() <= reach + _def.enemies[e.type].size 						and absf(to.angle_to(dir)) < deg_to_rad(60.0):
					_hit_enemy(e, dmg, w)
					hit_any = true
			if not _boss.is_empty() and _boss.active and not _boss.done:
				var tob: Vector2 = _boss.pos - _pos
				if tob.length() <= reach + _def.boss.size 						and absf(tob.angle_to(dir)) < deg_to_rad(60.0):
					_hit_boss(dmg, w)
					hit_any = true
		# Chain (mjolnir): arcs to N extra enemies beyond the swing
		if hit_any and w.has("chain"):
			var extra: int = w.get("chain", 0)
			for e in _enemies:
				if extra <= 0:
					break
				var to: Vector2 = e.pos - _pos
				if to.length() > reach and to.length() <= reach + 160.0:
					_hit_enemy(e, dmg, w)
					extra -= 1
		_katana_t = cd
		_slash = { "angle": dir.angle(), "life": 0.12, "reach": reach }
	else:
		# Ranged — auto-aim nearest in range, honor ammo + auto-reload
		if _reload_t > 0.0 or _katana_t > 0.0:
			return
		var rng_px: float = float(w.get("range", 150)) * WEAPON_SCALE
		var target := _acquire_target(rng_px)
		if target.is_empty():
			return
		var wid: String = GameState.equipped_weapon
		var ammo: int = GameState.ammo_left(wid)
		if ammo <= 0:
			_reload_t = RELOAD_TIME
			GameState.set_ammo(wid, int(w.get("max_ammo", 1)))
			_set_status("reloading...")
			return
		var dir: Vector2 = (target.pos - _pos).normalized()
		var shots: int = int(w.get("pellets", w.get("burst", 1)))
		var spread: float = 0.16 if w.has("pellets") else 0.05
		for s in shots:
			var jitter: float = 0.0 if shots == 1 else (s - (shots - 1) * 0.5) * spread
			_bullets.append({
				"pos": _pos + dir * 20.0,
				"dir": dir.rotated(jitter),
				"dmg": dmg,
				"left": rng_px,
				"pierce": w.get("piercing", false),
				"explosive": w.get("explosive", false),
				"w": w,
				"hit": [],
			})
		GameState.set_ammo(wid, ammo - 1)
		_katana_t = cd

func _tick_bullets(delta: float) -> void:
	var dead: Array = []
	for b in _bullets:
		var step: float = BULLET_SPEED * delta
		b.pos += b.dir * step
		b.left -= step
		if b.left <= 0.0 or _collide(b.pos, 3.0) != b.pos:
			dead.append(b)
			continue
		if not _boss.is_empty() and _boss.active and not _boss.done 				and not b.hit.has("boss") 				and b.pos.distance_to(_boss.pos) <= _def.boss.size + 8.0:
			_hit_boss(b.dmg, b.w)
			b.hit.append("boss")
			if not b.pierce:
				dead.append(b)
				continue
		for e in _enemies:
			if b.hit.has(e):
				continue
			if b.pos.distance_to(e.pos) <= _def.enemies[e.type].size + 6.0:
				_hit_enemy(e, b.dmg, b.w)
				b.hit.append(e)
				if b.explosive:
					_boom_flash = maxf(_boom_flash, 0.4)
					for e2 in _enemies:
						if e2 != e and e.pos.distance_to(e2.pos) <= 70.0:
							_hit_enemy(e2, maxi(1, b.dmg / 2), b.w)
				if not b.pierce:
					dead.append(b)
					break
	for b in dead:
		_bullets.erase(b)

## One weapon hit landing on an enemy — damage + canon specials
func _hit_enemy(e: Dictionary, dmg: int, w: Dictionary) -> void:
	_damage_enemy(e, dmg)
	var ls: float = w.get("life_steal", 0.0)
	if ls > 0.0:
		GameState.hp = mini(GameState.hp_max, GameState.hp + maxi(1, roundi(dmg * ls)))
	match w.get("status", ""):
		"stun", "emp":
			e["stun_t"] = 1.2
		"slow":
			e["slow_t"] = 2.2
		"burn":
			e["burn_t"] = 3.0

# ── Boss encounter — Phaser act-climax fights, def-driven. Patterns:
# chase, telegraphed charge, bullet spray, add summons. Bosses with
# flee_at escape at low HP (Rezz canon: "flees to return").
func _tick_boss(delta: float) -> void:
	if _boss.is_empty() or _boss.done:
		return
	var bdef: Dictionary = _def.boss
	if not _boss.active:
		if _boss.room.has_point(_pos):
			_boss.active = true
			Music.play_category("boss")
			DialogueOverlay.play_lines([{ "speaker": "", 					"text": bdef.get("bark_intro", "..."),
					"color": Color(1.3, 0.5, 0.3) }], "boss_intro")
		return
	_boss.flash = maxf(0.0, _boss.flash - delta)
	_boss.contact_t = maxf(0.0, _boss.contact_t - delta)
	if _boss.state == "flee":
		_boss.flee_t -= delta
		_boss.pos += _boss.charge_dir * bdef.speed * 3.5 * delta
		if _boss.flee_t <= 0.0:
			_boss_end(true)
		return
	var to_player: Vector2 = _pos - _boss.pos
	var dir: Vector2 = to_player.normalized()
	match _boss.state:
		"chase":
			_boss.pos = _collide(_boss.pos + dir * bdef.speed * delta, bdef.size * 0.7)
			_boss.charge_cd -= delta
			_boss.spray_cd -= delta
			_boss.summon_cd -= delta
			if bdef.get("charge", false) and _boss.charge_cd <= 0.0 					and to_player.length() < 520.0:
				_boss.state = "telegraph"
				_boss.state_t = 0.55
			elif bdef.has("spray") and _boss.spray_cd <= 0.0:
				var n: int = bdef.spray.count
				for i in n:
					var a: float = dir.angle() + (i - (n - 1) * 0.5) * 0.22
					_ebullets.append({ "pos": _boss.pos, "dir": Vector2.from_angle(a),
						"dmg": bdef.spray.dmg, "left": 900.0 })
				_boss.spray_cd = bdef.spray.cd
			elif bdef.has("summon") and _boss.summon_cd <= 0.0 					and _enemies.size() < int(bdef.summon.get("max", 5)):
				for i in int(bdef.summon.count):
					_spawn_enemy(_boss.pos, bdef.summon.pool)
				_boss.summon_cd = bdef.summon.cd
		"telegraph":
			_boss.state_t -= delta
			_boss.charge_dir = dir
			if _boss.state_t <= 0.0:
				_boss.state = "charge"
				_boss.state_t = 0.7
		"charge":
			_boss.state_t -= delta
			_boss.pos = _collide(_boss.pos + _boss.charge_dir * bdef.speed * 4.2 * delta,
				bdef.size * 0.7)
			if _boss.state_t <= 0.0:
				_boss.state = "chase"
				_boss.charge_cd = 5.5
	# Contact damage — charging hits harder
	if _boss.contact_t <= 0.0 and _invuln <= 0.0 and _dash_t <= 0.0 			and _boss.pos.distance_to(_pos) < bdef.size + 16.0:
		_boss.contact_t = CONTACT_CD
		_invuln = INVULN
		GameState.take_damage(bdef.dmg + (6 if _boss.state == "charge" else 0))
		if GameState.hp <= 0:
			_die()

func _hit_boss(dmg: int, w: Dictionary) -> void:
	if _boss.is_empty() or not _boss.active or _boss.done or _boss.state == "flee":
		return
	_boss.hp -= dmg * int(w.get("boss_multiplier", 1))
	_boss.flash = 0.12
	var ls: float = w.get("life_steal", 0.0)
	if ls > 0.0:
		GameState.hp = mini(GameState.hp_max, GameState.hp + maxi(1, roundi(dmg * ls)))
	var flee_at: float = _def.boss.get("flee_at", 0.0)
	if flee_at > 0.0 and _boss.hp <= _boss.hp_max * flee_at:
		_boss.state = "flee"
		_boss.flee_t = 1.2
		_boss.charge_dir = (_boss.pos - _pos).normalized()
		DialogueOverlay.play_lines([{ "speaker": "", 				"text": _def.boss.get("bark_flee", "..."),
				"color": Color(1.3, 0.5, 0.3) }], "boss_flee")
	elif _boss.hp <= 0:
		_boss_end(false)

func _boss_end(fled: bool) -> void:
	_boss.done = true
	var bdef: Dictionary = _def.boss
	GameState.add_credits(int(bdef.get("credits", 0)))
	for d in bdef.get("drops", []):
		if not GameState.has_item(d):
			GameState.add_item(d)
			_set_status("%s %s: %s dropped — equip it in the phone GEAR app" 					% [bdef.name, "bolted" if fled else "down", str(d).to_upper()])
	if str(bdef.get("flag", "")) != "":
		GameState.set_flag(str(bdef.flag))
	Music.play_category("dungeon")

## Weapon targeting that sees the boss as well as the mobs
func _acquire_target(max_d: float) -> Dictionary:
	var t := _nearest_enemy(max_d)
	if not _boss.is_empty() and _boss.active and not _boss.done and _boss.state != "flee":
		var bd: float = _pos.distance_to(_boss.pos)
		if bd <= max_d and (t.is_empty() or bd < _pos.distance_to(t.pos)):
			return { "pos": _boss.pos, "is_boss": true }
	return t

func _tick_ebullets(delta: float) -> void:
	var dead: Array = []
	for eb in _ebullets:
		var step: float = 420.0 * delta
		eb.pos += eb.dir * step
		eb.left -= step
		if eb.left <= 0.0 or _collide(eb.pos, 3.0) != eb.pos:
			dead.append(eb)
			continue
		if _invuln <= 0.0 and _dash_t <= 0.0 and eb.pos.distance_to(_pos) < 16.0:
			GameState.take_damage(int(eb.dmg))
			_invuln = INVULN * 0.6
			dead.append(eb)
			if GameState.hp <= 0:
				_die()
				return
	for eb in dead:
		_ebullets.erase(eb)

## Gear passives — shield recharge + hp regen (generators, nanoweave...)
func _tick_gear(delta: float) -> void:
	var ms: float = GameState.max_shield()
	if ms > 0.0:
		GameState.shield_hp = minf(ms, GameState.shield_hp + GameState.shield_recharge() * delta)
	var regen: float = GameState.hp_regen()
	if regen > 0.0 and GameState.hp < GameState.hp_max:
		_regen_acc += regen * delta
		if _regen_acc >= 1.0:
			_regen_acc -= 1.0
			GameState.hp += 1

func _tick_skills(delta: float) -> void:
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_nova_cd = maxf(0.0, _nova_cd - delta)
	_nova_flash = maxf(0.0, _nova_flash - delta * 3.0)
	_boom_flash = maxf(0.0, _boom_flash - delta * 2.2)

func _nearest_enemy(max_d: float) -> Dictionary:
	var best: Dictionary = {}
	var bd := max_d * max_d
	for e in _enemies:
		var d: float = _pos.distance_squared_to(e.pos)
		if d < bd:
			bd = d
			best = e
	return best

func _tick_enemies(delta: float) -> void:
	var dead_list: Array = []
	for e in _enemies:
		var def: Dictionary = _def.enemies[e.type]
		var dir: Vector2 = (_pos - e.pos).normalized()
		# Status effects from weapon hits (canon: stun/emp freeze, slow
		# halves speed, burn ticks 1 dmg)
		if e.get("stun_t", 0.0) > 0.0:
			e["stun_t"] = e.get("stun_t", 0.0) - delta
			e.contact_t = maxf(0.0, e.contact_t - delta)
			e.flash = maxf(0.0, e.flash - delta)
			if e.hp <= 0:
				dead_list.append(e)
			continue
		var speed_mult := 1.0
		if e.get("slow_t", 0.0) > 0.0:
			e["slow_t"] = e.get("slow_t", 0.0) - delta
			speed_mult = 0.5
		if e.get("burn_t", 0.0) > 0.0:
			e["burn_t"] = e.get("burn_t", 0.0) - delta
			e["burn_tick"] = e.get("burn_tick", 0.0) - delta
			if e.get("burn_tick", 0.0) <= 0.0:
				e["burn_tick"] = 0.8
				_damage_enemy(e, 1)
		def = def.duplicate()
		def.speed = def.speed * speed_mult
		if def.get("lunge", false):
			# Gator: slow stalk → freeze wind-up → explosive dash → cooldown
			var st: int = e.get("lunge_st", 0)
			var lt: float = e.get("lunge_t", 0.0) - delta
			if st == 0:
				e.pos = _collide(e.pos + dir * def.speed * delta, def.size * 0.7)
				if lt <= 0.0 and e.pos.distance_to(_pos) < 340.0:
					st = 1
					lt = 0.45
			elif st == 1:
				e["lunge_dir"] = dir
				if lt <= 0.0:
					st = 2
					lt = 0.38
			else:
				e.pos = _collide(e.pos + e.get("lunge_dir", dir) * def.speed * 6.5 * delta,
					def.size * 0.7)
				if lt <= 0.0:
					st = 0
					lt = 2.6
			e["lunge_st"] = st
			e["lunge_t"] = lt
		elif def.has("shoot"):
			# Gunner: hold range, back off when crowded, fire on cooldown
			var sh: Dictionary = def.shoot
			var d: float = e.pos.distance_to(_pos)
			if d < float(sh.get("keep", 220.0)):
				e.pos = _collide(e.pos - dir * def.speed * delta, def.size * 0.7)
			elif d > float(sh.range) * 0.9:
				e.pos = _collide(e.pos + dir * def.speed * delta, def.size * 0.7)
			e["shoot_t"] = e.get("shoot_t", randf() * float(sh.cd)) - delta
			if e.get("shoot_t", 0.0) <= 0.0 and d <= float(sh.range):
				e["shoot_t"] = float(sh.cd)
				_ebullets.append({ "pos": e.pos, "dir": dir,
					"dmg": sh.dmg, "left": float(sh.range) + 120.0 })
		else:
			e.pos = _collide(e.pos + dir * def.speed * delta, def.size * 0.7)
		e.contact_t = maxf(0.0, e.contact_t - delta)
		e.flash = maxf(0.0, e.flash - delta)
		if e.hp <= 0:
			dead_list.append(e)
			continue
		if e.contact_t <= 0.0 and _invuln <= 0.0 and _dash_t <= 0.0 \
				and e.pos.distance_to(_pos) < def.size + 14.0:
			e.contact_t = CONTACT_CD
			_invuln = INVULN
			GameState.take_damage(def.dmg)
			e.pos = _collide(e.pos + (e.pos - _pos).normalized() * 50.0, def.size * 0.7)
			if not _puzzle.is_empty():
				_cancel_puzzle("seal interrupted — they got to you!")
			if GameState.hp <= 0:
				_die()
				return
	for e in dead_list:
		_enemies.erase(e)

func _damage_enemy(e: Dictionary, dmg: int) -> void:
	e.hp -= dmg
	e.flash = 0.12
	if e.hp <= 0 and not e.get("scored", false):
		e.scored = true
		var def: Dictionary = _def.enemies[e.type]
		# Animals carry nothing; humans and machines drop credits + gear
		if def.get("drops", true):
			var payout: int = def.credits * (3 if e.get("elite", false) else 1)
			_coins.append({ "pos": e.pos, "amount": payout })
			var roll := randf()
			if roll < 0.06:
				_pickups.append({ "pos": e.pos + Vector2(14, 8), "kind": "medkit" })
			elif roll < 0.10:
				_pickups.append({ "pos": e.pos + Vector2(14, 8), "kind": "grenade" })
			elif roll < 0.13:
				_pickups.append({ "pos": e.pos + Vector2(14, 8), "kind": "stim" })

func _spawn_enemy(at: Vector2, pool: Array) -> void:
	if _enemies.size() >= 28:
		return
	var kind: String = pool[randi() % pool.size()]
	var elite: bool = randf() < ELITE_CHANCE
	_enemies.append({ "pos": at + Vector2(randf_range(-30, 30), randf_range(-30, 30)),
		"hp": _def.enemies[kind].hp * (2 if elite else 1), "type": kind,
		"elite": elite, "contact_t": 0.0, "flash": 0.0 })

func _tick_spawners(delta: float) -> void:
	for g in _grates:
		if g.sealed or g.pos.distance_to(_pos) > 640.0:
			continue
		g.t -= delta
		if g.t <= 0.0:
			g.t = randf_range(1.8, 3.2)
			_spawn_enemy(g.pos, _def.grate_pool)
	for hole in _holes:
		if hole.pos.distance_to(_pos) > 430.0:
			continue
		hole.t -= delta
		if hole.t <= 0.0:
			hole.t = randf_range(3.0, 5.5)
			_spawn_enemy(hole.pos, _def.hole_pool)

func _tick_loot(delta: float) -> void:
	var got: Array = []
	for c in _coins:
		var d: float = c.pos.distance_to(_pos)
		if d < 90.0:
			c.pos = c.pos.move_toward(_pos, 420.0 * delta)
		if d < 18.0:
			got.append(c)
	for c in got:
		_coins.erase(c)
		GameState.add_credits(c.amount)
	var taken: Array = []
	for p in _pickups:
		if p.pos.distance_to(_pos) < 26.0:
			taken.append(p)
	for p in taken:
		_pickups.erase(p)
		match p.kind:
			"medkit":
				GameState.add_item("medkit")
				_set_status("medkit picked up  [1]")
			"grenade":
				GameState.add_item("grenade")
				_set_status("grenade picked up  [2]")
			"stim":
				GameState.add_item("stim")
				_set_status("stim picked up  [3]")
			"stash":
				GameState.add_credits(_def.stash_credits)
				_set_status("stash cracked: %d credits." % _def.stash_credits)


# ═══════════════════════════════════════════════════════════════════════
# LOCKS — every lock in the dungeon runs through the reusable
# PuzzleOverlay: pipes (grates), lockpick (chests), wires (relay)
# ═══════════════════════════════════════════════════════════════════════

var _overlay
var _puzzle_ctx: Dictionary = {}

func _open_puzzle(puzzle_kind: String, title: String, ctx: Dictionary) -> void:
	if _overlay == null:
		_overlay = PuzzleOverlayScript.new()
		add_child(_overlay)
		_overlay.solved.connect(_on_puzzle_solved)
		_overlay.cancelled.connect(_on_puzzle_cancelled)
	_puzzle_ctx = ctx
	_puzzle = { "open": true }
	_overlay.start(puzzle_kind, title)

func _cancel_puzzle(reason: String) -> void:
	if _overlay and _overlay.active:
		_overlay.interrupt(reason)

func _on_puzzle_cancelled(reason: String) -> void:
	_puzzle = {}
	_puzzle_ctx = {}
	_set_status(reason)

func _on_puzzle_solved() -> void:
	var ctx := _puzzle_ctx
	_puzzle = {}
	_puzzle_ctx = {}
	match ctx.get("kind", ""):
		"grate":
			var g = ctx.grate
			g.sealed = true
			GameState.add_credits(_def.seal_reward)
			var open_count := 0
			for gg in _grates:
				if not gg.sealed:
					open_count += 1
			if open_count == 0:
				GameState.add_credits(_def.seal_all_reward)
				_set_status("ALL GRATES SEALED — +%d credits. the tunnels go quiet." 					% _def.seal_all_reward)
			else:
				_set_status("grate sealed. +%d credits. %d left." 					% [_def.seal_reward, open_count])
		"chest":
			var ch = ctx.chest
			ch.opened = true
			var amount := randi_range(60, 140)
			GameState.add_credits(amount)
			var bonus: String = ["medkit", "grenade", "stim"][randi() % 3]
			GameState.add_item(bonus)
			_set_status("chest picked: %d credits + a %s." % [amount, bonus])
		"relay":
			GameState.set_flag(_def.objective_flag)
			GameState.add_credits(_def.objective_credits)
			_set_status("relay cracked. %d credits siphoned. NYX will want to hear this." 				% _def.objective_credits)


# ═══════════════════════════════════════════════════════════════════════
# DEATH + EXIT + INPUT
# ═══════════════════════════════════════════════════════════════════════

func _die() -> void:
	_dead = true
	GameState.hp = 30
	var cl := CanvasLayer.new()
	add_child(cl)
	var dim := ColorRect.new()
	dim.color = Color(0.3, 0.0, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(dim)
	var l := Label.new()
	l.text = "you black out... and drag yourself back to the street."
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	l.position = Vector2(640 - 320, 340)
	cl.add_child(l)
	await get_tree().create_timer(1.8).timeout
	SceneTransition.go(_def.get("exit_scene", "city"), _def.exit_spawn)

func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	# Puzzle overlay owns the mouse + ESC while open
	if not _puzzle.is_empty():
		return
	if event.is_action_pressed("interact"):
		var g = _nearby_grate()
		var ch = _nearby_chest()
		if _pos.distance_to(_spawn_point) < 60.0:
			SceneTransition.go(_def.get("exit_scene", "city"), _def.exit_spawn)
		elif _pos.distance_to(_relay_pos) < 70.0 \
				and not GameState.has_flag(_def.objective_flag):
			if _def.get("objective_kind", "relay") == "rescue":
				_do_rescue()
			else:
				_open_puzzle("wires", "CRACK THE RELAY", { "kind": "relay" })
		elif g != null:
			_open_puzzle("pipes", "SEAL THE GRATE", { "kind": "grate", "grate": g })
		elif ch != null:
			_open_puzzle("lockpick", "PICK THE LOCK", { "kind": "chest", "chest": ch })
	elif event.is_action_pressed("ui_accept") and _dash_cd <= 0.0:
		_dash_cd = DASH_CD
		_dash_t = DASH_TIME
		_dash_dir = _facing
		_invuln = maxf(_invuln, DASH_TIME + 0.1)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F and _nova_cd <= 0.0:
		_nova_cd = NOVA_CD
		_nova_flash = 1.0
		for e in _enemies:
			if _pos.distance_to(e.pos) <= NOVA_RADIUS:
				_damage_enemy(e, NOVA_DMG)
	elif event.is_action_pressed("ui_cancel"):
		SceneTransition.go(_def.get("exit_scene", "city"), _def.exit_spawn)
	else:
		for i in range(1, 7):
			if event.is_action_pressed("hotbar_%d" % i):
				_use_slot(i)
				return

var _boom_flash := 0.0

func _do_rescue() -> void:
	GameState.set_flag(_def.objective_flag)
	GameState.add_credits(_def.objective_credits)
	var rname: String = _def.get("rescue_name", "???")
	DialogueOverlay.play_lines([
		{ "speaker": rname, "text": "took you long enough. the lock's a joke, the twelve guys were the problem.",
		  "color": Color(1.0, 0.6, 0.8) },
		{ "speaker": rname, "text": "i can get out the way you came in. faster than you, probably.",
		  "color": Color(1.0, 0.6, 0.8) },
		{ "speaker": "", "text": "She's gone before you finish nodding. %d credits were taped under the cage floor." % _def.objective_credits,
		  "color": Color(0.53, 0.53, 0.53) },
	], "rescue")

func _use_slot(slot: int) -> void:
	var id: String = GameState.hotbar.get(str(slot), "")
	if id == "":
		_set_status("slot %d empty. assign items in the phone GEAR app." % slot)
		return
	# Weapons on the hotbar swap on keypress (Phaser: select = wield)
	if GameState.Equip.is_weapon(id):
		if GameState.equip_weapon(id):
			_set_status("%s out." % GameState.weapon_def().get("name", id))
		return
	_use_item(id)

func _use_item(id: String) -> void:
	if not GameState.has_item(id):
		_set_status("no %s left. enemies and chests drop them." % id)
		return
	GameState.inventory.erase(id)
	match id:
		"medkit":
			GameState.hp = mini(GameState.hp_max, GameState.hp + MEDKIT_HEAL)
			_set_status("medkit used. +%d HP" % MEDKIT_HEAL)
		"grenade":
			_boom_flash = 1.0
			for e in _enemies:
				if _pos.distance_to(e.pos) <= GRENADE_RADIUS:
					_damage_enemy(e, GRENADE_DMG)
			_set_status("grenade out!")
		"stim":
			_stim_t = STIM_DURATION
			_set_status("stim hits. legs like pistons.")


# ═══════════════════════════════════════════════════════════════════════
# LIGHTS — CanvasModulate darkness + dynamic PointLight2D
# ═══════════════════════════════════════════════════════════════════════

func _build_lights() -> void:
	_low_lights = str(GameState.settings.get("lights", "full")) == "low"
	var cm := CanvasModulate.new()
	cm.color = Color(0.115, 0.125, 0.20)   # deep underground dark
	add_child(cm)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1.0),
		Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.0)])
	_light_tex = GradientTexture2D.new()
	_light_tex.gradient = grad
	_light_tex.width = 256
	_light_tex.height = 256
	_light_tex.fill = GradientTexture2D.FILL_RADIAL
	_light_tex.fill_from = Vector2(0.5, 0.5)
	_light_tex.fill_to = Vector2(0.5, 0.0)
	# No light of your own unless you bought a headlamp at GUNS+ (and
	# left it switched on — the GEAR app has the toggle)
	if GameState.headlamp_on():
		_torch = _add_light(_pos, Color(1.0, 0.85, 0.6), 4.0, 1.6)
	else:
		# eyes adjusting to the dark — barely anything
		_torch = _add_light(_pos, Color(0.75, 0.8, 0.95), 1.0, 0.24)
	# Sconces + moss glow (same deterministic spots the draw pass dresses)
	var tiles: Array = _gen.tiles
	for y in _gen.h:
		for x in _gen.w:
			if tiles[y][x] != DungeonGenSys.T_FLOOR:
				continue
			if not (y > 0 and tiles[y - 1][x] == DungeonGenSys.T_WALL):
				continue
			if _in_blackout_cell(Vector2i(x, y)):
				continue
			var p := Vector2((x + 0.5) * CELL, y * CELL + 8.0)
			if _gen.flavor.has(Vector2i(x, y)):
				if not _low_lights:
					var ml := _add_light(p, Color(0.35, 1.0, 0.5), 1.9, 1.0)
					_flickers.append({ "l": ml, "ph": randf() * TAU, "base": 1.0 })
			elif (x * 3 + y * 5) % 4 == 0:
				var sl := _add_light(p, Color(0.55, 0.85, 1.0), 1.9, 1.2)
				if not _low_lights:
					_flickers.append({ "l": sl, "ph": randf() * TAU, "base": 1.2 })
	# Faint glow off the water
	if not _low_lights:
		for r in _waters:
			_add_light(r.get_center(), Color(0.3, 0.8, 1.0),
				clampf(maxf(r.size.x, r.size.y) / 200.0, 1.0, 4.0), 0.45)
	# Grates pulse red until sealed
	for g in _grates:
		g["light"] = _add_light(g.pos, Color(1.0, 0.25, 0.2), 1.2, 0.7)
	_relay_light = _add_light(_relay_pos, Color(1.0, 0.2, 0.85), 2.2, 1.3)
	# Street light spilling down the entrance shaft
	_add_light(_spawn_point, Color(0.7, 0.8, 1.0), 2.0, 1.2)
	# Walls block light — real shadows, real dark corners
	for r in _walls:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([r.position,
			Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])
		occ.occluder = poly
		add_child(occ)

func _add_light(pos: Vector2, color: Color, tex_scale: float,
		energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.position = pos
	l.color = color
	l.texture_scale = tex_scale
	l.energy = energy
	l.shadow_enabled = not _low_lights
	l.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	l.shadow_filter_smooth = 2.5
	l.shadow_color = Color(0, 0, 0, 0.82)
	add_child(l)
	return l

func _in_blackout_cell(c: Vector2i) -> bool:
	for bo in _blackouts:
		if (bo.cells as Rect2i).has_point(c):
			return true
	return false

func _tick_blackout_warning() -> void:
	var pc := Vector2i(int(_pos.x / CELL), int(_pos.y / CELL))
	for bo in _blackouts:
		if not bo.warned and (bo.cells as Rect2i).has_point(pc):
			bo.warned = true
			if not GameState.headlamp_on():
				DialogueOverlay.play_lines([
					{ "speaker": "", "text": "it is pitch black in here.",
					  "color": Color(0.7, 0.75, 0.85) },
					{ "speaker": "", "text": "you are likely to be eaten by a gator.",
					  "color": Color(1.0, 0.4, 0.35) },
				], "blackout")
			return

func _tick_lights() -> void:
	if _torch:
		_torch.position = _pos
		# Live headlamp switch — flipping it in the phone works mid-run
		if GameState.headlamp_on():
			_torch.color = Color(1.0, 0.85, 0.6)
			_torch.texture_scale = 4.0
			_torch.energy = 1.6
		else:
			_torch.color = Color(0.75, 0.8, 0.95)
			_torch.texture_scale = 1.0
			_torch.energy = 0.24
	for g in _grates:
		if not g.has("light"):
			continue
		if g.sealed:
			g.light.color = Color(1.0, 0.7, 0.3)
			g.light.energy = 0.25
		else:
			g.light.energy = 0.55 + 0.30 * sin(_anim_t * 5.0 + g.t)
	# Fixture flicker — dying tubes, occasional dropout blink
	for f in _flickers:
		var drop: float = 0.35 if fmod(_anim_t * 0.7 + f.ph, 7.0) < 0.07 else 1.0
		f.l.energy = f.base * (0.86 + 0.14 * sin(_anim_t * 11.0 + f.ph)) * drop
	if _relay_light:
		var hacked: bool = GameState.has_flag(_def.objective_flag)
		_relay_light.color = Color(0.3, 1.0, 0.5) if hacked else Color(1.0, 0.2, 0.85)
		_relay_light.energy = 0.7 + 0.35 * sin(_anim_t * 3.0)


# ═══════════════════════════════════════════════════════════════════════
# DRAW — palette-driven: rooms, water + bridges, flavor lighting, props
# ═══════════════════════════════════════════════════════════════════════

func _draw_floor(b: Node2D) -> void:
	var ws := _world_size()
	var tiles: Array = _gen.tiles
	# Tiled concrete, palette-modulated (repeat enabled on the board)
	b.draw_texture_rect_region(TEX_FLOOR, Rect2(Vector2.ZERO, ws),
		Rect2(Vector2.ZERO, ws * 3.2), _pal.floor * 2.8)
	for y in _gen.h:
		for x in _gen.w:
			if tiles[y][x] != DungeonGenSys.T_FLOOR:
				continue
			var cell_rect := Rect2(x * CELL, y * CELL, CELL, CELL)
			if _gen.flavor.has(Vector2i(x, y)):
				b.draw_rect(cell_rect, Color(_pal.floor_flavor.r,
					_pal.floor_flavor.g, _pal.floor_flavor.b, 0.55), true)
			elif (x * 7 + y * 13) % 5 == 0:
				b.draw_rect(cell_rect, Color(0, 0, 0, 0.12), true)

func _draw_water(b: Node2D) -> void:
	# Plain white rects — the sewer_water shader paints them
	for r in _waters:
		b.draw_rect(r, Color.WHITE, true)
	var tiles: Array = _gen.tiles
	for y in _gen.h:
		for x in _gen.w:
			if tiles[y][x] == DungeonGenSys.T_BRIDGE:
				b.draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), Color.WHITE, true)

func _draw_world(b: Node2D) -> void:
	var tiles: Array = _gen.tiles
	# Bridge planks (the water shader runs underneath)
	for y in _gen.h:
		for x in _gen.w:
			if tiles[y][x] == DungeonGenSys.T_BRIDGE:
				var cell_rect := Rect2(x * CELL, y * CELL, CELL, CELL)
				for i in 4:
					b.draw_rect(Rect2(cell_rect.position + Vector2(6, 10 + i * 42),
						Vector2(CELL - 12, 30)), _pal.bridge, true)
	# Walls — the mass is void-black; a metal FACE renders only where a
	# wall meets walkable space below it. Reads as walls, not stacked
	# blocks, and kills the rim seams between merged rows.
	for r in _walls:
		b.draw_rect(r, Color(0.010, 0.012, 0.018), true)
	var flick := 0.75 + 0.25 * sin(_anim_t * 9.0)
	for y in _gen.h:
		for x in _gen.w:
			if tiles[y][x] != DungeonGenSys.T_WALL:
				continue
			var wx: float = x * CELL
			var wy: float = y * CELL
			if y + 1 < _gen.h and tiles[y + 1][x] != DungeonGenSys.T_WALL:
				var face := Rect2(wx, wy + CELL * 0.45, CELL, CELL * 0.55)
				b.draw_texture_rect_region(TEX_WALL, face,
					Rect2(face.position * 2.6, face.size * 2.6), _pal.wall * 3.4)
				b.draw_rect(Rect2(wx, wy + CELL * 0.45, CELL, 5.0),
					_pal.wall_rim * 1.8, true)
				if _pal.has("conduit"):
					b.draw_rect(Rect2(wx, wy + CELL - 13.0, CELL, 3.0),
						_pal.conduit * flick, true)
			# Thin edge lines where the void borders open space — keeps the
			# maze silhouette readable without lighting seams
			if y > 0 and tiles[y - 1][x] != DungeonGenSys.T_WALL:
				b.draw_rect(Rect2(wx, wy, CELL, 3.0), _pal.wall_rim * 0.7, true)
			if x > 0 and tiles[y][x - 1] != DungeonGenSys.T_WALL:
				b.draw_rect(Rect2(wx, wy, 3.0, CELL), _pal.wall_rim * 0.7, true)
			if x + 1 < _gen.w and tiles[y][x + 1] != DungeonGenSys.T_WALL:
				b.draw_rect(Rect2(wx + CELL - 3.0, wy, 3.0, CELL),
					_pal.wall_rim * 0.7, true)
	# Lighting dressing: flavor glow in flavor rooms, sconces elsewhere
	for y in _gen.h:
		for x in _gen.w:
			if tiles[y][x] != DungeonGenSys.T_FLOOR:
				continue
			var p := Vector2((x + 0.5) * CELL, y * CELL)
			var above_wall: bool = y > 0 and tiles[y - 1][x] == DungeonGenSys.T_WALL
			if not above_wall:
				continue
			if _in_blackout_cell(Vector2i(x, y)):
				continue
			if _gen.flavor.has(Vector2i(x, y)):
				b.draw_circle(Vector2(p.x, p.y + 8.0), 7.0, _pal.flavor_light)
				b.draw_circle(Vector2(p.x, p.y + 8.0), 12.0,
					Color(_pal.flavor_light.r, _pal.flavor_light.g,
						_pal.flavor_light.b, 0.22))
			elif (x * 3 + y * 5) % 4 == 0:
				b.draw_rect(Rect2(p + Vector2(-4.0, 2.0), Vector2(8.0, 10.0)),
					Color(0.15, 0.13, 0.11), true)
				b.draw_circle(Vector2(p.x, p.y + 5.0), 4.5, _pal.sconce)
	# Grates
	for g in _grates:
		b.draw_rect(Rect2(g.pos - Vector2(34, 24), Vector2(68, 48)), Color(0.02, 0.02, 0.02), true)
		for i in 4:
			b.draw_rect(Rect2(g.pos + Vector2(-30 + i * 17, -24), Vector2(5, 48)),
				Color(0.20, 0.20, 0.20), true)
		if g.sealed:
			# Welded shut — hot cross-brace cooling off
			b.draw_line(g.pos + Vector2(-30, -22), g.pos + Vector2(30, 22),
				Color(1.4, 0.8, 0.3), 6.0)
			b.draw_line(g.pos + Vector2(-30, 22), g.pos + Vector2(30, -22),
				Color(1.4, 0.8, 0.3), 6.0)
		else:
			b.draw_circle(g.pos, 6.0, Color(1.5, 0.25, 0.2))
	# Rat holes — dark arches at wall bases
	for hole in _holes:
		b.draw_circle(hole.pos + Vector2(0, -10.0), 16.0, Color(0.015, 0.015, 0.015))
		b.draw_rect(Rect2(hole.pos + Vector2(-16, -10), Vector2(32, 12)),
			Color(0.015, 0.015, 0.015), true)
	# Objective prop — relay pylon, or a cage with someone in it
	var hacked: bool = GameState.has_flag(_def.objective_flag)
	if _def.get("objective_kind", "relay") == "rescue":
		# Cage: floor plate + bars; the captive stands inside until freed
		b.draw_rect(Rect2(_relay_pos - Vector2(40, 46), Vector2(80, 88)),
			Color(0.03, 0.03, 0.04), true)
		if not hacked:
			b.draw_texture_rect_region(_sheets["cyberGirl"],
				Rect2(_relay_pos - Vector2(FRAME_W * 0.5, FRAME_H - 16.0),
					Vector2(FRAME_W, FRAME_H)),
				Rect2(0, 0, FRAME_W, FRAME_H), Color(1.1, 0.9, 1.0))
		var bar_col := Color(0.45, 0.42, 0.38) if not hacked else Color(0.25, 0.23, 0.2)
		for i in 5:
			var bx: float = _relay_pos.x - 36.0 + i * 18.0
			if hacked and i >= 2:
				continue   # the door side is torn open
			b.draw_rect(Rect2(bx, _relay_pos.y - 46.0, 6.0, 92.0), bar_col, true)
		b.draw_rect(Rect2(_relay_pos - Vector2(40, 50), Vector2(80, 6)), bar_col, true)
	else:
		b.draw_rect(Rect2(_relay_pos - Vector2(18, 34), Vector2(36, 68)), Color(0.05, 0.04, 0.08), true)
		var pulse := 0.5 + 0.5 * sin(_anim_t * 3.0)
		var node_col: Color = Color(0.3, 1.6, 0.6) if hacked else Color(1.6, 0.2, 0.9)
		for i in 4:
			b.draw_rect(Rect2(_relay_pos + Vector2(-12, -26 + i * 15), Vector2(24, 6)),
				node_col * (0.6 + 0.4 * pulse), true)
	# Pickups
	for p in _pickups:
		if p.kind == "medkit":
			b.draw_rect(Rect2(p.pos - Vector2(10, 8), Vector2(20, 16)), Color(0.9, 0.95, 1.0), true)
			b.draw_rect(Rect2(p.pos - Vector2(2, 6), Vector2(4, 12)), Color(1.6, 0.2, 0.3), true)
			b.draw_rect(Rect2(p.pos - Vector2(6, 2), Vector2(12, 4)), Color(1.6, 0.2, 0.3), true)
		else:
			b.draw_rect(Rect2(p.pos - Vector2(14, 10), Vector2(28, 20)), Color(0.4, 0.3, 0.08), true)
			b.draw_rect(Rect2(p.pos - Vector2(10, 6), Vector2(20, 12)), Color(1.6, 1.2, 0.2), true)
	# Chests — locked brown boxes with a glowing padlock, husks when open
	for ch in _chests:
		var base_col := Color(0.30, 0.20, 0.10) if not ch.opened else Color(0.14, 0.10, 0.07)
		b.draw_rect(Rect2(ch.pos - Vector2(20, 14), Vector2(40, 28)), base_col, true)
		b.draw_rect(Rect2(ch.pos - Vector2(20, 14), Vector2(40, 8)), base_col * 1.4, true)
		if not ch.opened:
			b.draw_rect(Rect2(ch.pos - Vector2(5, 2), Vector2(10, 12)), Color(1.5, 1.2, 0.3), true)
			b.draw_arc(ch.pos + Vector2(0, -2), 6.0, PI, TAU, 10, Color(1.5, 1.2, 0.3), 3.0)
	# Coins
	for c in _coins:
		b.draw_circle(c.pos, 6.0, Color(1.7, 1.4, 0.3))
		b.draw_circle(c.pos, 3.0, Color(0.5, 0.38, 0.05))
	# Entrance ladder
	b.draw_rect(Rect2(_spawn_point - Vector2(16, 26), Vector2(32, 52)), Color(0.10, 0.12, 0.14), true)
	for i in 4:
		b.draw_rect(Rect2(_spawn_point + Vector2(-14, -20 + i * 13), Vector2(28, 4)),
			Color(0.35, 0.40, 0.45), true)
	# Enemies
	for e in _enemies:
		var def: Dictionary = _def.enemies[e.type]
		if e.get("lunge_st", 0) == 1:
			b.draw_circle(e.pos, def.size + 12.0, Color(1.5, 0.25, 0.15, 0.30))
			b.draw_arc(e.pos, def.size + 12.0, 0, TAU, 24, Color(1.7, 0.3, 0.2, 0.8), 3.0)
		var to: Vector2 = _pos - e.pos
		var row := Facing.DOWN
		if absf(to.x) >= absf(to.y):
			row = Facing.RIGHT if to.x > 0 else Facing.LEFT
		else:
			row = Facing.DOWN if to.y > 0 else Facing.UP
		var tint: Color = def.tint if e.flash <= 0.0 else Color(2.2, 2.2, 2.2)
		if e.get("elite", false) and e.flash <= 0.0:
			tint = tint * Color(1.5, 0.55, 0.55)
		var sc: float = def.get("scale", 1.0)
		var frame := int(_anim_t * 7.0 + e.pos.x) % 3
		b.draw_texture_rect_region(_sheets[def.sheet],
			Rect2(e.pos - Vector2(FRAME_W * 0.5 * sc, (FRAME_H - 12.0) * sc),
				Vector2(FRAME_W * sc, FRAME_H * sc)),
			Rect2(frame * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H), tint)
	# Boss — bigger sprite, telegraph ring before the charge
	if not _boss.is_empty() and _boss.active and not _boss.done:
		var bdef: Dictionary = _def.boss
		if _boss.state == "telegraph":
			b.draw_circle(_boss.pos, bdef.size + 20.0, Color(1.5, 0.25, 0.15, 0.30))
			b.draw_arc(_boss.pos, bdef.size + 20.0, 0, TAU, 28, Color(1.7, 0.3, 0.2, 0.9), 3.5)
		var bto: Vector2 = _pos - _boss.pos
		var brow := Facing.DOWN
		if absf(bto.x) >= absf(bto.y):
			brow = Facing.RIGHT if bto.x > 0 else Facing.LEFT
		else:
			brow = Facing.DOWN if bto.y > 0 else Facing.UP
		var btint: Color = bdef.tint if _boss.flash <= 0.0 else Color(2.2, 2.2, 2.2)
		if _boss.state == "flee":
			btint.a = maxf(0.0, _boss.flee_t / 1.2)
		var bsc: float = bdef.get("scale", 1.5)
		var bframe := int(_anim_t * 8.0) % 3
		b.draw_texture_rect_region(_sheets[bdef.sheet],
			Rect2(_boss.pos - Vector2(FRAME_W * 0.5 * bsc, (FRAME_H - 12.0) * bsc),
				Vector2(FRAME_W * bsc, FRAME_H * bsc)),
			Rect2(bframe * FRAME_W, brow * FRAME_H, FRAME_W, FRAME_H), btint)
	# Enemy fire — hot red tracers
	for eb in _ebullets:
		b.draw_line(eb.pos - eb.dir * 10.0, eb.pos, Color(1.7, 0.35, 0.2), 3.0)
		b.draw_circle(eb.pos, 3.0, Color(1.8, 0.4, 0.2))
	# Bullets — glowing tracers in the weapon's palette
	for bl in _bullets:
		var bcol := Color(1.6, 1.3, 0.4)
		if bl.w.get("status", "") == "burn" or bl.w.get("explosive", false):
			bcol = Color(1.7, 0.6, 0.25)
		elif bl.w.get("status", "") in ["emp", "stun"]:
			bcol = Color(0.5, 1.4, 1.7)
		b.draw_line(bl.pos - bl.dir * 14.0, bl.pos, bcol, 3.0)
		b.draw_circle(bl.pos, 3.2, bcol)
	# Slash
	if not _slash.is_empty():
		var alpha: float = _slash.life / 0.12
		var slash_r: float = _slash.reach * 0.62 * (1.15 - alpha * 0.15)
		b.draw_arc(_pos, slash_r, _slash.angle - deg_to_rad(42.0),
			_slash.angle + deg_to_rad(42.0), 14, Color(1.8, 1.8, 2.0, alpha), 4.0)
		b.draw_arc(_pos, slash_r - 5.0, _slash.angle - deg_to_rad(32.0),
			_slash.angle + deg_to_rad(32.0), 12,
			Color(_pal.accent.r, _pal.accent.g, _pal.accent.b, alpha * 0.6), 2.5)
	# Nova ring
	if _nova_flash > 0.0:
		b.draw_arc(_pos, NOVA_RADIUS * (1.0 - _nova_flash * 0.3), 0, TAU, 48,
			Color(0.3, 1.6, 1.0, _nova_flash), 6.0)
	# Grenade blast ring
	if _boom_flash > 0.0:
		b.draw_arc(_pos, GRENADE_RADIUS * (1.1 - _boom_flash * 0.4), 0, TAU, 48,
			Color(1.7, 0.8, 0.2, _boom_flash), 8.0)
	# Player
	var tint := Color(1, 1, 1)
	if _dash_t > 0.0:
		tint = Color(0.6, 1.8, 2.0)
	elif not _puzzle.is_empty():
		tint = Color(1.3, 1.3, 0.8)
	elif _invuln > 0.0:
		tint = Color(2.0, 2.0, 2.0)
	b.draw_circle(_pos + Vector2(0, 8.0), 12.0, Color(0.0, 0.0, 0.0, 0.4))
	b.draw_texture_rect_region(_player_sheet,
		Rect2(_pos - Vector2(FRAME_W * 0.5, FRAME_H - 12.0), Vector2(FRAME_W, FRAME_H)),
		Rect2((int(_anim_t * 8.0) % 3 if _moving else 0) * FRAME_W,
			_face_row * FRAME_H, FRAME_W, FRAME_H), tint)


# ═══════════════════════════════════════════════════════════════════════
# HUD
# ═══════════════════════════════════════════════════════════════════════

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var title := Label.new()
	title.text = _def.name
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	title.position = Vector2(30, 8)
	cl.add_child(title)
	for key in ["dash", "nova", "grates", "wpn", "shield", "boss"]:
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
		cl.add_child(l)
		_hud[key] = l
	_hud.dash.position = Vector2(480, 10)
	_hud.nova.position = Vector2(600, 10)
	_hud.grates.position = Vector2(1085, 10)
	_hud.grates.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
	_hud.wpn.position = Vector2(720, 10)
	_hud.wpn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_hud.shield.position = Vector2(930, 10)
	_hud.shield.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	_hud.boss.position = Vector2(420, 44)
	_hud.boss.add_theme_font_size_override("font_size", 20)
	_hud.boss.add_theme_color_override("font_color", Color(1.4, 0.4, 0.25))
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_status_label.position = Vector2(30, 40)
	cl.add_child(_status_label)
	var hint := Label.new()
	hint.text = "WASD move · SPACE dash · F emp nova · 1-6 hotbar (assign in phone GEAR) · E interact · ESC leave"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hint.position = Vector2(30, 694)
	cl.add_child(hint)
	_refresh_hud()

func _set_status(t: String) -> void:
	if _status_label:
		_status_label.text = t

func _count_item(id: String) -> int:
	var n := 0
	for it in GameState.inventory:
		if it == id:
			n += 1
	return n

func _refresh_hud() -> void:
	_hud.dash.text = "DASH ✓" if _dash_cd <= 0.0 else "DASH %.1f" % _dash_cd
	_hud.nova.text = "NOVA ✓" if _nova_cd <= 0.0 else "NOVA %.1f" % _nova_cd
	var w: Dictionary = GameState.weapon_def()
	if w.get("type", "melee") == "ranged":
		if _reload_t > 0.0:
			_hud.wpn.text = "%s · RELOADING" % w.get("name", "?")
		else:
			_hud.wpn.text = "%s · %d/%d" % [w.get("name", "?"),
				GameState.ammo_left(GameState.equipped_weapon), w.get("max_ammo", 0)]
	else:
		_hud.wpn.text = str(w.get("name", "?"))
	var ms: float = GameState.max_shield()
	_hud.shield.text = "" if ms <= 0.0 else "SHIELD %d/%d" % [int(GameState.shield_hp), int(ms)]
	if not _boss.is_empty() and _boss.active and not _boss.done:
		var frac: float = clampf(float(_boss.hp) / float(_boss.hp_max), 0.0, 1.0)
		var cells: int = int(ceil(frac * 16.0))
		_hud.boss.text = "%s  %s%s" % [_def.boss.name,
			"█".repeat(cells), "░".repeat(16 - cells)]
	else:
		_hud.boss.text = ""
	var sealed := 0
	for g in _grates:
		if g.sealed:
			sealed += 1
	_hud.grates.text = "GRATES %d/%d" % [sealed, _grates.size()]
