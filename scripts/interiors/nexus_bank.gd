## NEXUS BANK — a corporate fortress, and the showcase for the in-house
## security model. Marble and gold up front; the money's in the vault on
## FLOOR 3, guarded by BLACKWING ninjas and ceiling auto-turrets. Nexus runs
## everything itself and NEVER calls the cops (posture "nexusbank",
## calls_police = false) — go loud and it's their ninjas and a KATANA UNIT
## that answer, not the NCPD.
##
## Three ways in, like everywhere: sneak past the cones to the vault and crack
## it quietly, or draw (F) and fight up through their security. Floor 1 lobby
## + guards, floor 2 offices, floor 3 the vault.
extends "res://scripts/interiors/secure_interior.gd"

const ListMenuScript := preload("res://scripts/systems/list_menu.gd")

var _floor := 1
var _menu

func _ready() -> void:
	_floor = clampi(GameState.bank_floor, 1, 3)
	room_w = 32.0
	room_d = 20.0
	interior_name = "NEXUS BANK · FL %d" % _floor
	exit_scene = "street_financial"
	exit_spawn = "from_bank"
	_posture_id = "nexusbank"
	super._ready()
	Music.play_category("shops")

# ── secure-interior hooks ──────────────────────────────────────────────────
func _sec_floor() -> int:
	return _floor

func _sec_exit() -> Array:
	return ["street_financial", "from_bank"]

func _reset_floor() -> void:
	GameState.bank_floor = 1

func _entrances() -> Array:
	var ex := room_w / 2.0 - 3.0
	return [Vector3(ex, 0.9, -room_d / 2.0 + 1.2),
		Vector3(room_w / 2.0 - 1.2, 0.9, room_d * 0.2)]

func _caught_lines() -> Array:
	return [
		{ "speaker": "NEXUS SECURITY", "text": "Private property. We don't call the police — we handle this ourselves.", "color": Color(1.0, 0.8, 0.35) },
		{ "speaker": "", "text": "You're marched out the front doors, cameras logging your face the whole way. Come back better prepared.", "color": Color(0.6, 0.6, 0.66) },
	]

# ── cold-money palette: pale marble + gold ─────────────────────────────────
func _ambient() -> Color:
	return Color(0.5, 0.5, 0.55)

func _wall_color() -> Color:
	return Color(0.66, 0.64, 0.58)

func _floor_color() -> Color:
	return Color(0.5, 0.49, 0.46)

func _accent_color() -> Color:
	return Color(1.2, 0.9, 0.3)      # gold trim

func _build_interior() -> void:
	_build_ceiling_lights()
	_build_elevator()
	match _floor:
		1: _build_lobby()
		3: _build_vault_floor()
		_: _build_offices()
	_build_garrison()
	_init_security()

func _build_ceiling_lights() -> void:
	for spot in [Vector3(-9, 4.4, -2), Vector3(0, 4.4, 2), Vector3(9, 4.4, -1)]:
		_add_box(spot, Vector3(2.6, 0.15, 0.6),
			Color(1.0, 0.97, 0.9), 0.0, 0.3, true, Color(1.0, 0.97, 0.85), 1.5)
		var l := OmniLight3D.new()
		l.position = spot - Vector3(0, 0.4, 0)
		l.light_color = Color(1.0, 0.96, 0.85)
		l.light_energy = 2.2
		l.omni_range = 14.0
		add_child(l)

# ── the per-floor garrison, from the posture ───────────────────────────────
func _build_garrison() -> void:
	match _floor:
		1:
			# Lobby: corp guards sweeping the teller line
			add_guard(Vector3(-9, 0, 4.0), 90.0,
				[Vector3(-9, 0, 4.0), Vector3(9, 0, 4.0)], "corp_guard")
			add_guard(Vector3(9, 0, -3.0), 270.0,
				[Vector3(9, 0, -3.0), Vector3(-9, 0, -3.0)], "corp_guard")
		2:
			add_guard(Vector3(0, 0, 3.5), 0.0,
				[Vector3(-8, 0, 3.5), Vector3(8, 0, 3.5)], "guard")
		3:
			# Vault floor: ninjas patrol, turrets cover the corners
			add_guard(Vector3(-8, 0, 3.0), 45.0,
				[Vector3(-8, 0, 3.0), Vector3(-8, 0, -3.0)], "ninja")
			add_guard(Vector3(8, 0, -3.0), 200.0,
				[Vector3(8, 0, -3.0), Vector3(8, 0, 3.0)], "ninja")
			add_turret(Vector3(-room_w / 2.0 + 1.0, 0, -room_d / 2.0 + 1.0), 135.0)
			add_turret(Vector3(room_w / 2.0 - 1.0, 0, -room_d / 2.0 + 1.0), 225.0)

# ── elevator ───────────────────────────────────────────────────────────────
func _build_elevator() -> void:
	var ex := room_w / 2.0 - 3.0
	var ez := -room_d / 2.0 + 1.2
	_add_box(Vector3(ex, 1.6, ez), Vector3(2.4, 3.2, 0.4),
		Color(0.35, 0.32, 0.22), 0.7, 0.3, true, Color(1.2, 0.9, 0.3), 0.4)
	var panel := Label3D.new()
	panel.text = "▲▼"
	panel.font_size = 40
	panel.pixel_size = 0.01
	panel.modulate = Color(1.2, 0.95, 0.4)
	panel.position = Vector3(ex + 1.4, 1.6, ez + 0.3)
	add_child(panel)
	add_interact(Vector3(ex, 1.2, ez + 1.6), Vector3(2.8, 2.4, 2.2),
		"the elevator", _open_elevator)

func _open_elevator() -> void:
	_menu_open = true
	_menu = ListMenuScript.new()
	add_child(_menu)
	var entries: Array = []
	var names := ["", "LOBBY", "OFFICES", "VAULT"]
	for f in range(1, 4):
		var tag := " · you are here" if f == _floor else ""
		entries.append({ "label": "FLOOR %d · %s%s" % [f, names[f], tag], "dim": f == _floor })
	_menu.picked.connect(_on_floor_pick)
	_menu.closed.connect(func():
		_menu_open = false
		_menu = null)
	_menu.open("ELEVATOR · select floor", entries, Color(1.2, 0.9, 0.35),
		"NEXUS BANK · authorized personnel only")

func _on_floor_pick(idx: int) -> void:
	var f := idx + 1
	if f == _floor:
		return
	GameState.bank_floor = f
	SceneTransition.go("nexus_bank", "elevator")

# ── floor 1: lobby ─────────────────────────────────────────────────────────
func _build_lobby() -> void:
	var cz := -6.0
	# Long teller counter with gold top
	_add_box(Vector3(0, 0.6, cz), Vector3(16.0, 1.2, 1.2), Color(0.6, 0.58, 0.52), 0.3, 0.4)
	_add_box(Vector3(0, 1.24, cz), Vector3(16.4, 0.08, 1.5), Color(1.1, 0.85, 0.35), 0.7, 0.2,
		true, Color(1.2, 0.9, 0.4), 0.4)
	# Teller windows (glass dividers)
	for wx in [-6.0, -2.0, 2.0, 6.0]:
		_add_box(Vector3(wx, 2.0, cz), Vector3(0.1, 1.4, 1.2),
			Color(0.5, 0.7, 0.8, 1.0), 0.2, 0.1, true, Color(0.4, 0.7, 0.9), 0.3)
	# Backlit NEXUS BANK logo
	_add_box(Vector3(0, 3.0, cz - 0.9), Vector3(10.0, 2.0, 0.2),
		Color(0.2, 0.16, 0.05), 0.0, 0.3, true, Color(1.2, 0.9, 0.3), 0.7)
	var logo := Label3D.new()
	logo.text = "NEXUS"
	logo.font_size = 130
	logo.pixel_size = 0.012
	logo.modulate = Color(1.3, 1.0, 0.4)
	logo.position = Vector3(0, 3.1, cz - 0.78)
	add_child(logo)
	# Tellers behind the counter + customers in the lobby (they'll flee)
	register_worker(add_npc("res://assets/sprites/cyberGirl.png", Vector3(-6.0, 0.9, cz - 1.1), 0))
	register_worker(add_npc("res://assets/sprites/lady.png", Vector3(2.0, 0.9, cz - 1.1), 0))
	register_worker(add_npc("res://assets/sprites/civ/civ-a08.png", Vector3(-4.0, 0.9, 5.0), 3))
	register_worker(add_npc("res://assets/sprites/npc-corpo.png", Vector3(6.0, 0.9, 4.0), 2))
	add_interact(Vector3(0, 1.2, cz + 1.6), Vector3(8.0, 2.4, 2.4),
		"talk to a teller", func():
			DialogueOverlay.play_lines([
				{ "speaker": "TELLER", "text": "Welcome to Nexus Bank. Accounts and safe-deposit are on this floor. The vault is not.", "color": Color(1.1, 0.9, 0.5) },
				{ "speaker": "", "text": "Her eyes flick to the ceiling camera. Everything here is watched, and Nexus doesn't wait for the police — they have their own.", "color": Color(0.53, 0.53, 0.53) },
			], "bank_teller"))

func _build_offices() -> void:
	# A quiet floor of loan desks — the buffer between lobby and vault
	var rng := RandomNumberGenerator.new()
	rng.seed = 720
	for gx in range(-2, 3):
		var p := Vector3(gx * 5.0, 0, 0)
		_add_box(p + Vector3(0, 0.72, -0.6), Vector3(3.0, 0.1, 1.4), Color(0.55, 0.5, 0.42), 0.2, 0.5)
		_add_box(p + Vector3(0.7, 1.15, -0.9), Vector3(0.7, 0.5, 0.1),
			Color(0.2, 0.18, 0.1), 0.0, 0.3, true, Color(1.0, 0.85, 0.4), 0.6)
		if rng.randf() < 0.5:
			register_worker(add_npc("res://assets/sprites/npc-corpo.png", p + Vector3(0, 0.9, 0.4), 0))

# ── floor 3: the vault ─────────────────────────────────────────────────────
func _build_vault_floor() -> void:
	var cz := -room_d / 2.0 + 1.2
	# The great vault door — a slab of steel with a gold locking wheel
	_add_box(Vector3(0, 2.2, cz), Vector3(6.0, 4.4, 0.8), Color(0.28, 0.29, 0.33), 0.9, 0.25)
	_add_box(Vector3(0, 2.2, cz + 0.45), Vector3(4.6, 3.4, 0.3), Color(0.35, 0.36, 0.4), 0.95, 0.2)
	_add_box(Vector3(0, 2.2, cz + 0.62), Vector3(1.2, 1.2, 0.2), Color(1.1, 0.85, 0.3), 0.9, 0.15,
		true, Color(1.2, 0.9, 0.35), 0.5)   # locking wheel
	var lbl := Label3D.new()
	lbl.text = "VAULT"
	lbl.font_size = 60
	lbl.pixel_size = 0.011
	lbl.modulate = Color(1.3, 1.0, 0.4)
	lbl.position = Vector3(0, 4.6, cz + 0.3)
	add_child(lbl)
	add_interact(Vector3(0, 1.4, cz + 2.0), Vector3(4.0, 2.4, 2.2),
		"crack the vault", _crack_vault)

func _crack_vault() -> void:
	if GameState.has_flag("bankVaultCracked"):
		_set_status("the vault's already been emptied. don't push your luck.")
		return
	if not HackOverlay.finished.is_connected(_on_vault_hacked):
		HackOverlay.finished.connect(_on_vault_hacked, CONNECT_ONE_SHOT)
	HackOverlay.open(3, false)

func _on_vault_hacked(success: bool) -> void:
	if not success:
		_set_status("the lock reset. and now they know someone tried.")
		GameState.add_heat(15.0)
		return
	GameState.set_flag("bankVaultCracked")
	GameState.add_credits(50000)
	GameState.add_heat(25.0)
	_set_status("VAULT OPEN — 50,000 credits lighter. get out before their people converge.")
