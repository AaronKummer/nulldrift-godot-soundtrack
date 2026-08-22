## Balcony — full 2D side-view scene.
##
## You're standing on a thin deck that overhangs the city. The city sprawls
## out and down beneath the railing. The hallway door is OFF-SCREEN to the
## left and the stairs down to the street are OFF-SCREEN to the right — you
## reach either by walking to that edge of the deck. No big rectangle in
## the middle blocking the view.
##
## Stack: Node2D root, Camera2D follows player on X, Backdrop Sprite2D is a
## child of the camera so the skyline stays locked in the frame as you walk.
## Player + NPCs are Sprite2D using the existing 48×64 sheet atlas.
extends Node2D

const SceneGraphData := preload("res://data/scene_graph.gd")

# Deck layout in world coords. Y is DOWN in Godot 2D. The visible "deck"
# strip sits in the bottom band of the viewport; the city backdrop above.
const PLAYER_Y    := 580.0    # feet roughly on the deck
const DECK_TOP_Y  := 540.0    # railing line
const DECK_BOT_Y  := 720.0    # bottom of visible deck
const DECK_HALF_W := 900.0    # walkable X range from center: ±900px
# Y walking range — player can step back/forward on the deck (small)
const PLAYER_Y_MIN := 555.0
const PLAYER_Y_MAX := 615.0

const FRAME_W := 48
const FRAME_H := 64
const COLS := 3
const FPS  := 8.0
enum Facing { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

const PLAYER_SCALE := 1.6    # match apartment iso-scale proportions
const NPC_SCALE    := 1.7    # slightly larger to compensate for hood/goggles

const NPCS := [
	{ "sheet": "res://assets/sprites/smoking_drifter.png",
	  "x": -460.0, "facing": Facing.DOWN, "cycle": [0,1,2,1], "fps": 1.6 },
	{ "sheet": "res://assets/sprites/smoking_scrapper.png",
	  "x":  140.0, "facing": Facing.DOWN, "cycle": [0,1,2,1], "fps": 1.0 },
	# A third figure — a different resident leaning on the rail (was a
	# duplicate of the drifter girl; two identical smokers looked wrong)
	{ "sheet": "res://assets/sprites/civ/civ-b03.png",
	  "x":  520.0, "facing": Facing.DOWN, "cycle": [0,0,0,0], "fps": 0.5 },
]

# Transitions: where each end of the deck takes you
# Exits are proximity interacts now: the south-facing door → hallway, and the
# far-left neon STAIRS → the city street (see _check_interactables).

var _camera: Camera2D
var _backdrop_layers: Array = []   # [{node, scroll}] — manual parallax
var _player_sprite: Sprite2D
var _player_atlas: AtlasTexture
var _player_x: float = 0.0
var _player_facing: int = Facing.DOWN
var _player_moving: bool = false
var _player_frame: int = 0
var _player_anim_t: float = 0.0
var _npcs: Array = []
var _status_label: Label
var _left_zone: Area2D
var _right_zone: Area2D
var _at_railing: bool = false
var _rail_line_idx: int = 0

# Railing lean spot — an empty stretch of deck between the smokers
const RAIL_SPOT_X := -160.0
const RAIL_SPOT_HALF_W := 90.0
const RAIL_LINES := [
	"the city hums. somewhere down there, Violet is waiting.",
	"four hundred floors of neon between you and the street.",
	"the rain never quite makes it up this high.",
	"you count the drones drifting past until the anger fades.",
	"one of those towers is Nexus Bank. it doesn't know you yet.",
]


func _ready() -> void:
	_build_backdrop_and_camera()
	_build_deck_visuals()
	_build_npcs()
	_build_player()
	_build_building_wall()
	_build_stairs_exit()
	_build_hallway_door()
	_build_rail_marker()
	_build_hud()
	_apply_pending_spawn()
	Music.play_category("balcony")

# ── The apartment building this balcony hangs off — a tall face rising many
# floors above the deck, lit windows, world-space so it scrolls with you. ──
const DOOR_X := 240.0
const STAIRS_X := -760.0
func _build_building_wall() -> void:
	var wall := ColorRect.new()
	wall.color = Color(0.045, 0.045, 0.075)
	wall.position = Vector2(-3000, -900)
	wall.size = Vector2(6000, 900 + DECK_TOP_Y)   # from far above down to the deck
	wall.z_index = -30
	add_child(wall)
	# A brighter pilaster band right behind the deck so the wall reads as near
	var base := ColorRect.new()
	base.color = Color(0.07, 0.07, 0.10)
	base.position = Vector2(-3000, DECK_TOP_Y - 210)
	base.size = Vector2(6000, 210)
	base.z_index = -29
	add_child(base)
	# Rows of lit windows climbing the face — multiple levels
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xBA1C
	for floor_i in range(0, 8):
		var wy := DECK_TOP_Y - 250 - floor_i * 150
		for wx in range(-2880, 3000, 150):
			# skip windows directly over the door column
			if absf(float(wx) - DOOR_X) < 90.0 and floor_i == 0:
				continue
			var lit := rng.randf() < 0.62
			var win := ColorRect.new()
			win.position = Vector2(wx, wy)
			win.size = Vector2(64, 90)
			if lit:
				var warm := rng.randf() < 0.7
				win.color = (Color(1.0, 0.82, 0.45) if warm else Color(0.4, 0.85, 1.1)) \
					* rng.randf_range(0.5, 0.85)
			else:
				win.color = Color(0.09, 0.09, 0.13)
			win.z_index = -28
			add_child(win)

# A soft glowing chevron over the lean spot — always faintly lit, flares up
# when you're in range, so an interact point reads at a glance (same idea as
# the doorway DoorGlow, balcony-flavored).
var _rail_glow: Polygon2D
func _build_rail_marker() -> void:
	_rail_glow = Polygon2D.new()
	_rail_glow.polygon = PackedVector2Array([
		Vector2(-14, 0), Vector2(0, -16), Vector2(14, 0), Vector2(0, -6)])
	_rail_glow.color = Color(0.4, 1.5, 1.7)   # hdr cyan — blooms
	_rail_glow.position = Vector2(RAIL_SPOT_X, DECK_TOP_Y - 26)
	_rail_glow.modulate.a = 0.5
	add_child(_rail_glow)
	var tw := create_tween().set_loops()
	tw.tween_property(_rail_glow, "position:y", DECK_TOP_Y - 34, 1.1) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(_rail_glow, "position:y", DECK_TOP_Y - 26, 1.1) \
		.set_trans(Tween.TRANS_SINE)


# ─────────────────────────────────────────────────────────────────────────
# BACKDROP + CAMERA — backdrop is a child of the camera so the city stays
# locked to the screen as the player walks
# ─────────────────────────────────────────────────────────────────────────

func _build_backdrop_and_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(0, 360)   # vertical center of 720 viewport
	add_child(_camera)
	_camera.make_current()

	# HDR 2D + glow — emissive windows / neon / beacons actually bloom.
	get_viewport().use_hdr_2d = true
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_strength = 1.1
	env.glow_bloom = 0.04
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# Procedural skyline, drawn in parallax layers. Layer content uses
	# screen-space Y (0..720). X parallax is manual: each layer is
	# repositioned every frame from the camera X (see _tick_parallax) —
	# scale 0.0 = glued to camera (sky), 1.0 = world-locked (deck).
	_add_backdrop_layer(_SkyLayer.new(), 0.0, -60)
	_add_backdrop_layer(_SkylineLayer.new(11, {
		"base_y": 548.0, "h_min": 120.0, "h_max": 260.0,
		"w_min": 50.0, "w_max": 110.0, "gap_max": 26.0,
		"body": Color(0.0153, 0.0085, 0.0331), "lit_p": 0.06,
		"win_w": 2.0, "win_h": 3.0, "pitch_x": 7.0, "pitch_y": 9.0,
		"neon_p": 0.0, "beacon_h": 235.0, "span": 1000.0,
	}), 0.05, -46)
	_add_backdrop_layer(_SkylineLayer.new(23, {
		"base_y": 556.0, "h_min": 160.0, "h_max": 360.0,
		"w_min": 70.0, "w_max": 150.0, "gap_max": 42.0,
		"body": Color(0.0245, 0.0134, 0.055), "lit_p": 0.14,
		"win_w": 3.0, "win_h": 4.0, "pitch_x": 9.0, "pitch_y": 12.0,
		"neon_p": 0.30, "beacon_h": 300.0, "span": 1200.0,
	}), 0.12, -42)
	var near := _SkylineLayer.new(37, {
		"base_y": 585.0, "h_min": 200.0, "h_max": 430.0,
		"w_min": 100.0, "w_max": 210.0, "gap_max": 70.0,
		"body": Color(0.0397, 0.022, 0.089), "lit_p": 0.20,
		"win_w": 5.0, "win_h": 6.0, "pitch_x": 13.0, "pitch_y": 16.0,
		"neon_p": 0.45, "beacon_h": 330.0, "span": 1400.0,
	})
	_add_backdrop_layer(near, 0.25, -36)
	# Air traffic drifts between the mid and near layers
	_add_backdrop_layer(_AirTraffic.new(), 0.16, -40)
	# Searchlight sweep from a near-layer rooftop
	var beam := _Searchlight.new()
	beam.position = Vector2(430.0, 300.0)
	near.add_child(beam)

func _add_backdrop_layer(layer: Node2D, scroll: float, z: int) -> void:
	layer.z_index = z
	add_child(layer)
	_backdrop_layers.append({ "node": layer, "scroll": scroll })

func _tick_parallax() -> void:
	# layer screen-shift = camera-shift * scroll  (0 = pinned to camera)
	for entry in _backdrop_layers:
		entry.node.position.x = _camera.position.x * (1.0 - entry.scroll)


# ─────────────────────────────────────────────────────────────────────────
# SKY — gradient night sky, stars, moon (pinned to camera, scroll 0)
# ─────────────────────────────────────────────────────────────────────────

class _SkyLayer extends Node2D:
	func _draw() -> void:
		# Vertical gradient in horizontal slices — deep space to neon horizon
		var stops := [
			[0.00, Color(0.0015, 0.0008, 0.0049)],
			[0.35, Color(0.0049, 0.0023, 0.0153)],
			[0.58, Color(0.0153, 0.0049, 0.0397)],
			[0.72, Color(0.0397, 0.0085, 0.0835)],
			[0.80, Color(0.0732, 0.0134, 0.1193)],
		]
		for i in stops.size():
			var y0: float = stops[i][0] * 720.0
			var y1: float = (stops[i + 1][0] * 720.0) if i + 1 < stops.size() else 720.0
			var c0: Color = stops[i][1]
			var c1: Color = (stops[i + 1][1]) if i + 1 < stops.size() else stops[i][1]
			var slices := 8
			for s in slices:
				var t0 := float(s) / slices
				var t1 := float(s + 1) / slices
				draw_rect(Rect2(-640, y0 + (y1 - y0) * t0, 1280, (y1 - y0) * (t1 - t0) + 1.0),
					c0.lerp(c1, t0), true)
		# Hot horizon smog line — glow blooms it into a haze band
		draw_rect(Rect2(-640, 542, 1280, 3), Color(1.3, 0.1005, 1.05, 0.35), true)

		# Stars — deterministic scatter, denser near the top
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 110:
			var x := rng.randf_range(-640.0, 640.0)
			var y := rng.randf_range(4.0, 470.0) * rng.randf_range(0.3, 1.0)
			var a := rng.randf_range(0.25, 0.9) * (1.0 - y / 520.0)
			var tint: Color = [Color(1, 1, 1), Color(0.5225, 0.7874, 1.0), Color(1.0, 0.6038, 0.89)][rng.randi() % 3]
			draw_rect(Rect2(x, y, 1.6, 1.6), Color(tint.r, tint.g, tint.b, a), true)

		# Moon — pale violet disc with layered halo
		var moon := Vector2(388.0, 118.0)
		for h in [[46.0, 0.05], [38.0, 0.09], [31.0, 0.16]]:
			draw_circle(moon, h[0], Color(0.6921, 0.3185, 1.0, h[1]))
		draw_circle(moon, 26.0, Color(1.10, 1.00, 1.25))
		# Craters — slightly darker discs
		draw_circle(moon + Vector2(-8, -4), 5.0, Color(1.05, 0.8276, 1.22))
		draw_circle(moon + Vector2(7, 9), 3.5, Color(1.08, 0.89, 1.25))
		draw_circle(moon + Vector2(10, -9), 2.5, Color(1.05, 0.8276, 1.22))


# ─────────────────────────────────────────────────────────────────────────
# SKYLINE LAYER — procedural buildings: lit window grids, neon, beacons,
# flickering windows. Deterministic per seed so renders are stable.
# ─────────────────────────────────────────────────────────────────────────

class _SkylineLayer extends Node2D:
	const WIN_COLORS := [
		Color(1.3, 0.89, 0.214),   # warm sodium
		Color(1.3, 0.89, 0.214),   # (weighted: warm is most common)
		Color(0.1706, 1.15, 1.3),   # cool cyan
		Color(1.25, 0.1706, 1.0),   # magenta
		Color(0.2633, 0.3185, 0.6038),   # dim blue-gray
	]
	const NEON_COLORS := [
		Color(2.2, 0.1329, 1.4), Color(0.0732, 2.0, 2.2),
		Color(2.4, 1.6, 0.0732), Color(0.214, 2.2, 0.7874),
	]
	var _seed: int
	var _cfg: Dictionary
	var _buildings: Array = []   # {x, w, top, h}

	func _init(layer_seed: int, cfg: Dictionary) -> void:
		_seed = layer_seed
		_cfg = cfg

	func _ready() -> void:
		# Generate the building strip once — placement is reused by _draw
		# and by the animated children (beacons, flicker windows).
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		var span: float = _cfg.span
		var x := -span
		while x < span:
			var w: float = rng.randf_range(_cfg.w_min, _cfg.w_max)
			var h: float = rng.randf_range(_cfg.h_min, _cfg.h_max)
			_buildings.append({ "x": x, "w": w, "top": _cfg.base_y - h, "h": h })
			x += w + rng.randf_range(4.0, _cfg.gap_max)
		# Animated children — beacons on the tallest towers, a few
		# flickering windows scattered across the strip
		var arng := RandomNumberGenerator.new()
		arng.seed = _seed * 31 + 5
		for b in _buildings:
			if b.h >= _cfg.beacon_h and arng.randf() < 0.65:
				var beacon := _Beacon.new()
				beacon.position = Vector2(b.x + b.w * 0.5, b.top - 8.0)
				beacon.phase = arng.randf_range(0.0, TAU)
				beacon.period = arng.randf_range(1.1, 2.3)
				add_child(beacon)
			if _cfg.lit_p > 0.1 and arng.randf() < 0.30:
				var fw := _FlickerWindow.new()
				fw.position = Vector2(
					b.x + arng.randf_range(6.0, maxf(b.w - 12.0, 7.0)),
					b.top + arng.randf_range(10.0, maxf(b.h - 30.0, 11.0)))
				fw.size = Vector2(_cfg.win_w, _cfg.win_h)
				fw.phase = arng.randf_range(0.0, 10.0)
				add_child(fw)

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed * 7 + 1
		for b in _buildings:
			# Body + subtle parapet edge
			var body: Color = _cfg.body
			var v := rng.randf_range(0.85, 1.15)
			body = Color(body.r * v, body.g * v, body.b * v)
			draw_rect(Rect2(b.x, b.top, b.w, b.h + 40.0), body, true)
			draw_rect(Rect2(b.x, b.top, b.w, 2.0), body * 2.8, true)
			# Rooftop clutter — antenna mast or water tank on some
			var roll := rng.randf()
			if roll < 0.30:
				draw_rect(Rect2(b.x + b.w * 0.5 - 1.0, b.top - 26.0, 2.0, 26.0), body * 3.2, true)
			elif roll < 0.48:
				draw_rect(Rect2(b.x + b.w * 0.22, b.top - 12.0, 14.0, 12.0), body * 2.0, true)
			# Window grid
			var wy: float = b.top + 8.0
			while wy < _cfg.base_y - 6.0:
				var wx: float = b.x + 5.0
				while wx < b.x + b.w - _cfg.win_w - 3.0:
					if rng.randf() < _cfg.lit_p:
						var wc: Color = WIN_COLORS[rng.randi() % WIN_COLORS.size()]
						wc = wc * rng.randf_range(0.7, 1.05)
						draw_rect(Rect2(wx, wy, _cfg.win_w, _cfg.win_h), wc, true)
					wx += _cfg.pitch_x
				wy += _cfg.pitch_y
			# Neon accents — vertical sign strip or rooftop billboard bar
			if rng.randf() < _cfg.neon_p:
				var nc: Color = NEON_COLORS[rng.randi() % NEON_COLORS.size()]
				if rng.randf() < 0.5:
					var nx: float = b.x + rng.randf_range(4.0, maxf(b.w - 10.0, 5.0))
					var nh: float = minf(rng.randf_range(40.0, 90.0), b.h - 20.0)
					draw_rect(Rect2(nx, b.top + 10.0, 4.0, nh), nc, true)
				else:
					var nw: float = b.w * rng.randf_range(0.4, 0.8)
					draw_rect(Rect2(b.x + (b.w - nw) * 0.5, b.top - 6.0, nw, 5.0), nc, true)


class _Beacon extends Node2D:
	var phase := 0.0
	var period := 1.6
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		var on := fmod(_t + phase, period) < period * 0.5
		modulate.a = 1.0 if on else 0.12
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 2.2, Color(2.6, 0.0509, 0.0509))


class _FlickerWindow extends Node2D:
	var size := Vector2(3, 4)
	var phase := 0.0
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		# Unsteady fluorescent: mostly on, stutters off in bursts
		var n := sin((_t + phase) * 13.0) + sin((_t + phase) * 4.7)
		modulate.a = 0.15 if n > 1.2 else 1.0
	func _draw() -> void:
		draw_rect(Rect2(-size * 0.5, size), Color(0.1706, 1.15, 1.3), true)


# ─────────────────────────────────────────────────────────────────────────
# AIR TRAFFIC — drifting lights crossing the skyline at varied depths
# ─────────────────────────────────────────────────────────────────────────

class _AirTraffic extends Node2D:
	const SPAN := 900.0
	var _ships: Array = []
	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for i in 6:
			_ships.append({
				"x": rng.randf_range(-SPAN, SPAN),
				"y": rng.randf_range(70.0, 400.0),
				"v": rng.randf_range(28.0, 95.0) * (1.0 if rng.randf() < 0.5 else -1.0),
				"c": [Color(1.8, 1.5, 1.1), Color(0.214, 1.8, 2.0), Color(2.0, 0.3185, 1.4)][rng.randi() % 3],
			})
	func _process(delta: float) -> void:
		for s in _ships:
			s.x += s.v * delta
			if s.x > SPAN: s.x = -SPAN
			elif s.x < -SPAN: s.x = SPAN
		queue_redraw()
	func _draw() -> void:
		for s in _ships:
			var head := Vector2(s.x, s.y)
			var tail_dir: float = -signf(s.v)
			# Fading tail then bright head
			for t in 4:
				var a := 0.30 - t * 0.07
				draw_rect(Rect2(head.x + tail_dir * (3.0 + t * 4.0), s.y - 0.8, 4.0, 1.6),
					Color(s.c.r, s.c.g, s.c.b, a), true)
			draw_circle(head, 1.8, s.c)


# ─────────────────────────────────────────────────────────────────────────
# SEARCHLIGHT — slow sweeping beam off a rooftop
# ─────────────────────────────────────────────────────────────────────────

class _Searchlight extends Node2D:
	var _t := 0.0
	func _ready() -> void:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
	func _process(delta: float) -> void:
		_t += delta
		rotation = deg_to_rad(-18.0 + sin(_t * 0.35) * 24.0)
	func _draw() -> void:
		var pts := PackedVector2Array([
			Vector2.ZERO, Vector2(-70.0, -560.0), Vector2(70.0, -560.0)])
		draw_colored_polygon(pts, Color(0.448, 0.2633, 1.0, 0.06))
		draw_circle(Vector2.ZERO, 3.0, Color(1.6, 1.3, 2.0))


# ─────────────────────────────────────────────────────────────────────────
# DECK VISUALS — thin strip across the bottom + railing line, world space
# (these scroll with the player as the camera follows X)
# ─────────────────────────────────────────────────────────────────────────

func _build_deck_visuals() -> void:
	# Long deck strip — extends well beyond the visible viewport on both
	# sides so the player can walk to the edges without seeing the end of it
	var deck := ColorRect.new()
	deck.color = Color(0.01, 0.0072, 0.0174)
	deck.position = Vector2(-3000, DECK_TOP_Y)
	deck.size = Vector2(6000, DECK_BOT_Y - DECK_TOP_Y)
	deck.z_index = -10
	add_child(deck)

	# Railing — a thick cyan horizontal line just above the deck
	var rail := ColorRect.new()
	rail.color = Color(0.0, 1.05, 1.25)
	rail.position = Vector2(-3000, DECK_TOP_Y - 6)
	rail.size = Vector2(6000, 6)
	rail.z_index = -5
	add_child(rail)
	# Subtle lower rail
	var rail2 := ColorRect.new()
	rail2.color = Color(0.0, 0.2633, 0.6921)
	rail2.position = Vector2(-3000, DECK_TOP_Y + 14)
	rail2.size = Vector2(6000, 3)
	rail2.z_index = -5
	add_child(rail2)
	# Posts at intervals
	for x_post in range(-2900, 3000, 120):
		var post := ColorRect.new()
		post.color = Color(0.0509, 0.0509, 0.0835)
		post.position = Vector2(x_post, DECK_TOP_Y - 4)
		post.size = Vector2(6, 30)
		post.z_index = -6
		add_child(post)


# ─────────────────────────────────────────────────────────────────────────
# NPCs — Sprite2D + AtlasTexture, ping-pong frames for cig idle
# ─────────────────────────────────────────────────────────────────────────

class _NPC2D extends Sprite2D:
	var _spec: Dictionary
	var _atlas: AtlasTexture
	var _t: float = 0.0
	var _idx: int = 0
	var _frame: int = 0

	func _init(spec: Dictionary) -> void:
		_spec = spec

	func _ready() -> void:
		var tex := load(_spec.sheet) as Texture2D
		_atlas = AtlasTexture.new()
		_atlas.atlas = tex
		_atlas.region = Rect2(0, _spec.facing * 64, 48, 64)
		texture = _atlas
		centered = true
		# Anchor feet on the deck — sprite center is mid-body, so offset up
		position = Vector2(_spec.x, _spec.get("y", 580.0))
		scale = Vector2(1.7, 1.7)
		z_index = 5

	func tick(delta: float) -> void:
		_t += delta
		var step: float = 1.0 / float(_spec.fps)
		while _t >= step:
			_t -= step
			_idx = (_idx + 1) % _spec.cycle.size()
			_frame = int(_spec.cycle[_idx])
			_atlas.region = Rect2(_frame * 48, _spec.facing * 64, 48, 64)

func _build_npcs() -> void:
	for spec in NPCS:
		var npc := _NPC2D.new(spec)
		add_child(npc)
		_npcs.append(npc)


# ─────────────────────────────────────────────────────────────────────────
# PLAYER — 2D sprite that animates by atlas region on direction change
# ─────────────────────────────────────────────────────────────────────────

func _build_player() -> void:
	_player_sprite = Sprite2D.new()
	var tex := load("res://assets/sprites/player-pizza.png") as Texture2D
	_player_atlas = AtlasTexture.new()
	_player_atlas.atlas = tex
	_player_atlas.region = Rect2(0, 0, FRAME_W, FRAME_H)
	_player_sprite.texture = _player_atlas
	_player_sprite.centered = true
	_player_sprite.position = Vector2(0, PLAYER_Y)
	_player_sprite.scale = Vector2(PLAYER_SCALE, PLAYER_SCALE)
	_player_sprite.z_index = 6
	add_child(_player_sprite)


# ─────────────────────────────────────────────────────────────────────────
# EDGE TRIGGERS — invisible Area2D at the far left and far right of deck.
# When the player crosses either edge, transition to the connected scene.
# ─────────────────────────────────────────────────────────────────────────

# A downward chevron that floats over an interact point — dim by default,
# flares + bobs when you're near. This is the "arrow over the thing",
# replacing the HUD [E] prompt.
var _door_arrow: Polygon2D
var _stairs_arrow: Polygon2D
func _make_interact_arrow(x: float, y: float, col: Color) -> Polygon2D:
	var a := Polygon2D.new()
	a.polygon = PackedVector2Array([
		Vector2(-16, -14), Vector2(16, -14), Vector2(0, 8)])
	a.color = col
	a.position = Vector2(x, y)
	a.modulate.a = 0.45
	a.z_index = 8
	add_child(a)
	var tw := create_tween().set_loops()
	tw.tween_property(a, "position:y", y - 12, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(a, "position:y", y, 0.9).set_trans(Tween.TRANS_SINE)
	return a

# ── The stairs down to the street — neon STAIRS sign + arrow, far left ──
func _build_stairs_exit() -> void:
	var sign := Sprite2D.new()
	sign.texture = load("res://assets/world/signs/stairs.png")
	sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sign.position = Vector2(STAIRS_X, DECK_TOP_Y - 150)
	sign.scale = Vector2(0.7, 0.7)
	sign.z_index = 4
	add_child(sign)
	# A dark stairwell mouth cut into the deck
	var mouth := ColorRect.new()
	mouth.color = Color(0.01, 0.02, 0.03)
	mouth.position = Vector2(STAIRS_X - 70, DECK_TOP_Y + 8)
	mouth.size = Vector2(140, 150)
	mouth.z_index = -4
	add_child(mouth)
	for i in 5:
		var step := ColorRect.new()
		step.color = Color(0.0, 0.5, 0.6) * (1.0 - i * 0.12)
		step.position = Vector2(STAIRS_X - 60 + i * 12, DECK_TOP_Y + 20 + i * 24)
		step.size = Vector2(120 - i * 24, 5)
		step.z_index = -3
		add_child(step)
	_stairs_arrow = _make_interact_arrow(STAIRS_X, DECK_TOP_Y - 40, Color(0.2, 1.4, 1.5))

# ── The door back into the hallway — south-facing, set in the wall ──
func _build_hallway_door() -> void:
	# Frame + lit interior slab (the door "faces" us, side-view)
	var frame := ColorRect.new()
	frame.color = Color(0.10, 0.09, 0.06)
	frame.position = Vector2(DOOR_X - 42, DECK_TOP_Y - 168)
	frame.size = Vector2(84, 168)
	frame.z_index = -20
	add_child(frame)
	var pane := ColorRect.new()
	pane.color = Color(1.0, 0.78, 0.42)   # warm light spilling from inside
	pane.position = Vector2(DOOR_X - 32, DECK_TOP_Y - 156)
	pane.size = Vector2(64, 150)
	pane.z_index = -19
	add_child(pane)
	var doorslab := ColorRect.new()
	doorslab.color = Color(0.05, 0.04, 0.06)
	doorslab.position = Vector2(DOOR_X - 26, DECK_TOP_Y - 150)
	doorslab.size = Vector2(40, 144)
	doorslab.z_index = -18
	add_child(doorslab)
	# Warm spill pooling on the deck in front of the door
	var spill := ColorRect.new()
	spill.color = Color(1.0, 0.7, 0.35, 0.18)
	spill.position = Vector2(DOOR_X - 70, DECK_TOP_Y)
	spill.size = Vector2(140, 60)
	spill.z_index = -3
	add_child(spill)
	_door_arrow = _make_interact_arrow(DOOR_X, DECK_TOP_Y - 190, Color(1.0, 0.75, 0.35))


# ─────────────────────────────────────────────────────────────────────────
# HUD — CanvasLayer overlay
# ─────────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	# Hearts / credits / hotbar are the GlobalHUD's job now — the balcony
	# only draws its own scene tag + interact prompt.
	var title := Label.new()
	title.text = "BALCONY · NIGHT"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.85))
	title.position = Vector2(20, 18)
	cl.add_child(title)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 17)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_status_label.position = Vector2(20, 40)
	cl.add_child(_status_label)

	var hint := Label.new()
	hint.text = "WASD MOVE · E INTERACT · I PHONE"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	hint.anchor_left = 0.0
	hint.anchor_bottom = 1.0
	hint.anchor_top = 1.0
	hint.offset_left = 20
	hint.offset_top = -22
	hint.offset_bottom = -8
	cl.add_child(hint)

func _set_status(txt: String) -> void:
	if _status_label:
		_status_label.text = txt


# ─────────────────────────────────────────────────────────────────────────
# Spawn marker — look up by name and set player.x
# ─────────────────────────────────────────────────────────────────────────

func _apply_pending_spawn() -> void:
	var spawn: String = SceneTransition.consume_spawn()
	if spawn == "":
		return
	# Arrive at the door (from the hallway) or by the stairs (from the street)
	if spawn == "from_hall":
		_player_sprite.position.x = DOOR_X
	elif spawn == "from_stairs":
		_player_sprite.position.x = STAIRS_X + 130.0


# ─────────────────────────────────────────────────────────────────────────
# Process — walk + camera follow + NPC anim + edge crossing
# ─────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_tick_player(delta)
	_tick_camera(delta)
	_tick_parallax()
	for npc in _npcs:
		npc.tick(delta)
	_check_interactables()

func _tick_player(delta: float) -> void:
	var input_x: float = Input.get_axis("move_left", "move_right")
	var input_y: float = Input.get_axis("move_up", "move_down")
	var speed := 240.0
	if Input.is_action_pressed("sprint"):
		speed *= 1.7
	_player_moving = Vector2(input_x, input_y).length() > 0.1

	# Facing: horizontal wins over vertical when both are pressed
	if absf(input_x) >= absf(input_y) and absf(input_x) > 0.1:
		_player_facing = Facing.RIGHT if input_x > 0 else Facing.LEFT
	elif absf(input_y) > 0.1:
		_player_facing = Facing.DOWN if input_y > 0 else Facing.UP

	# Walk
	_player_sprite.position.x += input_x * speed * delta
	_player_sprite.position.y += input_y * speed * 0.6 * delta
	_player_sprite.position.x = clampf(_player_sprite.position.x,
		-DECK_HALF_W, DECK_HALF_W)
	_player_sprite.position.y = clampf(_player_sprite.position.y,
		PLAYER_Y_MIN, PLAYER_Y_MAX)

	# Animate frames
	if _player_moving:
		_player_anim_t += delta
		var step: float = 1.0 / FPS
		while _player_anim_t >= step:
			_player_anim_t -= step
			_player_frame = (_player_frame + 1) % COLS
	else:
		_player_frame = 0
		_player_anim_t = 0.0
	_player_atlas.region = Rect2(_player_frame * FRAME_W,
		_player_facing * FRAME_H, FRAME_W, FRAME_H)

func _tick_camera(_delta: float) -> void:
	# Camera follows player on X, vertical stays locked
	_camera.position.x = _player_sprite.position.x

# Proximity → flare the nearest interact arrow. No HUD prompt text: the
# neon signs and the bobbing arrows say what's there.
var _near_id := ""
func _check_interactables() -> void:
	var x := _player_sprite.position.x
	var door_near := absf(x - DOOR_X) <= 90.0
	var stairs_near := absf(x - STAIRS_X) <= 100.0
	var rail_near := absf(x - RAIL_SPOT_X) <= RAIL_SPOT_HALF_W
	_flare(_door_arrow, door_near)
	_flare(_stairs_arrow, stairs_near)
	if _rail_glow:
		_rail_glow.modulate.a = 1.0 if rail_near else 0.5
		_rail_glow.scale = Vector2(1.3, 1.3) if rail_near else Vector2.ONE
	_at_railing = rail_near
	# Nearest wins if overlapping
	if door_near:
		_near_id = "door"
	elif stairs_near:
		_near_id = "stairs"
	elif rail_near:
		_near_id = "rail"
	else:
		_near_id = ""

func _flare(arrow: Polygon2D, near: bool) -> void:
	if arrow:
		arrow.modulate.a = 1.0 if near else 0.45
		arrow.scale = Vector2(1.25, 1.25) if near else Vector2.ONE


# ─────────────────────────────────────────────────────────────────────────
# Input
# ─────────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# phone_toggle is handled by the Phone autoload — toggling here too made
	# one keypress open+close the phone in the same frame.
	if event.is_action_pressed("interact"):
		match _near_id:
			"door":
				SceneTransition.go("hallway", "from_balcony")
			"stairs":
				SceneTransition.go("city", "from_stairs")
			"rail":
				_lean_on_railing()

func _lean_on_railing() -> void:
	# Face the city (back to camera) and cycle a flavor line
	_player_facing = Facing.UP
	_player_atlas.region = Rect2(0, _player_facing * FRAME_H, FRAME_W, FRAME_H)
	_set_status(RAIL_LINES[_rail_line_idx % RAIL_LINES.size()])
	_rail_line_idx += 1
