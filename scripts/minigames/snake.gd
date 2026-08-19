## NET RUNNER — snake arcade minigame. Port of hacking-game's SnakeScene.
##
## Classic snake on a 30x20 grid, neon aesthetic. Collect data nodes to
## grow; speed ramps with score. 15% of food spawns are x2 multiplier
## power-ups (10s). Walls and self are lethal.
##
## Launched from the arcade; ESC returns there. High score persists via
## GameState.arcade_scores.
##
## NOTE (hdr_2d): flat draw colors here are LINEAR — dark tones are
## pre-decoded (see balcony.gd for the same gotcha).
extends Node2D

const GRID_COLS := 30
const GRID_ROWS := 20
const CELL := 32.0
const PLAY_W := GRID_COLS * CELL          # 960
const PLAY_H := GRID_ROWS * CELL          # 640
const ORIGIN := Vector2((1280.0 - PLAY_W) * 0.5, (720.0 - PLAY_H) * 0.5)

const START_TICK := 0.15
const MIN_TICK := 0.07
const TICK_DECREASE := 0.002              # faster per food eaten
const MULTIPLIER_DUR := 10.0
const SPECIAL_CHANCE := 0.15
const FOOD_POINTS := 10

const COL_WALL := Color(1.4, 0.0, 1.4)
const COL_HEAD := Color(0.0, 1.6, 1.6)
const COL_BODY_A := Color(0.0, 0.9, 0.9)
const COL_BODY_B := Color(0.0, 0.15, 0.25)
const COL_FOOD := Color(1.8, 1.4, 0.0)
const COL_SPECIAL := Color(1.8, 0.0, 1.8)
const COL_GRID := Color(0.006, 0.006, 0.02)
const COL_BG := Color(0.003, 0.003, 0.012)

var _snake: Array = []                    # Array[Vector2i], head first
var _dir := Vector2i(1, 0)
var _next_dir := Vector2i(1, 0)
var _food := Vector2i(20, 10)
var _food_special := false
var _mult_left := 0.0
var _tick := START_TICK
var _acc := 0.0
var _score := 0
var _alive := true
var _started := false
var _board: Node2D
var _score_label: Label
var _best_label: Label
var _mult_label: Label
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
	_reset()

class _Board extends Node2D:
	var game
	func _draw() -> void:
		game._draw_board(self)

func _reset() -> void:
	_snake = [Vector2i(8, 10), Vector2i(7, 10), Vector2i(6, 10)]
	_dir = Vector2i(1, 0)
	_next_dir = _dir
	_tick = START_TICK
	_acc = 0.0
	_score = 0
	_mult_left = 0.0
	_alive = true
	_started = false
	_spawn_food()
	if _over_layer:
		_over_layer.queue_free()
		_over_layer = null
	_refresh_hud()
	_board.queue_redraw()

func _spawn_food() -> void:
	while true:
		var c := Vector2i(randi() % GRID_COLS, randi() % GRID_ROWS)
		if not _snake.has(c):
			_food = c
			_food_special = randf() < SPECIAL_CHANCE
			return

func _process(delta: float) -> void:
	if not _alive or not _started:
		return
	if _mult_left > 0.0:
		_mult_left = maxf(0.0, _mult_left - delta)
		_refresh_hud()
	_acc += delta
	while _acc >= _tick:
		_acc -= _tick
		_step()

func _step() -> void:
	_dir = _next_dir
	var head: Vector2i = _snake[0] + _dir
	# Walls + self are lethal
	if head.x < 0 or head.x >= GRID_COLS or head.y < 0 or head.y >= GRID_ROWS \
			or _snake.has(head):
		_die()
		return
	_snake.push_front(head)
	if head == _food:
		var pts := FOOD_POINTS * (2 if _mult_left > 0.0 else 1)
		_score += pts
		if _food_special:
			_mult_left = MULTIPLIER_DUR
		_tick = maxf(MIN_TICK, _tick - TICK_DECREASE)
		_spawn_food()
		_refresh_hud()
	else:
		_snake.pop_back()
	_board.queue_redraw()

func _die() -> void:
	_alive = false
	var new_best := GameState.submit_arcade_score("snake", _score)
	_show_game_over(new_best)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SceneTransition.go("arcade", "from_game_snake")
		return
	if not _alive:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			_reset()
		return
	var want := _next_dir
	if event.is_action_pressed("move_up"):
		want = Vector2i(0, -1)
	elif event.is_action_pressed("move_down"):
		want = Vector2i(0, 1)
	elif event.is_action_pressed("move_left"):
		want = Vector2i(-1, 0)
	elif event.is_action_pressed("move_right"):
		want = Vector2i(1, 0)
	else:
		return
	_started = true
	# No instant reversal
	if want + _dir != Vector2i.ZERO:
		_next_dir = want

func _draw_board(b: Node2D) -> void:
	# Background + grid
	b.draw_rect(Rect2(ORIGIN, Vector2(PLAY_W, PLAY_H)), COL_BG, true)
	for cx in range(GRID_COLS + 1):
		b.draw_rect(Rect2(ORIGIN + Vector2(cx * CELL, 0), Vector2(1, PLAY_H)), COL_GRID, true)
	for cy in range(GRID_ROWS + 1):
		b.draw_rect(Rect2(ORIGIN + Vector2(0, cy * CELL), Vector2(PLAY_W, 1)), COL_GRID, true)
	# Neon wall border
	var t := 4.0
	b.draw_rect(Rect2(ORIGIN - Vector2(t, t), Vector2(PLAY_W + t * 2, t)), COL_WALL, true)
	b.draw_rect(Rect2(ORIGIN + Vector2(-t, PLAY_H), Vector2(PLAY_W + t * 2, t)), COL_WALL, true)
	b.draw_rect(Rect2(ORIGIN - Vector2(t, 0), Vector2(t, PLAY_H)), COL_WALL, true)
	b.draw_rect(Rect2(ORIGIN + Vector2(PLAY_W, 0), Vector2(t, PLAY_H)), COL_WALL, true)
	# Food
	var fc := COL_SPECIAL if _food_special else COL_FOOD
	var fpos := ORIGIN + Vector2(_food) * CELL
	b.draw_rect(Rect2(fpos + Vector2(6, 6), Vector2(CELL - 12, CELL - 12)), fc, true)
	# Snake — head hot cyan, body fades toward dark
	for i in _snake.size():
		var seg: Vector2i = _snake[i]
		var pos := ORIGIN + Vector2(seg) * CELL
		var col := COL_HEAD if i == 0 else \
			COL_BODY_A.lerp(COL_BODY_B, float(i) / maxf(1.0, _snake.size() - 1.0))
		b.draw_rect(Rect2(pos + Vector2(3, 3), Vector2(CELL - 6, CELL - 6)), col, true)
	if not _started and _alive:
		pass  # hint label handles messaging

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var title := Label.new()
	title.text = "NET RUNNER"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	title.position = Vector2(ORIGIN.x, 8)
	cl.add_child(title)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", Color(0.9, 1.0, 1.0))
	_score_label.position = Vector2(ORIGIN.x + 300, 10)
	cl.add_child(_score_label)
	_best_label = Label.new()
	_best_label.add_theme_font_size_override("font_size", 20)
	_best_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_best_label.position = Vector2(ORIGIN.x + 520, 10)
	cl.add_child(_best_label)
	_mult_label = Label.new()
	_mult_label.add_theme_font_size_override("font_size", 20)
	_mult_label.add_theme_color_override("font_color", Color(1.0, 0.4, 1.0))
	_mult_label.position = Vector2(ORIGIN.x + 740, 10)
	cl.add_child(_mult_label)
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
	exit_btn.pressed.connect(func(): SceneTransition.go("arcade", "from_game_snake"))
	cl.add_child(exit_btn)
	var hint := Label.new()
	hint.text = "WASD/ARROWS steer · ESC back to arcade"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hint.position = Vector2(ORIGIN.x, 700 - 6)
	cl.add_child(hint)
	_refresh_hud()

func _refresh_hud() -> void:
	if _score_label:
		_score_label.text = "SCORE %d" % _score
	if _best_label:
		_best_label.text = "BEST %d" % GameState.arcade_best("snake")
	if _mult_label:
		_mult_label.text = ("x2  %0.1fs" % _mult_left) if _mult_left > 0.0 else ""

func _show_game_over(new_best: bool) -> void:
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
	l1.text = "CONNECTION LOST"
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
