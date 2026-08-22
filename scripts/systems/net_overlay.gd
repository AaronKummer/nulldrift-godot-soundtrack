extends Node

## NetOverlay — autoload. The deep-hacking node-graph view: the playable
## screen over NetState. You jack into a site, see the net as a tree of
## neon nodes (only the ones you've revealed), and click a node to crack it.
## Cracking a gateway reveals the tier it guards; cracking the prize wins
## the run. TRACE climbs the whole time; let it — or your exposure — top out
## and the sea hag locks on and raids your apartment.
##
## This is the enabler for the remote path: every job that can be done in
## person can, in principle, be done from the deck in your bedroom. Wire a
## site's prize to a story flag (see _apply_site_reward) and that objective
## becomes completable without leaving the apartment.
##
## Usage:  NetOverlay.open("atm_branch")
##         NetOverlay.finished.connect(func(success): ...)

signal finished(success: bool)

const NetState := preload("res://scripts/systems/net_state.gd")
const NetDefs := preload("res://data/net_defs.gd")

# Which prize maps to which story reward. Cracking the prize node banks these
# once. This is the spine of the apartment-only run: as the plot needs a
# remote equivalent for a physical objective, add its site + flag here.
const SITE_REWARDS := {
	"vohl_net": { "flag": "vohlDefeated", "skill": 5,
		"msg": "Vohl's research core is yours. Sublevel containment vented remotely — the thing in there is dead, and so is his project. You never had to set foot in the building." },
	"atm_branch": { "skill": 2,
		"msg": "branch payment processor drained. petty, clean, and nobody's looking for a ghost yet." },
	"corp_office": { "skill": 3,
		"msg": "domain admin secured. you own every machine on ArkLight's net now — reuse it while it's warm." },
	"home_block": { "skill": 1,
		"msg": "your own building's LAN, mapped end to end. good practice. don't be a creep about it." },
}

# yield → short ASCII tag shown on the node face (Aaron's font tofus emoji)
const YIELD_GLYPH := {
	"money": "$", "wifi": "KEY", "cred": "KEY", "master": "ADMIN", "dirt": "DIRT",
	"control": "CTRL", "intel": "INTEL", "power": "GRID", "none": "-",
}

var _layer: CanvasLayer
var _panel: Panel
var _graph: Control          # holds edge Line2Ds + node buttons
var _log: RichTextLabel
var _title_label: Label
var _trace_bar: ProgressBar
var _expo_bar: ProgressBar
var _hag_label: Label
var _money_label: Label
var _jack_btn: Button
var _hint: Label

var _net: RefCounted = null
var _site := ""
var _active := false
var _closing := false
var _pos: Dictionary = {}     # uid -> Vector2 center in graph space
var _log_shown := 0           # how many net.log_lines we've mirrored

const GRAPH_RECT := Rect2(30, 96, 792, 556)
const NODE_SIZE := Vector2(146, 52)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 72
	_layer.visible = false
	add_child(_layer)

	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.02, 0.05, 0.98)
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_title_label.position = Vector2(30, 22)
	_panel.add_child(_title_label)

	var sub := Label.new()
	sub.text = "click a lit node to crack it · gateways reveal what they guard · jack out before the trace finds you"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	sub.position = Vector2(30, 52)
	_panel.add_child(sub)

	# Graph canvas — edges and node buttons get added here on each rebuild.
	_graph = Control.new()
	_graph.position = GRAPH_RECT.position
	_graph.size = GRAPH_RECT.size
	_graph.clip_contents = true
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(0.03, 0.04, 0.08, 1.0)
	gsb.border_color = Color(0.12, 0.3, 0.4)
	gsb.set_border_width_all(1)
	var gp := Panel.new()
	gp.set_anchors_preset(Control.PRESET_FULL_RECT)
	gp.add_theme_stylebox_override("panel", gsb)
	gp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph.add_child(gp)
	_panel.add_child(_graph)

	# Right column: trace / exposure / money + console log.
	var rx := 838.0
	_trace_bar = _make_bar("TRACE", Vector2(rx, 96), Color(1.0, 0.45, 0.2))
	_expo_bar = _make_bar("EXPOSURE", Vector2(rx, 150), Color(0.9, 0.2, 0.9))

	_hag_label = Label.new()
	_hag_label.add_theme_font_size_override("font_size", 13)
	_hag_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_hag_label.position = Vector2(rx, 200)
	_panel.add_child(_hag_label)

	_money_label = Label.new()
	_money_label.add_theme_font_size_override("font_size", 15)
	_money_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	_money_label.position = Vector2(rx, 222)
	_panel.add_child(_money_label)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.position = Vector2(rx, 256)
	_log.size = Vector2(412, 356)
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.add_theme_color_override("default_color", Color(0.55, 0.85, 0.95))
	_panel.add_child(_log)

	_jack_btn = Button.new()
	_jack_btn.text = "JACK OUT"
	_jack_btn.position = Vector2(rx, 624)
	_jack_btn.size = Vector2(412, 44)
	var jsb := StyleBoxFlat.new()
	jsb.bg_color = Color(0.10, 0.06, 0.10)
	jsb.border_color = Color(0.9, 0.3, 0.4)
	jsb.set_border_width_all(2)
	jsb.set_corner_radius_all(4)
	_jack_btn.add_theme_stylebox_override("normal", jsb)
	_jack_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7))
	_jack_btn.pressed.connect(_on_jack_out)
	_panel.add_child(_jack_btn)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.45, 0.55, 0.6))
	_hint.position = Vector2(30, 664)
	_panel.add_child(_hint)

func _make_bar(name: String, pos: Vector2, col: Color) -> ProgressBar:
	var lbl := Label.new()
	lbl.text = name
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	lbl.position = pos
	_panel.add_child(lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.show_percentage = true
	bar.position = pos + Vector2(0, 20)
	bar.size = Vector2(412, 20)
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.09, 0.12)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	_panel.add_child(bar)
	return bar

func is_active() -> bool:
	return _active

func open(site_id: String) -> void:
	if _active:
		return
	_site = site_id
	_net = NetState.new()
	_net.build(site_id, GameState.hack_skill)
	_net.exposure = 0.0
	_active = true
	_closing = false
	_log_shown = 0
	_log.clear()
	var s: Dictionary = NetDefs.site(site_id)
	_title_label.text = "DEEP-HACK · " + str(s.get("name", site_id))
	get_tree().paused = true
	_layer.visible = true
	_sync_log()
	_rebuild_graph()
	_refresh_meters()

func _rebuild_graph() -> void:
	# Wipe previous edges + buttons (keep the background panel at index 0).
	for c in _graph.get_children():
		if c is Button or c is Line2D:
			c.queue_free()
	_pos.clear()

	# Column x by layer depth (stable across reveals); row y by order within
	# the layer among currently-revealed nodes.
	var max_layer := 0
	for n in _net.nodes:
		max_layer = maxi(max_layer, int(n.layer))
	var gw := GRAPH_RECT.size.x
	var gh := GRAPH_RECT.size.y
	var by_layer: Dictionary = {}
	for n in _net.revealed_nodes():
		by_layer.get_or_add(int(n.layer), []).append(n)
	for layer in by_layer:
		var col: Array = by_layer[layer]
		var lx := 40.0 + (float(layer) / maxf(1.0, float(max_layer))) * (gw - NODE_SIZE.x - 80.0)
		for i in col.size():
			var n: Dictionary = col[i]
			var ly := (float(i) + 1.0) / (float(col.size()) + 1.0) * gh
			_pos[n.uid] = Vector2(lx + NODE_SIZE.x * 0.5, ly)

	# Edges first (behind buttons): parent → child, only if both revealed.
	for n in _net.revealed_nodes():
		if not _pos.has(n.parent):
			continue
		var a: Vector2 = _pos[n.parent]
		var b: Vector2 = _pos[n.uid]
		var line := Line2D.new()
		line.points = PackedVector2Array([a, b])
		line.width = 2.0
		var lit: bool = _net.node_by_uid(n.parent).get("cracked", false)
		line.default_color = Color(0.3, 0.7, 0.9, 0.8) if lit else Color(0.2, 0.3, 0.4, 0.5)
		_graph.add_child(line)

	# Node buttons.
	for n in _net.revealed_nodes():
		_graph.add_child(_make_node_button(n))

func _make_node_button(n: Dictionary) -> Button:
	var btn := Button.new()
	btn.size = NODE_SIZE
	btn.position = _pos[n.uid] - NODE_SIZE * 0.5
	var glyph: String = YIELD_GLYPH.get(n.yield, "-")
	var tag := ""
	if n.gateway:
		tag = "  [GATEWAY]"
	elif n.ice:
		tag = "  [ICE]"
	btn.text = "%s\nsec %d · %s%s" % [n.label, n.sec, glyph, tag]
	btn.add_theme_font_size_override("font_size", 12)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD

	var face: Color
	var border: Color
	if n.cracked:
		face = Color(0.05, 0.14, 0.10)
		border = Color(0.3, 0.9, 0.5)
		btn.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
	elif n.ice:
		face = Color(0.16, 0.05, 0.05)
		border = Color(1.0, 0.35, 0.3)
		btn.add_theme_color_override("font_color", Color(1.0, 0.65, 0.6))
	elif n.gateway:
		face = Color(0.06, 0.10, 0.16)
		border = Color(0.5, 0.75, 1.0)
		btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	else:
		face = Color(0.07, 0.08, 0.12)
		border = Color(0.35, 0.55, 0.7)
		btn.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))

	for state in ["normal", "hover", "pressed", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = face if state != "hover" else face.lightened(0.12)
		s.border_color = border if state != "hover" else border.lightened(0.2)
		s.set_border_width_all(2 if not n.cracked else 1)
		s.set_corner_radius_all(5)
		s.content_margin_left = 6
		s.content_margin_right = 6
		btn.add_theme_stylebox_override(state, s)

	if n.cracked or not _net.can_attempt(n.uid):
		btn.disabled = true
	else:
		var uid: int = n.uid
		btn.pressed.connect(func(): _on_node_pressed(uid))
	return btn

func _on_node_pressed(uid: int) -> void:
	if not _active or _closing:
		return
	var res: Dictionary = _net.crack(uid)
	_sync_log()
	if res.get("ice_burn", false):
		_refresh_meters()
		_rebuild_graph()
		_raid("BLACK ICE burned your deck. the trace rode it home.")
		return
	if res.get("win", false) or res.get("ok", false):
		# Prize check → bank the story reward once.
		if _net._prize_cracked():
			_apply_site_reward()
	_rebuild_graph()
	_refresh_meters()

func _apply_site_reward() -> void:
	if not SITE_REWARDS.has(_site):
		return
	var r: Dictionary = SITE_REWARDS[_site]
	if r.has("skill"):
		GameState.raise_hack_skill(int(r.skill))
	if r.has("flag") and not GameState.has_flag(r.flag):
		GameState.set_flag(r.flag)
	if r.has("msg"):
		_log.append_text("[color=#8affd0]>> %s[/color]\n" % r.msg)

func _sync_log() -> void:
	# Sim lines can contain literal brackets ("[+]", "[i]") that would be read
	# as BBCode tags — escape the opening bracket so they render verbatim.
	while _log_shown < _net.log_lines.size():
		var safe := String(_net.log_lines[_log_shown]).replace("[", "[lb]")
		_log.append_text("[color=#7fb8c8]%s[/color]\n" % safe)
		_log_shown += 1

func _refresh_meters() -> void:
	_trace_bar.value = _net.trace
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.4, 0.9, 0.4) if _net.trace < 50 else \
		(Color(1.0, 0.75, 0.2) if _net.trace < 80 else Color(1.0, 0.3, 0.2))
	_trace_bar.add_theme_stylebox_override("fill", fill)
	_expo_bar.value = GameState.exposure + _net.exposure
	_money_label.text = "exfiltrated: %d cr" % _net.money_taken
	var hag: float = (GameState.exposure + _net.exposure) + float(_net.money_taken) / 2000.0 + _net.site_heat * 20.0
	if hag >= 70.0:
		_hag_label.text = "⚠ the sea hag is close. bank it and bail."
	elif hag >= 40.0:
		_hag_label.text = "something big just turned toward your signal."
	else:
		_hag_label.text = ""
	if _net._prize_cracked():
		_hint.text = "prize secured. JACK OUT to bank it — the trace won't stop climbing."
	else:
		_hint.text = "crack the marked prize, then jack out. or grab what you can and run."

func _process(delta: float) -> void:
	if not _active or _closing:
		return
	var hag: bool = _net.tick(delta)
	_refresh_meters()
	if hag:
		_raid("the sea hag locked onto your signal. she's coming for the apartment.")
		return
	if _net.trace >= 100.0 and not _net.done:
		# trace maxed but not yet fatal — exposure is spiking; warn hard
		_hag_label.text = "!! TRACE MAXED — exposure climbing every second you stay"

func _raid(reason: String) -> void:
	_closing = true
	_log.append_text("[color=#ff5040]>>> %s[/color]\n" % reason)
	_net.settle()
	get_tree().create_timer(2.0).timeout.connect(func(): _close(false))

func _on_jack_out() -> void:
	if not _active or _closing:
		return
	_closing = true
	var won: bool = _net._prize_cracked()
	_net.settle()
	if won:
		_log.append_text("[color=#8affd0]>>> clean disconnect. prize banked.[/color]\n")
	elif _net.money_taken > 0:
		_log.append_text("[color=#9fe870]>>> disconnected. %d cr banked, prize left on the table.[/color]\n" % _net.money_taken)
	else:
		_log.append_text("[color=#7f9aa8]>>> disconnected. nothing to show for it.[/color]\n")
	get_tree().create_timer(1.0).timeout.connect(func(): _close(won))

func _close(success: bool) -> void:
	_active = false
	_layer.visible = false
	get_tree().paused = false
	finished.emit(success)
