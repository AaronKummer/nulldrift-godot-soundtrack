## PuzzleOverlay — reusable locking/unlocking minipuzzles, mouse-driven.
##
## Three kinds, one API. Anything in the game that locks — grates, chests,
## doors, terminals — instantiates this and listens for the result:
##
##   "pipes"    physical valve — CLICK tiles to rotate pipe segments until
##              the flow connects the inlet to the outlet
##   "lockpick" physical lock — DRAG each pin up to the shear line until
##              every pin sets
##   "wires"    electronic lock — DRAG each colored lead to the socket of
##              the same color
##
## Usage:
##   var puzzle := PuzzleOverlayScript.new()
##   add_child(puzzle)
##   puzzle.start("pipes", "SEAL THE GRATE")
##   puzzle.solved.connect(func(): ...)
##   puzzle.cancelled.connect(func(reason): ...)
##   puzzle.interrupt("they got to you!")   # e.g. on taking damage
##
## The caller is responsible for freezing its player while `active`.
extends CanvasLayer

signal solved
signal cancelled(reason: String)

var active := false

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # N E S W

# pipes
const P_COLS := 4
const P_ROWS := 3
const P_TILE := 96.0
# lockpick
const PIN_COUNT := 5
const PIN_TOLERANCE := 0.045
# wires
const WIRE_COLORS := [
	Color(1.6, 0.25, 0.35), Color(0.2, 1.5, 1.6),
	Color(1.6, 1.3, 0.2), Color(0.5, 1.6, 0.5),
]

var _kind := ""
var _title := ""
var _panel: Control
var _state := {}

func start(kind: String, title: String) -> void:
	_kind = kind
	_title = title
	active = true
	layer = 80
	if _panel == null:
		_panel = _Panel.new()
		_panel.overlay = self
		add_child(_panel)
	_panel.visible = true
	match kind:
		"pipes": _init_pipes()
		"lockpick": _init_lockpick()
		"wires": _init_wires()

func interrupt(reason: String) -> void:
	if active:
		_close()
		cancelled.emit(reason)

func _close() -> void:
	active = false
	if _panel:
		_panel.visible = false

func _finish() -> void:
	_close()
	solved.emit()

class _Panel extends Control:
	var overlay
	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _process(_d: float) -> void:
		if overlay.active:
			queue_redraw()
	func _draw() -> void:
		if overlay.active:
			overlay._draw_panel(self)
	func _gui_input(event: InputEvent) -> void:
		if overlay.active:
			overlay._input_panel(event)
			accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("ui_cancel"):
		_close()
		cancelled.emit("backed off.")
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════
# COMMON DRAW
# ═══════════════════════════════════════════════════════════════════════

func _panel_rect() -> Rect2:
	return Rect2(Vector2(340, 150), Vector2(600, 420))

func _draw_frame(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0, 0, 0, 0.55), true)
	var r := _panel_rect()
	c.draw_rect(r, Color(0.010, 0.030, 0.040, 0.96), true)
	c.draw_rect(r, Color(0.0, 0.9, 1.0), false, 2.0)
	c.draw_string(ThemeDB.fallback_font, r.position + Vector2(20, 34),
		_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.3, 1.0, 0.9))
	c.draw_string(ThemeDB.fallback_font, r.position + Vector2(20, r.size.y - 14),
		"ESC to back off", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.45, 0.5, 0.6))

func _draw_panel(c: Control) -> void:
	_draw_frame(c)
	match _kind:
		"pipes": _draw_pipes(c)
		"lockpick": _draw_lockpick(c)
		"wires": _draw_wires(c)

func _input_panel(event: InputEvent) -> void:
	match _kind:
		"pipes": _input_pipes(event)
		"lockpick": _input_lockpick(event)
		"wires": _input_wires(event)


# ═══════════════════════════════════════════════════════════════════════
# PIPES — click to rotate, connect inlet to outlet
# ═══════════════════════════════════════════════════════════════════════

func _init_pipes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var r_in := rng.randi_range(0, P_ROWS - 1)
	var r_out := rng.randi_range(0, P_ROWS - 1)
	# Column row-targets carve a guaranteed solvable path
	var rows: Array = [r_in]
	for cidx in range(1, P_COLS):
		rows.append(rng.randi_range(0, P_ROWS - 1))
	rows[P_COLS - 1] = r_out
	var tiles: Array = []
	for i in P_COLS * P_ROWS:
		tiles.append({ "type": "straight" if rng.randf() < 0.5 else "elbow",
			"rot": rng.randi_range(0, 3), "path": false })
	for cidx in P_COLS:
		var from_row: int = rows[cidx - 1] if cidx > 0 else r_in
		var to_row: int = rows[cidx]
		var step: int = 1 if to_row > from_row else -1
		var rr := from_row
		while true:
			var t: Dictionary = tiles[rr * P_COLS + cidx]
			t.path = true
			var conns: Array = []
			# west side: entry from the left (or inlet)
			if rr == from_row:
				conns.append(3)
			else:
				conns.append(0 if step > 0 else 2)
			# exit: east if we're at the target row, else continue vertical
			if rr == to_row:
				conns.append(1)
			else:
				conns.append(2 if step > 0 else 0)
			_assign_pipe(t, conns, rng)
			if rr == to_row:
				break
			rr += step
	_state = { "tiles": tiles, "r_in": r_in, "r_out": r_out }
	_flow_pipes()

func _assign_pipe(t: Dictionary, conns: Array, rng: RandomNumberGenerator) -> void:
	var a: int = conns[0]
	var b: int = conns[1]
	if (a + 2) % 4 == b:
		t.type = "straight"
		t.correct = 0 if a % 2 == 0 else 1
	else:
		t.type = "elbow"
		for r in 4:
			var set_r: Array = [(0 + r) % 4, (1 + r) % 4]
			if conns[0] in set_r and conns[1] in set_r:
				t.correct = r
				break
	# scramble
	t.rot = rng.randi_range(0, 3)

func _pipe_conns(t: Dictionary) -> Array:
	if t.type == "straight":
		return [(0 + t.rot) % 4, (2 + t.rot) % 4]
	return [(0 + t.rot) % 4, (1 + t.rot) % 4]

func _flow_pipes() -> void:
	var tiles: Array = _state.tiles
	for t in tiles:
		t.flow = false
	# BFS from the inlet
	var queue: Array = []
	var start: Dictionary = tiles[_state.r_in * P_COLS + 0]
	if 3 in _pipe_conns(start):
		start.flow = true
		queue.append(Vector2i(0, _state.r_in))
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		var t: Dictionary = tiles[cell.y * P_COLS + cell.x]
		for d in _pipe_conns(t):
			var n: Vector2i = cell + DIRS[d]
			if n.x < 0 or n.x >= P_COLS or n.y < 0 or n.y >= P_ROWS:
				continue
			var nt: Dictionary = tiles[n.y * P_COLS + n.x]
			if nt.flow:
				continue
			if ((d + 2) % 4) in _pipe_conns(nt):
				nt.flow = true
				queue.append(n)
	# Solved when the outlet tile flows out its east side
	var out: Dictionary = tiles[_state.r_out * P_COLS + (P_COLS - 1)]
	if out.flow and 1 in _pipe_conns(out):
		_finish()

func _pipes_origin() -> Vector2:
	var r := _panel_rect()
	return r.position + Vector2((r.size.x - P_COLS * P_TILE) * 0.5, 60.0)

func _input_pipes(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = event.position - _pipes_origin()
		var cx := int(local.x / P_TILE)
		var cy := int(local.y / P_TILE)
		if cx >= 0 and cx < P_COLS and cy >= 0 and cy < P_ROWS \
				and local.x >= 0 and local.y >= 0:
			var t: Dictionary = _state.tiles[cy * P_COLS + cx]
			t.rot = (t.rot + 1) % 4
			_flow_pipes()

func _draw_pipes(c: Control) -> void:
	var org := _pipes_origin()
	for cy in P_ROWS:
		for cx in P_COLS:
			var t: Dictionary = _state.tiles[cy * P_COLS + cx]
			var cell_org: Vector2 = org + Vector2(cx * P_TILE, cy * P_TILE)
			var center: Vector2 = cell_org + Vector2(P_TILE, P_TILE) * 0.5
			c.draw_rect(Rect2(cell_org + Vector2(3, 3),
				Vector2(P_TILE - 6, P_TILE - 6)), Color(0.03, 0.06, 0.08), true)
			var col := Color(0.30, 1.5, 0.7) if t.flow else Color(0.30, 0.36, 0.45)
			for d in _pipe_conns(t):
				var edge: Vector2 = center + Vector2(DIRS[d]) * (P_TILE * 0.5 - 4.0)
				c.draw_line(center, edge, col, 14.0)
			c.draw_circle(center, 10.0, col * 1.1)
	# Inlet + outlet markers
	var in_c: Vector2 = org + Vector2(-24, _state.r_in * P_TILE + P_TILE * 0.5)
	c.draw_circle(in_c, 11.0, Color(0.30, 1.5, 0.7))
	c.draw_string(ThemeDB.fallback_font, in_c + Vector2(-14, 30), "IN",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 1.0, 0.7))
	var out_c: Vector2 = org + Vector2(P_COLS * P_TILE + 24, _state.r_out * P_TILE + P_TILE * 0.5)
	c.draw_circle(out_c, 11.0, Color(1.5, 0.5, 0.2))
	c.draw_string(ThemeDB.fallback_font, out_c + Vector2(-18, 30), "OUT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.6, 0.3))


# ═══════════════════════════════════════════════════════════════════════
# LOCKPICK — drag pins to the shear line
# ═══════════════════════════════════════════════════════════════════════

func _init_lockpick() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pins: Array = []
	for i in PIN_COUNT:
		pins.append({ "y": 0.95, "target": rng.randf_range(0.25, 0.75), "set": false })
	_state = { "pins": pins, "drag": -1 }

func _lock_geom() -> Dictionary:
	var r := _panel_rect()
	return { "x0": r.position.x + 90.0, "spacing": 105.0,
		"top": r.position.y + 70.0, "h": 270.0 }

func _input_lockpick(event: InputEvent) -> void:
	var g := _lock_geom()
	var pins: Array = _state.pins
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for i in PIN_COUNT:
				if pins[i].set:
					continue
				var px: float = g.x0 + i * g.spacing
				var py: float = g.top + pins[i].y * g.h
				if Rect2(px - 26, py - 34, 52, 60).has_point(event.position):
					_state.drag = i
					break
		else:
			# Release: does the pin set?
			var di: int = _state.drag
			if di >= 0:
				var pin: Dictionary = pins[di]
				if absf(pin.y - pin.target) < PIN_TOLERANCE:
					pin.set = true
					pin.y = pin.target
					var all_set := true
					for pp in pins:
						if not pp.set:
							all_set = false
							break
					if all_set:
						_finish()
				# a loose pin sags back a little
				elif pin.y < 0.9:
					pin.y = minf(0.95, pin.y + 0.12)
			_state.drag = -1
	elif event is InputEventMouseMotion and _state.drag >= 0:
		var pin: Dictionary = pins[_state.drag]
		pin.y = clampf((event.position.y - g.top) / g.h, 0.05, 0.95)

func _draw_lockpick(c: Control) -> void:
	var g := _lock_geom()
	var pins: Array = _state.pins
	for i in PIN_COUNT:
		var px: float = g.x0 + i * g.spacing
		# Channel
		c.draw_rect(Rect2(px - 14, g.top - 10, 28, g.h + 40), Color(0.05, 0.08, 0.10), true)
		# Shear mark — faint scratch at the sweet spot
		var ty: float = g.top + pins[i].target * g.h
		c.draw_rect(Rect2(px - 20, ty - 2, 40, 4), Color(1.4, 1.1, 0.3, 0.5), true)
		# Pin body
		var py: float = g.top + pins[i].y * g.h
		var col := Color(0.3, 1.5, 0.7) if pins[i].set else \
			(Color(1.2, 1.2, 1.4) if _state.drag == i else Color(0.55, 0.60, 0.72))
		c.draw_rect(Rect2(px - 12, py - 30, 24, 52), col, true)
		c.draw_rect(Rect2(px - 12, py - 30, 24, 8), col * 1.3, true)
	c.draw_string(ThemeDB.fallback_font,
		_panel_rect().position + Vector2(20, _panel_rect().size.y - 36),
		"drag each pin to the scratch mark", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.6, 0.65, 0.75))


# ═══════════════════════════════════════════════════════════════════════
# WIRES — drag colored leads to matching sockets
# ═══════════════════════════════════════════════════════════════════════

func _init_wires() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var order_l: Array = [0, 1, 2, 3]
	var order_r: Array = [0, 1, 2, 3]
	for arr in [order_l, order_r]:
		for i in range(3, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = arr[i]
			arr[i] = arr[j]
			arr[j] = tmp
	_state = { "left": order_l, "right": order_r,
		"linked": [false, false, false, false], "drag": -1, "mouse": Vector2.ZERO }

func _wire_pos(side: String, slot: int) -> Vector2:
	var r := _panel_rect()
	var x: float = r.position.x + (70.0 if side == "left" else r.size.x - 70.0)
	return Vector2(x, r.position.y + 90.0 + slot * 78.0)

func _input_wires(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_state.mouse = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for slot in 4:
				var color_id: int = _state.left[slot]
				if not _state.linked[color_id] \
						and _wire_pos("left", slot).distance_to(event.position) < 30.0:
					_state.drag = slot
					_state.mouse = event.position
					break
		else:
			var di: int = _state.drag
			if di >= 0:
				var color_id: int = _state.left[di]
				for slot in 4:
					if _wire_pos("right", slot).distance_to(event.position) < 30.0:
						if _state.right[slot] == color_id:
							_state.linked[color_id] = true
							var all_done := true
							for l in _state.linked:
								if not l:
									all_done = false
									break
							if all_done:
								_finish()
						break
			_state.drag = -1

func _draw_wires(c: Control) -> void:
	# Established links
	for slot in 4:
		var color_id: int = _state.left[slot]
		if _state.linked[color_id]:
			var to_slot := 0
			for rs in 4:
				if _state.right[rs] == color_id:
					to_slot = rs
					break
			c.draw_line(_wire_pos("left", slot), _wire_pos("right", to_slot),
				WIRE_COLORS[color_id], 6.0)
	# Active drag
	if _state.drag >= 0:
		c.draw_line(_wire_pos("left", _state.drag), _state.mouse,
			WIRE_COLORS[_state.left[_state.drag]], 6.0)
	# Jacks + sockets
	for slot in 4:
		var lc: int = _state.left[slot]
		var lp := _wire_pos("left", slot)
		c.draw_circle(lp, 16.0, WIRE_COLORS[lc])
		c.draw_circle(lp, 7.0, Color(0.02, 0.03, 0.04))
		var rc: int = _state.right[slot]
		var rp := _wire_pos("right", slot)
		c.draw_circle(rp, 18.0, Color(0.08, 0.10, 0.13))
		c.draw_arc(rp, 15.0, 0, TAU, 24, WIRE_COLORS[rc], 4.0)
		if _state.linked[rc]:
			c.draw_circle(rp, 8.0, WIRE_COLORS[rc])
	c.draw_string(ThemeDB.fallback_font,
		_panel_rect().position + Vector2(20, _panel_rect().size.y - 36),
		"drag each lead to its matching socket", HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
		Color(0.6, 0.65, 0.75))
