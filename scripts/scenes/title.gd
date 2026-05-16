extends Node3D

## NULL//DRIFT title screen — Godot port of
## hacking-game/src/components/IntroSequence.vue (Three.js + UnrealBloomPass).
##
## "NULL" purple neon tubes · "_" white · "DRIFT" cyan tubes · pink outline frame,
## starfield, rain, bloom. Replaces the previous skyline mockup that didn't
## match the current Phaser/Three.js title.

const NULL_COLOR := Color(0.75, 0.37, 1.0)        # #bf5fff
const DRIFT_COLOR := Color(0.0, 1.0, 1.0)         # #00ffff
const UNDERSCORE_COLOR := Color(1.0, 1.0, 1.0)
const FRAME_COLOR := Color(1.0, 0.0, 0.4)         # #ff0066

const NULL_INTENSITY := 2.5
const DRIFT_INTENSITY := 1.4
const UNDERSCORE_INTENSITY := 1.0
const FRAME_INTENSITY := 1.2

const TUBE_R := 0.06
const LETTER_H := 1.6
const LETTER_SPACING := 1.1

const SCENE_ID := "title"

var _starting := false
var _flicker_meshes: Array[MeshInstance3D] = []
var _flicker_offsets: Array[float] = []
var _flicker_bases: Array[float] = []
var _time := 0.0

var _menu_items: Array = []
var _menu_buttons: Array[Button] = []
var _selected_index := 0

func _ready() -> void:
	GameState.last_scene_id = SCENE_ID
	Interaction.clear_zones()
	var def: Dictionary = Scenes.get_scene(SCENE_ID)
	SceneBuilder.apply_environment(self, def["environment"])
	SceneBuilder.apply_camera(self, def["camera"])
	_menu_items = Menus.title_items(SaveManager.has_save())
	_build_neon_logo()
	_build_atmosphere()
	_build_overlay()
	Music.play_category(def["music_category"])

# ═══════════════════════════════════════════════════════════════════════
# NEON LOGO — "NULL_DRIFT" as capsule-tube letters
# ═══════════════════════════════════════════════════════════════════════

func _build_neon_logo() -> void:
	var total_width := 11.0 * LETTER_SPACING
	var start_x := -total_width / 2.0

	var null_mat := _make_emissive(NULL_COLOR, NULL_INTENSITY)
	var drift_mat := _make_emissive(DRIFT_COLOR, DRIFT_INTENSITY)
	var under_mat := _make_emissive(UNDERSCORE_COLOR, UNDERSCORE_INTENSITY)
	var frame_mat := _make_emissive(FRAME_COLOR, FRAME_INTENSITY)

	# NULL
	_letter_n(start_x + LETTER_SPACING * 0, 0, null_mat)
	_letter_u(start_x + LETTER_SPACING * 1, 0, null_mat)
	_letter_l(start_x + LETTER_SPACING * 2, 0, null_mat)
	_letter_l(start_x + LETTER_SPACING * 3, 0, null_mat)
	# _
	_underscore(start_x + LETTER_SPACING * 4.3, 0, under_mat)
	# DRIFT
	_letter_d(start_x + LETTER_SPACING * 5.5, 0, drift_mat)
	_letter_r(start_x + LETTER_SPACING * 6.6, 0, drift_mat)
	_letter_i(start_x + LETTER_SPACING * 7.7, 0, drift_mat)
	_letter_f(start_x + LETTER_SPACING * 8.5, 0, drift_mat)
	_letter_t(start_x + LETTER_SPACING * 9.5, 0, drift_mat)
	# Frame
	_frame(start_x - 0.8, total_width + 1.2, 2.4, frame_mat)

func _make_emissive(color: Color, intensity: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.1
	m.roughness = 0.2
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = intensity
	return m

func _tube(x: float, y: float, w: float, h: float, mat: StandardMaterial3D) -> MeshInstance3D:
	# Capsule oriented along longest axis. Matches Three.js createTube which uses
	# max(w,h) - 2*r as the cylinder length → total capsule height = max(w,h).
	var capsule := CapsuleMesh.new()
	capsule.radius = TUBE_R
	capsule.height = max(w, h)
	capsule.radial_segments = 8
	capsule.rings = 4
	capsule.material = mat.duplicate()
	var mi := MeshInstance3D.new()
	mi.mesh = capsule
	if w > h:
		mi.rotation = Vector3(0, 0, PI / 2.0)
	mi.position = Vector3(x + w / 2.0, y + h / 2.0, 0)
	add_child(mi)
	_flicker_meshes.append(mi)
	_flicker_offsets.append(randf() * TAU)
	_flicker_bases.append((mi.mesh.material as StandardMaterial3D).emission_energy_multiplier)
	return mi

func _diagonal(x: float, y: float, length: float, angle: float,
		mat: StandardMaterial3D) -> MeshInstance3D:
	var capsule := CapsuleMesh.new()
	capsule.radius = TUBE_R
	capsule.height = length + TUBE_R * 2.0
	capsule.radial_segments = 8
	capsule.rings = 4
	capsule.material = mat.duplicate()
	var mi := MeshInstance3D.new()
	mi.mesh = capsule
	mi.rotation = Vector3(0, 0, angle)
	mi.position = Vector3(x, y, 0)
	add_child(mi)
	_flicker_meshes.append(mi)
	_flicker_offsets.append(randf() * TAU)
	_flicker_bases.append((mi.mesh.material as StandardMaterial3D).emission_energy_multiplier)
	return mi

func _letter_n(x: float, y: float, mat: StandardMaterial3D) -> void:
	_tube(x, y - LETTER_H / 2.0, TUBE_R * 2.0, LETTER_H, mat)
	_tube(x + 0.6, y - LETTER_H / 2.0, TUBE_R * 2.0, LETTER_H, mat)
	_diagonal(x + 0.3, y, 1.5, -0.45, mat)

func _letter_u(x: float, y: float, mat: StandardMaterial3D) -> void:
	_tube(x, y - LETTER_H / 2.0 + 0.3, TUBE_R * 2.0, LETTER_H - 0.6, mat)
	_tube(x + 0.6, y - LETTER_H / 2.0 + 0.3, TUBE_R * 2.0, LETTER_H - 0.6, mat)
	_tube(x, y - LETTER_H / 2.0, 0.6 + TUBE_R * 2.0, TUBE_R * 2.0, mat)

func _letter_l(x: float, y: float, mat: StandardMaterial3D) -> void:
	_tube(x, y - LETTER_H / 2.0, TUBE_R * 2.0, LETTER_H, mat)
	_tube(x, y - LETTER_H / 2.0, 0.5, TUBE_R * 2.0, mat)

func _underscore(x: float, y: float, mat: StandardMaterial3D) -> void:
	_tube(x, y - 0.8, 0.6, TUBE_R * 2.0, mat)

func _letter_d(x: float, y: float, mat: StandardMaterial3D) -> void:
	_tube(x, y - LETTER_H / 2.0, TUBE_R * 2.0, LETTER_H, mat)
	_tube(x, y + LETTER_H / 2.0 - TUBE_R, 0.4, TUBE_R * 2.0, mat)
	_tube(x, y - LETTER_H / 2.0, 0.4, TUBE_R * 2.0, mat)
	_tube(x + 0.5, y - LETTER_H / 2.0 + 0.3, TUBE_R * 2.0, LETTER_H - 0.6, mat)

func _letter_r(x: float, y: float, mat: StandardMaterial3D) -> void:
	_tube(x, y - LETTER_H / 2.0, TUBE_R * 2.0, LETTER_H, mat)
	_tube(x, y + LETTER_H / 2.0 - TUBE_R, 0.4, TUBE_R * 2.0, mat)
	_tube(x, y, 0.4, TUBE_R * 2.0, mat)
	_tube(x + 0.5, y + 0.4, TUBE_R * 2.0, LETTER_H / 2.0 - 0.2, mat)
	_diagonal(x + 0.35, y - 0.4, 0.8, 0.5, mat)

func _letter_i(x: float, y: float, mat: StandardMaterial3D) -> void:
	_tube(x, y - LETTER_H / 2.0, TUBE_R * 2.0, LETTER_H, mat)
	_tube(x - 0.15, y + LETTER_H / 2.0 - TUBE_R, 0.3, TUBE_R * 2.0, mat)
	_tube(x - 0.15, y - LETTER_H / 2.0, 0.3, TUBE_R * 2.0, mat)

func _letter_f(x: float, y: float, mat: StandardMaterial3D) -> void:
	_tube(x, y - LETTER_H / 2.0, TUBE_R * 2.0, LETTER_H, mat)
	_tube(x, y + LETTER_H / 2.0 - TUBE_R, 0.5, TUBE_R * 2.0, mat)
	_tube(x, y + 0.1, 0.4, TUBE_R * 2.0, mat)

func _letter_t(x: float, y: float, mat: StandardMaterial3D) -> void:
	_tube(x + 0.25, y - LETTER_H / 2.0, TUBE_R * 2.0, LETTER_H, mat)
	_tube(x, y + LETTER_H / 2.0 - TUBE_R, 0.6, TUBE_R * 2.0, mat)

func _frame(x: float, width: float, height: float, mat: StandardMaterial3D) -> void:
	var r := TUBE_R
	var half_h := height / 2.0
	var half_w := width / 2.0
	var cx := x + width / 2.0
	# Top, bottom, left, right
	_tube(cx - half_w, half_h, width, r * 2.0, mat)
	_tube(cx - half_w, -half_h, width, r * 2.0, mat)
	_tube(cx - half_w, -half_h, r * 2.0, height, mat)
	_tube(cx + half_w - r * 2.0, -half_h, r * 2.0, height, mat)

# ═══════════════════════════════════════════════════════════════════════
# ATMOSPHERE — starfield + rain (Three.js Points → Godot small meshes)
# ═══════════════════════════════════════════════════════════════════════

func _build_atmosphere() -> void:
	var rng := RandomNumberGenerator.new()
	rng.set_seed(13)

	# Starfield — 100 white dots behind the logo
	var star_mat := StandardMaterial3D.new()
	star_mat.albedo_color = Color(1, 1, 1, 0.4)
	star_mat.emission_enabled = true
	star_mat.emission = Color(1, 1, 1)
	star_mat.emission_energy_multiplier = 1.5
	star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(120):
		var s := MeshInstance3D.new()
		var m := SphereMesh.new()
		m.radius = rng.randf_range(0.02, 0.06)
		m.height = m.radius * 2
		m.radial_segments = 6
		m.rings = 4
		m.material = star_mat
		s.mesh = m
		s.position = Vector3(
			rng.randf_range(-20, 20),
			rng.randf_range(-12, 12),
			rng.randf_range(-18, -6))
		add_child(s)

	# Rain — GPUParticles3D streaking past, blue-grey
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(18, 0.5, 8)
	pm.direction = Vector3(-0.15, -1, 0)
	pm.spread = 2.0
	pm.gravity = Vector3(0, -8, 0)
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 7.0
	pm.scale_min = 0.02
	pm.scale_max = 0.04
	p.process_material = pm
	p.amount = 800
	p.lifetime = 2.5
	p.position = Vector3(0, 9, -2)

	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.22, 0.012)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.27, 0.53, 0.67, 0.6)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.emission_enabled = true
	dm.emission = Color(0.27, 0.53, 0.67)
	dm.emission_energy_multiplier = 0.8
	drop.material = dm
	p.draw_pass_1 = drop
	add_child(p)

# ═══════════════════════════════════════════════════════════════════════
# UI OVERLAY — menu only, no title text (the 3D logo is the title)
# ═══════════════════════════════════════════════════════════════════════

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Menu box — centered, below the logo (which sits at viewport center)
	var menu_box := VBoxContainer.new()
	menu_box.set_anchors_preset(Control.PRESET_CENTER)
	menu_box.position = Vector2(-150, 80)
	menu_box.size = Vector2(300, 220)
	menu_box.add_theme_constant_override("separation", 10)
	menu_box.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(menu_box)

	_menu_buttons.clear()
	for i in range(_menu_items.size()):
		var item: Dictionary = _menu_items[i]
		var btn := _add_menu_button(menu_box, item["label"], i)
		_menu_buttons.append(btn)
	_refresh_selection()

func _add_menu_button(parent: Container, label_text: String, idx: int) -> Button:
	var btn := Button.new()
	btn.text = "  " + label_text
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", Color(0, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 0.18, 0.58))
	btn.add_theme_color_override("font_pressed_color", Color(1, 0.18, 0.58))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	btn.add_theme_constant_override("outline_size", 6)

	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0, 0, 0, 0)
	flat.set_border_width_all(0)
	btn.add_theme_stylebox_override("normal", flat)
	btn.add_theme_stylebox_override("hover", flat)
	btn.add_theme_stylebox_override("pressed", flat)
	btn.add_theme_stylebox_override("focus", flat)
	btn.custom_minimum_size = Vector2(0, 38)
	btn.flat = true

	btn.pressed.connect(func(): _select_menu_item(idx))
	btn.mouse_entered.connect(func(): _hover_item(idx))
	parent.add_child(btn)
	return btn

func _refresh_selection() -> void:
	for i in range(_menu_buttons.size()):
		var b := _menu_buttons[i]
		if i == _selected_index:
			b.text = "▶ " + _menu_items[i]["label"]
			b.add_theme_color_override("font_color", Color(1, 0.18, 0.58))
		else:
			b.text = "  " + _menu_items[i]["label"]
			b.add_theme_color_override("font_color", Color(0, 1, 1))

func _hover_item(idx: int) -> void:
	_selected_index = idx
	_refresh_selection()

func _select_menu_item(idx: int) -> void:
	_selected_index = idx
	_refresh_selection()
	_activate_selected()

# ═══════════════════════════════════════════════════════════════════════
# ANIMATION + INPUT
# ═══════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	_time += delta
	# Per-tube flicker — gentle subtle pulse, occasional dip
	for i in range(_flicker_meshes.size()):
		var mi := _flicker_meshes[i]
		if mi == null or mi.mesh == null:
			continue
		var mat := mi.mesh.material as StandardMaterial3D
		if mat == null:
			continue
		var base: float = _flicker_bases[i]
		var off: float = _flicker_offsets[i]
		var pulse := 1.0 + 0.06 * sin(_time * 2.5 + off)
		# Occasional dip — fmod-based
		var phase := fmod(_time * 0.7 + off, 7.0)
		if phase < 0.04:
			pulse = 0.4
		mat.emission_energy_multiplier = base * pulse

func _input(event: InputEvent) -> void:
	if _starting:
		return
	if event.is_action_pressed("ui_accept"):
		_activate_selected()
	elif event.is_action_pressed("ui_cancel"):
		_selected_index = clamp(_menu_index_of("options"), 0, _menu_items.size() - 1)
		_refresh_selection()
	elif event.is_action_pressed("move_up"):
		_selected_index = (_selected_index - 1 + _menu_items.size()) % _menu_items.size()
		_refresh_selection()
	elif event.is_action_pressed("move_down"):
		_selected_index = (_selected_index + 1) % _menu_items.size()
		_refresh_selection()

func _menu_index_of(id: String) -> int:
	for i in range(_menu_items.size()):
		if _menu_items[i]["id"] == id:
			return i
	return -1

func _activate_selected() -> void:
	if _starting:
		return
	if _selected_index < 0 or _selected_index >= _menu_items.size():
		return
	var id: String = _menu_items[_selected_index]["id"]
	match id:
		"continue":
			SaveManager.load_save()
			_start_game()
		"newgame":
			_start_game()
		"soundtrack":
			_starting = true
			get_tree().change_scene_to_file("res://scenes/soundtrack.tscn")
		"controls", "options":
			# Sub-views land in task #6 polish
			pass

func _start_game() -> void:
	_starting = true
	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scenes/apartment.tscn")
