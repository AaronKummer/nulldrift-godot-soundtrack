## DATA DUEL — breakout/arkanoid minigame. Port of hacking-game's
## BreakoutScene.
##
## Bounce a ball off a paddle to clear rows of data blocks. Same tuning as
## the Phaser version: 8x6 grid, top rows take multiple hits and pay more,
## 10% of bricks drop a power-up (wide paddle / multiball / +1 life),
## 3 lives, levels loop with faster balls.
##
## NOTE (hdr_2d): flat draw colors are LINEAR — dark tones pre-decoded.
extends Node2D

const PLAY_W := 720.0
const PLAY_H := 640.0
const ORIGIN := Vector2((1280.0 - PLAY_W) * 0.5, (720.0 - PLAY_H) * 0.5)

const PADDLE_W := 80.0
const PADDLE_WIDE_W := 130.0
const PADDLE_H := 12.0
const PADDLE_SPEED := 420.0
const PADDLE_Y := PLAY_H - 40.0

const BALL_R := 5.0
const BALL_SPEED := 280.0
const BALL_MAX_SPEED := 500.0

const COLS := 8
const ROWS := 6
const BRICK_PAD := 4.0
const BRICK_H := 18.0
const BRICK_TOP := 60.0
const START_LIVES := 3

const POWERUP_CHANCE := 0.10
const POWERUP_R := 8.0
const POWERUP_FALL := 120.0
const WIDE_DUR := 8.0

# Same row table as Phaser: top rows are tanky and worth more.
# Colors are HDR-ish so bricks glow.
const ROW_DEFS := [
	{ "color": Color(1.6, 1.3, 0.0), "pts": 50, "hits": 3 },
	{ "color": Color(1.6, 0.0, 1.6), "pts": 40, "hits": 2 },
	{ "color": Color(1.6, 0.25, 0.25), "pts": 30, "hits": 1 },
	{ "color": Color(1.6, 0.6, 0.0), "pts": 20, "hits": 1 },
	{ "color": Color(0.25, 1.6, 0.25), "pts": 15, "hits": 1 },
	{ "color": Color(0.0, 1.4, 1.4), "pts": 10, "hits": 1 },
]
const COL_WALL := Color(1.4, 0.0, 1.4)
const COL_PADDLE := Color(0.0, 1.6, 1.6)
const COL_BALL := Color(1.6, 1.6, 1.6)
const COL_BG := Color(0.003, 0.003, 0.012)
const COL_GRID := Color(0.006, 0.006, 0.022)

var _bricks: Array = []       # {rect: Rect2, hits: int, pts: int, color: Color}
var _balls: Array = []        # {pos: Vector2, vel: Vector2}
var _powerups: Array = []     # {pos: Vector2, kind: String}
var _paddle_x := PLAY_W * 0.5
var _paddle_w := PADDLE_W
var _wide_left := 0.0
var _score := 0
var _lives := START_LIVES
var _level := 1
var _launched := false
var _alive := true
var _board: Node2D
var _score_label: Label
var _best_label: Label
var _lives_label: Label
var _level_label: Label
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
	_lives = START_LIVES
	_level = 1
	_alive = true
	if _over_layer:
		_over_layer.queue_free()
		_over_layer = null
	_build_level()
	_reset_ball()
	_refresh_hud()

func _build_level() -> void:
	_bricks.clear()
	_powerups.clear()
	var bw := (PLAY_W - BRICK_PAD * (COLS + 1)) / COLS
	for r in ROWS:
		var def: Dictionary = ROW_DEFS[r]
		for c in COLS:
			_bricks.append({
				"rect": Rect2(BRICK_PAD + c * (bw + BRICK_PAD),
					BRICK_TOP + r * (BRICK_H + BRICK_PAD), bw, BRICK_H),
				"hits": def.hits, "pts": def.pts, "color": def.color,
			})

func _reset_ball() -> void:
	_balls = [{ "pos": Vector2(_paddle_x, PADDLE_Y - 14.0),
		"vel": Vector2.ZERO }]
	_launched = false
	_paddle_w = PADDLE_W
	_wide_left = 0.0

func _ball_speed() -> float:
	return minf(BALL_MAX_SPEED, BALL_SPEED + (_level - 1) * 40.0)

func _process(delta: float) -> void:
	if not _alive:
		return
	# Paddle
	var ax := Input.get_axis("move_left", "move_right")
	_paddle_x = clampf(_paddle_x + ax * PADDLE_SPEED * delta,
		_paddle_w * 0.5, PLAY_W - _paddle_w * 0.5)
	if _wide_left > 0.0:
		_wide_left -= delta
		if _wide_left <= 0.0:
			_paddle_w = PADDLE_W
	if not _launched:
		_balls[0].pos.x = _paddle_x
		return
	# Balls
	var dead_balls: Array = []
	for ball in _balls:
		ball.pos += ball.vel * delta
		# Walls
		if ball.pos.x < BALL_R:
			ball.pos.x = BALL_R
			ball.vel.x = absf(ball.vel.x)
		elif ball.pos.x > PLAY_W - BALL_R:
			ball.pos.x = PLAY_W - BALL_R
			ball.vel.x = -absf(ball.vel.x)
		if ball.pos.y < BALL_R:
			ball.pos.y = BALL_R
			ball.vel.y = absf(ball.vel.y)
		# Paddle
		var half := _paddle_w * 0.5
		if ball.vel.y > 0 and ball.pos.y >= PADDLE_Y - PADDLE_H * 0.5 - BALL_R \
				and ball.pos.y <= PADDLE_Y + PADDLE_H and \
				absf(ball.pos.x - _paddle_x) <= half + BALL_R:
			# Bounce angle from hit offset (classic breakout feel)
			var off := clampf((ball.pos.x - _paddle_x) / half, -1.0, 1.0)
			var ang := deg_to_rad(-90.0 + off * 60.0)
			ball.vel = Vector2(cos(ang), sin(ang)) * _ball_speed()
			ball.pos.y = PADDLE_Y - PADDLE_H * 0.5 - BALL_R
		# Bricks
		for br in _bricks:
			var r: Rect2 = br.rect
			if r.grow(BALL_R).has_point(ball.pos):
				# Bounce off the nearest face
				var cx := clampf(ball.pos.x, r.position.x, r.end.x)
				var cy := clampf(ball.pos.y, r.position.y, r.end.y)
				if absf(ball.pos.x - cx) > absf(ball.pos.y - cy):
					ball.vel.x = -ball.vel.x
				else:
					ball.vel.y = -ball.vel.y
				br.hits -= 1
				if br.hits <= 0:
					_score += br.pts
					if randf() < POWERUP_CHANCE:
						_powerups.append({ "pos": r.get_center(),
							"kind": ["wide", "multi", "life"][randi() % 3] })
					_bricks.erase(br)
					_refresh_hud()
				break
		# Lost below paddle
		if ball.pos.y > PLAY_H + BALL_R * 2:
			dead_balls.append(ball)
	for b in dead_balls:
		_balls.erase(b)
	if _balls.is_empty():
		_lives -= 1
		_refresh_hud()
		if _lives <= 0:
			_game_over()
		else:
			_reset_ball()
		return
	# Powerups fall
	var caught: Array = []
	for pu in _powerups:
		pu.pos.y += POWERUP_FALL * delta
		if pu.pos.y >= PADDLE_Y - PADDLE_H and \
				absf(pu.pos.x - _paddle_x) <= _paddle_w * 0.5 + POWERUP_R:
			caught.append(pu)
		elif pu.pos.y > PLAY_H + 20.0:
			caught.append(pu)   # off-screen, just remove
	for pu in caught:
		if pu.pos.y < PLAY_H + 20.0:
			_apply_powerup(pu.kind)
		_powerups.erase(pu)
	# Level clear
	if _bricks.is_empty():
		_level += 1
		_build_level()
		_reset_ball()
		_refresh_hud()

func _apply_powerup(kind: String) -> void:
	match kind:
		"wide":
			_paddle_w = PADDLE_WIDE_W
			_wide_left = WIDE_DUR
		"multi":
			var extra: Array = []
			for ball in _balls:
				if ball.vel != Vector2.ZERO:
					extra.append({ "pos": ball.pos,
						"vel": ball.vel.rotated(deg_to_rad(25.0)) })
					extra.append({ "pos": ball.pos,
						"vel": ball.vel.rotated(deg_to_rad(-25.0)) })
			_balls.append_array(extra)
		"life":
			_lives += 1
	_refresh_hud()

func _game_over() -> void:
	_alive = false
	var new_best := GameState.submit_arcade_score("breakout", _score)
	_over_layer = CanvasLayer.new()
	add_child(_over_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.position = Vector2(640 - 160, 280)
	_over_layer.add_child(box)
	var l1 := Label.new()
	l1.text = "DATA CORRUPTED"
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneTransition.go("arcade", "from_game_breakout")
		return
	if not _alive:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_new_game()
		return
	if not _launched and (event.is_action_pressed("ui_accept") \
			or event.is_action_pressed("interact") or event.is_action_pressed("move_up")):
		_launched = true
		var ang := deg_to_rad(-90.0 + randf_range(-30.0, 30.0))
		_balls[0].vel = Vector2(cos(ang), sin(ang)) * _ball_speed()

func _draw_board(b: Node2D) -> void:
	# Background + faint grid
	b.draw_rect(Rect2(ORIGIN, Vector2(PLAY_W, PLAY_H)), COL_BG, true)
	var gstep := 40.0
	var gx := gstep
	while gx < PLAY_W:
		b.draw_rect(Rect2(ORIGIN + Vector2(gx, 0), Vector2(1, PLAY_H)), COL_GRID, true)
		gx += gstep
	var gy := gstep
	while gy < PLAY_H:
		b.draw_rect(Rect2(ORIGIN + Vector2(0, gy), Vector2(PLAY_W, 1)), COL_GRID, true)
		gy += gstep
	# Neon walls (top + sides — bottom is open)
	var t := 4.0
	b.draw_rect(Rect2(ORIGIN - Vector2(t, t), Vector2(PLAY_W + t * 2, t)), COL_WALL, true)
	b.draw_rect(Rect2(ORIGIN - Vector2(t, 0), Vector2(t, PLAY_H)), COL_WALL, true)
	b.draw_rect(Rect2(ORIGIN + Vector2(PLAY_W, 0), Vector2(t, PLAY_H)), COL_WALL, true)
	# Bricks — damaged ones dim
	for br in _bricks:
		var r: Rect2 = br.rect
		var col: Color = br.color
		var max_hits := 1
		for def in ROW_DEFS:
			if def.pts == br.pts:
				max_hits = def.hits
		if br.hits < max_hits:
			col = col * (0.45 + 0.55 * float(br.hits) / float(max_hits))
		b.draw_rect(Rect2(ORIGIN + r.position, r.size), col, true)
	# Paddle
	b.draw_rect(Rect2(ORIGIN + Vector2(_paddle_x - _paddle_w * 0.5,
		PADDLE_Y - PADDLE_H * 0.5), Vector2(_paddle_w, PADDLE_H)), COL_PADDLE, true)
	# Balls
	for ball in _balls:
		b.draw_circle(ORIGIN + ball.pos, BALL_R, COL_BALL)
	# Powerups — colored diamonds (drawn as circles, letter via glow color)
	for pu in _powerups:
		var pc := Color(0.0, 1.6, 1.6)
		if pu.kind == "multi":
			pc = Color(1.6, 1.3, 0.0)
		elif pu.kind == "life":
			pc = Color(1.6, 0.2, 0.6)
		b.draw_circle(ORIGIN + pu.pos, POWERUP_R, pc)
	# Launch hint
	if not _launched and _alive:
		pass

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var title := Label.new()
	title.text = "DATA DUEL"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	title.position = Vector2(ORIGIN.x, 8)
	cl.add_child(title)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
	_score_label.position = Vector2(ORIGIN.x + 220, 10)
	cl.add_child(_score_label)
	_best_label = Label.new()
	_best_label.add_theme_font_size_override("font_size", 20)
	_best_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_best_label.position = Vector2(ORIGIN.x + 400, 10)
	cl.add_child(_best_label)
	_lives_label = Label.new()
	_lives_label.add_theme_font_size_override("font_size", 20)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.5))
	_lives_label.position = Vector2(ORIGIN.x + 560, 10)
	cl.add_child(_lives_label)
	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 20)
	_level_label.add_theme_color_override("font_color", Color(0.7, 0.6, 1.0))
	_level_label.position = Vector2(ORIGIN.x + 660, 10)
	cl.add_child(_level_label)
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
	exit_btn.pressed.connect(func(): SceneTransition.go("arcade", "from_game_breakout"))
	cl.add_child(exit_btn)
	var hint := Label.new()
	hint.text = "A/D move · SPACE/E launch · ESC back to arcade"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hint.position = Vector2(ORIGIN.x, 700 - 6)
	cl.add_child(hint)
	_refresh_hud()

func _refresh_hud() -> void:
	if _score_label:
		_score_label.text = "SCORE %d" % _score
	if _best_label:
		_best_label.text = "BEST %d" % GameState.arcade_best("breakout")
	if _lives_label:
		_lives_label.text = "♥ %d" % _lives
	if _level_label:
		_level_label.text = "LVL %d" % _level
