## ListMenu — reusable selection overlay. Up/down (arrows or W/S) moves the
## cursor, ENTER or E confirms, ESC leaves. Replaces the old number-key menus.
##
##   var menu := ListMenuScript.new()
##   add_child(menu)
##   menu.picked.connect(func(idx): ...)
##   menu.closed.connect(func(): ...)
##   menu.open("RIDENET · where to?", entries, accent, footer)
##
## entries: [{ "label": String, "dim": bool }] — dim rows render grey but
## stay selectable so the caller can bark at the player ("you are here").
## refresh()/set_footer() update in place, keeping the cursor.
extends CanvasLayer

signal picked(idx: int)
signal closed

const ROW_H := 42
const PANEL_W := 560.0

var _entries: Array = []
var _footer_text := ""
var _idx := 0
var _accent := Color(0.2, 1.0, 1.2)
var _labels: Array = []
var _footer_label: Label
var _panel: Panel
var _armed := false

func open(title_text: String, entries: Array, accent := Color(0.2, 1.0, 1.2),
		footer := "") -> void:
	layer = 70
	_entries = entries
	_footer_text = footer
	_accent = accent
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel_h := 96.0 + entries.size() * ROW_H + 74.0
	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -PANEL_W / 2.0
	_panel.offset_right = PANEL_W / 2.0
	_panel.offset_top = -panel_h / 2.0
	_panel.offset_bottom = panel_h / 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.04, 0.96)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.shadow_color = Color(accent.r, accent.g, accent.b, 0.25)
	sb.shadow_size = 14
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", accent)
	title.position = Vector2(26, 18)
	_panel.add_child(title)
	for i in entries.size():
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 20)
		l.position = Vector2(26, 74 + i * ROW_H)
		_panel.add_child(l)
		_labels.append(l)
	_footer_label = Label.new()
	_footer_label.add_theme_font_size_override("font_size", 17)
	_footer_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55))
	_footer_label.position = Vector2(26, 82 + entries.size() * ROW_H)
	_footer_label.size = Vector2(PANEL_W - 52, 24)
	_panel.add_child(_footer_label)
	var hint := Label.new()
	hint.text = "W/S · arrows to choose · ENTER or E to confirm · ESC to leave"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.58, 0.62))
	hint.position = Vector2(26, 110 + entries.size() * ROW_H)
	_panel.add_child(hint)
	# Start on the first non-dim row
	_idx = 0
	for i in entries.size():
		if not entries[i].get("dim", false):
			_idx = i
			break
	_render()
	# The E press that opened the menu must not also confirm row 0
	_armed = false
	get_tree().create_timer(0.15).timeout.connect(func(): _armed = true)

func refresh(entries: Array, footer := "") -> void:
	_entries = entries
	_footer_text = footer
	_idx = clampi(_idx, 0, entries.size() - 1)
	_render()

func set_footer(t: String) -> void:
	_footer_text = t
	if _footer_label:
		_footer_label.text = t

func close_menu() -> void:
	closed.emit()
	queue_free()

func _render() -> void:
	for i in _labels.size():
		var l: Label = _labels[i]
		if i >= _entries.size():
			l.text = ""
			continue
		var e: Dictionary = _entries[i]
		var sel := i == _idx
		l.text = ("▸ " if sel else "   ") + e.get("label", "")
		if e.get("dim", false):
			l.add_theme_color_override("font_color",
				Color(0.55, 0.6, 0.65) if sel else Color(0.38, 0.42, 0.48))
		elif sel:
			l.add_theme_color_override("font_color", _accent * 1.1)
		else:
			l.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	if _footer_label:
		_footer_label.text = _footer_text

func _move(dir: int) -> void:
	if _entries.is_empty():
		return
	_idx = (_idx + dir + _entries.size()) % _entries.size()
	_render()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()
		return
	if not _armed:
		return
	if event.is_action_pressed("ui_up", true) or event.is_action_pressed("move_up", true):
		_move(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down", true) or event.is_action_pressed("move_down", true):
		_move(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		picked.emit(_idx)
