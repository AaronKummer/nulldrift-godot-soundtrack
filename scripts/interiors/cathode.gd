## THE CATHODE — underground live music venue. Port of the Phaser
## CathodeScene. Two bands rotate nightly:
##   PERFECT TOMMY — Aaron (Ultranova synth), John (drum machines/vocals),
##                   Brian (bass, frontman). High energy punk.
##   GODSNACK — Greg, solo. Guitar, keyboard, drum machine. Cyberpunk
##              Lou Reed. Brooding, poetic, raw.
## Spotlights sweep, the crowd bounces, lyrics float off the stage.
extends "res://scripts/interiors/interior_base.gd"

const ListMenuScript := preload("res://scripts/systems/list_menu.gd")

const LYRICS_PT := [
	"BURNING CHROME IN THE NEON RAIN",
	"WE ARE THE GLITCH IN THE MACHINE",
	"UPLOAD YOUR SOUL / DELETE YOUR PAIN",
	"STATIC HEARTS AND ELECTRIC VEINS",
	"THE NETWORK NEVER SLEEPS",
	"REBOOT THE REVOLUTION",
	"SIGNAL LOST / SIGNAL FOUND",
	"RUNNING HOT ON STOLEN CODE",
	"404: HOPE NOT FOUND",
	"GHOST IN THE WIRE",
	"OVERCLOCK MY HEART",
	"DIGITAL LOVE IN AN ANALOG WORLD",
	"ERROR: TOO MUCH FEELING",
	"BREAK THE FIREWALL, FREE YOUR MIND",
	"CHROME AND BONE AND NEON LIGHT",
]
const LYRICS_GS := [
	"WALKING DOWN THE ELECTRIC AVENUE",
	"THE CITY HUMS BUT IT DON'T SING FOR YOU",
	"SATELLITE EYES IN A NEON SKY",
	"I SOLD MY SHADOW TO THE ALGORITHM",
	"SWEET JANE IN THE MACHINE",
	"PERFECT DAY FOR A SYSTEM CRASH",
	"ALL TOMORROW'S PARTIES... CANCELLED",
	"TAKE A WALK ON THE DARK WEB SIDE",
	"WAITING FOR MY BANDWIDTH",
]

const DRINK_COST := 5
const DRINK_HEAL := 15

var _is_godsnack := false
var _crowd: Array = []          # { node, phase, amp }
var _surge_t := 0.0
var _lyric_labels: Array = []
var _lyric_t := 0.0
var _spots: Array = []
var _bar_menu

func _ready() -> void:
	room_w = 32.0
	room_d = 22.0
	interior_name = "THE CATHODE"
	exit_scene = "street_downtown"
	exit_spawn = "from_cathode"
	_is_godsnack = randi() % 2 == 0
	super._ready()
	Music.play_category("live_band")
	var band := "GODSNACK" if _is_godsnack else "PERFECT TOMMY"
	_set_status(band + " is on stage tonight.")

func _ambient() -> Color:
	return Color(0.16, 0.12, 0.22)

func _wall_color() -> Color:
	return Color(0.09, 0.07, 0.11)

func _floor_color() -> Color:
	return Color(0.08, 0.07, 0.10)

func _build_interior() -> void:
	_build_stage()
	_build_band()
	_build_spotlights()
	_build_crowd()
	_build_bar()
	_build_merch()

# ── the stage ────────────────────────────────────────────────────────────
func _build_stage() -> void:
	_add_box(Vector3(0, 0.45, -8.5), Vector3(20.0, 0.9, 4.6),
		Color(0.14, 0.10, 0.08), 0.1, 0.7)                       # platform
	_add_box(Vector3(0, 0.92, -8.5), Vector3(20.0, 0.06, 4.6),
		Color(0.20, 0.15, 0.11), 0.1, 0.5)                       # worn top
	# Edge strip light
	_add_box(Vector3(0, 0.95, -6.25), Vector3(20.0, 0.05, 0.06),
		Color(1.0, 0.2, 0.8), 0.0, 0.4, true, Color(1.5, 0.25, 1.0), 2.2)
	# Amp stacks flanking
	for ax in [-8.5, 8.5]:
		for i in 2:
			_add_box(Vector3(ax, 1.4 + i * 1.15, -9.2), Vector3(1.6, 1.1, 1.2),
				Color(0.07, 0.07, 0.08), 0.2, 0.7)
			_add_box(Vector3(ax, 1.4 + i * 1.15, -8.58), Vector3(1.3, 0.8, 0.06),
				Color(0.12, 0.12, 0.13), 0.0, 0.9)               # grille
	# Floor monitors
	for mx in [-4.0, 4.0]:
		_add_box(Vector3(mx, 1.05, -6.6), Vector3(1.2, 0.5, 0.7),
			Color(0.08, 0.08, 0.09), 0.2, 0.7)
	# Back wall: THE CATHODE in dying neon + a big CRT logo
	var sign := Label3D.new()
	sign.text = "THE CATHODE"
	sign.font_size = 140
	sign.pixel_size = 0.012
	sign.modulate = Color(1.5, 0.25, 0.9)
	sign.outline_size = 18
	sign.outline_modulate = Color(0.2, 0.0, 0.15)
	sign.position = Vector3(0, 4.2, -10.6)
	add_child(sign)
	_add_box(Vector3(0, 3.5, -10.6), Vector3(11.0, 0.05, 0.05),
		Color(1.0, 0.2, 0.7), 0.0, 0.4, true, Color(1.5, 0.25, 0.9), 2.6)
	# Watch-the-band zone at the stage lip
	add_interact(Vector3(0, 1.2, -5.6), Vector3(10.0, 2.4, 1.8),
		"watch the band", _watch_band)

# ── the band ─────────────────────────────────────────────────────────────
func _build_band() -> void:
	if _is_godsnack:
		# Greg, alone with three instruments and zero apologies
		add_npc("res://assets/sprites/smoking_scrapper.png", Vector3(0.0, 1.8, -8.6), 0)
		_stage_prop_console(Vector3(-1.6, 0, -8.2), Color(0.9, 0.6, 0.2))   # keyboard
		_stage_prop_console(Vector3(1.6, 0, -8.2), Color(0.3, 0.9, 1.0))    # drum machine
		_name_tag("GREG", Vector3(0.0, 3.1, -8.6), Color(0.9, 0.7, 0.4))
	else:
		# Perfect Tommy, three-piece
		add_npc("res://assets/sprites/npc-cyberpunk.png", Vector3(-4.5, 1.8, -8.6), 0)
		_stage_prop_console(Vector3(-4.5, 0, -7.6), Color(0.4, 0.9, 1.2))   # the Ultranova
		_name_tag("AARON", Vector3(-4.5, 3.1, -8.6), Color(0.4, 0.9, 1.2))
		add_npc("res://assets/sprites/npc-thug.png", Vector3(4.5, 1.8, -8.6), 0)
		_stage_prop_console(Vector3(4.5, 0, -7.6), Color(1.0, 0.5, 0.9))    # drum machines
		_name_tag("JOHN", Vector3(4.5, 3.1, -8.6), Color(1.0, 0.5, 0.9))
		add_npc("res://assets/sprites/npc-corpo.png", Vector3(0.0, 1.8, -8.0), 0)
		_name_tag("BRIAN", Vector3(0.0, 3.1, -8.0), Color(1.2, 0.9, 0.3))
		# Mic stand for the frontman
		_add_box(Vector3(0.4, 1.6, -7.4), Vector3(0.05, 1.4, 0.05),
			Color(0.3, 0.3, 0.33), 0.8, 0.3)

func _stage_prop_console(pos: Vector3, glow: Color) -> void:
	_add_box(pos + Vector3(0, 1.15, 0), Vector3(1.6, 0.14, 0.6),
		Color(0.06, 0.06, 0.08), 0.3, 0.5)
	_add_box(pos + Vector3(0, 1.24, 0), Vector3(1.4, 0.04, 0.45),
		glow * 0.35, 0.0, 0.4, true, glow, 1.4)
	_add_box(pos + Vector3(-0.6, 0.55, 0), Vector3(0.1, 1.1, 0.1),
		Color(0.2, 0.2, 0.22), 0.7, 0.4)
	_add_box(pos + Vector3(0.6, 0.55, 0), Vector3(0.1, 1.1, 0.1),
		Color(0.2, 0.2, 0.22), 0.7, 0.4)

func _name_tag(n: String, pos: Vector3, col: Color) -> void:
	var l := Label3D.new()
	l.text = n
	l.font_size = 48
	l.pixel_size = 0.01
	l.modulate = col
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0)
	l.position = pos
	add_child(l)

# ── sweeping spotlights ──────────────────────────────────────────────────
func _build_spotlights() -> void:
	for spec in [[Vector3(-6.0, 5.2, -4.0), Color(1.5, 0.25, 0.9)],
			[Vector3(6.0, 5.2, -4.0), Color(0.25, 0.9, 1.5)]]:
		var spot := SpotLight3D.new()
		spot.position = spec[0]
		spot.light_color = spec[1]
		spot.light_energy = 6.0
		spot.spot_range = 14.0
		spot.spot_angle = 22.0
		spot.shadow_enabled = true
		add_child(spot)
		spot.look_at(Vector3(0, 1.0, -8.5), Vector3.UP)
		_spots.append({ "l": spot, "ph": randf() * TAU })

# ── the crowd ────────────────────────────────────────────────────────────
func _build_crowd() -> void:
	var sheets := ["res://assets/sprites/civ/civ-a02.png",
		"res://assets/sprites/civ/civ-a05.png", "res://assets/sprites/civ/civ-a09.png",
		"res://assets/sprites/civ/civ-b01.png", "res://assets/sprites/civ/civ-b04.png",
		"res://assets/sprites/civ/civ-b07.png", "res://assets/sprites/civ/civ-b10.png",
		"res://assets/sprites/civ/civ-a11.png", "res://assets/sprites/cyberGirl.png",
		"res://assets/sprites/lady.png"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xCA70
	for i in 10:
		var px := rng.randf_range(-8.0, 8.0)
		var pz := rng.randf_range(-4.6, -1.8)
		var fan := add_npc(sheets[i % sheets.size()], Vector3(px, 0.9, pz), 3,
			[Color(1, 1, 1), Color(1.0, 0.85, 0.85), Color(0.85, 0.9, 1.0),
				Color(0.88, 1.0, 0.88), Color(1.0, 0.95, 0.78)][rng.randi() % 5])
		_crowd.append({ "node": fan, "phase": rng.randf() * TAU,
			"amp": rng.randf_range(0.06, 0.16), "base": 0.9 })

# ── Zee's bar ────────────────────────────────────────────────────────────
func _build_bar() -> void:
	_add_box(Vector3(-11.5, 0.55, 6.5), Vector3(5.0, 1.1, 1.4),
		Color(0.14, 0.09, 0.07), 0.1, 0.5)
	_add_box(Vector3(-11.5, 1.12, 6.5), Vector3(5.3, 0.08, 1.7),
		Color(0.08, 0.07, 0.08), 0.6, 0.3)
	_add_box(Vector3(-11.5, 0.2, 7.2), Vector3(5.0, 0.05, 0.04),
		Color(1.0, 0.2, 0.8), 0.0, 0.5, true, Color(1.4, 0.25, 0.9), 2.0)
	add_npc("res://assets/sprites/cyberGirl.png", Vector3(-11.5, 0.9, 5.4), 0)
	add_interact(Vector3(-11.5, 1.2, 8.0), Vector3(4.6, 2.4, 2.0),
		"zee's bar", _open_zee_menu)

func _open_zee_menu() -> void:
	_menu_open = true
	_bar_menu = ListMenuScript.new()
	add_child(_bar_menu)
	_bar_menu.picked.connect(_on_zee_pick)
	_bar_menu.closed.connect(func():
		_menu_open = false
		_bar_menu = null)
	_bar_menu.open("THE CATHODE · zee doesn't card", [
		{ "label": "HOUSE SWILL · %dcr (+%d hp)" % [DRINK_COST, DRINK_HEAL] },
		{ "label": "talk to zee" },
	], Color(1.4, 0.3, 0.9),
		"credits: %d   hp: %d/%d" % [GameState.credits, GameState.hp, GameState.hp_max])

func _on_zee_pick(idx: int) -> void:
	if idx == 1:
		_bar_menu.close_menu()
		DialogueOverlay.play("zee")
		return
	if GameState.credits < DRINK_COST:
		_bar_menu.set_footer("zee: 'tab's closed, choom.'")
		return
	GameState.add_credits(-DRINK_COST)
	GameState.hp = mini(GameState.hp + DRINK_HEAL, GameState.hp_max)
	_bar_menu.set_footer("credits: %d   hp: %d/%d · it tastes like batteries. good ones."
		% [GameState.credits, GameState.hp, GameState.hp_max])

# ── merch table ──────────────────────────────────────────────────────────
func _build_merch() -> void:
	_add_box(Vector3(11.0, 0.55, 6.5), Vector3(4.0, 1.1, 1.6),
		Color(0.12, 0.10, 0.09), 0.1, 0.6)
	for i in 3:
		var tc: Color = [Color(1.4, 0.3, 0.9), Color(0.3, 0.9, 1.4), Color(1.2, 0.9, 0.3)][i]
		_add_box(Vector3(9.8 + i * 1.2, 1.25, 6.4), Vector3(0.8, 0.25, 0.6),
			tc * 0.4, 0.0, 0.6, true, tc, 0.5)
	add_interact(Vector3(11.0, 1.2, 8.0), Vector3(4.4, 2.4, 2.0),
		"merch table", func():
			_set_status("PERFECT TOMMY shirts. GODSNACK vinyl. the vinyl is a CD glued to a record. 'limited edition.'"))

# ── watching the band ────────────────────────────────────────────────────
func _watch_band() -> void:
	_surge_t = 3.0
	if _is_godsnack:
		DialogueOverlay.play_lines([
			{ "speaker": "GREG", "text": "this one's about a vending machine that loved a girl.", "color": Color(0.9, 0.7, 0.4) },
			{ "speaker": "", "text": "He plays three instruments at once and stares through the back wall.", "color": Color(0.53, 0.53, 0.53) },
			{ "speaker": "", "text": "The crowd sways like a single organism with poor posture.", "color": Color(0.53, 0.53, 0.53) },
		], "band")
	else:
		DialogueOverlay.play_lines([
			{ "speaker": "BRIAN", "text": "SIGNAL HOLLOW! ARE YOU RECEIVING?", "color": Color(1.2, 0.9, 0.3) },
			{ "speaker": "", "text": "Aaron absolutely kills it on the Ultranova. John's drum machines hit like a car crash in 4/4.", "color": Color(0.53, 0.53, 0.53) },
			{ "speaker": "", "text": "The crowd surges. Somebody loses a shoe. Nobody cares.", "color": Color(0.53, 0.53, 0.53) },
		], "band")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var t := Time.get_ticks_msec() / 1000.0
	_surge_t = maxf(0.0, _surge_t - delta)
	var surge := 1.0 + (1.4 if _surge_t > 0.0 else 0.0)
	for c in _crowd:
		var n: Node3D = c.node
		n.position.y = c.base + absf(sin(t * 5.0 + c.phase)) * c.amp * surge
	for s in _spots:
		var sp: SpotLight3D = s.l
		sp.rotation.y = sin(t * 0.6 + s.ph) * 0.35
	# Floating lyrics
	_lyric_t -= delta
	if _lyric_t <= 0.0:
		_lyric_t = 2.6
		_spawn_lyric()

func _spawn_lyric() -> void:
	var pool := LYRICS_GS if _is_godsnack else LYRICS_PT
	var l := Label3D.new()
	l.text = pool[randi() % pool.size()]
	l.font_size = 40
	l.pixel_size = 0.010
	l.modulate = Color(1.4, 0.3, 0.9) if not _is_godsnack else Color(0.9, 0.7, 0.4)
	l.outline_size = 8
	l.outline_modulate = Color(0, 0, 0)
	l.position = Vector3(randf_range(-6.0, 6.0), 2.6, -7.5)
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 2.8, 3.2)
	tw.tween_property(l, "modulate:a", 0.0, 3.2).from(1.0)
	tw.chain().tween_callback(l.queue_free)
