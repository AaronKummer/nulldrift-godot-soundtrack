## VOHL PHARMACEUTICALS (above ground) — a LIT, working corporate office
## tower, not a dungeon. Lobby lights on, staff at their desks. You ride the
## elevator up; floor 6 is Vohl's lab office, gated behind clearance you get
## by hacking a terminal (or, later, talking your way in). Floor 6 has the
## secret door down to the real lab — the basement dungeon ("vohl").
##
## Floors 2-5 are patrolled by security with vision cones (StealthGuard):
## walk freely, but linger in a cone, sprint past, or trip the alarm and you
## get grabbed, thrown out to the street, and marked (heat). Clearance for
## floor 6 comes three ways — hack the maint terminal (FL2), sneak the
## supervisor's keycard (FL3), or (later) talk your way in. Hold SHIFT to
## sneak so the cones fill slower.
##
## The whole thing is also doable remotely from the apartment via the deep-
## hacking net (that path lands in the same basement sim).
extends "res://scripts/interiors/interior_base.gd"

const ListMenuScript := preload("res://scripts/systems/list_menu.gd")
const StealthGuardScript := preload("res://scripts/systems/stealth_guard.gd")

var _floor := 1
var _menu
var _guards: Array = []
var _caught := false
var _alarm_label: Label

func _ready() -> void:
	_floor = clampi(GameState.vohl_floor, 1, 6)
	room_w = 30.0
	room_d = 18.0
	interior_name = "VOHL PHARMA · FL %d" % _floor
	exit_scene = "street_financial"
	exit_spawn = "from_vohl"
	super._ready()
	Music.play_category("shops")

# Bright office lighting — this reads as lit, NOT the dark dungeon
func _ambient() -> Color:
	return Color(0.55, 0.58, 0.65)

func _wall_color() -> Color:
	return Color(0.62, 0.64, 0.70)

func _floor_color() -> Color:
	return Color(0.40, 0.42, 0.47)

func _build_interior() -> void:
	_build_ceiling_lights()
	_build_elevator()
	match _floor:
		1: _build_reception()
		6: _build_vohl_floor()
		_: _build_cubicles()
	# Floors 2-5 are watched: security patrols the sensitive corners. Walk
	# freely, but linger in a cone (or run/kill) and the alarm trips.
	if _floor >= 2 and _floor <= 5:
		_build_guards()
	_build_alarm_hud()

func _build_ceiling_lights() -> void:
	for spot in [Vector3(-8, 4.2, -2), Vector3(0, 4.2, 2), Vector3(8, 4.2, -1)]:
		_add_box(spot, Vector3(2.4, 0.15, 0.6),
			Color(0.95, 0.97, 1.0), 0.0, 0.3, true, Color(1.0, 1.0, 1.0), 1.4)
		var l := OmniLight3D.new()
		l.position = spot - Vector3(0, 0.4, 0)
		l.light_color = Color(0.95, 0.97, 1.05)
		l.light_energy = 2.2
		l.omni_range = 13.0
		add_child(l)

# ── elevator (between floors) ────────────────────────────────────────────
func _build_elevator() -> void:
	var ex := room_w / 2.0 - 3.0
	var ez := -room_d / 2.0 + 1.2
	_add_box(Vector3(ex, 1.6, ez), Vector3(2.4, 3.2, 0.4),
		Color(0.30, 0.32, 0.38), 0.7, 0.3)
	_add_box(Vector3(ex, 1.5, ez + 0.24), Vector3(0.06, 2.6, 0.05),
		Color(0.5, 0.7, 0.9), 0.3, 0.2, true, Color(0.5, 0.8, 1.1), 1.0)   # door seam
	var panel := Label3D.new()
	panel.text = "▲▼"
	panel.font_size = 40
	panel.pixel_size = 0.01
	panel.modulate = Color(0.6, 0.9, 1.2)
	panel.position = Vector3(ex + 1.4, 1.6, ez + 0.3)
	add_child(panel)
	add_interact(Vector3(ex, 1.2, ez + 1.6), Vector3(2.8, 2.4, 2.2),
		"the elevator", _open_elevator)

func _open_elevator() -> void:
	_menu_open = true
	_menu = ListMenuScript.new()
	add_child(_menu)
	var entries: Array = []
	for f in range(1, 7):
		var locked: bool = f == 6 and not GameState.has_flag("vohlKeycard")
		var tag := ""
		if f == _floor:
			tag = " · you are here"
		elif locked:
			tag = " · RESTRICTED"
		entries.append({ "label": "FLOOR %d%s" % [f, tag], "dim": f == _floor or locked })
	_menu.picked.connect(_on_floor_pick)
	_menu.closed.connect(func():
		_menu_open = false
		_menu = null)
	_menu.open("ELEVATOR · select floor", entries, Color(0.5, 0.8, 1.1),
		"clearance: %s" % ("FLOOR 6" if GameState.has_flag("vohlKeycard") else "lobby only"))

func _on_floor_pick(idx: int) -> void:
	var f := idx + 1
	if f == _floor:
		return
	if f == 6 and not GameState.has_flag("vohlKeycard"):
		if _menu:
			_menu.set_footer("FLOOR 6 restricted — hack a terminal for clearance.")
		return
	GameState.vohl_floor = f
	SceneTransition.go("vohl_office", "elevator")

# ── floor 1: reception ───────────────────────────────────────────────────
func _build_reception() -> void:
	var cz := -5.0
	_add_box(Vector3(-2.0, 0.6, cz), Vector3(8.0, 1.2, 1.4),
		Color(0.75, 0.76, 0.8), 0.2, 0.4)                       # reception desk
	_add_box(Vector3(-2.0, 1.25, cz), Vector3(8.4, 0.08, 1.7),
		Color(0.5, 0.55, 0.6), 0.5, 0.3)
	# Backlit VOHL logo wall
	_add_box(Vector3(-2.0, 2.6, cz - 0.9), Vector3(7.0, 2.0, 0.2),
		Color(0.1, 0.3, 0.15), 0.0, 0.3, true, Color(0.4, 1.0, 0.5), 0.8)
	var logo := Label3D.new()
	logo.text = "VOHL"
	logo.font_size = 120
	logo.pixel_size = 0.012
	logo.modulate = Color(0.6, 1.3, 0.7)
	logo.position = Vector3(-2.0, 2.7, cz - 0.78)
	add_child(logo)
	add_npc("res://assets/sprites/cyberGirl.png", Vector3(-2.0, 0.9, cz - 1.3), 0)
	add_interact(Vector3(-2.0, 1.2, cz + 1.6), Vector3(6.0, 2.4, 2.4),
		"talk to the receptionist", func():
			DialogueOverlay.play_lines([
				{ "speaker": "RECEPTIONIST", "text": "Welcome to Vohl Pharmaceuticals. Do you have an appointment?", "color": Color(0.6, 1.1, 0.7) },
				{ "speaker": "RECEPTIONIST", "text": "...No? Floors two through five are open to visitors. Floor six is Dr. Vohl's. Restricted.", "color": Color(0.6, 1.1, 0.7) },
				{ "speaker": "", "text": "She goes back to her screen. There's a maintenance terminal on floor two nobody's watching.", "color": Color(0.53, 0.53, 0.53) },
			], "vohl_reception"))
	# Waiting-area staff + a plant
	add_npc("res://assets/sprites/civ/civ-a08.png", Vector3(6.0, 0.9, 3.0), 3)
	add_npc("res://assets/sprites/lady.png", Vector3(-8.0, 0.9, 3.5), 2)

# ── floors 2-5: cubicles + staff; floor 2 has the hackable terminal ──────
func _build_cubicles() -> void:
	# Cubicle partitions in a grid, workers at some
	var rng := RandomNumberGenerator.new()
	rng.seed = 200 + _floor
	for gx in range(-3, 3):
		for gz in range(-1, 2):
			var p := Vector3(gx * 4.0 + 1.0, 0, gz * 4.0)
			_add_box(p + Vector3(0, 0.9, -1.4), Vector3(3.2, 1.6, 0.1),
				Color(0.5, 0.52, 0.55), 0.1, 0.6)              # partition
			_add_box(p + Vector3(0, 0.72, -0.6), Vector3(2.6, 0.1, 1.2),
				Color(0.6, 0.55, 0.45), 0.2, 0.5)              # desk
			_add_box(p + Vector3(0.6, 1.15, -0.9), Vector3(0.7, 0.5, 0.1),
				Color(0.1, 0.2, 0.3), 0.0, 0.3, true, Color(0.3, 0.7, 1.0), 0.8)  # monitor
			if rng.randf() < 0.55:
				var sheets := ["res://assets/sprites/npc-corpo.png",
					"res://assets/sprites/civ/civ-a01.png",
					"res://assets/sprites/civ/civ-a08.png",
					"res://assets/sprites/civ/civ-b05.png"]
				add_npc(sheets[rng.randi() % sheets.size()], p + Vector3(0, 0.9, 0.2), 0)
	if _floor == 3:
		# STEALTH route to clearance: a supervisor left a keycard on the desk
		# by the security nook. No hacking — just get to it unseen and pocket
		# it. A guard's patrol sweeps right past, so time it or crouch.
		var kx := room_w / 2.0 - 3.0
		var kz := 4.0
		_add_box(Vector3(kx, 0.72, kz), Vector3(2.2, 0.1, 1.2),
			Color(0.5, 0.5, 0.55), 0.3, 0.4)                    # supervisor desk
		if not GameState.has_flag("vohlKeycard"):
			var card := _add_box(Vector3(kx, 0.82, kz), Vector3(0.5, 0.04, 0.32),
				Color(0.9, 0.85, 0.2), 0.2, 0.2, true, Color(1.2, 1.0, 0.3), 1.4)  # keycard
			var kl := Label3D.new()
			kl.text = "KEYCARD"
			kl.font_size = 32
			kl.pixel_size = 0.008
			kl.modulate = Color(1.1, 1.0, 0.4)
			kl.position = Vector3(kx, 1.3, kz)
			add_child(kl)
			add_interact(Vector3(kx, 1.0, kz + 1.2), Vector3(2.2, 2.0, 1.6),
				"pocket the keycard", func():
					if GameState.has_flag("vohlKeycard"):
						return
					GameState.set_flag("vohlKeycard")
					card.queue_free()
					kl.queue_free()
					_set_status("supervisor's keycard pocketed. floor 6 clearance, no logs."))
	if _floor == 2:
		# The unwatched maintenance terminal — hack it for floor-6 clearance
		var tx := -room_w / 2.0 + 2.5
		_add_box(Vector3(tx, 1.2, 4.0), Vector3(1.2, 1.6, 0.8),
			Color(0.15, 0.2, 0.25), 0.4, 0.3, true, Color(0.3, 1.0, 0.5), 0.9)
		var lbl := Label3D.new()
		lbl.text = "MAINT."
		lbl.font_size = 40
		lbl.pixel_size = 0.009
		lbl.modulate = Color(0.4, 1.1, 0.6)
		lbl.position = Vector3(tx, 2.2, 4.0)
		add_child(lbl)
		add_interact(Vector3(tx, 1.2, 4.0 + 1.2), Vector3(2.2, 2.4, 2.0),
			"maintenance terminal", func():
				if GameState.has_flag("vohlKeycard"):
					_set_status("already spoofed. floor 6 clearance is on your deck.")
					return
				if not HackOverlay.finished.is_connected(_on_keycard_hacked):
					HackOverlay.finished.connect(_on_keycard_hacked, CONNECT_ONE_SHOT)
				HackOverlay.open(2, false))

func _on_keycard_hacked(success: bool) -> void:
	if success:
		GameState.set_flag("vohlKeycard")
		_set_status("clearance spoofed. floor 6 will let you in now.")

# ── security patrol / stealth ────────────────────────────────────────────
## Two guards per floor, patrolling lanes that sweep the sensitive corners
## (the maint terminal on 2, the keycard desk on 3). Hold SHIFT to sneak so
## their cones fill slowly. Get spotted (or run past them) and it's over.
func _build_guards() -> void:
	var routes := [
		[Vector3(-10, 0, 4.5), Vector3(10, 0, 4.5)],       # sweeps the front lane (desk/terminal side)
		[Vector3(8, 0, -4.5), Vector3(-8, 0, -4.5)],       # back lane
	]
	var starts := [Vector3(-10, 0, 4.5), Vector3(8, 0, -4.5)]
	var facings := [90.0, 270.0]
	# A wanted player walks into a floor already on edge — hotter cones.
	var alert_boost: float = 0.25 * float(GameState.wanted_level())
	for i in routes.size():
		var g = StealthGuardScript.new()
		g.position = starts[i]
		g.configure(_player, facings[i], {
			"sheet": "res://assets/sprites/npc-cop2.png",
			"tint": Color(0.8, 0.85, 1.0),
			"range": 7.5,
			"patrol": routes[i],
			"patrol_speed": 1.8,
		})
		g.fill_rate += alert_boost
		g.spotted.connect(_on_spotted)
		add_child(g)
		_guards.append(g)

func _build_alarm_hud() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 40
	add_child(cl)
	_alarm_label = Label.new()
	_alarm_label.add_theme_font_size_override("font_size", 22)
	_alarm_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	_alarm_label.anchor_left = 0.5
	_alarm_label.anchor_right = 0.5
	_alarm_label.anchor_top = 0.14
	_alarm_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alarm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.add_child(_alarm_label)

func _process(_dt: float) -> void:
	# Surface the tensest guard's suspicion as a warning line.
	if _caught or _alarm_label == null or _guards.is_empty():
		return
	var worst := 0.0
	for g in _guards:
		worst = maxf(worst, g.detection())
	if worst >= 0.85:
		_alarm_label.text = "! SPOTTED !"
	elif worst >= 0.25:
		_alarm_label.text = "· noticed · SHIFT to sneak ·"
	else:
		_alarm_label.text = ""

## Full detection on any floor → SECURITY. You're grabbed, marked, and thrown
## back to the street; you keep any clearance already earned but lose your
## position in the building and take a heat hit. Try again, quieter.
func _on_spotted() -> void:
	if _caught:
		return
	_caught = true
	_menu_open = true                       # freeze the player
	for g in _guards:
		g.active = false
	GameState.add_heat(30.0)
	if _alarm_label:
		_alarm_label.text = "!! SECURITY !!"
	DialogueOverlay.play_lines([
		{ "speaker": "SECURITY", "text": "Hold it right there. Hands where I can see them.", "color": Color(1.0, 0.4, 0.35) },
		{ "speaker": "", "text": "Two guards have you by the arms before you clear the aisle. You're walked out the front doors and told not to come back.", "color": Color(0.6, 0.6, 0.66) },
	], "vohl_caught")
	if not DialogueOverlay.finished.is_connected(_after_caught):
		DialogueOverlay.finished.connect(_after_caught, CONNECT_ONE_SHOT)

func _after_caught(_tree := "") -> void:
	GameState.vohl_floor = 1
	SceneTransition.go("street_financial", "from_vohl")

# ── floor 6: Vohl's lab office + the secret door down to the basement ────
func _build_vohl_floor() -> void:
	# Darker, weirder than the offices below — Vohl's private floor
	var cz := -5.0
	_add_box(Vector3(0, 1.2, cz), Vector3(10.0, 0.9, 1.6),
		Color(0.18, 0.22, 0.18), 0.3, 0.4, true, Color(0.3, 0.9, 0.4), 0.5)  # lab bench
	# Specimen jars glowing on the bench
	for jx in [-3.0, -1.0, 1.0, 3.0]:
		_add_box(Vector3(jx, 1.9, cz), Vector3(0.4, 0.7, 0.4),
			Color(0.2, 0.6, 0.3), 0.0, 0.2, true, Color(0.4, 1.3, 0.5), 1.2)
	var assistant := add_npc("res://assets/sprites/civ/civ-a01.png", Vector3(-6.0, 0.9, cz - 0.6), 0)
	add_interact(Vector3(-6.0, 1.2, cz + 1.4), Vector3(2.4, 2.4, 2.2),
		"talk to the lab assistant", func():
			DialogueOverlay.play_lines([
				{ "speaker": "ASSISTANT", "text": "Dr. Vohl's downstairs. The REAL lab. You're not cleared for that.", "color": Color(0.6, 1.0, 0.6) },
				{ "speaker": "ASSISTANT", "text": "...the freight elevator's behind the specimen wall. I didn't tell you that.", "color": Color(0.6, 1.0, 0.6) },
			], "vohl_assistant"))
	# The secret door — behind the specimen wall, down to the basement labs
	var dx := room_w / 2.0 - 4.0
	_add_box(Vector3(dx, 1.5, -room_d / 2.0 + 0.6), Vector3(2.2, 3.0, 0.4),
		Color(0.05, 0.08, 0.05), 0.4, 0.3, true, Color(0.3, 1.2, 0.4), 0.7)
	var sd := Label3D.new()
	sd.text = "↓ SUBLEVELS"
	sd.font_size = 44
	sd.pixel_size = 0.009
	sd.modulate = Color(0.4, 1.2, 0.5)
	sd.position = Vector3(dx, 3.1, -room_d / 2.0 + 0.7)
	add_child(sd)
	add_interact(Vector3(dx, 1.2, -room_d / 2.0 + 1.8), Vector3(2.6, 2.4, 2.2),
		"the freight elevator down", func():
			GameState.pending_dungeon = "vohl"
			GameState.dungeon_floor = 0
			SceneTransition.go("dungeon", "from_city"))
