## AnimatedBillboard — a Node3D that wraps a Sprite3D with 4-direction walk
## animations driven by a 144×256 spritesheet (3 cols × 4 rows, 48×64 frames).
##
## Row layout (matches hacking-game/src/phaser/scenes/BootScene.js):
##   row 0 = walk DOWN   (facing camera / +z)
##   row 1 = walk LEFT
##   row 2 = walk RIGHT
##   row 3 = walk UP     (facing away / -z)
##
## API:
##   var npc := AnimatedBillboard.new()
##   npc.load_sheet("res://assets/sprites/blackCat.png")
##   npc.pixel_size = 0.04
##   add_child(npc)
##   # each frame:
##   npc.update_facing_from_input(input_vec)   # input.x = D-A, input.y = S-W
##   npc.set_moving(input_vec.length() > 0.1)
class_name AnimatedBillboard
extends Node3D

## Cell size auto-detects from the sheet on `load_sheet()` assuming a 3×4
## grid layout. Defaults match the legacy 48×64 cats until a sheet loads.
var FRAME_W: int = 48
var FRAME_H: int = 64
const COLS := 3
const FPS := 8.0

enum Facing { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

var pixel_size: float = 0.04 : set = _set_pixel_size
var facing: int = Facing.DOWN
var moving: bool = false
## Set false for scenes with a shallow camera angle (3/4 view ~28° pitch).
## At low angles the flat-floor shadow sprite projects as a vertical ghost
## column rather than a shadow. Iso 45° scenes (apartment) keep it true.
var show_floor_shadow: bool = true

var _sprite: Sprite3D
var _atlas: AtlasTexture
var _tex: Texture2D
var _frame := 0
var _t := 0.0
var _shadow: Sprite3D       # flat silhouette on the floor — animated walk cycle
var _shadow_blob: MeshInstance3D  # tiny soft oval glued to the feet

func _ready() -> void:
	# Two-part ground shadow:
	#  1. _shadow_blob — small dark oval right at the feet so the contact
	#     point is always anchored regardless of light direction
	#  2. _shadow — a copy of the character laid flat on the floor that
	#     stretches behind them (away from camera). Same AtlasTexture as
	#     the upright sprite so it animates with the walk cycle.
	# This gives a "real" character-shaped shadow rather than a fake blob,
	# and it tracks the walk frame the player sees.

	_shadow_blob = MeshInstance3D.new()
	var disc := PlaneMesh.new()
	var w: float = FRAME_W * pixel_size * 0.55
	disc.size = Vector2(w, w * 0.5)
	var blob_mat := StandardMaterial3D.new()
	blob_mat.albedo_color = Color(0, 0, 0, 0.45)
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc.material = blob_mat
	_shadow_blob.mesh = disc
	_shadow_blob.position = Vector3(0, 0.012, 0)
	_shadow_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow_blob.visible = show_floor_shadow
	add_child(_shadow_blob)

	_shadow = Sprite3D.new()
	_shadow.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_shadow.pixel_size = pixel_size
	_shadow.shaded = false
	_shadow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.modulate = Color(0, 0, 0, 0.55)
	# Lay flat on the floor, feet at parent origin, head extending away
	# from camera (-z). Iso camera is at (+x, +y, +z) so "away" = -z, -x.
	_shadow.rotation_degrees = Vector3(-90, 45, 0)
	# Compress along the shadow-length axis so it looks more like a real
	# cast shadow (foreshortened) than a person-shaped sticker.
	_shadow.scale = Vector3(1.0, 0.65, 1.0)
	# Offset back so feet sit at parent origin after the flat rotation.
	# The half-height projects along (-x,-z)/√2 after the 45° yaw.
	var off: float = FRAME_H * pixel_size * 0.5
	_shadow.position = Vector3(-off * 0.5, 0.02, -off * 0.5)
	_shadow.visible = show_floor_shadow
	add_child(_shadow)

	_sprite = Sprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.pixel_size = pixel_size
	_sprite.shaded = false
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Lift the sprite so its feet sit at the parent's origin
	_sprite.position = Vector3(0, FRAME_H * pixel_size * 0.5, 0)
	add_child(_sprite)
	if _tex:
		_apply_texture()

func load_sheet(path: String) -> void:
	_tex = load(path) as Texture2D
	if _tex:
		FRAME_W = _tex.get_width() / COLS
		FRAME_H = _tex.get_height() / 4
		# Re-anchor sprites & shadow blob to the new cell size
		if _sprite:
			_sprite.position = Vector3(0, FRAME_H * pixel_size * 0.5, 0)
		if _shadow:
			var off: float = FRAME_H * pixel_size * 0.5
			_shadow.position = Vector3(-off * 0.5, 0.02, -off * 0.5)
		if _shadow_blob and _shadow_blob.mesh is PlaneMesh:
			var w: float = FRAME_W * pixel_size * 0.55
			(_shadow_blob.mesh as PlaneMesh).size = Vector2(w, w * 0.5)
	if _sprite:
		_apply_texture()

func _apply_texture() -> void:
	if _tex == null:
		return
	_atlas = AtlasTexture.new()
	_atlas.atlas = _tex
	_atlas.region = Rect2(0, 0, FRAME_W, FRAME_H)
	_sprite.texture = _atlas
	if _shadow:
		# Same atlas resource — region updates flow to both sprites
		_shadow.texture = _atlas

func _set_pixel_size(v: float) -> void:
	pixel_size = v
	if _sprite:
		_sprite.pixel_size = v
		_sprite.position = Vector3(0, FRAME_H * v * 0.5, 0)
	if _shadow:
		_shadow.pixel_size = v
		var off: float = FRAME_H * v * 0.5
		_shadow.position = Vector3(-off * 0.5, 0.02, -off * 0.5)
	if _shadow_blob and _shadow_blob.mesh is PlaneMesh:
		var w: float = FRAME_W * v * 0.55
		(_shadow_blob.mesh as PlaneMesh).size = Vector2(w, w * 0.5)

func _process(delta: float) -> void:
	if not moving:
		_frame = 0
		_t = 0.0
		_update_region()
		return
	_t += delta
	var step := 1.0 / FPS
	while _t >= step:
		_t -= step
		_frame = (_frame + 1) % COLS
	_update_region()

func _update_region() -> void:
	if _atlas == null:
		return
	_atlas.region = Rect2(_frame * FRAME_W, facing * FRAME_H, FRAME_W, FRAME_H)

## Update facing from a screen-space input vector.
## input.x = D - A, input.y = S - W
func update_facing_from_input(input: Vector2) -> void:
	if input.length_squared() < 0.01:
		return
	# Horizontal wins when its component is at least as large as vertical
	if absf(input.x) >= absf(input.y):
		facing = Facing.RIGHT if input.x > 0.0 else Facing.LEFT
	else:
		facing = Facing.DOWN if input.y > 0.0 else Facing.UP

func set_moving(v: bool) -> void:
	moving = v
