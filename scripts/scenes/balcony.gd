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
	{ "sheet": "res://assets/sprites/smoking_drifter.png",
	  "x":  520.0, "facing": Facing.DOWN, "cycle": [0,1,2,1], "fps": 0.8 },
]

# Transitions: where each end of the deck takes you
const TRANSITION_LEFT_TARGET  := { "scene": "hallway", "spawn": "from_balcony" }
const TRANSITION_RIGHT_TARGET := { "scene": "city",    "spawn": "from_stairs" }

var _camera: Camera2D
var _backdrop: Sprite2D
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
var _at_left_edge: bool = false
var _at_right_edge: bool = false


func _ready() -> void:
	_build_backdrop_and_camera()
	_build_deck_visuals()
	_build_npcs()
	_build_player()
	_build_edge_triggers()
	_build_hud()
	_apply_pending_spawn()
	Music.play_category("balcony")


# ─────────────────────────────────────────────────────────────────────────
# BACKDROP + CAMERA — backdrop is a child of the camera so the city stays
# locked to the screen as the player walks
# ─────────────────────────────────────────────────────────────────────────

func _build_backdrop_and_camera() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(0, 360)   # vertical center of 720 viewport
	add_child(_camera)
	_camera.make_current()

	# Backdrop — child of the camera, centered, scaled to fit 1280×720.
	# Source PNG is 1920×1080, so scale = 1280/1920 = 0.667 (uniform).
	_backdrop = Sprite2D.new()
	_backdrop.texture = load("res://assets/textures/backdrop_balcony_city.png")
	_backdrop.centered = true
	_backdrop.position = Vector2.ZERO
	_backdrop.scale = Vector2(1280.0 / 1920.0, 720.0 / 1080.0)
	_backdrop.z_index = -50
	_camera.add_child(_backdrop)


# ─────────────────────────────────────────────────────────────────────────
# DECK VISUALS — thin strip across the bottom + railing line, world space
# (these scroll with the player as the camera follows X)
# ─────────────────────────────────────────────────────────────────────────

func _build_deck_visuals() -> void:
	# Long deck strip — extends well beyond the visible viewport on both
	# sides so the player can walk to the edges without seeing the end of it
	var deck := ColorRect.new()
	deck.color = Color(0.08, 0.06, 0.10)
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
	rail2.color = Color(0.0, 0.55, 0.85)
	rail2.position = Vector2(-3000, DECK_TOP_Y + 14)
	rail2.size = Vector2(6000, 3)
	rail2.z_index = -5
	add_child(rail2)
	# Posts at intervals
	for x_post in range(-2900, 3000, 120):
		var post := ColorRect.new()
		post.color = Color(0.20, 0.20, 0.26)
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

func _build_edge_triggers() -> void:
	# Visible hint marker on the left side: small arrow + label "← hallway"
	var left_hint := Label.new()
	left_hint.text = "← hallway"
	left_hint.add_theme_font_size_override("font_size", 13)
	left_hint.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	left_hint.position = Vector2(-DECK_HALF_W + 40, 470)
	add_child(left_hint)

	# Visible hint marker on the right side: small arrow + label "stairs ↓"
	var right_hint := Label.new()
	right_hint.text = "stairs →"
	right_hint.add_theme_font_size_override("font_size", 13)
	right_hint.add_theme_color_override("font_color", Color(0.0, 1.0, 1.2))
	right_hint.position = Vector2(DECK_HALF_W - 100, 470)
	add_child(right_hint)


# ─────────────────────────────────────────────────────────────────────────
# HUD — CanvasLayer overlay
# ─────────────────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	# HEALTH label + hearts
	var hp_label := Label.new()
	hp_label.text = "HEALTH"
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	hp_label.position = Vector2(20, 14)
	cl.add_child(hp_label)
	for i in 5:
		var heart := Label.new()
		heart.text = "♥"
		heart.add_theme_font_size_override("font_size", 18)
		heart.add_theme_color_override("font_color", Color(1.0, 0.20, 0.45))
		heart.position = Vector2(82 + i * 22, 6)
		cl.add_child(heart)

	# CREDITS / BOUNTY
	var credits := Label.new()
	credits.text = "CREDITS"
	credits.add_theme_font_size_override("font_size", 11)
	credits.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	credits.position = Vector2(20, 42)
	cl.add_child(credits)
	var credits_amt := Label.new()
	credits_amt.text = "$0"
	credits_amt.add_theme_font_size_override("font_size", 14)
	credits_amt.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	credits_amt.position = Vector2(82, 39)
	cl.add_child(credits_amt)
	var bounty := Label.new()
	bounty.text = "BOUNTY"
	bounty.add_theme_font_size_override("font_size", 11)
	bounty.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	bounty.position = Vector2(20, 62)
	cl.add_child(bounty)
	var bounty_amt := Label.new()
	bounty_amt.text = "★ 0"
	bounty_amt.add_theme_font_size_override("font_size", 13)
	bounty_amt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
	bounty_amt.position = Vector2(82, 60)
	cl.add_child(bounty_amt)

	# Inventory row
	for i in 6:
		var slot := Panel.new()
		slot.position = Vector2(200 + i * 36, 8)
		slot.size = Vector2(28, 28)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.05, 0.08, 0.65)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.4, 0.5, 0.65, 0.7)
		slot.add_theme_stylebox_override("panel", sb)
		cl.add_child(slot)

	# Scene tag
	var title := Label.new()
	title.text = "BALCONY · NIGHT"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.85))
	title.position = Vector2(20, 92)
	cl.add_child(title)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_status_label.position = Vector2(20, 112)
	cl.add_child(_status_label)

	var hint := Label.new()
	hint.text = "WASD MOVE · E INTERACT · P PHONE"
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
	# Place player based on which edge they arrived from
	if spawn == "from_hall":
		_player_sprite.position.x = -DECK_HALF_W + 200
	elif spawn == "from_stairs":
		_player_sprite.position.x = DECK_HALF_W - 200


# ─────────────────────────────────────────────────────────────────────────
# Process — walk + camera follow + NPC anim + edge crossing
# ─────────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_tick_player(delta)
	_tick_camera(delta)
	for npc in _npcs:
		npc.tick(delta)
	_check_edge_crossing()

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

func _check_edge_crossing() -> void:
	# Near-edge detection — sets _at_left_edge/_at_right_edge so the [E]
	# prompt shows in the HUD. Actual transition happens on E press.
	var x := _player_sprite.position.x
	var threshold := 120.0
	if x <= -DECK_HALF_W + threshold:
		if not _at_left_edge:
			_at_left_edge = true
			_set_status("[E] ← hallway")
	else:
		if _at_left_edge:
			_at_left_edge = false
			if not _at_right_edge:
				_set_status("")
	if x >= DECK_HALF_W - threshold:
		if not _at_right_edge:
			_at_right_edge = true
			_set_status("[E] stairs → street")
	else:
		if _at_right_edge:
			_at_right_edge = false
			if not _at_left_edge:
				_set_status("")


# ─────────────────────────────────────────────────────────────────────────
# Input
# ─────────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone_toggle"):
		Phone.toggle()
	elif event.is_action_pressed("interact"):
		if _at_left_edge:
			SceneTransition.go(TRANSITION_LEFT_TARGET.scene, TRANSITION_LEFT_TARGET.spawn)
		elif _at_right_edge:
			SceneTransition.go(TRANSITION_RIGHT_TARGET.scene, TRANSITION_RIGHT_TARGET.spawn)
