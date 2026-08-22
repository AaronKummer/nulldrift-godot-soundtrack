## THE BEACH — a quiet night boardwalk you Uber to. Side-view 2D like the
## balcony: parallax layers (star sky, the city skyline across the water,
## a shimmering ocean, a distant pier) drift at different speeds as you
## walk the sand past stilted beach houses. Leave via the boardwalk exit
## (or Uber out from the phone).
extends Node2D

const FRAME_W := 48
const FRAME_H := 64
const COLS := 3
const FPS := 8.0
enum Facing { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

const PLAYER_SCALE := 1.6
const PLAYER_Y := 585.0
const SAND_TOP_Y := 545.0
const WALK_HALF_W := 1100.0
const PLAYER_Y_MIN := 560.0
const PLAYER_Y_MAX := 620.0
const EXIT_X := 980.0

var _camera: Camera2D
var _player: Sprite2D
var _atlas: AtlasTexture
var _facing := Facing.LEFT
var _frame := 0
var _anim_t := 0.0
var _moving := false
var _parallax: Array = []       # { node, scroll }
var _ocean_shimmer: Array = []
var _t := 0.0
var _exit_arrow: Polygon2D
var _near_exit := false
var _near_id := ""
var _status: Label

func _ready() -> void:
	_build_camera_and_sky()
	_build_ocean()
	_build_sand_and_houses()
	_build_named_buildings()
	_build_exit()
	_build_player()
	_build_hud()
	_apply_spawn()
	Music.play_category("ambient")

# ── camera + parallax sky (layers are camera children, offset by scroll) ──
func _build_camera_and_sky() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(0, 360)
	add_child(_camera)
	_camera.make_current()
	# Sky gradient — dusk over the water (drawn as stacked bands)
	var sky := ColorRect.new()
	sky.color = Color(0.03, 0.03, 0.09)
	sky.position = Vector2(-960, -360)
	sky.size = Vector2(1920, 1080)
	sky.z_index = -60
	_camera.add_child(sky)
	var glow := ColorRect.new()   # warm horizon band
	glow.color = Color(0.35, 0.12, 0.22)
	glow.position = Vector2(-960, 120)
	glow.size = Vector2(1920, 220)
	glow.z_index = -59
	_camera.add_child(glow)
	# Stars
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 90:
		var s := ColorRect.new()
		s.color = Color(1, 1, 1, rng.randf_range(0.3, 0.9))
		s.position = Vector2(rng.randf_range(-960, 960), rng.randf_range(-360, 180))
		s.size = Vector2(2, 2)
		s.z_index = -58
		_camera.add_child(s)
	# Moon over the water
	var moon := ColorRect.new()
	moon.color = Color(1.0, 0.95, 0.85)
	moon.position = Vector2(360, -180)
	moon.size = Vector2(70, 70)
	moon.z_index = -57
	_camera.add_child(moon)
	# City skyline across the water — far parallax silhouette
	var sky_layer := Node2D.new()
	sky_layer.z_index = -50
	_camera.add_child(sky_layer)
	var srng := RandomNumberGenerator.new()
	srng.seed = 42
	var x := -1400.0
	while x < 1400.0:
		var w: float = srng.randf_range(40, 90)
		var h: float = srng.randf_range(60, 200)
		var b := ColorRect.new()
		b.color = Color(0.06, 0.06, 0.13)
		b.position = Vector2(x, 300 - h)
		b.size = Vector2(w, h)
		sky_layer.add_child(b)
		# a few lit windows
		for wi in int(h / 40):
			if srng.randf() < 0.4:
				var win := ColorRect.new()
				win.color = Color(1.0, 0.85, 0.5, 0.7)
				win.position = Vector2(x + srng.randf_range(6, w - 12), 300 - h + 10 + wi * 34)
				win.size = Vector2(6, 8)
				sky_layer.add_child(win)
		x += w + srng.randf_range(6, 24)
	_parallax.append({ "node": sky_layer, "scroll": 0.15 })

# ── ocean band with drifting shimmer lines (mid parallax) ────────────────
func _build_ocean() -> void:
	var ocean := ColorRect.new()
	ocean.color = Color(0.03, 0.09, 0.14)
	ocean.position = Vector2(-3000, 300)
	ocean.size = Vector2(6000, SAND_TOP_Y - 300)
	ocean.z_index = -40
	add_child(ocean)
	# Moonlit shimmer — horizontal highlight bars that slide
	for i in 14:
		var sh := ColorRect.new()
		sh.color = Color(0.5, 0.75, 0.9, 0.18)
		sh.position = Vector2(-1000 + i * 160, 320 + (i % 5) * 34)
		sh.size = Vector2(90, 4)
		sh.z_index = -39
		add_child(sh)
		_ocean_shimmer.append({ "node": sh, "spd": 20.0 + (i % 4) * 12.0,
			"base": sh.position.x })
	# Foam line where surf meets sand
	var foam := ColorRect.new()
	foam.color = Color(0.6, 0.8, 0.85, 0.5)
	foam.position = Vector2(-3000, SAND_TOP_Y - 6)
	foam.size = Vector2(6000, 6)
	foam.z_index = -30
	add_child(foam)

# ── sand + stilted beach houses (world space, scroll with player) ─────────
func _build_sand_and_houses() -> void:
	var sand := ColorRect.new()
	sand.color = Color(0.14, 0.11, 0.09)
	sand.position = Vector2(-3000, SAND_TOP_Y)
	sand.size = Vector2(6000, 720 - SAND_TOP_Y)
	sand.z_index = -20
	add_child(sand)
	# Beach houses on stilts, set back from the surf
	var hrng := RandomNumberGenerator.new()
	hrng.seed = 1993
	var palette := [Color(0.9, 0.5, 0.55), Color(0.5, 0.7, 0.85),
		Color(0.85, 0.8, 0.5), Color(0.6, 0.85, 0.7)]
	for hx in [-820.0, -420.0, -40.0, 360.0, 720.0]:
		var body: Color = palette[hrng.randi() % palette.size()] * 0.5
		# stilts
		for sx in [hx - 45, hx + 45]:
			_rect(Vector2(sx, SAND_TOP_Y - 40), Vector2(8, 46), Color(0.1, 0.08, 0.07), -19)
		# house body
		_rect(Vector2(hx - 60, SAND_TOP_Y - 118), Vector2(120, 80), body, -18)
		# roof
		_rect(Vector2(hx - 70, SAND_TOP_Y - 128), Vector2(140, 12), body * 1.3, -18)
		# lit window
		_rect(Vector2(hx - 30, SAND_TOP_Y - 100), Vector2(30, 30),
			Color(1.0, 0.82, 0.45, 0.9), -17)
		# deck light glow
		var gl := PointLight2D.new()
		gl.position = Vector2(hx, SAND_TOP_Y - 70)
		gl.color = Color(1.0, 0.7, 0.35)
		gl.energy = 0.5
		gl.texture = _soft_light_tex()
		gl.texture_scale = 1.6
		add_child(gl)

# Stephen's house + Growlers — enterable, with a lit door, a sign, and a
# bobbing arrow that flares on approach.
const STEPHENS_X := -520.0
const GROWLERS_X := 220.0
var _steph_arrow: Polygon2D
var _grow_arrow: Polygon2D
func _build_named_buildings() -> void:
	# STEPHEN'S — a big lit party house
	_named_building(STEPHENS_X, Color(0.55, 0.3, 0.5), "STEPHEN'S", Color(1.0, 0.5, 0.9))
	_steph_arrow = _named_arrow(STEPHENS_X)
	# GROWLERS — beach bar
	_named_building(GROWLERS_X, Color(0.5, 0.4, 0.25), "GROWLERS", Color(1.0, 0.7, 0.35))
	_grow_arrow = _named_arrow(GROWLERS_X)

func _named_building(hx: float, body: Color, name_txt: String, neon: Color) -> void:
	for sx in [hx - 70, hx + 70]:
		_rect(Vector2(sx, SAND_TOP_Y - 60), Vector2(10, 66), Color(0.1, 0.08, 0.07), -19)
	_rect(Vector2(hx - 95, SAND_TOP_Y - 165), Vector2(190, 105), body * 0.6, -18)
	_rect(Vector2(hx - 108, SAND_TOP_Y - 178), Vector2(216, 16), body, -18)   # roof
	# lit windows
	for wx in [hx - 60, hx + 20]:
		_rect(Vector2(wx, SAND_TOP_Y - 140), Vector2(38, 34), Color(1.0, 0.82, 0.45, 0.9), -17)
	# door + warm spill
	_rect(Vector2(hx - 18, SAND_TOP_Y - 74), Vector2(36, 74), Color(0.05, 0.04, 0.06), -17)
	_rect(Vector2(hx - 12, SAND_TOP_Y - 66), Vector2(24, 66), Color(1.0, 0.75, 0.4, 0.85), -16)
	# neon sign
	var lbl := Label.new()
	lbl.text = name_txt
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", neon)
	lbl.position = Vector2(hx - 70, SAND_TOP_Y - 210)
	add_child(lbl)
	var gl := PointLight2D.new()
	gl.position = Vector2(hx, SAND_TOP_Y - 40)
	gl.color = neon
	gl.energy = 0.6
	gl.texture = _soft_light_tex()
	gl.texture_scale = 2.2
	add_child(gl)

func _named_arrow(hx: float) -> Polygon2D:
	var a := Polygon2D.new()
	a.polygon = PackedVector2Array([Vector2(-16, -14), Vector2(16, -14), Vector2(0, 8)])
	a.color = Color(1.0, 0.9, 0.5)
	a.position = Vector2(hx, SAND_TOP_Y - 84)
	a.modulate.a = 0.45
	a.z_index = 8
	add_child(a)
	var tw := create_tween().set_loops()
	tw.tween_property(a, "position:y", SAND_TOP_Y - 96, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(a, "position:y", SAND_TOP_Y - 84, 0.9).set_trans(Tween.TRANS_SINE)
	return a

func _rect(pos: Vector2, size: Vector2, col: Color, z: int) -> void:
	var r := ColorRect.new()
	r.color = col
	r.position = pos
	r.size = size
	r.z_index = z
	add_child(r)

var _light_tex_cache: GradientTexture2D
func _soft_light_tex() -> GradientTexture2D:
	if _light_tex_cache == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		_light_tex_cache = GradientTexture2D.new()
		_light_tex_cache.gradient = g
		_light_tex_cache.width = 128
		_light_tex_cache.height = 128
		_light_tex_cache.fill = GradientTexture2D.FILL_RADIAL
		_light_tex_cache.fill_from = Vector2(0.5, 0.5)
		_light_tex_cache.fill_to = Vector2(0.5, 0.0)
	return _light_tex_cache

# ── boardwalk exit back to the city (arrow, no HUD prompt) ────────────────
func _build_exit() -> void:
	# A lit boardwalk ramp at the far right
	_rect(Vector2(EXIT_X - 20, SAND_TOP_Y - 10), Vector2(160, 14),
		Color(0.35, 0.25, 0.18), -19)
	var lbl := Label.new()
	lbl.text = "BOARDWALK"
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.2, 1.2, 1.3))
	lbl.position = Vector2(EXIT_X - 30, SAND_TOP_Y - 120)
	add_child(lbl)
	_exit_arrow = Polygon2D.new()
	_exit_arrow.polygon = PackedVector2Array([
		Vector2(-16, -14), Vector2(16, -14), Vector2(0, 8)])
	_exit_arrow.color = Color(0.2, 1.3, 1.4)
	_exit_arrow.position = Vector2(EXIT_X + 40, SAND_TOP_Y - 60)
	_exit_arrow.modulate.a = 0.5
	_exit_arrow.z_index = 8
	add_child(_exit_arrow)
	var tw := create_tween().set_loops()
	tw.tween_property(_exit_arrow, "position:y", SAND_TOP_Y - 72, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_exit_arrow, "position:y", SAND_TOP_Y - 60, 0.9).set_trans(Tween.TRANS_SINE)

func _build_player() -> void:
	_player = Sprite2D.new()
	var tex := load("res://assets/sprites/player-pizza.png") as Texture2D
	_atlas = AtlasTexture.new()
	_atlas.atlas = tex
	_atlas.region = Rect2(0, 0, FRAME_W, FRAME_H)
	_player.texture = _atlas
	_player.position = Vector2(0, PLAYER_Y)
	_player.scale = Vector2(PLAYER_SCALE, PLAYER_SCALE)
	_player.z_index = 6
	add_child(_player)

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var title := Label.new()
	title.text = "THE BEACH · NIGHT"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.3, 1.1, 1.2))
	title.position = Vector2(20, 18)
	cl.add_child(title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
	_status.position = Vector2(20, 40)
	cl.add_child(_status)

func _apply_spawn() -> void:
	var spawn := SceneTransition.consume_spawn()
	# Land at the door you came out of, or by the boardwalk on arrival
	match spawn:
		"from_stephens":
			_player.position.x = STEPHENS_X
		"from_growlers":
			_player.position.x = GROWLERS_X
		_:
			_player.position.x = EXIT_X - 200.0

func _process(delta: float) -> void:
	_t += delta
	_tick_player(delta)
	_camera.position.x = _player.position.x
	# Parallax
	for p in _parallax:
		p.node.position.x = _camera.position.x * (1.0 - p.scroll)
	# Ocean shimmer drift
	for s in _ocean_shimmer:
		var nx: float = s.base + fmod(_t * s.spd, 320.0)
		s.node.position.x = nx
	# Proximity → flare the nearest arrow, set _near_id (no HUD prompt)
	var px := _player.position.x
	_near_exit = absf(px - EXIT_X) <= 110.0
	_beach_flare(_exit_arrow, _near_exit)
	var near_steph := absf(px - STEPHENS_X) <= 90.0
	var near_grow := absf(px - GROWLERS_X) <= 90.0
	_beach_flare(_steph_arrow, near_steph)
	_beach_flare(_grow_arrow, near_grow)
	if near_steph:
		_near_id = "stephens"
	elif near_grow:
		_near_id = "growlers"
	elif _near_exit:
		_near_id = "exit"
	else:
		_near_id = ""

func _beach_flare(a: Polygon2D, near: bool) -> void:
	if a:
		a.modulate.a = 1.0 if near else 0.45
		a.scale = Vector2(1.25, 1.25) if near else Vector2.ONE

func _tick_player(delta: float) -> void:
	var ix := Input.get_axis("move_left", "move_right")
	var iy := Input.get_axis("move_up", "move_down")
	var speed := 320.0
	if Input.is_action_pressed("sprint"):
		speed *= 1.7
	_moving = Vector2(ix, iy).length() > 0.1
	if absf(ix) >= absf(iy) and absf(ix) > 0.1:
		_facing = Facing.RIGHT if ix > 0 else Facing.LEFT
	elif absf(iy) > 0.1:
		_facing = Facing.DOWN if iy > 0 else Facing.UP
	_player.position.x = clampf(_player.position.x + ix * speed * delta, -WALK_HALF_W, WALK_HALF_W)
	_player.position.y = clampf(_player.position.y + iy * speed * 0.6 * delta, PLAYER_Y_MIN, PLAYER_Y_MAX)
	if _moving:
		_anim_t += delta
		var stepd := 1.0 / FPS
		while _anim_t >= stepd:
			_anim_t -= stepd
			_frame = (_frame + 1) % COLS
	else:
		_frame = 0
	_atlas.region = Rect2(_frame * FRAME_W, _facing * FRAME_H, FRAME_W, FRAME_H)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		match _near_id:
			"stephens":
				SceneTransition.go("stephens_house", "from_beach")
			"growlers":
				SceneTransition.go("growlers", "from_beach")
			"exit":
				SceneTransition.go("city", "from_ridenet")
