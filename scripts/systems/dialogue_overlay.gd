extends Node

## DialogueOverlay — autoload. Global dialog box. Any scene calls
##   DialogueOverlay.play("nyx")
## and the overlay shows the right branch of Dialogue.TREES based on
## current GameState flags + active quest. Player presses interact/accept
## to advance lines. Emits `finished` when done.
##
## Mirrors hacking-game/src/phaser/DialogueUI.js + dialogueTrees consumption.

signal finished(npc_id: String)

var _layer: CanvasLayer
var _panel: Panel
var _speaker_label: Label
var _text_label: Label
var _hint_label: Label
var _lines: Array = []
var _idx := -1
var _active := false
var _npc_id := ""

func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	_layer.visible = false
	add_child(_layer)

	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -400
	_panel.offset_right = 400
	_panel.offset_top = -210
	_panel.offset_bottom = -30
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0.04, 0.06, 0.92)
	style.border_color = Color(0, 1, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0, 1, 1, 0.35)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)
	_layer.add_child(_panel)

	_speaker_label = Label.new()
	_speaker_label.add_theme_font_size_override("font_size", 18)
	_speaker_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_speaker_label.add_theme_constant_override("outline_size", 4)
	_speaker_label.position = Vector2(20, 14)
	_speaker_label.size = Vector2(760, 24)
	_panel.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 20)
	_text_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.95))
	_text_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_text_label.add_theme_constant_override("outline_size", 4)
	_text_label.position = Vector2(20, 52)
	_text_label.size = Vector2(760, 100)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_text_label)

	_hint_label = Label.new()
	_hint_label.text = "[E] CONTINUE"
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.27, 0.67, 0.67))
	_hint_label.position = Vector2(680, 154)
	_panel.add_child(_hint_label)

	process_mode = Node.PROCESS_MODE_ALWAYS

func play(npc_id: String) -> void:
	var lines := Dialogue.resolve(npc_id, GameState.flags, GameState.active_quest,
		GameState.quest_states.get(GameState.active_quest, ""))
	if lines.is_empty():
		return
	_lines = lines
	_idx = -1
	_npc_id = npc_id
	_active = true
	_layer.visible = true
	_advance()

func is_active() -> bool:
	return _active

func _advance() -> void:
	_idx += 1
	if _idx >= _lines.size():
		_close()
		return
	var line: Dictionary = _lines[_idx]
	_speaker_label.text = line.get("speaker", "")
	_speaker_label.add_theme_color_override("font_color",
		line.get("color", Color(1, 1, 1)))
	_text_label.text = line.get("text", "")

func _close() -> void:
	_active = false
	_layer.visible = false
	_lines = []
	finished.emit(_npc_id)
	_npc_id = ""

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
