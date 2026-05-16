extends Node3D

## NULL//DRIFT FM — first-person midnight-drive music player.
##
## Permanent night. No cycle. A procedural Sky resource paints a soft
## navy-to-violet vertical gradient as the backdrop, with stars sprinkled
## across it. A stylized synthwave moon sits in the upper sky and acts
## as a real DirectionalLight illuminating the cabin cool/violet. The
## road itself is lit by the camera's headlight spotlights. The dashboard
## (a DALL-E photo with alpha-keyed sky) holds gauges + radio recess at
## the bottom of the screen. Audio is its own AudioStreamPlayer.

const SCENE_ID := "soundtrack"
const MUSIC_DIR := "res://audio/music"

# Palette
const HOT_PINK    := Color(1.0, 0.10, 0.60)
const NEON_CYAN   := Color(0.10, 1.0, 0.96)
const NEON_PURPLE := Color(0.75, 0.20, 1.0)
const NEON_ORANGE := Color(1.0, 0.55, 0.10)
const ASPHALT     := Color(0.025, 0.025, 0.035)
const LANE_WHITE  := Color(0.92, 0.92, 0.96)
const DASH_DARK   := Color(0.040, 0.025, 0.075)
const DASH_TRIM   := Color(0.085, 0.045, 0.140)

# Road — 3-lane look. Car drives in the middle lane; dashes are the
# divider lines flanking the car (not running underneath it).
const ROAD_WIDTH := 11.0
const ROAD_LENGTH := 400.0
const DASH_LANE_X := 2.0          # left/right offset of the lane-divider dashes
const DASH_COUNT := 32             # per side
const DASH_SPACING := 8.0
const DASH_LEN := 2.4
const DASH_NEAR_Z := -10.0
const DASH_SPEED := 32.0

# Streetlights — sparse, like a real desert highway. Wide spacing so only
# 1-2 are visible at a time.
const STREETLIGHT_COUNT := 4
const STREETLIGHT_SPACING := 80.0
const STREETLIGHT_NEAR_Z := -10.0
const STREETLIGHT_HEIGHT := 6.5
const STREETLIGHT_ARM := 4.0
const STREETLIGHT_SPEED := 32.0

# Camera (driver's-eye, first-person). Sits at driver-seat height with a
# slight forward look at the road. The 2D dashboard overlay covers the
# bottom half of the screen, so the camera's view is the windshield.
const CAM_POS := Vector3(0.0, 1.15, 0.0)
const CAM_LOOK := Vector3(0.0, 0.65, 14.0)

# ─── state ────────────────────────────────────────────────────────────
var _camera: Camera3D
var _time := 0.0
var _exiting := false

# 3D world refs (updated each frame)
var _dashes: Array[MeshInstance3D] = []
var _streetlights: Array[Node3D] = []
var _sun: Node3D
var _moon: Node3D
var _flora: Array[Node3D] = []
var _flora_speeds: Array[float] = []
var _sky_light: DirectionalLight3D
var _sun_light: DirectionalLight3D
var _moon_light: DirectionalLight3D
var _sky_quad: MeshInstance3D       # gradient backdrop, animated by cycle
var _sky_quad_mat: ShaderMaterial
var _star_root: Node3D              # parent for all stars, faded by cycle

# Wipers — periodic sweep, simple visual (no rain clearing).
class WiperDraw extends Control:
	var time: float = 0.0
	var col_arm: Color = Color(0.06, 0.05, 0.10)
	var col_blade: Color = Color(0.02, 0.01, 0.03)
	var col_hilight: Color = Color(0.18, 0.20, 0.30)
	# Cycle: sweep up (0.0-0.8s), sweep back (0.8-1.4s), pause (1.4-2.6s)
	const CYCLE: float = 2.6

	func _process(delta: float) -> void:
		time += delta
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w <= 0 or h <= 0:
			return
		var ct: float = fmod(time, CYCLE)
		# Rest: blades parked HORIZONTAL pointing right along the bottom
		# of the windshield. Sweep: arcs UP to vertical, then back.
		# With base_up = (0,-1), rotating by +PI/2 yields (1, 0) — right.
		var rest_angle: float = PI * 0.50
		var peak_angle: float = 0.0
		var angle: float = rest_angle
		if ct < 0.8:
			var t: float = ct / 0.8
			t = 1.0 - pow(1.0 - t, 2.0)
			angle = lerp(rest_angle, peak_angle, t)
		elif ct < 1.4:
			var t: float = (ct - 0.8) / 0.6
			t = t * t
			angle = lerp(peak_angle, rest_angle, t)
		# Both wipers sweep in sync.
		_draw_wiper(Vector2(w * 0.28, h * 0.60),
			angle, h * 0.45)
		_draw_wiper(Vector2(w * 0.62, h * 0.60),
			angle, h * 0.40)

	func _draw_wiper(pivot: Vector2, angle: float, arm_len: float) -> void:
		# Sci-fi sports car wiper: ONE clean rigid blade extending from
		# the pivot. No exposed J-arm or visible armature. Small glowing
		# cyan LED indicator near the tip.
		var base_up: Vector2 = Vector2(0, -1)
		var sa: float = sin(angle)
		var ca: float = cos(angle)
		var dir: Vector2 = Vector2(
			base_up.x * ca - base_up.y * sa,
			base_up.x * sa + base_up.y * ca)
		var tip: Vector2 = pivot + dir * arm_len

		# Pivot mount: dark hub with a subtle cyan glow ring.
		draw_circle(pivot, 7.0, col_arm)
		draw_arc(pivot, 7.5, 0.0, TAU, 24,
			Color(0.30, 0.85, 1.0, 0.55), 1.5, true)

		# Blade — a single thick dark stroke from pivot to tip.
		draw_line(pivot, tip, col_blade, 9.0, true)
		# Subtle highlight along one edge so it doesn't read as a flat line.
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		draw_line(pivot + perp * 1.8, tip + perp * 1.8,
			Color(col_hilight.r, col_hilight.g, col_hilight.b, 0.6),
			1.0, true)

		# LED at the tip — small bright cyan dot with a halo.
		var led_pos: Vector2 = pivot + dir * (arm_len * 0.92)
		draw_circle(led_pos, 5.0,
			Color(0.45, 0.95, 1.0, 0.30))
		draw_circle(led_pos, 2.6,
			Color(0.70, 1.0, 1.0, 1.0))

# Rain on windshield (full-screen canvas_item shader, intensity 0..1).
var _rain_mat: ShaderMaterial
var _rain_intensity := 0.0
var _rain_target := 1.0
var _rain_next_toggle := 35.0
const RAIN_ON_SECONDS := 35.0
const RAIN_OFF_SECONDS := 15.0
var _world_rain: GPUParticles3D        # falling rain in the 3D distance

# Day/night cycle — 2 minutes total. cycle_t goes 0..1 each cycle.
# 0.00–0.45: sun visible (low, sinking)
# 0.45–0.55: twilight, both barely visible at horizon
# 0.55–1.00: moon visible (descending from top to mid sky)
const CYCLE_SECONDS := 120.0

# Audio
var _player: AudioStreamPlayer
var _tracks: Array[Dictionary] = []
var _current_idx := -1
var _is_paused := false

# UI refs
var _np_track_label: Label
var _np_scene_label: Label
var _np_progress_fill: ColorRect
var _np_progress_bar: Control
var _np_time_label: Label
var _play_btn: Button
var _eq_bars: Array[ColorRect] = []
var _eq_phases: Array[float] = []
var _tracklist_modal: Control
var _tracklist_container: VBoxContainer
var _tracklist_count: Label

# ═══════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════

func _ready() -> void:
	GameState.last_scene_id = SCENE_ID
	Interaction.clear_zones()
	Music.stop(0.4)
	if Phone and Phone.has_method("set_button_visible"):
		Phone.set_button_visible(false)

	var def: Dictionary = Scenes.get_scene(SCENE_ID)
	SceneBuilder.apply_environment(self, def["environment"])
	_camera = SceneBuilder.apply_camera(self, def["camera"])

	_apply_night_sky()
	_build_moon()
	_build_stars()
	_build_mountains()
	_build_city_skyline()
	_build_road()
	_build_streetlights()
	_build_flora()
	_build_headlights()
	_build_moon_light()

	_build_hud()
	# Rain + wipers disabled until the shader is rewritten without the
	# tell-tale grid artefacts. The rain code is preserved (call these
	# to re-enable):
	#   _build_rain_overlay()
	#   _build_world_rain()
	_setup_audio()
	_scan_tracks()
	_refresh_now_playing()

func _exit_tree() -> void:
	if _player and _player.playing:
		_player.stop()
	if Phone and Phone.has_method("set_button_visible"):
		Phone.set_button_visible(true)

# ═══════════════════════════════════════════════════════════════════════
# WORLD — moon (only celestial body; black sky otherwise)
# ═══════════════════════════════════════════════════════════════════════

func _apply_night_sky() -> void:
	# Procedural sky shader on the WorldEnvironment. The skybox renders
	# behind everything automatically — no depth/sort fights. A subtle
	# vertical gradient: violet horizon, deep navy zenith.
	var we: WorldEnvironment = null
	for child in get_children():
		if child is WorldEnvironment:
			we = child
			break
	if we == null or we.environment == null:
		return
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type sky;
uniform vec3 horizon_col : source_color = vec3(0.10, 0.05, 0.22);
uniform vec3 mid_col     : source_color = vec3(0.04, 0.02, 0.12);
uniform vec3 zenith_col  : source_color = vec3(0.004, 0.004, 0.020);
void sky() {
	// EYEDIR.y: -1 down, 0 horizon, 1 up
	float t = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(horizon_col, mid_col, smoothstep(0.0, 0.15, t));
	col = mix(col, zenith_col, smoothstep(0.15, 0.75, t));
	COLOR = col;
}
"""
	sky_mat.shader = sh
	sky.sky_material = sky_mat
	we.environment.sky = sky
	we.environment.background_mode = Environment.BG_SKY
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	we.environment.ambient_light_energy = 0.4

	# Screen-space reflections — gives the wet asphalt actual reflected
	# streetlight + headlight smears, the iconic "rainy night highway"
	# look. Modest step count so it stays cheap.
	we.environment.ssr_enabled = true
	we.environment.ssr_max_steps = 48
	we.environment.ssr_fade_in = 0.15
	we.environment.ssr_fade_out = 2.0
	we.environment.ssr_depth_tolerance = 0.2

func _build_moon() -> void:
	_moon = _make_sky_sprite("res://assets/textures/moon_alpha.png", 70.0)
	_moon.position = Vector3(58.0, 90.0, 360.0)
	for child in _moon.get_children():
		if child is Sprite3D:
			child.modulate = Color(4.0, 4.0, 4.0, 1.0)
	add_child(_moon)

func _build_rain_overlay() -> void:
	# Full-screen canvas_item shader sitting BELOW the dashboard but
	# ABOVE the 3D scene. Procedural drops + downward trails + a touch
	# of screen-refraction read through SCREEN_TEXTURE. Intensity fades
	# in/out via `_rain_intensity` so rain can start and stop.
	var layer := CanvasLayer.new()
	layer.layer = 20    # dashboard is at 30; 3D is below
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(1, 1, 1, 1)
	layer.add_child(rect)

	_rain_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
// Rain on a windshield at highway speed.
//
// Two layers:
//
//   1) STATIC FIELD — a dense field of small drops STUCK to the glass
//      via surface tension. These don't move. They grow in alpha as the
//      time-since-wipe uniform increases — the field "fills in" between
//      wiper sweeps. This is most of the visible rain.
//
//   2) RUNNING DROPS — a sparse pool of drops that have broken free
//      and streak UPWARD-and-OUTWARD along the windshield airflow at
//      speed. Each is a small head with a thin STRAIGHT trail behind
//      it. No squiggle — the airflow vector at any point is consistent,
//      so drops travel in straight lines.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity = 1.0;
uniform float time_since_wipe = 1.0;     // 0 = just swept, grows over cycle
uniform vec2  wind_origin = vec2(0.5, 1.05);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 wind_dir(vec2 uv) {
	vec2 d = normalize(uv - wind_origin + vec2(0.0, -0.05));
	return normalize(d * 0.6 + vec2(0.0, -1.0) * 0.5);
}

// Static field — small drops at fixed hash positions. Each drop has its
// own "appear time" within the wipe cycle so the field fills in
// progressively rather than appearing all at once.
float static_drops(vec2 uv) {
	vec2 cells = vec2(72.0, 42.0);
	vec2 grid = uv * cells;
	vec2 cid = floor(grid);
	vec2 cuv = fract(grid);

	// Not every cell has a drop
	float exists = step(0.40, hash21(cid + 19.0));
	if (exists < 0.5) {
		return 0.0;
	}
	// Drop position within cell, jittered
	vec2 dp = vec2(0.25 + hash21(cid + 1.7) * 0.50,
		0.25 + hash21(cid + 11.3) * 0.50);
	float r = 0.18 + hash21(cid + 7.0) * 0.10;
	float d = distance(cuv, dp);
	float drop = smoothstep(r, r * 0.30, d);

	// Each drop appears at a different time in the wipe cycle
	float appear_t = hash21(cid + 23.0) * 0.95;
	float visible = smoothstep(appear_t, appear_t + 0.15, time_since_wipe);

	return drop * visible;
}

// Running drops — sparse cells with a drop streaking outward.
float running_drops(vec2 uv) {
	vec2 cells = vec2(18.0, 11.0);
	vec2 grid = uv * cells;
	vec2 cid = floor(grid);

	// Only ~18% of cells host a running drop at any given moment
	if (hash21(cid + 33.0) > 0.18) {
		return 0.0;
	}

	vec2 spawn_off = vec2(hash21(cid + 41.0), hash21(cid + 47.0));
	vec2 spawn_uv = (cid + spawn_off) / cells;
	vec2 wd = wind_dir(spawn_uv);

	float t_off = hash21(cid + 53.0) * 6.28;
	float life = fract(TIME * 0.95 + t_off);

	float drift = life * 0.55;
	vec2 head_uv = spawn_uv + wd * drift;

	float head_w = 0.0040 + hash21(cid + 61.0) * 0.003;
	float head = smoothstep(head_w * 1.6, 0.0, distance(uv, head_uv));

	vec2 to_uv = uv - head_uv;
	float along = dot(to_uv, -wd);
	vec2 perp_wd = vec2(-wd.y, wd.x);
	float perp = abs(dot(to_uv, perp_wd));
	float trail_len = 0.06 + hash21(cid + 67.0) * 0.04;
	float trail_w = 0.0024;
	float trail = 0.0;
	if (along > 0.0 && along < trail_len && perp < trail_w * 2.5) {
		float band = smoothstep(trail_w * 1.4, 0.0, perp);
		float fade = 1.0 - (along / trail_len);
		trail = band * fade * 0.72;
	}

	// Splash on impact (first 6% of life): small radial burst
	float splash = 0.0;
	if (life < 0.06) {
		float r0 = life * 0.07;
		float dist_spawn = distance(uv, spawn_uv);
		float ring = smoothstep(r0 * 1.3, r0 * 0.9, dist_spawn)
			- smoothstep(r0 * 0.9, r0 * 0.3, dist_spawn);
		splash = max(ring, 0.0) * (1.0 - life / 0.06) * 0.5;
	}

	float fade = smoothstep(0.0, 0.05, life) * smoothstep(1.0, 0.80, life);
	return max(max(head, trail), splash) * fade;
}

void fragment() {
	if (intensity < 0.001) {
		COLOR = vec4(0.0);
	} else {
		float sd = static_drops(UV);
		float rd = running_drops(UV);
		float total = clamp(max(sd * 0.65, rd), 0.0, 1.0);

		// Subtle refraction where drops sit
		vec3 behind = texture(screen_tex, SCREEN_UV).rgb;

		// Highlight from cool ambient (city + moon)
		vec3 highlight = vec3(0.80, 0.92, 1.0);
		vec3 col = behind + highlight * total * 0.45;

		COLOR = vec4(col, total * intensity);
	}
}
"""
	_rain_mat.shader = sh
	_rain_mat.set_shader_parameter("intensity", 0.0)
	rect.material = _rain_mat

	# Wipers also disabled along with the rain — they only make sense
	# while it's raining. Re-enable here when the rain shader is fixed.
	# var wiper_layer := CanvasLayer.new()
	# wiper_layer.layer = 25
	# add_child(wiper_layer)
	# var wiper := WiperDraw.new()
	# wiper.set_anchors_preset(Control.PRESET_FULL_RECT)
	# wiper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# wiper_layer.add_child(wiper)

func _build_world_rain() -> void:
	# Rain falling in 3D space ahead of the camera. Pale blue-white
	# emissive streaks slanting toward the camera. Emission scales with
	# _rain_intensity in _process so the world rain comes and goes with
	# the windshield rain.
	_world_rain = GPUParticles3D.new()
	_world_rain.amount = 1400
	_world_rain.lifetime = 1.4
	_world_rain.preprocess = 0.8
	_world_rain.position = Vector3(0, 18, 35)
	_world_rain.emitting = false

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(110.0, 0.5, 90.0)
	pm.direction = Vector3(-0.15, -1.0, -0.3)
	pm.spread = 3.0
	pm.gravity = Vector3(0, -32, 0)
	pm.initial_velocity_min = 28.0
	pm.initial_velocity_max = 34.0
	pm.scale_min = 0.10
	pm.scale_max = 0.18
	_world_rain.process_material = pm

	var drop := BoxMesh.new()
	drop.size = Vector3(0.05, 1.2, 0.05)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.75, 0.88, 1.0, 0.70)
	dm.emission_enabled = true
	dm.emission = Color(0.75, 0.88, 1.0)
	dm.emission_energy_multiplier = 3.0
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.disable_receive_shadows = true
	dm.disable_fog = true
	drop.material = dm
	_world_rain.draw_pass_1 = drop

	add_child(_world_rain)

func _build_moon_light() -> void:
	# Real DirectionalLight from the moon's position toward scene origin
	# so the cabin is lit cool/violet from where the moon actually is.
	_moon_light = DirectionalLight3D.new()
	var moon_pos: Vector3 = _moon.position if _moon else Vector3(58, 90, 360)
	# Set rotation from a from→to pair without needing the node in the
	# tree first. look_at requires being in tree.
	_moon_light.transform = Transform3D().looking_at(-moon_pos, Vector3.UP)
	_moon_light.position = moon_pos
	_moon_light.light_color = Color(0.55, 0.55, 1.0)
	_moon_light.light_energy = 0.03
	_moon_light.shadow_enabled = false
	add_child(_moon_light)

	# Faint fill so the cabin never goes pure black between source pools.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	fill.light_color = Color(0.35, 0.30, 0.55)
	fill.light_energy = 0.10
	fill.shadow_enabled = false
	add_child(fill)

func _set_sky_sprite_alpha(root: Node3D, brightness: float) -> void:
	# Adjust modulate so the sprite fades smoothly during the day/night
	# crossfade. The Sprite3D is the first child of the wrapper Node3D.
	for child in root.get_children():
		if child is Sprite3D:
			child.modulate = Color(brightness, brightness, brightness, 1.0)

func _make_sky_sprite(tex_path: String, world_size: float) -> Node3D:
	# Returns a Node3D wrapper containing a billboarded Sprite3D. The
	# wrapper makes position handling uniform with the previous shader
	# version. `world_size` is the disc's diameter in world units; we
	# convert to Sprite3D's pixel_size (size per texture pixel).
	var root := Node3D.new()
	var sprite := Sprite3D.new()
	var img := Image.new()
	if img.load(tex_path) != OK:
		push_warning("Soundtrack: sprite tex missing: " + tex_path)
		root.add_child(sprite)
		return root
	var tex := ImageTexture.create_from_image(img)
	sprite.texture = tex
	# Image is 1024x1024; pixel_size = world_size / image_width
	sprite.pixel_size = world_size / float(img.get_width())
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.fixed_size = false
	sprite.no_depth_test = false
	sprite.render_priority = -2
	# Brighten the texture slightly so it pops against the night sky.
	sprite.modulate = Color(1.4, 1.4, 1.4, 1.0)
	root.add_child(sprite)
	return root

func _make_disc_shader() -> Shader:
	# Shared shader for sun + moon. Reads a square PNG with a black
	# background, treats luminance < 0.02 as transparent, emits everything
	# else. Explicit empty fog() override so distant discs don't get
	# washed out by the scene's purple fog.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D disc_tex : source_color, filter_linear_mipmap;
uniform float emission_strength = 2.0;
uniform float opacity = 1.0;

void fragment() {
	vec4 c = texture(disc_tex, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float alpha = smoothstep(0.015, 0.07, lum);
	ALBEDO = vec3(0.0);
	EMISSION = c.rgb * emission_strength;
	ALPHA = alpha * opacity;
}
"""
	return sh

func _make_textured_disc(shader: Shader, tex_path: String,
		disc_size: float, emission: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(disc_size, disc_size)
	mi.mesh = qm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Override the per-mesh AABB so frustum culling can't drop it (the
	# tiny quad's local AABB doesn't account for our position changes).
	mi.custom_aabb = AABB(Vector3(-disc_size, -disc_size, -disc_size),
		Vector3(disc_size * 2.0, disc_size * 2.0, disc_size * 2.0))
	mi.extra_cull_margin = 200.0
	var img := Image.new()
	var err: int = img.load(tex_path)
	if err != OK:
		push_warning("Soundtrack: disc texture missing: %s (err %d)" % [tex_path, err])
		return mi
	print("Soundtrack: loaded %s (%dx%d)" % [tex_path, img.get_width(), img.get_height()])
	var tex := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("disc_tex", tex)
	mat.set_shader_parameter("emission_strength", emission)
	mat.set_shader_parameter("opacity", 1.0)
	mi.material_override = mat
	return mi

func _make_sky_disc(shader: Shader, disc_size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(disc_size, disc_size)
	# QuadMesh defaults to face +Z (normal pointing AWAY from camera
	# when placed in front of camera). Flip to face the camera by
	# rotating 180° around Y.
	mi.rotation = Vector3(0, PI, 0)
	mi.mesh = qm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Frustum culling uses the mesh AABB, which is local to the unrotated
	# quad — give it a generous margin so the disc doesn't disappear at
	# odd camera angles.
	mi.extra_cull_margin = 100.0
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mi.material_override = mat
	return mi

func _make_sun_shader() -> Shader:
	# Classic retrowave split-sun: yellow-to-magenta gradient with
	# horizontal "slats" carving into the bottom half (the iconic look).
	# A wide soft halo radiates outward from the disc.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 col_top : source_color = vec3(1.00, 0.90, 0.30);
uniform vec3 col_mid : source_color = vec3(1.00, 0.45, 0.55);
uniform vec3 col_bot : source_color = vec3(0.95, 0.12, 0.55);
uniform float emission_strength = 4.5;
uniform float opacity = 1.0;
uniform float band_count = 7.0;

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p);
	float t = UV.y;

	vec3 grad = mix(col_bot, col_mid, smoothstep(0.0, 0.55, t));
	grad = mix(grad, col_top, smoothstep(0.55, 1.0, t));

	float disc = 1.0 - smoothstep(0.46, 0.50, d);

	float in_bot = 1.0 - smoothstep(0.40, 0.55, t);
	float band_y = (0.55 - t) * band_count;
	float slat = step(0.45, fract(band_y));
	float slat_mask = mix(1.0, slat, in_bot);

	float halo = (1.0 - smoothstep(0.18, 0.50, d)) * 0.6;
	halo *= 1.0 - disc;

	vec3 col = grad * (disc * slat_mask) + col_mid * halo;
	float a = max(disc * slat_mask, halo * 0.45);

	ALBEDO = vec3(0.0);
	EMISSION = col * emission_strength;
	ALPHA = a * opacity;
}
"""
	return sh

func _make_moon_shader() -> Shader:
	# Stylized vector moon: pale violet circle, faint inner gradient, a
	# couple of dim maria patches via cheap hash-circle dimples.
	# No photo-realism — keeps the look cohesive with the synthwave sun.
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 col_core : source_color = vec3(0.94, 0.93, 1.00);
uniform vec3 col_rim  : source_color = vec3(0.55, 0.62, 0.95);
uniform vec3 halo_col : source_color = vec3(0.45, 0.55, 1.00);
uniform float emission_strength = 3.5;
uniform float opacity = 1.0;

float maria(vec2 uv) {
	// Three fixed soft dimples on the visible face.
	float m = 0.0;
	m += smoothstep(0.12, 0.0, distance(uv, vec2(0.42, 0.58)));
	m += smoothstep(0.09, 0.0, distance(uv, vec2(0.60, 0.46)));
	m += smoothstep(0.07, 0.0, distance(uv, vec2(0.50, 0.34)));
	return clamp(m, 0.0, 1.0);
}

void fragment() {
	vec2 p = UV - 0.5;
	float d = length(p);

	// Disc mask
	float disc = 1.0 - smoothstep(0.46, 0.50, d);

	// Radial gradient: brighter core, dimmer rim
	float rim_t = smoothstep(0.0, 0.50, d);
	vec3 face = mix(col_core, col_rim, rim_t);

	// Subtle limb darkening at the very edge
	float limb = 1.0 - rim_t * 0.55;
	face *= limb;

	// Maria
	face *= 1.0 - maria(UV) * 0.35;

	// Halo
	float halo = smoothstep(0.50, 0.15, d) * 0.4;

	vec3 col = face * disc + halo_col * halo;
	float a = max(disc, halo * 0.55);

	ALBEDO = vec3(0.0);
	EMISSION = col * emission_strength;
	ALPHA = a * opacity;
}
"""
	return sh

# ═══════════════════════════════════════════════════════════════════════
# WORLD — stars (sky depth)
# ═══════════════════════════════════════════════════════════════════════

func _build_stars() -> void:
	# Billboarded quads with a soft additive Gaussian falloff shader.
	# Parented to _star_root so we can fade them all together as the
	# sun rises and washes them out.
	_star_root = Node3D.new()
	add_child(_star_root)
	var rng := RandomNumberGenerator.new()
	rng.set_seed(101)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0);
uniform float brightness = 1.0;
uniform float twinkle_phase = 0.0;
uniform float twinkle_speed = 1.4;

void vertex() {
	// Billboard to face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0],
		INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2],
		MODEL_MATRIX[3]);
}

void fragment() {
	vec2 c = UV - 0.5;
	float d = length(c);
	// Soft Gaussian core
	float core = exp(-d * 22.0);
	// Cross-spike (subtle): boosts brightness along horizontal+vertical axes
	float spike = max(
		exp(-abs(c.x) * 95.0) * exp(-abs(c.y) * 5.0),
		exp(-abs(c.y) * 95.0) * exp(-abs(c.x) * 5.0)) * 0.4;
	float a = clamp(core + spike, 0.0, 1.0);
	float tw = 0.65 + 0.35 * sin(TIME * twinkle_speed + twinkle_phase);
	EMISSION = tint * brightness * a * tw;
	ALPHA = a;
}
"""
	# A small set of star colors weighted toward white.
	var palette: Array[Color] = [
		Color(1.00, 1.00, 1.00),
		Color(1.00, 1.00, 1.00),
		Color(1.00, 1.00, 1.00),
		Color(0.85, 0.92, 1.00),   # cool blue
		Color(1.00, 0.92, 0.78),   # warm yellow
		Color(0.95, 0.85, 1.00),   # pale violet
	]
	for i in range(110):
		var star := MeshInstance3D.new()
		var qm := QuadMesh.new()
		var size: float = 0.9 + pow(rng.randf(), 5.0) * 4.5
		qm.size = Vector2(size, size)
		star.mesh = qm
		star.position = Vector3(
			rng.randf_range(-180.0, 180.0),
			rng.randf_range(28.0, 110.0),
			rng.randf_range(170.0, 360.0))
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tint", palette[rng.randi() % palette.size()])
		mat.set_shader_parameter("brightness", 1.4 + rng.randf_range(0.0, 4.0))
		mat.set_shader_parameter("twinkle_phase", rng.randf_range(0.0, TAU))
		mat.set_shader_parameter("twinkle_speed", 0.7 + rng.randf_range(0.0, 1.8))
		star.material_override = mat
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_star_root.add_child(star)

# ═══════════════════════════════════════════════════════════════════════
# WORLD — mountains + city skyline (parallax silhouettes)
# ═══════════════════════════════════════════════════════════════════════

func _build_mountains() -> void:
	# Far layer: deep purple wash, simple triangular silhouettes.
	var rng := RandomNumberGenerator.new()
	rng.set_seed(11)
	var z := 320.0
	var peak_count := 14
	var base_width := 60.0
	var start_x := -float(peak_count) * base_width * 0.5
	var fill := ImmediateMesh.new()
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.20, 0.10, 0.28)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.disable_fog = true
	fill.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fm)
	for i in range(peak_count):
		var bx: float = start_x + float(i) * base_width
		var px: float = bx + base_width * 0.5
		var rx: float = bx + base_width
		var ph: float = 22.0 + rng.randf_range(0.0, 22.0)
		fill.surface_add_vertex(Vector3(bx, 0.0, z))
		fill.surface_add_vertex(Vector3(px, ph, z))
		fill.surface_add_vertex(Vector3(rx, 0.0, z))
	fill.surface_end()
	var fm_mi := MeshInstance3D.new()
	fm_mi.mesh = fill
	fm_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fm_mi)

	# Near layer: pink-rim ridges in front of the city for depth.
	var rng2 := RandomNumberGenerator.new()
	rng2.set_seed(29)
	var z2 := 240.0
	var peak2 := 22
	var bw2 := 22.0
	var sx2 := -float(peak2) * bw2 * 0.5
	var fill2 := ImmediateMesh.new()
	var fm2 := StandardMaterial3D.new()
	fm2.albedo_color = Color(0.12, 0.04, 0.20)
	fm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm2.disable_fog = true
	fill2.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fm2)
	for i in range(peak2):
		var bx: float = sx2 + float(i) * bw2
		var px: float = bx + bw2 * 0.5
		var rx: float = bx + bw2
		var ph: float = 10.0 + rng2.randf_range(0.0, 16.0)
		fill2.surface_add_vertex(Vector3(bx, 0.0, z2))
		fill2.surface_add_vertex(Vector3(px, ph, z2))
		fill2.surface_add_vertex(Vector3(rx, 0.0, z2))
	fill2.surface_end()
	var fm2_mi := MeshInstance3D.new()
	fm2_mi.mesh = fill2
	fm2_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fm2_mi)

func _build_city_skyline() -> void:
	# Distant city silhouette — what a real city looks like from 20+
	# miles down a desert highway at night:
	#   - dark building shapes you can BARELY see against the haze
	#   - tiny warm window specks scattered on the bodies
	#   - very occasional aircraft-warning red light on a tall antenna
	#   - one or two real "landmark" billboards (rare, not every roof)
	#   - a soft horizon glow leaking up between them
	# No rainbow rooftop neon. Real cities don't look like Lisa Frank.
	var rng := RandomNumberGenerator.new()
	rng.set_seed(73)
	var city_z := 280.0

	var dark_body := StandardMaterial3D.new()
	dark_body.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark_body.albedo_color = Color(0.090, 0.050, 0.150)
	dark_body.disable_fog = true

	# Window-light material — warm tungsten yellow, very tiny specks.
	var window_mat := StandardMaterial3D.new()
	window_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	window_mat.emission_enabled = true
	window_mat.emission = Color(1.0, 0.85, 0.45)
	window_mat.emission_energy_multiplier = 2.5
	window_mat.albedo_color = Color(1.0, 0.85, 0.45)
	window_mat.disable_fog = true

	# Soft horizon haze BEHIND the city — pink-purple, fades upward.
	var glow := MeshInstance3D.new()
	var glow_mesh := PlaneMesh.new()
	glow_mesh.size = Vector2(380.0, 32.0)
	glow_mesh.orientation = PlaneMesh.FACE_Z
	glow.mesh = glow_mesh
	glow.position = Vector3(0.0, 11.0, city_z + 0.6)
	var glow_mat := ShaderMaterial.new()
	var glow_shader := Shader.new()
	glow_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
uniform vec3 col_low  : source_color = vec3(0.95, 0.25, 0.55);
uniform vec3 col_high : source_color = vec3(0.30, 0.10, 0.60);
uniform float strength = 2.6;
void fragment() {
	float t = clamp(UV.y, 0.0, 1.0);
	float band = pow(1.0 - t, 1.8) * smoothstep(0.0, 0.10, 1.0 - t);
	vec3 col = mix(col_low, col_high, t);
	ALBEDO = vec3(0.0);
	EMISSION = col * strength * band;
	ALPHA = band;
}
"""
	glow_mat.shader = glow_shader
	glow.material_override = glow_mat
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)

	# Pick a few specific buildings (by index) to host the rare landmarks:
	# a single big animated billboard and a couple of antenna FAA reds.
	# Everything else stays plain (dark body + window specks).
	var building_count_estimate := 26
	var billboard_idx: int = 9 + rng.randi() % 6      # one billboard
	var faa_indices: Array[int] = [
		3 + rng.randi() % 4,
		15 + rng.randi() % 5,
	]

	var x: float = -150.0
	var idx: int = 0
	while x < 150.0:
		var w: float = 5.0 + rng.randf_range(0.0, 9.0)
		var h: float = 7.0 + rng.randf_range(0.0, 22.0)
		var bz: float = city_z + rng.randf_range(-2.0, 3.0)

		# Body
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, 1.6)
		body.mesh = bm
		body.position = Vector3(x + w * 0.5, h * 0.5, bz)
		body.material_override = dark_body
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(body)

		# Sprinkle of lit windows on the building face. Sparse — most
		# windows in a real city are off. Tiny — they're 20 miles away.
		var rows: int = max(2, int(h / 1.8))
		var cols: int = max(2, int(w / 1.0))
		for ry in range(1, rows):
			for cx in range(1, cols):
				if rng.randf() > 0.18:
					continue
				var win := MeshInstance3D.new()
				var wmesh := BoxMesh.new()
				wmesh.size = Vector3(0.18, 0.22, 0.06)
				win.mesh = wmesh
				var wx: float = x + (float(cx) + 0.5) * (w / float(cols))
				var wy: float = (float(ry) + 0.5) * (h / float(rows))
				win.position = Vector3(wx, wy, bz - 0.85)
				win.material_override = window_mat
				win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(win)

		# Rare: a single big landmark billboard with a neon panel.
		if idx == billboard_idx:
			var bbw: float = w * 0.80
			var bbh: float = 1.6
			var bb := MeshInstance3D.new()
			var bbm := BoxMesh.new()
			bbm.size = Vector3(bbw, bbh, 0.20)
			bb.mesh = bbm
			bb.position = Vector3(x + w * 0.5, h + bbh * 0.5 + 0.4,
				bz - 0.95)
			# Pick ONE accent color and stick with it for this billboard
			var billboard_color := HOT_PINK if (rng.randi() % 2 == 0) \
				else NEON_CYAN
			var bbmat := _make_emissive_unshaded(billboard_color, 3.0)
			bbmat.disable_fog = true
			bb.material_override = bbmat
			bb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bb)
			# Support struts beneath the billboard
			var strut := MeshInstance3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(bbw * 0.06, 0.4, 0.12)
			strut.mesh = sm
			strut.position = Vector3(x + w * 0.5, h + 0.2, bz - 0.85)
			strut.material_override = dark_body
			strut.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(strut)

		# Rare: aircraft-warning red light on a thin antenna (FAA req'd
		# on tall structures; classic distant-city detail).
		if idx in faa_indices:
			var ah: float = 3.5 + rng.randf_range(0.0, 3.5)
			var antenna := MeshInstance3D.new()
			var amesh := BoxMesh.new()
			amesh.size = Vector3(0.10, ah, 0.10)
			antenna.mesh = amesh
			var ax: float = x + w * (0.30 + rng.randf_range(0.0, 0.40))
			antenna.position = Vector3(ax, h + ah * 0.5, bz)
			antenna.material_override = dark_body
			antenna.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(antenna)

			var tip := MeshInstance3D.new()
			var tmesh := BoxMesh.new()
			tmesh.size = Vector3(0.22, 0.22, 0.22)
			tip.mesh = tmesh
			tip.position = Vector3(ax, h + ah + 0.05, bz)
			var tip_mat := _make_emissive_unshaded(Color(1.0, 0.15, 0.15),
				4.0)
			tip_mat.disable_fog = true
			tip.material_override = tip_mat
			tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tip)

		x += w + 0.4 + rng.randf_range(0.0, 1.6)
		idx += 1

# ═══════════════════════════════════════════════════════════════════════
# WORLD — road (asphalt + lane dashes + edge lines)
# ═══════════════════════════════════════════════════════════════════════

func _build_road() -> void:
	# Main asphalt plate — wide enough that we don't see its edges through
	# the fog.
	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(ROAD_WIDTH * 4.0, ROAD_LENGTH)
	road.mesh = rm
	# Slightly damp asphalt — modest reflectivity. Higher metallic +
	# lower roughness make any light source create a focused bright
	# streak that outshines the source itself; we tone it down.
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.030, 0.025, 0.045)
	road_mat.metallic = 0.35
	road_mat.metallic_specular = 0.7
	road_mat.roughness = 0.45
	road_mat.rim_enabled = true
	road_mat.rim = 0.25
	road_mat.rim_tint = 0.5
	road.material_override = road_mat
	road.position = Vector3(0, 0.0, ROAD_LENGTH / 2.0 - 30.0)
	add_child(road)

	# Solid edge lines (left + right) — long thin glowing strips.
	var edge_mat := _make_emissive_unshaded(LANE_WHITE, 1.4)
	var edge_xs: Array[float] = [-ROAD_WIDTH / 2.0, ROAD_WIDTH / 2.0]
	for x in edge_xs:
		var edge := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.12, 0.01, ROAD_LENGTH)
		edge.mesh = em
		edge.position = Vector3(x, 0.02, ROAD_LENGTH / 2.0 - 30.0)
		edge.material_override = edge_mat
		edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(edge)

	# Lane-divider dashes — two rows, one on each side of the car so the
	# car visibly drives in the middle lane (not on top of the dashes).
	var dash_mat := _make_emissive_unshaded(LANE_WHITE, 1.2)
	var dash_xs: Array[float] = [-DASH_LANE_X, DASH_LANE_X]
	for x in dash_xs:
		for i in range(DASH_COUNT):
			var d := MeshInstance3D.new()
			var dm := BoxMesh.new()
			dm.size = Vector3(0.18, 0.01, DASH_LEN)
			d.mesh = dm
			d.position = Vector3(x, 0.025,
				DASH_NEAR_Z + float(i) * DASH_SPACING)
			d.material_override = dash_mat
			d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(d)
			_dashes.append(d)

# ═══════════════════════════════════════════════════════════════════════
# WORLD — streetlights pool
# ═══════════════════════════════════════════════════════════════════════

func _build_streetlights() -> void:
	# Pool of streetlights spaced down the road, alternating sides. Each
	# scrolls toward the camera and recycles to the far end.
	for i in range(STREETLIGHT_COUNT):
		var side: float = 1.0 if (i % 2 == 0) else -1.0
		var z: float = STREETLIGHT_NEAR_Z + float(i) * STREETLIGHT_SPACING
		var sl := _make_streetlight(side)
		sl.position = Vector3(side * (ROAD_WIDTH / 2.0 + 1.6), 0.0, z)
		add_child(sl)
		_streetlights.append(sl)

func _make_streetlight(side: float) -> Node3D:
	var root := Node3D.new()

	# Pole — thin tall dark column
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.10
	pm.bottom_radius = 0.14
	pm.height = STREETLIGHT_HEIGHT
	pm.radial_segments = 12
	pole.mesh = pm
	pole.position = Vector3(0, STREETLIGHT_HEIGHT / 2.0, 0)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.06, 0.06, 0.08)
	pole_mat.roughness = 0.6
	pole_mat.metallic = 0.4
	pole.material_override = pole_mat
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pole)

	# Crossarm — extends out over the road
	var arm := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(STREETLIGHT_ARM, 0.10, 0.14)
	arm.mesh = am
	arm.position = Vector3(-side * STREETLIGHT_ARM / 2.0,
		STREETLIGHT_HEIGHT - 0.15, 0)
	arm.material_override = pole_mat
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(arm)

	# Lamp housing — small box at the end of the arm
	var lamp_x: float = -side * STREETLIGHT_ARM
	var housing := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.55, 0.20, 0.42)
	housing.mesh = hm
	housing.position = Vector3(lamp_x, STREETLIGHT_HEIGHT - 0.35, 0)
	housing.material_override = pole_mat
	housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(housing)

	# Bulb — emissive TEAL synthwave streetlight, casts a violet-tinted
	# cyan pool on the asphalt below.
	var bulb := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.50, 0.04, 0.38)
	bulb.mesh = bm
	bulb.position = Vector3(lamp_x, STREETLIGHT_HEIGHT - 0.55, 0)
	bulb.material_override = _make_emissive_unshaded(NEON_PURPLE, 5.0)
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bulb)

	var spot := SpotLight3D.new()
	spot.position = Vector3(lamp_x, STREETLIGHT_HEIGHT - 0.55, 0)
	spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	spot.light_color = Color(0.55, 0.35, 1.0)   # vivid blue-violet
	spot.light_energy = 5.5
	spot.spot_range = STREETLIGHT_HEIGHT + 8.0
	spot.spot_angle = 45.0
	spot.spot_attenuation = 1.2
	spot.shadow_enabled = false
	root.add_child(spot)

	return root

# ═══════════════════════════════════════════════════════════════════════
# WORLD — driver's-eye headlights (no visible car, just cones of light)
# ═══════════════════════════════════════════════════════════════════════

func _build_flora() -> void:
	# Sparse roadside cactus + palm sprites that scroll past the camera,
	# wrapping forward when they pass behind us. Outlined billboards →
	# they read clean against the night without needing 3D models.
	var rng := RandomNumberGenerator.new()
	rng.set_seed(57)
	var cactus_img := Image.new()
	var palm_img := Image.new()
	var have_cactus: bool = (cactus_img.load(
		"res://assets/textures/cactus_alpha.png") == OK)
	var have_palm: bool = (palm_img.load(
		"res://assets/textures/palm_alpha.png") == OK)
	if not have_cactus and not have_palm:
		return
	var cactus_tex: Texture2D = (ImageTexture.create_from_image(cactus_img)
		if have_cactus else null)
	var palm_tex: Texture2D = (ImageTexture.create_from_image(palm_img)
		if have_palm else null)

	# Very sparse — desolate desert highway, mostly empty.
	for i in range(2):
		var side: float = 1.0 if (i % 2 == 0) else -1.0
		# Mostly palm trees, rare cactus — the synthwave-palm visual
		# carries the desert mood better than pink cacti.
		var is_palm: bool = (rng.randf() < 0.75) and have_palm
		var tex: Texture2D = palm_tex if is_palm else cactus_tex
		if tex == null:
			continue
		var world_h: float = (10.0 if is_palm else 3.5) \
			+ rng.randf_range(0.0, 2.0)
		var plant := _make_billboard_sprite(tex, world_h)
		var dist_from_road: float = ROAD_WIDTH / 2.0 + 2.5 \
			+ rng.randf_range(0.0, 4.0)
		# Wide spacing so plants pass slowly, not landscape-style density.
		var z: float = -20.0 + float(i) * 80.0 \
			+ rng.randf_range(-6.0, 6.0)
		# Anchor at ground level — sprite's pivot is its center, so lift
		# it by half its world height.
		plant.position = Vector3(side * dist_from_road, world_h * 0.5, z)
		add_child(plant)
		_flora.append(plant)
		_flora_speeds.append(DASH_SPEED)

func _make_billboard_sprite(tex: Texture2D, world_height: float) -> Node3D:
	# A Sprite3D whose vertical pixel-size is computed so the displayed
	# height matches `world_height`. Y_BILLBOARD keeps the sprite
	# upright (it rotates only on Y to face the camera).
	var root := Node3D.new()
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.shaded = false
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	var img_h: int = tex.get_height()
	sprite.pixel_size = world_height / float(img_h)
	sprite.modulate = Color(1.1, 1.1, 1.1, 1.0)
	sprite.render_priority = -1
	root.add_child(sprite)
	return root

func _build_headlights() -> void:
	# Twin SpotLights at "front of car" position — wide bright cones
	# illuminating the road ahead, parented to the camera so the bob
	# carries them.
	var hl_xs: Array[float] = [-0.95, 0.95]
	for x in hl_xs:
		var hl := SpotLight3D.new()
		hl.position = Vector3(x, -0.55, 2.0)
		hl.rotation_degrees = Vector3(-2.5, 0.0, 0.0)
		hl.light_color = Color(1.0, 0.98, 0.88)
		hl.light_energy = 7.5
		hl.spot_range = 110.0
		hl.spot_angle = 36.0
		hl.spot_attenuation = 1.0
		hl.shadow_enabled = false
		_camera.add_child(hl)

# ═══════════════════════════════════════════════════════════════════════
# WORLD — atmospheric lights (rim + fill so the car has shape)
# ═══════════════════════════════════════════════════════════════════════


func _make_emissive_unshaded(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

# ═══════════════════════════════════════════════════════════════════════
# HUD — minimal cyberpunk console at the bottom of the screen
# ═══════════════════════════════════════════════════════════════════════

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Dashboard photo — anchored to the bottom of the viewport so it
	# only occupies the lower ~40% of the screen, leaving the upper 60%
	# for the windshield (sky, moon, stars, road horizon). The image's
	# remaining sky portion is alpha-keyed out by the shader, but since
	# we've cropped the visible rect to the dashboard area, that mostly
	# matters for the soft edges around the gauges.
	var dash := TextureRect.new()
	dash.anchor_left = 0.0
	dash.anchor_right = 1.0
	dash.anchor_top = 0.58
	dash.anchor_bottom = 1.0
	dash.offset_left = 0
	dash.offset_right = 0
	dash.offset_top = 0
	dash.offset_bottom = 0
	var img := Image.new()
	var ok := img.load("res://assets/textures/dashboard.png")
	if ok == OK:
		dash.texture = ImageTexture.create_from_image(img)
	dash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dash.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dash_mat := ShaderMaterial.new()
	var dash_shader := Shader.new()
	dash_shader.code = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// Pixels with very low luminance (the DALL-E "sky" portion of the
	// dashboard image) are alpha-keyed out so the 3D windshield shows
	// through cleanly. Threshold is higher than the previous pure-black
	// gate so subtle dark-blue tints in the sky also become transparent.
	float alpha = smoothstep(0.025, 0.09, lum);
	COLOR = vec4(c.rgb, alpha);
}
"""
	dash_mat.shader = dash_shader
	dash.material = dash_mat
	root.add_child(dash)

	# Music console — anchored OVER the radio recess. Tight, compact,
	# all info on a single short LCD strip.
	var console := _make_console()
	console.anchor_left = 0.435
	console.anchor_right = 0.605
	console.anchor_top = 0.79
	console.anchor_bottom = 0.83
	console.offset_left = 0
	console.offset_right = 0
	console.offset_top = 0
	console.offset_bottom = 0
	root.add_child(console)

	# Transport buttons — directly below the recess, compact.
	var ctrls := _make_transport_row()
	ctrls.anchor_left = 0.5
	ctrls.anchor_right = 0.5
	ctrls.anchor_top = 0.855
	ctrls.anchor_bottom = 0.855
	ctrls.offset_left = -64
	ctrls.offset_right = 64
	ctrls.offset_top = 0
	ctrls.offset_bottom = 24
	root.add_child(ctrls)

	# Back link — top-left, away from the dashboard.
	var back := Button.new()
	back.text = "◂ BACK"
	back.flat = true
	back.position = Vector2(22, 18)
	back.add_theme_font_size_override("font_size", 14)
	back.add_theme_color_override("font_color", NEON_CYAN)
	back.add_theme_color_override("font_hover_color", HOT_PINK)
	back.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	back.add_theme_constant_override("outline_size", 4)
	back.pressed.connect(_back_to_title)
	root.add_child(back)

	# Station ID — top-right, small.
	var station := Label.new()
	station.text = "NULL//DRIFT FM · 95.3"
	station.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	station.position = Vector2(-200, 18)
	station.size = Vector2(180, 22)
	station.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	station.add_theme_font_size_override("font_size", 14)
	station.add_theme_color_override("font_color", NEON_CYAN)
	station.add_theme_color_override("font_outline_color", HOT_PINK)
	station.add_theme_constant_override("outline_size", 3)
	root.add_child(station)

	# Tracklist modal (hidden until LIST pressed)
	_tracklist_modal = _make_tracklist_modal()
	_tracklist_modal.visible = false
	root.add_child(_tracklist_modal)

func _make_console() -> PanelContainer:
	# A tiny LCD-style readout that fits inside the dashboard's radio
	# recess. Two stacked rows:
	#   row 1: small "▶ NULL//DRIFT FM" station tag + tiny amber clock
	#   row 2: amber-glowing track name marquee
	#   row 3: thin pink progress sliver + tiny time + 4 eq bars
	# All text is small, amber/cyan only — like a real car LCD.
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	# Faint dark backplate, no visible border — the dashboard photo
	# already paints the recess frame around it.
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.set_border_width_all(0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	panel.add_child(info)

	# Row 1: track name (left, large-ish), time (right, tiny). Cyan/violet
	# to match the cool dashboard illumination.
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	info.add_child(row1)
	_np_track_label = Label.new()
	_np_track_label.text = "— PRESS PLAY —"
	_np_track_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_np_track_label.add_theme_font_size_override("font_size", 11)
	_np_track_label.add_theme_color_override("font_color",
		Color(0.55, 0.95, 1.0))
	_np_track_label.add_theme_color_override("font_outline_color",
		Color(0.0, 0.0, 0.0, 0.95))
	_np_track_label.add_theme_constant_override("outline_size", 2)
	_np_track_label.clip_text = true
	row1.add_child(_np_track_label)
	_np_time_label = Label.new()
	_np_time_label.text = "--:--"
	_np_time_label.add_theme_font_size_override("font_size", 9)
	_np_time_label.add_theme_color_override("font_color",
		Color(0.70, 0.55, 1.0))
	row1.add_child(_np_time_label)

	# Row 2: thin progress bar.
	_np_progress_bar = Control.new()
	_np_progress_bar.custom_minimum_size = Vector2(0, 2)
	_np_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_np_progress_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_np_progress_bar.gui_input.connect(_on_progress_input)
	var pbg := ColorRect.new()
	pbg.color = Color(0.45, 0.85, 1.0, 0.18)
	pbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_np_progress_bar.add_child(pbg)
	_np_progress_fill = ColorRect.new()
	_np_progress_fill.color = Color(0.40, 0.85, 1.0)
	_np_progress_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_np_progress_fill.size = Vector2(0, 2)
	_np_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_np_progress_bar.add_child(_np_progress_fill)
	info.add_child(_np_progress_bar)

	# Tiny scene tag + EQ on one short row.
	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 4)
	_np_scene_label = Label.new()
	_np_scene_label.text = "95.3 NULL//DRIFT"
	_np_scene_label.add_theme_font_size_override("font_size", 8)
	_np_scene_label.add_theme_color_override("font_color",
		Color(0.70, 0.55, 1.0))
	row3.add_child(_np_scene_label)
	var sp3 := Control.new()
	sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row3.add_child(sp3)
	var eq := HBoxContainer.new()
	eq.add_theme_constant_override("separation", 1)
	for i in range(4):
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(2, 6)
		bar.color = Color(0.40, 0.85, 1.0)
		eq.add_child(bar)
		_eq_bars.append(bar)
		_eq_phases.append(i * 0.6)
	row3.add_child(eq)
	info.add_child(row3)

	return panel

func _make_transport_row() -> HBoxContainer:
	# Compact transport row that fits inside the dashboard's radio
	# recess. Buttons are tight; total width stays below the recess
	# width so they don't poke past the bezel.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_STOP

	var prev_btn := _make_ctrl_btn("⏮", NEON_CYAN, 14, 34)
	prev_btn.pressed.connect(_prev_track)
	row.add_child(prev_btn)
	_play_btn = _make_ctrl_btn("▶", HOT_PINK, 18, 44)
	_play_btn.pressed.connect(_toggle_play)
	row.add_child(_play_btn)
	var next_btn := _make_ctrl_btn("⏭", NEON_CYAN, 14, 34)
	next_btn.pressed.connect(_next_track)
	row.add_child(next_btn)
	var list_btn := _make_ctrl_btn("≡", NEON_PURPLE, 14, 34)
	list_btn.pressed.connect(_open_tracklist)
	row.add_child(list_btn)
	return row

func _make_ctrl_btn(text: String, color: Color, font_size: int,
		min_width: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	btn.add_theme_constant_override("outline_size", 4)
	btn.custom_minimum_size = Vector2(min_width, 36)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	normal.border_color = Color(color.r, color.g, color.b, 0.65)
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.corner_radius_top_left = 2
	normal.corner_radius_top_right = 2
	normal.corner_radius_bottom_left = 2
	normal.corner_radius_bottom_right = 2
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", normal)
	btn.add_theme_stylebox_override("pressed", normal)
	btn.add_theme_stylebox_override("focus", normal)
	return btn

# ═══════════════════════════════════════════════════════════════════════
# TRACKLIST MODAL
# ═══════════════════════════════════════════════════════════════════════

func _make_tracklist_modal() -> Control:
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.012, 0.0, 0.06, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_tracklist())
	bg.add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = -280
	panel.offset_bottom = 280
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.012, 0.0, 0.06)
	ps.border_color = NEON_PURPLE
	ps.set_border_width_all(2)
	ps.content_margin_left = 18
	ps.content_margin_right = 18
	ps.content_margin_top = 14
	ps.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", ps)
	bg.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var head := HBoxContainer.new()
	var h := Label.new()
	h.text = "≡ TRACKLIST"
	h.add_theme_font_size_override("font_size", 18)
	h.add_theme_color_override("font_color", NEON_CYAN)
	h.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	h.add_theme_constant_override("outline_size", 4)
	head.add_child(h)
	var hs := Control.new()
	hs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hs)
	_tracklist_count = Label.new()
	_tracklist_count.text = "— / —"
	_tracklist_count.add_theme_font_size_override("font_size", 13)
	_tracklist_count.add_theme_color_override("font_color", NEON_PURPLE)
	head.add_child(_tracklist_count)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", HOT_PINK)
	close_btn.add_theme_color_override("font_outline_color",
		Color(0, 0, 0, 0.9))
	close_btn.add_theme_constant_override("outline_size", 4)
	var cbs := StyleBoxFlat.new()
	cbs.bg_color = Color(0.012, 0.0, 0.06)
	cbs.border_color = HOT_PINK
	cbs.set_border_width_all(2)
	cbs.content_margin_left = 10
	cbs.content_margin_right = 10
	cbs.content_margin_top = 4
	cbs.content_margin_bottom = 4
	close_btn.add_theme_stylebox_override("normal", cbs)
	close_btn.add_theme_stylebox_override("hover", cbs)
	close_btn.add_theme_stylebox_override("pressed", cbs)
	close_btn.add_theme_stylebox_override("focus", cbs)
	close_btn.pressed.connect(_close_tracklist)
	head.add_child(close_btn)
	col.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(564, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_tracklist_container = VBoxContainer.new()
	_tracklist_container.add_theme_constant_override("separation", 0)
	_tracklist_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tracklist_container)

	return bg

func _populate_tracklist() -> void:
	for child in _tracklist_container.get_children():
		child.queue_free()
	for i in range(_tracks.size()):
		_tracklist_container.add_child(_make_track_row(i, _tracks[i]))
	var cur: String = str(_current_idx + 1) if _current_idx >= 0 else "—"
	_tracklist_count.text = "%s / %d" % [cur, _tracks.size()]

func _make_track_row(idx: int, t: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 46)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_track_row_pressed(idx))
	var is_cur := (idx == _current_idx)
	var rs := StyleBoxFlat.new()
	rs.bg_color = (Color(1.0, 0.10, 0.60, 0.10) if is_cur
		else Color(0, 0, 0, 0))
	rs.border_color = (HOT_PINK if is_cur
		else Color(NEON_CYAN.r, NEON_CYAN.g, NEON_CYAN.b, 0.18))
	rs.border_width_left = (3 if is_cur else 0)
	rs.border_width_bottom = 1
	rs.content_margin_left = 12
	rs.content_margin_right = 12
	rs.content_margin_top = 8
	rs.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", rs)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)

	var num := Label.new()
	num.text = "%02d" % (idx + 1)
	num.add_theme_font_size_override("font_size", 14)
	num.add_theme_color_override("font_color", NEON_PURPLE)
	num.custom_minimum_size = Vector2(28, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(num)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	hb.add_child(info)
	var name_lbl := Label.new()
	name_lbl.text = t["name"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color",
		(HOT_PINK if is_cur else NEON_CYAN))
	name_lbl.add_theme_color_override("font_outline_color",
		Color(0, 0, 0, 0.9))
	name_lbl.add_theme_constant_override("outline_size", 3)
	info.add_child(name_lbl)
	var scene_lbl := Label.new()
	scene_lbl.text = t["scene"]
	scene_lbl.add_theme_font_size_override("font_size", 11)
	scene_lbl.add_theme_color_override("font_color", NEON_PURPLE)
	info.add_child(scene_lbl)

	return row

func _on_track_row_pressed(idx: int) -> void:
	if idx == _current_idx:
		_toggle_play()
	else:
		_play_index(idx)
		_populate_tracklist()

func _open_tracklist() -> void:
	_populate_tracklist()
	_tracklist_modal.visible = true

func _close_tracklist() -> void:
	_tracklist_modal.visible = false

# ═══════════════════════════════════════════════════════════════════════
# AUDIO PLAYBACK
# ═══════════════════════════════════════════════════════════════════════

func _setup_audio() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -6.0
	_player.finished.connect(_on_track_finished)
	add_child(_player)

func _scan_tracks() -> void:
	_tracks.clear()
	var dir := DirAccess.open(MUSIC_DIR)
	if dir == null:
		push_warning("Soundtrack: music dir missing: " + MUSIC_DIR)
		return
	var stems: Array[String] = []
	for fname in dir.get_files():
		if fname.ends_with(".mp3"):
			stems.append(fname.get_basename())
	stems.sort()
	var category_of: Dictionary = {}
	for cat in Music.CATEGORIES.keys():
		for stem in Music.CATEGORIES[cat]:
			category_of[stem] = cat
	for stem in stems:
		_tracks.append({
			"file": stem + ".mp3",
			"stem": stem,
			"name": _prettify(stem),
			"scene": _scene_label_for(category_of.get(stem, "")),
		})

func _prettify(stem: String) -> String:
	var s := stem.replace("-", " ").replace("_", " ")
	var parts := s.split(" ")
	var out: Array[String] = []
	for p in parts:
		if p == "full":
			out.append("(FULL)")
		elif p.length() > 0:
			out.append(p.to_upper())
	return " ".join(out)

func _scene_label_for(category: String) -> String:
	match category:
		"title": return "▸ TITLE"
		"apartment": return "▸ APARTMENT"
		"story": return "▸ STORY"
		"combat": return "▸ COMBAT"
		"driving": return "▸ HIGHWAY"
		"game_over": return "▸ GAME OVER"
		"ending": return "▸ ENDING"
		"ambient": return "▸ AMBIENT"
		_: return "▸ DEEP CUT"

func _play_index(idx: int) -> void:
	if idx < 0 or idx >= _tracks.size():
		return
	var path := "%s/%s" % [MUSIC_DIR, _tracks[idx]["file"]]
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Soundtrack: failed to load " + path)
		return
	if stream.has_method("set_loop"):
		stream.set_loop(false)
	_player.stop()
	_player.stream = stream
	_player.play()
	_current_idx = idx
	_is_paused = false
	_refresh_now_playing()

func _toggle_play() -> void:
	if _current_idx == -1 and _tracks.size() > 0:
		_play_index(0)
		return
	if _player.stream == null:
		return
	if _is_paused:
		_player.stream_paused = false
		_is_paused = false
	elif _player.playing:
		_player.stream_paused = true
		_is_paused = true
	else:
		_player.play()
	_refresh_now_playing()

func _next_track() -> void:
	if _tracks.is_empty():
		return
	var n: int = 0 if _current_idx == -1 else (_current_idx + 1) % _tracks.size()
	_play_index(n)
	if _tracklist_modal.visible:
		_populate_tracklist()

func _prev_track() -> void:
	if _tracks.is_empty():
		return
	var n: int = 0 if _current_idx == -1 else (_current_idx - 1 + _tracks.size()) % _tracks.size()
	_play_index(n)
	if _tracklist_modal.visible:
		_populate_tracklist()

func _on_track_finished() -> void:
	_next_track()

func _refresh_now_playing() -> void:
	if _current_idx == -1:
		_np_track_label.text = "— PRESS PLAY —"
		_np_track_label.add_theme_color_override("font_color",
			Color(0.4, 0.5, 0.6))
		_np_scene_label.text = ""
		_play_btn.text = "▶"
		_np_time_label.text = "--:-- / --:--"
		_np_progress_fill.size.x = 0
	else:
		var t: Dictionary = _tracks[_current_idx]
		_np_track_label.text = t["name"]
		_np_track_label.add_theme_color_override("font_color", HOT_PINK)
		_np_scene_label.text = t["scene"]
		_play_btn.text = ("▶" if _is_paused else "❚❚")
	if _tracklist_modal.visible:
		_populate_tracklist()

# ═══════════════════════════════════════════════════════════════════════
# SEEK + PROGRESS
# ═══════════════════════════════════════════════════════════════════════

func _on_progress_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _player.stream == null:
		return
	var dur: float = _player.stream.get_length()
	if dur <= 0:
		return
	var ratio: float = clamp(event.position.x / _np_progress_bar.size.x,
		0.0, 1.0)
	_player.seek(dur * ratio)

func _update_progress() -> void:
	if _player.stream == null or _current_idx == -1:
		return
	var dur: float = _player.stream.get_length()
	if dur <= 0:
		return
	var pos: float = _player.get_playback_position()
	var ratio: float = clamp(pos / dur, 0.0, 1.0)
	_np_progress_fill.size.x = _np_progress_bar.size.x * ratio
	_np_time_label.text = "%s / %s" % [_fmt_time(pos), _fmt_time(dur)]

func _fmt_time(s: float) -> String:
	var total: int = int(s)
	return "%d:%02d" % [total / 60, total % 60]

# ═══════════════════════════════════════════════════════════════════════
# ANIMATION
# ═══════════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	_time += delta

	# Scroll lane dashes toward the camera; wrap to the far end.
	var dash_loop_z: float = DASH_SPACING * float(DASH_COUNT)
	for d in _dashes:
		d.position.z -= DASH_SPEED * delta
		if d.position.z < DASH_NEAR_Z:
			d.position.z += dash_loop_z

	# Scroll streetlights past the camera; wrap to the far end.
	var sl_loop_z: float = STREETLIGHT_SPACING * float(STREETLIGHT_COUNT)
	for sl in _streetlights:
		sl.position.z -= STREETLIGHT_SPEED * delta
		if sl.position.z < STREETLIGHT_NEAR_Z - 4.0:
			sl.position.z += sl_loop_z

	# Scroll flora past the camera; wrap to the far end.
	var flora_loop_z: float = 80.0 * float(_flora.size())
	for i in range(_flora.size()):
		var plant := _flora[i]
		plant.position.z -= _flora_speeds[i] * delta
		if plant.position.z < -20.0:
			plant.position.z += flora_loop_z

	# Camera: subtle handheld bob.
	if _camera:
		_camera.position.x = CAM_POS.x + sin(_time * 0.6) * 0.04
		_camera.position.y = CAM_POS.y + sin(_time * 2.2) * 0.025
		_camera.position.z = CAM_POS.z
		_camera.look_at(CAM_LOOK + Vector3(
			sin(_time * 0.4) * 0.05, 0.0, 0.0), Vector3.UP)

	# Subtle moon drift — slow, like 5 minutes per lap of the sky.
	if _moon and _moon_light:
		var moon_x: float = 58.0 + sin(_time * 0.020) * 25.0
		_moon.position.x = moon_x
		_moon_light.position = _moon.position
		_moon_light.look_at(Vector3.ZERO, Vector3.UP)

	# Rain cycle disabled along with the overlay/particles — driven by
	# the same _rain_mat / _world_rain checks which are null while
	# disabled, so this block is a no-op.
	if _rain_mat:
		_rain_intensity = move_toward(_rain_intensity, _rain_target,
			delta * 0.5)
		_rain_mat.set_shader_parameter("intensity", _rain_intensity)
		var wiper_ct: float = fmod(_time, 2.6)
		var time_since_wipe: float = (wiper_ct - 1.4) if wiper_ct > 1.4 \
			else 0.0
		_rain_mat.set_shader_parameter("time_since_wipe", time_since_wipe)
	if _world_rain:
		_world_rain.emitting = _rain_intensity > 0.05
		_world_rain.amount_ratio = _rain_intensity

	# Equalizer
	var eq_active := (_current_idx != -1 and not _is_paused
		and _player and _player.playing)
	for i in range(_eq_bars.size()):
		var bar := _eq_bars[i]
		if eq_active:
			var s: float = 0.3 + 0.7 * (0.5 + 0.5 * sin(_time * 9.0
				+ _eq_phases[i]))
			bar.custom_minimum_size.y = 14.0 * s
		else:
			bar.custom_minimum_size.y = 4.0

	_update_progress()

# ═══════════════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if _exiting:
		return
	if event.is_action_pressed("ui_cancel"):
		if _tracklist_modal.visible:
			_close_tracklist()
		else:
			_back_to_title()
	elif event.is_action_pressed("ui_accept"):
		if not _tracklist_modal.visible:
			_toggle_play()

func _back_to_title() -> void:
	_exiting = true
	if _player and _player.playing:
		_player.stop()
	get_tree().change_scene_to_file("res://scenes/title.tscn")
