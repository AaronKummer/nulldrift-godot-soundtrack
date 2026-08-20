## GlobalHUD — autoload. ONE hud everywhere (port of the Phaser
## UniversalHUD idea): hearts + credits top-left, the 6-slot hotbar
## top-center. Scenes stop hand-rolling these. Hidden in minigames and
## on the title screen (they own their whole frame).
##
## Hotbar keys 1-6 work globally: if the current scene defines _use_slot
## (the dungeon does — grenades need enemies), it handles them; otherwise
## this uses items directly (medkit heals anywhere).
extends CanvasLayer

const MEDKIT_HEAL := 35

var _hearts: Array = []
var _credits_label: Label
var _slots: Array = []
var _toast: Label
var _toast_tw: Tween

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	# HEALTH + hearts (the home street's original look, now global)
	var hp_l := Label.new()
	hp_l.text = "HEALTH"
	hp_l.add_theme_font_size_override("font_size", 11)
	hp_l.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	hp_l.position = Vector2(20, 8)
	add_child(hp_l)
	for i in 5:
		var heart := Label.new()
		heart.text = "♥"
		heart.add_theme_font_size_override("font_size", 18)
		heart.position = Vector2(82 + i * 22, 6)
		add_child(heart)
		_hearts.append(heart)
	var cr_l := Label.new()
	cr_l.text = "CREDITS"
	cr_l.add_theme_font_size_override("font_size", 11)
	cr_l.add_theme_color_override("font_color", Color(0.55, 0.6, 0.75))
	cr_l.position = Vector2(20, 42)
	add_child(cr_l)
	_credits_label = Label.new()
	_credits_label.add_theme_font_size_override("font_size", 14)
	_credits_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	_credits_label.position = Vector2(82, 39)
	add_child(_credits_label)
	# Hotbar — six slots, top-center
	for i in 6:
		var box := Panel.new()
		box.position = Vector2(742 + i * 46, 4)
		box.size = Vector2(42, 34)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.04, 0.07, 0.85)
		sb.border_color = Color(0.25, 0.3, 0.4)
		sb.set_border_width_all(1)
		box.add_theme_stylebox_override("panel", sb)
		add_child(box)
		var num := Label.new()
		num.text = str(i + 1)
		num.add_theme_font_size_override("font_size", 9)
		num.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
		num.position = Vector2(3, 0)
		box.add_child(num)
		var glyph := Label.new()
		glyph.add_theme_font_size_override("font_size", 12)
		glyph.position = Vector2(9, 10)
		box.add_child(glyph)
		var cnt := Label.new()
		cnt.add_theme_font_size_override("font_size", 10)
		cnt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		cnt.position = Vector2(24, 20)
		box.add_child(cnt)
		_slots.append({ "glyph": glyph, "cnt": cnt })
	# Toast line under the hotbar for item feedback
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 13)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	_toast.position = Vector2(742, 42)
	_toast.modulate.a = 0.0
	add_child(_toast)
	GameState.credits_changed.connect(func(n): _credits_label.text = "$%d" % n)
	var t := Timer.new()
	t.wait_time = 0.35
	t.autostart = true
	t.timeout.connect(_refresh)
	add_child(t)
	_refresh()

func _refresh() -> void:
	# Hide inside minigames / title / capture harness — they own the frame
	var scene := get_tree().current_scene
	var path: String = scene.scene_file_path if scene else ""
	visible = not (path.contains("/minigames/") or path.contains("title")
		or path.contains("_capture") or path.contains("_phone_probe"))
	if not visible:
		return
	var frac: float = float(GameState.hp) / maxf(1.0, float(GameState.hp_max))
	var lit: int = int(ceil(frac * 5.0))
	for i in 5:
		_hearts[i].add_theme_color_override("font_color",
			Color(1.0, 0.20, 0.45) if i < lit else Color(0.25, 0.12, 0.18))
	_credits_label.text = "$%d" % GameState.credits
	for i in 6:
		var sd: Dictionary = _slots[i]
		var id: String = GameState.hotbar.get(str(i + 1), "")
		if id == "":
			sd.glyph.text = ""
			sd.cnt.text = ""
		else:
			sd.glyph.text = GameState.HOTBAR_GLYPHS.get(id, id.left(3).to_upper())
			var n: int = GameState.count_item(id)
			sd.cnt.text = "x%d" % n
			sd.glyph.add_theme_color_override("font_color",
				Color(0.9, 1.0, 1.0) if n > 0 else Color(0.4, 0.45, 0.5))

func _unhandled_input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	var scene := get_tree().current_scene
	if scene and scene.has_method("_use_slot"):
		return   # the dungeon handles its own hotbar (grenades, stims)
	for i in range(1, 7):
		if event.is_action_pressed("hotbar_%d" % i):
			_use_slot_global(i)
			get_viewport().set_input_as_handled()
			return

func _use_slot_global(slot: int) -> void:
	var id: String = GameState.hotbar.get(str(slot), "")
	if id == "":
		_show_toast("slot %d empty · assign in phone GEAR" % slot)
		return
	if GameState.count_item(id) <= 0:
		_show_toast("no %s left" % id)
		return
	match id:
		"medkit":
			if GameState.hp >= GameState.hp_max:
				_show_toast("already at full health")
				return
			GameState.inventory.erase("medkit")
			GameState.hp = mini(GameState.hp_max, GameState.hp + MEDKIT_HEAL)
			_show_toast("medkit used · +%d HP" % MEDKIT_HEAL)
		_:
			_show_toast("save it for the underground")
	_refresh()

func _show_toast(t: String) -> void:
	_toast.text = t
	if _toast_tw:
		_toast_tw.kill()
	_toast.modulate.a = 1.0
	_toast_tw = create_tween()
	_toast_tw.tween_interval(1.6)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
