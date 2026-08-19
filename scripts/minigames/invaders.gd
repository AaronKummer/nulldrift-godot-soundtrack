## VOID INVADERS — Space Invaders / Galaga minigame. Port of hacking-game's
## SpaceInvadersScene ("GRID WARS").
##
## 8x5 formation marches down, speeds up as it thins. Destructible barriers,
## mystery ship, 3 lives, max 3 player bullets, waves loop faster and lower.
## Same row shapes/points as the Phaser version.
extends Node2D

const PLAY_W := 800.0
const PLAY_H := 640.0
const ORIGIN := Vector2((1280.0 - PLAY_W) * 0.5, (720.0 - PLAY_H) * 0.5)

const COLS := 8
const ROWS := 5
const MAX_LIVES := 3
const MAX_BULLETS := 3
const SHIP_SPEED := 280.0
const SHIP_W := 26.0
const SHIP_H := 20.0
const FIRE_CD := 0.18
const BULLET_SPEED := 420.0
const SPACING_X := 52.0
const SPACING_Y := 44.0
const ENEMY_SIZE := 17.0
const MOVE_BASE := 0.9        # formation step interval at full strength
const STEP_X := 12.0
const DROP_Y := 16.0
const EBULLET_SPEED := 220.0
const EFIRE_BASE := 1.8
const EFIRE_MIN := 0.4
const MYSTERY_SPEED := 140.0
const MYSTERY_PTS := [100, 150, 200, 300]
const BLOCK := 9.0            # barrier block size
const B_COLS := 8
const B_ROWS := 5

# Same shape/point rows as Phaser (colors HDR-boosted for glow)
const ROW_DEFS := [
	{ "shape": "diamond", "pts": 30, "color": Color(1.6, 0.0, 1.6) },
	{ "shape": "circle",  "pts": 20, "color": Color(1.1, 0.45, 1.6) },
	{ "shape": "square",  "pts": 15, "color": Color(1.6, 0.85, 0.0) },
	{ "shape": "square",  "pts": 15, "color": Color(1.6, 0.6, 0.0) },
	{ "shape": "hexagon", "pts": 10, "color": Color(0.45, 1.6, 0.45) },
]
const COL_SHIP := Color(0.0, 1.6, 1.6)
const COL_WALL := Color(1.4, 0.0, 1.4)
const COL_BG := Color(0.004, 0.004, 0.012)
const COL_BARRIER := Color(0.0, 1.5, 0.9)
const COL_MYSTERY := Color(1.7, 0.0, 0.3)

var _ship_x := PLAY_W * 0.5
var _alive := true            # player currently controllable
var _lives := MAX_LIVES
var _score := 0
var _wave := 1
var _fire_cd := 0.0
var _respawn := 0.0
var _bullets: Array = []      # Vector2
var _ebullets: Array = []
var _enemies: Array = []      # {pos: Vector2, row: int, alive: bool}
var _dir := 1.0
var _move_t := 0.0
var _efire_t := 0.0
var _mystery_t := 20.0
var _mystery_x := -100.0
var _mystery_on := false
var _mystery_dir := 1.0
var _barriers: Array = []     # Array of {x0, y0, blocks: Array[bool 2D flat]}
var _particles: Array = []    # {pos, vel, life, color}
var _game_over := false
var _board: Node2D
var _score_label: Label
var _best_label: Label
var _lives_label: Label
var _wave_label: Label
var _over_layer: CanvasLayer

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
	_board = _Board.new()
	_board.game = self
	add_child(_board)
	_build_hud()
	_new_game()

class _Board extends Node2D:
	var game
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		game._draw_board(self)

func _new_game() -> void:
	_score = 0
	_lives = MAX_LIVES
	_wave = 1
	_game_over = false
	if _over_layer:
		_over_layer.queue_free()
		_over_layer = null
	_spawn_wave()
	_build_barriers()
	_refresh_hud()

func _spawn_wave() -> void:
	_enemies.clear()
	_bullets.clear()
	_ebullets.clear()
	var x0 := (PLAY_W - (COLS - 1) * SPACING_X) * 0.5
	var y0 := 70.0 + minf(float(_wave - 1) * 14.0, 90.0)
	for r in ROWS:
		for c in COLS:
			_enemies.append({
				"pos": Vector2(x0 + c * SPACING_X, y0 + r * SPACING_Y),
				"row": r, "alive": true })
	_dir = 1.0
	_move_t = 0.0
	_efire_t = EFIRE_BASE

func _build_barriers() -> void:
	_barriers.clear()
	for b in 4:
		var bx := PLAY_W * (0.5 + (b - 1.5) * 0.22) - B_COLS * BLOCK * 0.5
		var blocks: Array = []
		for r in B_ROWS:
			for c in B_COLS:
				# Notch the underside like classic invaders shields
				var solid: bool = not (r >= B_ROWS - 2 and c >= 2 and c <= B_COLS - 3)
				blocks.append(solid)
		_barriers.append({ "x0": bx, "y0": PLAY_H - 130.0, "blocks": blocks })

func _alive_count() -> int:
	var n := 0
	for e in _enemies:
		if e.alive:
			n += 1
	return n

func _process(delta: float) -> void:
	if _game_over:
		return
	# Ship
	if _alive:
		var ax := Input.get_axis("move_left", "move_right")
		_ship_x = clampf(_ship_x + ax * SHIP_SPEED * delta,
			SHIP_W * 0.5, PLAY_W - SHIP_W * 0.5)
		_fire_cd = maxf(0.0, _fire_cd - delta)
		if Input.is_action_pressed("ui_accept") or Input.is_action_pressed("interact"):
			if _fire_cd <= 0.0 and _bullets.size() < MAX_BULLETS:
				_bullets.append(Vector2(_ship_x, PLAY_H - 50.0))
				_fire_cd = FIRE_CD
	else:
		_respawn -= delta
		if _respawn <= 0.0:
			_alive = true
			_ship_x = PLAY_W * 0.5
	_tick_formation(delta)
	_tick_bullets(delta)
	_tick_mystery(delta)
	_tick_particles(delta)
	# Wave cleared
	if _alive_count() == 0:
		_wave += 1
		_score += 100
		_spawn_wave()
		_refresh_hud()

func _tick_formation(delta: float) -> void:
	var alive := _alive_count()
	if alive == 0:
		return
	var interval: float = maxf(0.06,
		MOVE_BASE * float(alive) / float(COLS * ROWS) / (1.0 + (_wave - 1) * 0.15))
	_move_t += delta
	if _move_t >= interval:
		_move_t = 0.0
		# Edge check first
		var hit_edge := false
		for e in _enemies:
			if not e.alive:
				continue
			var nx: float = e.pos.x + _dir * STEP_X
			if nx < ENEMY_SIZE or nx > PLAY_W - ENEMY_SIZE:
				hit_edge = true
				break
		if hit_edge:
			_dir = -_dir
			for e in _enemies:
				e.pos.y += DROP_Y
				# Invasion reaches the ship line = instant game over
				if e.alive and e.pos.y > PLAY_H - 80.0:
					_die(true)
					return
		else:
			for e in _enemies:
				e.pos.x += _dir * STEP_X
	# Enemy fire
	_efire_t -= delta
	if _efire_t <= 0.0:
		_efire_t = maxf(EFIRE_MIN, EFIRE_BASE - (_wave - 1) * 0.2) * randf_range(0.6, 1.4)
		var shooters: Array = []
		for e in _enemies:
			if e.alive:
				shooters.append(e)
		if not shooters.is_empty():
			var e: Dictionary = shooters[randi() % shooters.size()]
			_ebullets.append(Vector2(e.pos.x, e.pos.y + ENEMY_SIZE))

func _tick_bullets(delta: float) -> void:
	# Player bullets
	var dead: Array = []
	for b in _bullets.size():
		_bullets[b].y -= BULLET_SPEED * delta
		var bp: Vector2 = _bullets[b]
		if bp.y < 10.0 or _hit_barrier(bp) :
			dead.append(_bullets[b])
			continue
		# Enemies
		for e in _enemies:
			if e.alive and absf(e.pos.x - bp.x) < ENEMY_SIZE and absf(e.pos.y - bp.y) < ENEMY_SIZE:
				e.alive = false
				var def: Dictionary = ROW_DEFS[e.row]
				_score += def.pts
				_burst(e.pos, def.color)
				dead.append(_bullets[b])
				_refresh_hud()
				break
		# Mystery ship
		if _mystery_on and absf(_mystery_x - bp.x) < 24.0 and absf(46.0 - bp.y) < 16.0:
			_mystery_on = false
			var pts: int = MYSTERY_PTS[randi() % MYSTERY_PTS.size()]
			_score += pts
			_burst(Vector2(_mystery_x, 46.0), COL_MYSTERY)
			dead.append(_bullets[b])
			_refresh_hud()
	for d in dead:
		_bullets.erase(d)
	# Enemy bullets
	dead.clear()
	for b in _ebullets.size():
		_ebullets[b].y += EBULLET_SPEED * delta
		var bp: Vector2 = _ebullets[b]
		if bp.y > PLAY_H - 6.0 or _hit_barrier(bp):
			dead.append(_ebullets[b])
			continue
		if _alive and absf(_ship_x - bp.x) < SHIP_W * 0.6 \
				and absf((PLAY_H - 36.0) - bp.y) < SHIP_H:
			dead.append(_ebullets[b])
			_die(false)
	for d in dead:
		_ebullets.erase(d)

func _hit_barrier(p: Vector2) -> bool:
	for bar in _barriers:
		var lx: float = p.x - bar.x0
		var ly: float = p.y - bar.y0
		if lx < 0.0 or ly < 0.0 or lx >= B_COLS * BLOCK or ly >= B_ROWS * BLOCK:
			continue
		var c := int(lx / BLOCK)
		var r := int(ly / BLOCK)
		var idx := r * B_COLS + c
		if bar.blocks[idx]:
			bar.blocks[idx] = false
			return true
	return false

func _tick_mystery(delta: float) -> void:
	if _mystery_on:
		_mystery_x += MYSTERY_SPEED * _mystery_dir * delta
		if _mystery_x < -60.0 or _mystery_x > PLAY_W + 60.0:
			_mystery_on = false
	else:
		_mystery_t -= delta
		if _mystery_t <= 0.0:
			_mystery_t = randf_range(15.0, 30.0)
			_mystery_on = true
			_mystery_dir = 1.0 if randf() < 0.5 else -1.0
			_mystery_x = -50.0 if _mystery_dir > 0 else PLAY_W + 50.0

func _burst(at: Vector2, color: Color) -> void:
	for i in 12:
		var a := randf() * TAU
		_particles.append({ "pos": at,
			"vel": Vector2(cos(a), sin(a)) * randf_range(40.0, 160.0),
			"life": 0.4, "color": color })

func _tick_particles(delta: float) -> void:
	var dead: Array = []
	for pt in _particles:
		pt.life -= delta
		pt.pos += pt.vel * delta
		if pt.life <= 0.0:
			dead.append(pt)
	for d in dead:
		_particles.erase(d)

func _die(invaded: bool) -> void:
	_burst(Vector2(_ship_x, PLAY_H - 36.0), COL_SHIP)
	_lives -= 1
	_refresh_hud()
	if _lives <= 0 or invaded:
		_game_over = true
		var new_best := GameState.submit_arcade_score("invaders", _score)
		_show_game_over(new_best, invaded)
	else:
		_alive = false
		_respawn = 1.2

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneTransition.go("arcade", "from_game_invaders")
		return
	if _game_over and (event.is_action_pressed("interact") \
			or event.is_action_pressed("ui_accept")):
		_new_game()

func _draw_board(b: Node2D) -> void:
	b.draw_rect(Rect2(ORIGIN, Vector2(PLAY_W, PLAY_H)), COL_BG, true)
	# Starfield speckle (static)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 50:
		b.draw_rect(Rect2(ORIGIN + Vector2(rng.randf_range(0, PLAY_W),
			rng.randf_range(0, PLAY_H)), Vector2(1.4, 1.4)),
			Color(0.4, 0.4, 0.55, rng.randf_range(0.2, 0.7)), true)
	# Walls
	var t := 4.0
	b.draw_rect(Rect2(ORIGIN - Vector2(t, t), Vector2(PLAY_W + t * 2, t)), COL_WALL, true)
	b.draw_rect(Rect2(ORIGIN - Vector2(t, 0), Vector2(t, PLAY_H)), COL_WALL, true)
	b.draw_rect(Rect2(ORIGIN + Vector2(PLAY_W, 0), Vector2(t, PLAY_H)), COL_WALL, true)
	b.draw_rect(Rect2(ORIGIN + Vector2(-t, PLAY_H), Vector2(PLAY_W + t * 2, t)), COL_WALL, true)
	# Enemies
	for e in _enemies:
		if e.alive:
			_draw_enemy(b, ORIGIN + e.pos, ROW_DEFS[e.row])
	# Mystery ship
	if _mystery_on:
		var mp := ORIGIN + Vector2(_mystery_x, 46.0)
		b.draw_rect(Rect2(mp - Vector2(20, 7), Vector2(40, 14)), COL_MYSTERY, true)
		b.draw_rect(Rect2(mp - Vector2(10, 12), Vector2(20, 6)), COL_MYSTERY * 0.7, true)
	# Barriers
	for bar in _barriers:
		for r in B_ROWS:
			for c in B_COLS:
				if bar.blocks[r * B_COLS + c]:
					var shade: Color = COL_BARRIER * (1.0 - float(r) * 0.13)
					b.draw_rect(Rect2(ORIGIN + Vector2(bar.x0 + c * BLOCK,
						bar.y0 + r * BLOCK), Vector2(BLOCK - 1, BLOCK - 1)), shade, true)
	# Ship
	if _alive and not _game_over:
		var sp := ORIGIN + Vector2(_ship_x, PLAY_H - 36.0)
		var pts := PackedVector2Array([
			sp + Vector2(0, -SHIP_H * 0.6),
			sp + Vector2(-SHIP_W * 0.5, SHIP_H * 0.4),
			sp + Vector2(SHIP_W * 0.5, SHIP_H * 0.4)])
		b.draw_colored_polygon(pts, COL_SHIP)
		b.draw_rect(Rect2(sp + Vector2(-2, -SHIP_H * 0.9), Vector2(4, 6)), Color(1.6, 1.6, 1.6), true)
	# Bullets
	for bp in _bullets:
		b.draw_rect(Rect2(ORIGIN + bp - Vector2(1.5, 7), Vector2(3, 14)), COL_SHIP, true)
	for bp in _ebullets:
		b.draw_rect(Rect2(ORIGIN + bp - Vector2(1.5, 7), Vector2(3, 14)), Color(1.6, 0.3, 0.3), true)
	# Particles
	for pt in _particles:
		var pc: Color = pt.color
		pc.a = pt.life / 0.4
		b.draw_rect(Rect2(ORIGIN + pt.pos, Vector2(3, 3)), pc, true)

func _draw_enemy(b: Node2D, p: Vector2, def: Dictionary) -> void:
	var s := ENEMY_SIZE
	var c: Color = def.color
	match def.shape:
		"diamond":
			b.draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -s), p + Vector2(s, 0),
				p + Vector2(0, s), p + Vector2(-s, 0)]), c)
		"circle":
			b.draw_circle(p, s * 0.8, c)
			b.draw_circle(p, s * 0.35, Color(0.02, 0.02, 0.04))
		"hexagon":
			var pts := PackedVector2Array()
			for i in 6:
				var a := TAU * float(i) / 6.0
				pts.append(p + Vector2(cos(a), sin(a)) * s * 0.85)
			b.draw_colored_polygon(pts, c)
		_:
			b.draw_rect(Rect2(p - Vector2(s * 0.8, s * 0.8),
				Vector2(s * 1.6, s * 1.6)), c, true)
			b.draw_rect(Rect2(p - Vector2(s * 0.35, s * 0.35),
				Vector2(s * 0.7, s * 0.7)), Color(0.02, 0.02, 0.04), true)

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var title := Label.new()
	title.text = "VOID INVADERS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.75, 0.45, 1.0))
	title.position = Vector2(ORIGIN.x, 8)
	cl.add_child(title)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
	_score_label.position = Vector2(ORIGIN.x + 260, 10)
	cl.add_child(_score_label)
	_best_label = Label.new()
	_best_label.add_theme_font_size_override("font_size", 20)
	_best_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_best_label.position = Vector2(ORIGIN.x + 440, 10)
	cl.add_child(_best_label)
	_lives_label = Label.new()
	_lives_label.add_theme_font_size_override("font_size", 20)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.5))
	_lives_label.position = Vector2(ORIGIN.x + 600, 10)
	cl.add_child(_lives_label)
	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override("font_size", 20)
	_wave_label.add_theme_color_override("font_color", Color(0.7, 0.6, 1.0))
	_wave_label.position = Vector2(ORIGIN.x + 700, 10)
	cl.add_child(_wave_label)
	var exit_btn := Button.new()
	exit_btn.text = "EXIT GAME"
	exit_btn.position = Vector2(1010, 8)
	exit_btn.size = Vector2(110, 32)
	exit_btn.focus_mode = Control.FOCUS_NONE
	var exit_sb := StyleBoxFlat.new()
	exit_sb.bg_color = Color(0.05, 0.02, 0.04, 0.9)
	exit_sb.border_color = Color(1.0, 0.25, 0.5)
	exit_sb.set_border_width_all(2)
	exit_btn.add_theme_stylebox_override("normal", exit_sb)
	exit_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.7))
	exit_btn.pressed.connect(func(): SceneTransition.go("arcade", "from_game_invaders"))
	cl.add_child(exit_btn)
	var hint := Label.new()
	hint.text = "A/D move · SPACE/E fire · ESC back to arcade"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hint.position = Vector2(ORIGIN.x, 700 - 6)
	cl.add_child(hint)
	_refresh_hud()

func _refresh_hud() -> void:
	if _score_label:
		_score_label.text = "SCORE %d" % _score
	if _best_label:
		_best_label.text = "BEST %d" % GameState.arcade_best("invaders")
	if _lives_label:
		_lives_label.text = "♥ %d" % _lives
	if _wave_label:
		_wave_label.text = "WAVE %d" % _wave

func _show_game_over(new_best: bool, invaded: bool) -> void:
	_over_layer = CanvasLayer.new()
	add_child(_over_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.position = Vector2(640 - 170, 280)
	_over_layer.add_child(box)
	var l1 := Label.new()
	l1.text = "SECTOR OVERRUN" if invaded else "SHIP DESTROYED"
	l1.add_theme_font_size_override("font_size", 40)
	l1.add_theme_color_override("font_color", Color(1.0, 0.2, 0.5))
	box.add_child(l1)
	var l2 := Label.new()
	l2.text = "SCORE: %d%s" % [_score, "   ★ NEW BEST" if new_best else ""]
	l2.add_theme_font_size_override("font_size", 24)
	l2.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
	box.add_child(l2)
	var l3 := Label.new()
	l3.text = "[E] retry   ·   ESC exit"
	l3.add_theme_font_size_override("font_size", 18)
	l3.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	box.add_child(l3)
