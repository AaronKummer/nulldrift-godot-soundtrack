## DATA PONG — the DUEL TABLE's head-to-head game. One seat is you; the
## house AI fills the other. First to 7. Ball speeds up every return and
## takes spin from where it hits the paddle.
extends Node2D

const PLAY_W := 960.0
const PLAY_H := 560.0
const ORIGIN := Vector2((1280.0 - PLAY_W) * 0.5, (720.0 - PLAY_H) * 0.5 + 20.0)

const PADDLE_H := 96.0
const PADDLE_W := 14.0
const PADDLE_SPEED := 420.0
const AI_SPEED_BASE := 240.0
const BALL_R := 7.0
const SERVE_SPEED := 340.0
const SPEED_UP := 1.045
const MAX_SPEED := 760.0
const WIN_SCORE := 7

const COL_P1 := Color(0.0, 1.6, 1.6)
const COL_P2 := Color(1.6, 0.15, 0.7)
const COL_BALL := Color(1.6, 1.6, 1.6)
const COL_BG := Color(0.004, 0.004, 0.012)

var _p1_y := PLAY_H * 0.5
var _p2_y := PLAY_H * 0.5
var _ball := Vector2(PLAY_W * 0.5, PLAY_H * 0.5)
var _vel := Vector2.ZERO
var _s1 := 0
var _s2 := 0
var _serving := true
var _serve_dir := 1.0
var _rally := 0
var _done := false
var _board: Node2D
var _score_label: Label
var _best_label: Label
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

class _Board extends Node2D:
	var game
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		game._draw_board(self)

func _process(delta: float) -> void:
	if _done:
		return
	# Player paddle (left) — W/S
	var ay := Input.get_axis("move_up", "move_down")
	_p1_y = clampf(_p1_y + ay * PADDLE_SPEED * delta,
		PADDLE_H * 0.5, PLAY_H - PADDLE_H * 0.5)
	# AI paddle (right) — speed scales with your lead so it stays beatable
	var ai_speed: float = AI_SPEED_BASE + float(_s1 - _s2) * 22.0 + _rally * 4.0
	var target: float = _ball.y if _vel.x > 0 else PLAY_H * 0.5
	_p2_y = move_toward(_p2_y, clampf(target, PADDLE_H * 0.5, PLAY_H - PADDLE_H * 0.5),
		ai_speed * delta)
	if _serving:
		_ball = Vector2(PLAY_W * 0.5, PLAY_H * 0.5)
		return
	_ball += _vel * delta
	# Top/bottom walls
	if _ball.y < BALL_R:
		_ball.y = BALL_R
		_vel.y = absf(_vel.y)
	elif _ball.y > PLAY_H - BALL_R:
		_ball.y = PLAY_H - BALL_R
		_vel.y = -absf(_vel.y)
	# Paddles
	if _vel.x < 0 and _ball.x < 30.0 + PADDLE_W and _ball.x > 20.0 \
			and absf(_ball.y - _p1_y) < PADDLE_H * 0.5 + BALL_R:
		_bounce(_p1_y, 1.0)
	elif _vel.x > 0 and _ball.x > PLAY_W - 30.0 - PADDLE_W and _ball.x < PLAY_W - 20.0 \
			and absf(_ball.y - _p2_y) < PADDLE_H * 0.5 + BALL_R:
		_bounce(_p2_y, -1.0)
	# Goals
	if _ball.x < -20.0:
		_point(false)
	elif _ball.x > PLAY_W + 20.0:
		_point(true)

func _bounce(paddle_y: float, dir: float) -> void:
	_rally += 1
	var off := clampf((_ball.y - paddle_y) / (PADDLE_H * 0.5), -1.0, 1.0)
	var speed: float = minf(MAX_SPEED, _vel.length() * SPEED_UP)
	var ang := off * deg_to_rad(55.0)
	_vel = Vector2(cos(ang) * dir, sin(ang)) * speed

func _point(player_scored: bool) -> void:
	if player_scored:
		_s1 += 1
	else:
		_s2 += 1
	_rally = 0
	_refresh_hud()
	if _s1 >= WIN_SCORE or _s2 >= WIN_SCORE:
		_finish()
	else:
		_serving = true
		_serve_dir = -1.0 if player_scored else 1.0

func _serve() -> void:
	_serving = false
	var ang := randf_range(-0.5, 0.5)
	_vel = Vector2(cos(ang) * _serve_dir, sin(ang)) * SERVE_SPEED

func _finish() -> void:
	_done = true
	var won := _s1 > _s2
	var pts := _s1 * 100 + (300 if won else 0)
	var new_best := GameState.submit_arcade_score("pong", pts)
	_over_layer = CanvasLayer.new()
	add_child(_over_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.position = Vector2(640 - 180, 280)
	_over_layer.add_child(box)
	var l1 := Label.new()
	l1.text = "YOU WIN THE TABLE" if won else "HOUSE WINS"
	l1.add_theme_font_size_override("font_size", 40)
	l1.add_theme_color_override("font_color",
		Color(0.3, 1.0, 0.6) if won else Color(1.0, 0.2, 0.5))
	box.add_child(l1)
	var l2 := Label.new()
	l2.text = "%d — %d   ·   %d pts%s" % [_s1, _s2, pts,
		"   ★ NEW BEST" if new_best else ""]
	l2.add_theme_font_size_override("font_size", 24)
	l2.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
	box.add_child(l2)
	var l3 := Label.new()
	l3.text = "[E] rematch   ·   ESC exit"
	l3.add_theme_font_size_override("font_size", 18)
	l3.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	box.add_child(l3)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneTransition.go("arcade", "from_game_pong")
		return
	if _done:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_s1 = 0
			_s2 = 0
			_done = false
			_serving = true
			_serve_dir = 1.0
			if _over_layer:
				_over_layer.queue_free()
				_over_layer = null
			_refresh_hud()
		return
	if _serving and (event.is_action_pressed("interact") \
			or event.is_action_pressed("ui_accept")):
		_serve()

func _draw_board(b: Node2D) -> void:
	b.draw_rect(Rect2(ORIGIN, Vector2(PLAY_W, PLAY_H)), COL_BG, true)
	# Center line — dashed
	var y := 10.0
	while y < PLAY_H:
		b.draw_rect(Rect2(ORIGIN + Vector2(PLAY_W * 0.5 - 2, y), Vector2(4, 18)),
			Color(0.25, 0.25, 0.4), true)
		y += 34.0
	# Walls
	var t := 4.0
	b.draw_rect(Rect2(ORIGIN - Vector2(t, t), Vector2(PLAY_W + t * 2, t)), Color(1.4, 0.0, 1.4), true)
	b.draw_rect(Rect2(ORIGIN + Vector2(-t, PLAY_H), Vector2(PLAY_W + t * 2, t)), Color(1.4, 0.0, 1.4), true)
	# Paddles
	b.draw_rect(Rect2(ORIGIN + Vector2(24.0, _p1_y - PADDLE_H * 0.5),
		Vector2(PADDLE_W, PADDLE_H)), COL_P1, true)
	b.draw_rect(Rect2(ORIGIN + Vector2(PLAY_W - 24.0 - PADDLE_W, _p2_y - PADDLE_H * 0.5),
		Vector2(PADDLE_W, PADDLE_H)), COL_P2, true)
	# Ball
	b.draw_circle(ORIGIN + _ball, BALL_R, COL_BALL)
	if _serving and not _done:
		pass

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var title := Label.new()
	title.text = "DATA PONG — DUEL TABLE"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	title.position = Vector2(ORIGIN.x, 8)
	cl.add_child(title)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 26)
	_score_label.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
	_score_label.position = Vector2(600, 8)
	cl.add_child(_score_label)
	_best_label = Label.new()
	_best_label.add_theme_font_size_override("font_size", 20)
	_best_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_best_label.position = Vector2(780, 12)
	cl.add_child(_best_label)
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
	exit_btn.pressed.connect(func(): SceneTransition.go("arcade", "from_game_pong"))
	cl.add_child(exit_btn)
	var hint := Label.new()
	hint.text = "W/S move · SPACE/E serve · first to 7 · ESC exit"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hint.position = Vector2(ORIGIN.x, 700 - 6)
	cl.add_child(hint)
	_refresh_hud()

func _refresh_hud() -> void:
	if _score_label:
		_score_label.text = "%d — %d" % [_s1, _s2]
	if _best_label:
		_best_label.text = "BEST %d" % GameState.arcade_best("pong")
