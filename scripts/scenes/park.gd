## CENTRAL PARK — Signal Hollow's one patch of green. Unlike the streets
## (locked east-west), the park is a full 4-directional iso space you roam
## N/S/E/W, with the street running along the south edge (the way in/out).
## Trees, a lit fountain, benches, lamp paths.
##
## Scripted beat: near the fountain a thug is mugging a corpo couple. Walk
## up and RAZZIEL FEN — a two-sword wanderer with a black panther, Galaia —
## steps in and saves them. Afterward he lingers here, talkable. (Your
## canon GameScene rescue, ported.)
extends Node3D

const AnimatedBillboardScript := preload("res://scripts/systems/animated_billboard.gd")

const CAMERA_OFFSET := Vector3(24, 27, 24)
const CAMERA_LERP := 7.0
const WALK_SPEED := 7.0
const HALF := 34.0                 # park half-extent (x/z walkable)
const STREET_Z := 30.0             # the street runs along the south edge

var _camera: Camera3D
var _cam_rot: Vector3
var _player: CharacterBody3D
var _player_anim
var _status: Label
var _near_exit := false
var _near_razziel := false
var _cutscene := false
var _razziel_done := false
var _thug: Node3D
var _razziel: Node3D
var _exit_arrow: Node3D
var _razziel_arrow: Node3D

func _ready() -> void:
	_razziel_done = GameState.has_flag("razzielMet")
	_setup_camera()
	_setup_environment()
	_build_ground()
	_build_fountain()
	_build_trees_and_benches()
	_build_skyline()
	_build_exit()
	_build_rescue()
	_build_player()
	_build_hud()
	_apply_spawn()
	Music.play_category("ambient")

func _setup_camera() -> void:
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 30.0
	_camera.near = 0.05
	_camera.far = 400.0
	_camera.position = CAMERA_OFFSET
	_camera.current = true
	add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_cam_rot = _camera.rotation

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.02, 0.02, 0.06)
	sm.sky_horizon_color = Color(0.10, 0.08, 0.20)
	sm.ground_horizon_color = Color(0.04, 0.05, 0.06)
	sm.ground_bottom_color = Color(0.01, 0.02, 0.02)
	sky.sky_material = sm
	env.sky = sky
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.18, 0.22, 0.30)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_density = 0.002
	env.fog_light_color = Color(0.10, 0.12, 0.22)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.6
	moon.rotation_degrees = Vector3(-55, -30, 0)
	add_child(moon)

func _build_ground() -> void:
	# Grass field
	_box(Vector3(0, -0.05, -4), Vector3(HALF * 2 + 10, 0.1, HALF * 2 - 4),
		Color(0.08, 0.16, 0.10), 0.0, 0.9)
	# South street + sidewalk (the way in/out)
	_box(Vector3(0, -0.02, STREET_Z + 4), Vector3(HALF * 2 + 40, 0.12, 10.0),
		Color(0.05, 0.05, 0.07), 0.0, 0.85)
	_box(Vector3(0, -0.01, STREET_Z - 2.5), Vector3(HALF * 2 + 40, 0.14, 4.0),
		Color(0.13, 0.13, 0.15), 0.0, 0.9)
	# Center-line dashes
	var dx := -HALF - 16.0
	while dx < HALF + 16.0:
		_box(Vector3(dx, 0.04, STREET_Z + 4), Vector3(3.0, 0.03, 0.4),
			Color(0.7, 0.6, 0.1), 0.0, 0.4, true, Color(1.0, 0.85, 0.2), 1.6)
		dx += 8.0
	# Winding path from the street to the fountain (paved slabs)
	for i in 9:
		var pz := STREET_Z - 4.0 - i * 3.6
		var px := sin(i * 0.7) * 4.0
		_box(Vector3(px, 0.01, pz), Vector3(3.2, 0.05, 3.2),
			Color(0.18, 0.17, 0.16), 0.0, 0.8)
	# Hedge borders (soft walls) N/E/W with collision
	for edge in [[Vector3(0, 1.0, -HALF), Vector3(HALF * 2, 2.0, 1.4)],
			[Vector3(-HALF, 1.0, 12), Vector3(1.4, 2.0, HALF * 2)],
			[Vector3(HALF, 1.0, 12), Vector3(1.4, 2.0, HALF * 2)]]:
		_box(edge[0], edge[1], Color(0.06, 0.14, 0.08), 0.0, 0.9)

func _build_fountain() -> void:
	# Stone basin + glowing water, the park's centerpiece
	_box(Vector3(0, 0.3, 0), Vector3(7.0, 0.6, 7.0), Color(0.22, 0.22, 0.25), 0.2, 0.7)
	_box(Vector3(0, 0.55, 0), Vector3(6.0, 0.3, 6.0),
		Color(0.1, 0.35, 0.55), 0.1, 0.2, true, Color(0.3, 0.9, 1.2), 1.4)
	_box(Vector3(0, 1.3, 0), Vector3(0.8, 1.8, 0.8), Color(0.25, 0.25, 0.28), 0.3, 0.6)
	_box(Vector3(0, 2.3, 0), Vector3(1.6, 0.4, 1.6),
		Color(0.2, 0.5, 0.7), 0.0, 0.2, true, Color(0.35, 1.0, 1.3), 1.6)
	var fl := OmniLight3D.new()
	fl.position = Vector3(0, 1.5, 0)
	fl.light_color = Color(0.35, 0.8, 1.1)
	fl.light_energy = 2.0
	fl.omni_range = 12.0
	add_child(fl)

func _build_trees_and_benches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x9AA
	for i in 16:
		var tx := rng.randf_range(-HALF + 4, HALF - 4)
		var tz := rng.randf_range(-HALF + 4, STREET_Z - 8)
		if Vector2(tx, tz).length() < 8.0:
			continue   # keep the fountain plaza clear
		_box(Vector3(tx, 1.4, tz), Vector3(0.6, 2.8, 0.6), Color(0.12, 0.08, 0.05), 0.0, 0.9)
		_box(Vector3(tx, 3.4, tz), Vector3(3.2, 2.6, 3.2),
			Color(0.06, 0.20, 0.10) * rng.randf_range(0.8, 1.2), 0.0, 0.85)
	# Lamp posts along the path
	for lz in [STREET_Z - 6.0, STREET_Z - 16.0, STREET_Z - 26.0]:
		for lx in [-8.0, 8.0]:
			_box(Vector3(lx, 2.4, lz), Vector3(0.16, 4.8, 0.16), Color(0.15, 0.15, 0.18), 0.7, 0.4)
			_box(Vector3(lx, 4.9, lz), Vector3(0.4, 0.3, 0.4),
				Color(1.0, 0.9, 0.6), 0.0, 0.3, true, Color(1.0, 0.85, 0.5), 2.2)
			var l := OmniLight3D.new()
			l.position = Vector3(lx, 4.6, lz)
			l.light_color = Color(1.0, 0.85, 0.6)
			l.light_energy = 1.8
			l.omni_range = 9.0
			add_child(l)
	# Benches facing the fountain
	for spot in [Vector3(-9, 0, 3), Vector3(9, 0, 3), Vector3(3, 0, -9)]:
		_box(spot + Vector3(0, 0.5, 0), Vector3(2.6, 0.15, 0.8), Color(0.2, 0.15, 0.10), 0.1, 0.7)
		_box(spot + Vector3(0, 0.9, -0.3), Vector3(2.6, 0.7, 0.15), Color(0.2, 0.15, 0.10), 0.1, 0.7)

func _build_skyline() -> void:
	# Distant city towers ringing the park, north side
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5C1
	var mm := MultiMeshInstance3D.new()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = BoxMesh.new()
	var items: Array = []
	var x := -120.0
	while x < 120.0:
		var w: float = rng.randf_range(8, 18)
		var h: float = rng.randf_range(20, 60)
		items.append({ "x": Transform3D(Basis.from_scale(Vector3(w, h, 10)),
			Vector3(x, h * 0.5, -HALF - 40)), "c": Color(0.05, 0.05, 0.10) })
		x += w + rng.randf_range(3, 10)
	multi.instance_count = items.size()
	for i in items.size():
		multi.set_instance_transform(i, items[i].x)
		multi.set_instance_color(i, items[i].c)
	mm.multimesh = multi
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mm.material_override = mat
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm)

func _build_exit() -> void:
	# Leave via the south street (back to the home street)
	_exit_arrow = _make_arrow(Vector3(0, 2.6, STREET_Z - 1.0), Color(0.2, 1.3, 1.5))
	var lbl := Label3D.new()
	lbl.text = "◄ STREET"
	lbl.font_size = 64
	lbl.pixel_size = 0.012
	lbl.modulate = Color(0.3, 1.2, 1.4)
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0)
	lbl.position = Vector3(0, 3.4, STREET_Z - 1.0)
	add_child(lbl)

func _build_rescue() -> void:
	if _razziel_done:
		# Aftermath: Razziel + Galaia still linger by the fountain
		_razziel = _npc("res://assets/sprites/ninja-classic.png", Vector3(-4, 0.9, -4), 2)
		_panther(Vector3(-5.4, 0.6, -3.4))
		return
	# The mugging in progress, east of the fountain
	var spot := Vector3(11, 0, -3)
	_thug = _npc("res://assets/sprites/npc-thug.png", spot, 1, Color(1.1, 0.9, 0.9))
	_couple_corpo = _npc("res://assets/sprites/npc-corpo.png", spot + Vector3(2.4, 0, 0.3), 1)
	_couple_lady = _npc("res://assets/sprites/lady.png", spot + Vector3(3.4, 0, 0.3), 1)
	var trig := Area3D.new()
	trig.position = spot + Vector3(1.0, 1.0, 2.0)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(9.0, 2.4, 8.0)
	c.shape = s
	trig.add_child(c)
	trig.body_entered.connect(_on_rescue_trigger)
	add_child(trig)

var _couple_corpo: Node3D
var _couple_lady: Node3D

func _on_rescue_trigger(body: Node) -> void:
	if _cutscene or _razziel_done or not (body is CharacterBody3D):
		return
	_cutscene = true
	# Razziel + Galaia stride in from the shadows
	_razziel = _npc("res://assets/sprites/ninja-classic.png", Vector3(18, 0.9, -3), 1)
	_panther(Vector3(19.2, 0.6, -2.2))
	DialogueOverlay.play_lines([
		{ "speaker": "THUG", "text": "Nice watch, corpo. Hand it over. The girl's necklace too.", "color": Color(1.0, 0.5, 0.4) },
		{ "speaker": "CORPO", "text": "Please, we don't want any trouble...", "color": Color(0.8, 0.85, 0.95) },
		{ "speaker": "???", "text": "I wouldn't do that if I were you.", "color": Color(0.7, 0.85, 1.0) },
		{ "speaker": "THUG", "text": "Who the hell are you? Get lost, freak!", "color": Color(1.0, 0.5, 0.4) },
		{ "speaker": "???", "text": "My name is... difficult to pronounce. But my blades speak clearly enough.", "color": Color(0.7, 0.85, 1.0) },
		{ "speaker": "", "text": "Steel flashes twice. A panther is already moving. The thug never draws.", "color": Color(0.53, 0.53, 0.53) },
		{ "speaker": "CORPO", "text": "Thank you! You saved us! What's your name?", "color": Color(0.8, 0.85, 0.95) },
		{ "speaker": "RAZZIEL FEN", "text": "Razziel Fen. And this is Galaia. We were just... enjoying the moonlight.", "color": Color(0.7, 0.85, 1.0) },
		{ "speaker": "LADY", "text": "Razziel? That's... quite a name. Like something from a fantasy novel.", "color": Color(1.0, 0.7, 0.9) },
		{ "speaker": "RAZZIEL FEN", "text": "...I get that a lot. It's an old elven name. My parents were... eccentric.", "color": Color(0.7, 0.85, 1.0) },
	], "razziel_rescue")
	DialogueOverlay.finished.connect(_on_rescue_done, CONNECT_ONE_SHOT)

func _on_rescue_done(_id: String) -> void:
	GameState.set_flag("razzielMet")
	_razziel_done = true
	# The thug and the rescued couple clear out; Razziel + Galaia stay
	if _thug: _thug.queue_free()
	if _couple_corpo: _couple_corpo.queue_free()
	if _couple_lady: _couple_lady.queue_free()
	if _razziel:
		_razziel.position = Vector3(-4, 0.9, -4)
	_razziel_arrow = _make_arrow(Vector3(-4, 2.4, -4), Color(0.7, 0.85, 1.0))

func _build_player() -> void:
	_player = CharacterBody3D.new()
	_player.position = Vector3(0, 0.85, STREET_Z - 4.0)
	add_child(_player)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	_player.add_child(col)
	_player_anim = AnimatedBillboardScript.new()
	_player_anim.pixel_size = 0.04
	_player_anim.position = Vector3(0, -0.85, 0)
	_player.add_child(_player_anim)
	_player_anim.load_sheet("res://assets/sprites/player-pizza.png")

func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	var title := Label.new()
	title.text = "CENTRAL PARK · NIGHT"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
	title.position = Vector2(20, 18)
	cl.add_child(title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", Color(0.9, 0.95, 0.8))
	_status.position = Vector2(20, 40)
	cl.add_child(_status)

func _apply_spawn() -> void:
	SceneTransition.consume_spawn()   # always enter from the south street

func _process(delta: float) -> void:
	if _camera and _player:
		_camera.global_position = _camera.global_position.lerp(
			_player.global_position + CAMERA_OFFSET, clampf(delta * CAMERA_LERP, 0, 1))
		_camera.rotation = _cam_rot
	# animate the panther bob
	if is_instance_valid(_galaia):
		_galaia_t += delta

func _physics_process(_delta: float) -> void:
	if _player == null or DialogueOverlay.is_active():
		return
	var input := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down"))
	var world_dir := Vector3(input.x + input.y, 0, -input.x + input.y) * (1.0 / sqrt(2.0))
	var speed := WALK_SPEED * (1.7 if Input.is_action_pressed("sprint") else 1.0)
	_player.velocity = world_dir * speed
	_player.move_and_slide()
	if _player_anim:
		_player_anim.update_facing_from_input(input)
		_player_anim.set_moving(input.length() > 0.1)
	# clamp to the park bounds
	_player.position.x = clampf(_player.position.x, -HALF + 1.5, HALF - 1.5)
	_player.position.z = clampf(_player.position.z, -HALF + 1.5, STREET_Z - 1.0)
	_update_prompts()

func _update_prompts() -> void:
	var p := _player.position
	_near_exit = absf(p.x) < 4.0 and p.z > STREET_Z - 4.5
	_arrow_flare(_exit_arrow, _near_exit)
	_near_razziel = false
	if _razziel_done and is_instance_valid(_razziel):
		_near_razziel = p.distance_to(_razziel.position) < 3.5
		_arrow_flare(_razziel_arrow, _near_razziel)

func _unhandled_input(event: InputEvent) -> void:
	if DialogueOverlay.is_active():
		return
	if event.is_action_pressed("interact"):
		if _near_razziel:
			DialogueOverlay.play("razziel")
		elif _near_exit:
			SceneTransition.go("city", "from_ridenet")
	elif event.is_action_pressed("ui_cancel"):
		SceneTransition.go("city", "from_ridenet")

# ── helpers ──────────────────────────────────────────────────────────────
var _galaia: Node3D
var _galaia_t := 0.0

func _npc(sheet: String, pos: Vector3, facing: int, tint := Color(1, 1, 1)) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)
	var ab = AnimatedBillboardScript.new()
	ab.show_floor_shadow = false
	ab.pixel_size = 0.04
	pivot.add_child(ab)
	ab.tint = tint
	ab.load_sheet(sheet)
	ab.facing = facing
	ab.set_moving(false)
	return pivot

func _panther(pos: Vector3) -> void:
	_galaia = _npc("res://assets/sprites/blackCat.png", pos, 2, Color(0.4, 0.4, 0.5))
	_galaia.scale = Vector3(1.9, 1.9, 1.9)

func _make_arrow(pos: Vector3, col: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.8, 0.6, 0.3)
	mi.mesh = pm
	mi.rotation = Vector3(PI, 0, 0)   # point down
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.6
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	var tw := create_tween().set_loops()
	tw.tween_property(mi, "position:y", pos.y + 0.4, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mi, "position:y", pos.y, 0.9).set_trans(Tween.TRANS_SINE)
	return mi

func _arrow_flare(arrow: Node3D, near: bool) -> void:
	if is_instance_valid(arrow):
		arrow.scale = Vector3(1.3, 1.3, 1.3) if near else Vector3.ONE

func _box(pos: Vector3, sz: Vector3, col: Color, metallic := 0.0, rough := 0.8,
		emissive := false, emission := Color.BLACK, energy := 1.0) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mesh.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = metallic
	mat.roughness = rough
	if emissive:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	mesh.material_override = mat
	body.add_child(mesh)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	cs.shape = box
	body.add_child(cs)
	add_child(body)
