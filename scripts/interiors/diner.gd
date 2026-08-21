## HANK'S DINER — home street. Checkerboard floor, counter service, pie
## case, and the booths along the west wall. Booth two is canon: it's
## where Nyx will meet you when Act 1 wires up (dialogueTrees.js:52,
## "Booth two, Ghost. ...God, you look terrible."). Hank and Roxy speak
## their Phaser lines.
extends "res://scripts/interiors/interior_base.gd"

const ListMenuScript := preload("res://scripts/systems/list_menu.gd")

const MENU := [
	{ "id": "coffee",  "name": "COFFEE",         "price": 5,  "heal": 5,
	  "bark": "hank pours without looking. it's perfect. he knows it's perfect." },
	{ "id": "cakes",   "name": "STACK O' CAKES", "price": 12, "heal": 20,
	  "bark": "syrup that glows faintly. roxy swears it's just food coloring." },
	{ "id": "special", "name": "THE SPECIAL",    "price": 25, "heal": 40,
	  "bark": "you don't ask what it is. hank doesn't say. it's delicious." },
]

var _diner_menu

func _ready() -> void:
	room_w = 28.0
	room_d = 18.0
	interior_name = "HANK'S DINER"
	exit_scene = "city"
	exit_spawn = "from_diner"
	super._ready()
	Music.play_category("shops")

func _ambient() -> Color:
	return Color(0.34, 0.27, 0.18)

func _floor_color() -> Color:
	return Color(0.13, 0.12, 0.11)

func _build_interior() -> void:
	_build_checker_floor()
	_build_counter_and_hank()
	_build_pie_case()
	_build_booths()
	_build_roxy()
	_build_neon()

# ── checkerboard tile over the base floor ────────────────────────────────
func _build_checker_floor() -> void:
	var tile := 2.0
	var nx := int(room_w / tile)
	var nz := int(room_d / tile)
	for ix in nx:
		for iz in nz:
			if (ix + iz) % 2 == 0:
				continue
			_add_box(Vector3(-room_w / 2.0 + tile * 0.5 + ix * tile, 0.011,
					-room_d / 2.0 + tile * 0.5 + iz * tile),
					Vector3(tile, 0.022, tile),
					Color(0.55, 0.52, 0.48), 0.0, 0.6)

# ── counter along the back, Hank behind it ───────────────────────────────
func _build_counter_and_hank() -> void:
	var cz := -5.5
	_add_box(Vector3(1.0, 0.55, cz), Vector3(15.0, 1.1, 1.4),
		Color(0.55, 0.10, 0.12), 0.1, 0.5)                     # red diner body
	_add_box(Vector3(1.0, 1.12, cz), Vector3(15.4, 0.08, 1.7),
		Color(0.75, 0.72, 0.68), 0.5, 0.25)                    # chrome top
	_add_box(Vector3(1.0, 0.18, cz + 0.74), Vector3(15.0, 0.06, 0.04),
		Color(0.9, 0.3, 0.3), 0.0, 0.5, true, Color(1.2, 0.25, 0.25), 2.0)
	# Stools — chrome + red caps
	for i in 5:
		var sx := -4.5 + i * 2.8
		_add_box(Vector3(sx, 0.35, cz + 1.9), Vector3(0.14, 0.7, 0.14),
			Color(0.6, 0.6, 0.65), 0.9, 0.2)
		_add_box(Vector3(sx, 0.76, cz + 1.9), Vector3(0.6, 0.12, 0.6),
			Color(0.7, 0.12, 0.14), 0.1, 0.5)
	# Coffee machine — steaming
	_add_box(Vector3(-5.0, 1.55, cz - 0.3), Vector3(0.9, 0.8, 0.6),
		Color(0.20, 0.20, 0.23), 0.7, 0.3, true, Color(1.0, 0.5, 0.2), 0.3)
	# Hank behind the counter
	add_npc("res://assets/sprites/civ/civ-a02.png", Vector3(1.0, 0.9, cz - 1.3), 0)
	add_interact(Vector3(1.0, 1.2, cz + 2.0), Vector3(6.0, 2.4, 2.4),
		"talk to hank / order food", _open_diner_menu)

func _build_pie_case() -> void:
	var cz := -5.5
	_add_box(Vector3(8.0, 1.5, cz), Vector3(2.4, 0.7, 1.2),
		Color(0.12, 0.20, 0.24), 0.3, 0.15, true, Color(0.5, 0.8, 0.9), 0.7)
	for i in 2:
		_add_box(Vector3(7.4 + i * 1.2, 1.35, cz), Vector3(0.55, 0.18, 0.55),
			[Color(0.7, 0.4, 0.15), Color(0.55, 0.2, 0.3)][i], 0.0, 0.6)

# ── booths along the west wall — booth two is THE booth ──────────────────
func _build_booths() -> void:
	var bx := -room_w / 2.0 + 2.2
	for i in 3:
		var bz := -3.5 + i * 4.4
		# Table
		_add_box(Vector3(bx + 1.6, 0.75, bz), Vector3(1.8, 0.08, 1.6),
			Color(0.60, 0.58, 0.54), 0.4, 0.3)
		_add_box(Vector3(bx + 1.6, 0.38, bz), Vector3(0.16, 0.75, 0.16),
			Color(0.3, 0.3, 0.33), 0.7, 0.4)
		# Bench seats north+south of the table
		for off in [-1.35, 1.35]:
			_add_box(Vector3(bx + 1.6, 0.45, bz + off), Vector3(2.0, 0.9, 0.7),
				Color(0.50, 0.10, 0.12), 0.1, 0.6)
			_add_box(Vector3(bx + 1.6, 1.1, bz + off * 1.22), Vector3(2.0, 1.2, 0.25),
				Color(0.45, 0.09, 0.11), 0.1, 0.6)
		# Booth number — little glowing tag on the wall
		var tag := Label3D.new()
		tag.text = str(3 - i)
		tag.font_size = 64
		tag.pixel_size = 0.008
		tag.modulate = Color(1.0, 0.6, 0.25)
		tag.outline_size = 12
		tag.outline_modulate = Color(0, 0, 0)
		tag.position = Vector3(bx - 0.8, 1.9, bz)
		tag.rotation.y = PI / 2.0
		add_child(tag)
	# Booth two (middle) — the story booth. Nyx waits here through Act 1.
	var booth_two_z := 0.9
	if _nyx_present():
		# NYX at the booth (smoking_drifter = her canon hooded sprite),
		# seated at the table end so she isn't standing in the bench
		add_npc("res://assets/sprites/smoking_drifter.png",
			Vector3(bx + 2.9, 0.9, booth_two_z), 2, Color(1.0, 0.9, 1.0))
		add_interact(Vector3(bx + 3.2, 1.0, booth_two_z), Vector3(1.8, 2.2, 3.0),
			"talk to the girl in booth two", _talk_to_nyx)
	else:
		add_interact(Vector3(bx + 3.2, 1.0, booth_two_z), Vector3(1.8, 2.2, 3.0),
			"booth two", func():
				DialogueOverlay.play_lines([
					{ "speaker": "", "text": "The booth sits empty. A coffee cup, still warm. Magenta lipstick on the rim.", "color": Color(0.53, 0.53, 0.53) },
					{ "speaker": "", "text": "Someone's carved into the table edge: 0xFADE.", "color": Color(0.53, 0.53, 0.53) },
				], "booth_two"))

## Nyx is at booth two from the first-hack meeting until Act 1 wraps.
func _nyx_present() -> bool:
	return GameState.has_flag("firstHackDone") and not GameState.has_flag("actOneComplete")

func _talk_to_nyx() -> void:
	# Snapshot the quest-relevant state BEFORE the talk, apply the payoff
	# when the dialogue finishes.
	var was_met: bool = GameState.has_flag("metCyberGirl")
	var report_ready: bool = GameState.has_flag("securedTerminalHacked") 			and not GameState.has_flag("actOneComplete")
	if not DialogueOverlay.finished.is_connected(_on_nyx_talk_done):
		DialogueOverlay.finished.connect(_on_nyx_talk_done.bind(was_met, report_ready),
			CONNECT_ONE_SHOT)
	DialogueOverlay.play("nyx_diner")

func _on_nyx_talk_done(_npc: String, was_met: bool, report_ready: bool) -> void:
	# First sit-down completes the meeting (grants metCyberGirl + 500 cr)
	if not was_met and GameState.has_flag("firstHackDone"):
		GameState.complete_quest("dinerMeeting")
	# Reporting the terminal data back closes Act 1
	elif report_ready:
		GameState.set_flag("reportedToNyx")   # completes goingDeeper → actOneComplete

func _build_roxy() -> void:
	# Roxy works the floor — standing at the end of booth three's table
	add_npc("res://assets/sprites/cyberGirl.png", Vector3(-8.2, 0.9, -4.6), 2,
		Color(1.0, 0.85, 0.9))
	add_interact(Vector3(-7.2, 1.0, -4.0), Vector3(2.2, 2.2, 2.2),
		"talk to roxy", func(): DialogueOverlay.play("roxy"))

func _build_neon() -> void:
	# EAT sign over the counter — classic
	var sign := Label3D.new()
	sign.text = "EAT"
	sign.font_size = 120
	sign.pixel_size = 0.012
	sign.modulate = Color(1.3, 0.35, 0.3)
	sign.outline_size = 18
	sign.outline_modulate = Color(0.3, 0.05, 0.05)
	sign.position = Vector3(1.0, 3.4, -room_d / 2.0 + 0.6)
	add_child(sign)
	var glow := OmniLight3D.new()
	glow.position = Vector3(1.0, 3.0, -5.0)
	glow.light_color = Color(1.0, 0.35, 0.3)
	glow.light_energy = 1.6
	glow.omni_range = 8.0
	glow.omni_attenuation = 1.5
	add_child(glow)
	# Warm ceiling pools
	for spot in [Vector3(-7.0, 3.6, 1.0), Vector3(4.0, 3.6, 1.5)]:
		_add_box(spot, Vector3(0.5, 0.15, 0.5),
			Color(0.95, 0.85, 0.6), 0.0, 0.4, true, Color(1.0, 0.88, 0.6), 1.6)
		var l := OmniLight3D.new()
		l.position = spot - Vector3(0, 0.4, 0)
		l.light_color = Color(1.0, 0.88, 0.65)
		l.light_energy = 2.0
		l.omni_range = 10.0
		l.omni_attenuation = 1.2
		add_child(l)

# ── counter service ──────────────────────────────────────────────────────
func _open_diner_menu() -> void:
	_menu_open = true
	_diner_menu = ListMenuScript.new()
	add_child(_diner_menu)
	var entries: Array = [{ "label": "talk to hank", "dim": false }]
	for m in MENU:
		entries.append({ "label": "%s · %d cr (+%d hp)" % [m.name, m.price, m.heal],
			"dim": false })
	_diner_menu.picked.connect(_on_diner_pick)
	_diner_menu.closed.connect(func():
		_menu_open = false
		_diner_menu = null)
	_diner_menu.open("HANK'S · what'll it be", entries, Color(1.0, 0.55, 0.3),
		"credits: $%d · hp: %d/%d" % [GameState.credits, GameState.hp, GameState.hp_max])

func _on_diner_pick(idx: int) -> void:
	if idx == 0:
		if _diner_menu:
			_diner_menu.close_menu()
		DialogueOverlay.play("hank")
		return
	var m: Dictionary = MENU[idx - 1]
	if GameState.credits < m.price:
		_diner_menu.set_footer("hank: 'no tab. house rule.'")
		return
	if GameState.hp >= GameState.hp_max:
		_diner_menu.set_footer("roxy: 'you look fine, hon. save your credits.'")
		return
	GameState.add_credits(-m.price)
	GameState.hp = mini(GameState.hp + m.heal, GameState.hp_max)
	_diner_menu.set_footer(m.bark)
