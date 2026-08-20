## LUCKY CHROME CASINO — downtown's money pit. Port of the Phaser
## CasinoScene: three playable games (SLOTS, BLACKJACK, HIGH-LOW), all
## run through the shared list menu. The house edge is real. So is the
## pit boss watching you win.
extends "res://scripts/interiors/interior_base.gd"

const ListMenuScript := preload("res://scripts/systems/list_menu.gd")

const SLOT_BET := 50
const BJ_BET := 100
const HL_BET := 50
const SLOT_SYMBOLS := ["7", "◆", "●", "★"]

var _menu
var _bj := {}          # blackjack hand state
var _hl_card := 0
var _hl_streak := 0

func _ready() -> void:
	room_w = 32.0
	room_d = 22.0
	interior_name = "LUCKY CHROME"
	exit_scene = "street_downtown"
	exit_spawn = "from_casino"
	super._ready()
	Music.play_category("city")

func _ambient() -> Color:
	return Color(0.30, 0.22, 0.14)

func _wall_color() -> Color:
	return Color(0.14, 0.10, 0.13)

func _floor_color() -> Color:
	return Color(0.20, 0.08, 0.10)   # casino carpet red

func _build_interior() -> void:
	_build_slots_row()
	_build_card_table()
	_build_highlow_lounge()
	_build_glitz()
	_build_people()

# ── slot machines ────────────────────────────────────────────────────────
func _build_slots_row() -> void:
	for i in 4:
		var sx := -10.0 + i * 3.2
		_add_box(Vector3(sx, 1.1, -8.5), Vector3(2.2, 2.2, 1.4),
			Color(0.16, 0.10, 0.18), 0.3, 0.4)
		_add_box(Vector3(sx, 1.6, -7.78), Vector3(1.6, 0.9, 0.06),
			Color(1.2, 0.9, 0.2) * 0.35, 0.0, 0.4, true, Color(1.5, 1.1, 0.25), 1.2)
		_add_box(Vector3(sx, 2.45, -8.2), Vector3(1.8, 0.3, 0.9),
			Color(1.0, 0.3, 0.3) * 0.4, 0.0, 0.4, true,
			[Color(1.5, 0.3, 0.3), Color(0.3, 1.3, 0.5), Color(0.4, 0.6, 1.5),
				Color(1.4, 0.4, 1.2)][i], 1.6)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.85, 0.4)
	lamp.light_energy = 1.8
	lamp.omni_range = 10.0
	lamp.position = Vector3(-5.0, 3.4, -7.0)
	add_child(lamp)
	add_interact(Vector3(-5.0, 1.2, -6.6), Vector3(12.0, 2.4, 2.0),
		"slots · %dcr a spin" % SLOT_BET, _open_slots)

func _open_slots() -> void:
	_open_game("SLOTS · LUCKY CHROME", [
		{ "label": "SPIN · %dcr" % SLOT_BET },
		{ "label": "walk away" },
	], Color(1.5, 1.1, 0.25), _on_slots_pick,
		"three 7s pay x20 · diamonds x8 · dots x5 · any pair x2")

func _on_slots_pick(idx: int) -> void:
	if idx == 1:
		_menu.close_menu()
		return
	if GameState.credits < SLOT_BET:
		_menu.set_footer("the machine eyes your empty pockets.")
		return
	GameState.add_credits(-SLOT_BET)
	var r := [SLOT_SYMBOLS[randi() % 4], SLOT_SYMBOLS[randi() % 4],
		SLOT_SYMBOLS[randi() % 4]]
	var payout := 0
	if r[0] == r[1] and r[1] == r[2]:
		payout = SLOT_BET * (20 if r[0] == "7" else (8 if r[0] == "◆" else 5))
	elif r[0] == r[1] or r[1] == r[2] or r[0] == r[2]:
		payout = SLOT_BET * 2
	GameState.add_credits(payout)
	var msg := "  ".join(r)
	if payout > 0:
		msg += "   WIN +%d" % payout
	else:
		msg += "   the machine chuckles."
	_menu.set_footer(msg + "   credits: %d" % GameState.credits)

# ── blackjack table ──────────────────────────────────────────────────────
func _build_card_table() -> void:
	_add_box(Vector3(7.0, 0.8, -6.5), Vector3(5.2, 0.16, 3.0),
		Color(0.05, 0.32, 0.16), 0.0, 0.9)
	_add_box(Vector3(7.0, 0.55, -6.5), Vector3(5.5, 0.5, 3.3),
		Color(0.18, 0.12, 0.08), 0.1, 0.5)
	_add_box(Vector3(7.0, 0.9, -7.4), Vector3(1.4, 0.06, 0.9),
		Color(0.8, 0.8, 0.85), 0.0, 0.4)   # dealer shoe
	add_npc("res://assets/sprites/npc-corpo.png", Vector3(7.0, 0.9, -8.2), 0)
	add_interact(Vector3(7.0, 1.2, -4.6), Vector3(6.0, 2.4, 2.0),
		"blackjack · %dcr a hand" % BJ_BET, _open_blackjack)

func _bj_card() -> int:
	var c := randi() % 13 + 1   # 1=ace, 11-13 face
	return mini(c, 10) if c > 1 else 11

func _bj_total(hand: Array) -> int:
	var t := 0
	var aces := 0
	for c in hand:
		t += c
		if c == 11:
			aces += 1
	while t > 21 and aces > 0:
		t -= 10
		aces -= 1
	return t

func _open_blackjack() -> void:
	_bj = {}
	_open_game("BLACKJACK · house rules", [
		{ "label": "DEAL · %dcr" % BJ_BET },
		{ "label": "walk away" },
	], Color(0.3, 1.2, 0.6), _on_bj_pick, "dealer stands on 17")

func _on_bj_pick(idx: int) -> void:
	if _bj.is_empty():
		if idx == 1:
			_menu.close_menu()
			return
		if GameState.credits < BJ_BET:
			_menu.set_footer("dealer: 'chips first.'")
			return
		GameState.add_credits(-BJ_BET)
		_bj = { "you": [_bj_card(), _bj_card()], "dealer": [_bj_card()] }
		_menu.refresh([{ "label": "HIT" }, { "label": "STAND" }], _bj_footer())
		if _bj_total(_bj.you) == 21:
			_bj_resolve()
		return
	if idx == 0:   # hit
		_bj.you.append(_bj_card())
		if _bj_total(_bj.you) > 21:
			_bj_resolve()
		else:
			_menu.refresh([{ "label": "HIT" }, { "label": "STAND" }], _bj_footer())
	else:
		_bj_resolve()

func _bj_footer() -> String:
	return "you: %d   ·   dealer shows: %d   ·   credits: %d" \
		% [_bj_total(_bj.you), _bj.dealer[0], GameState.credits]

func _bj_resolve() -> void:
	var yt := _bj_total(_bj.you)
	var msg := ""
	if yt > 21:
		msg = "BUST at %d. the dealer almost looks sorry." % yt
	else:
		while _bj_total(_bj.dealer) < 17:
			_bj.dealer.append(_bj_card())
		var dt := _bj_total(_bj.dealer)
		if dt > 21 or yt > dt:
			var pay := BJ_BET * 2
			GameState.add_credits(pay)
			msg = "you: %d · dealer: %d · WIN +%d" % [yt, dt, pay]
		elif yt == dt:
			GameState.add_credits(BJ_BET)
			msg = "push at %d. nobody's happy." % yt
		else:
			msg = "you: %d · dealer: %d · house takes it." % [yt, dt]
	_bj = {}
	_menu.refresh([{ "label": "DEAL · %dcr" % BJ_BET }, { "label": "walk away" }],
		msg + "   credits: %d" % GameState.credits)

# ── high-low lounge ──────────────────────────────────────────────────────
func _build_highlow_lounge() -> void:
	_add_box(Vector3(-1.0, 0.7, 5.5), Vector3(3.0, 0.14, 2.0),
		Color(0.28, 0.10, 0.28), 0.0, 0.8)
	_add_box(Vector3(-1.0, 0.45, 5.5), Vector3(3.2, 0.4, 2.2),
		Color(0.14, 0.10, 0.14), 0.2, 0.5)
	add_npc("res://assets/sprites/cyberGirl.png", Vector3(-1.0, 0.9, 4.2), 0)
	add_interact(Vector3(-1.0, 1.2, 6.9), Vector3(4.0, 2.4, 2.0),
		"high-low · %dcr" % HL_BET, _open_highlow)

func _open_highlow() -> void:
	_hl_card = randi() % 13 + 1
	_hl_streak = 0
	_open_game("HIGH-LOW · double or nothing", [
		{ "label": "HIGHER · %dcr" % HL_BET },
		{ "label": "LOWER · %dcr" % HL_BET },
		{ "label": "walk away" },
	], Color(1.2, 0.4, 1.2), _on_hl_pick,
		"card up: %d · aces low, kings high" % _hl_card)

func _on_hl_pick(idx: int) -> void:
	if idx == 2:
		_menu.close_menu()
		return
	if GameState.credits < HL_BET:
		_menu.set_footer("dealer: 'no stake, no game.'")
		return
	GameState.add_credits(-HL_BET)
	var next := randi() % 13 + 1
	var win := (next > _hl_card) if idx == 0 else (next < _hl_card)
	var msg := "card: %d → %d. " % [_hl_card, next]
	if next == _hl_card:
		GameState.add_credits(HL_BET)
		msg += "tie. stake back."
	elif win:
		_hl_streak += 1
		var pay := HL_BET * 2
		GameState.add_credits(pay)
		msg += "WIN +%d · streak %d" % [pay, _hl_streak]
	else:
		_hl_streak = 0
		msg += "house takes it."
	_hl_card = next
	_menu.set_footer(msg + "   credits: %d" % GameState.credits)

# ── glitz + people ───────────────────────────────────────────────────────
func _build_glitz() -> void:
	var sign := Label3D.new()
	sign.text = "LUCKY CHROME"
	sign.font_size = 130
	sign.pixel_size = 0.012
	sign.modulate = Color(1.5, 1.15, 0.3)
	sign.outline_size = 16
	sign.outline_modulate = Color(0.2, 0.1, 0.0)
	sign.position = Vector3(0, 4.1, -10.6)
	add_child(sign)
	# Gold ceiling ropes of light
	for zz in [-4.0, 1.0, 6.0]:
		_add_box(Vector3(0, 4.3, zz), Vector3(28.0, 0.05, 0.05),
			Color(1.2, 0.9, 0.3) * 0.4, 0.0, 0.4, true, Color(1.4, 1.05, 0.3), 1.8)
	for spot in [Vector3(7.0, 3.4, -6.0), Vector3(-1.0, 3.2, 5.0)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.8, 0.45)
		lamp.light_energy = 1.5
		lamp.omni_range = 9.0
		lamp.shadow_enabled = true
		lamp.position = spot
		add_child(lamp)

func _build_people() -> void:
	# The pit boss. He is always watching.
	add_npc("res://assets/sprites/npc-thug.png", Vector3(2.0, 0.9, -2.0), 0)
	add_interact(Vector3(2.0, 1.2, -0.8), Vector3(2.2, 2.4, 2.0),
		"the pit boss", func():
			_set_status("he doesn't blink. 'luck's a system, friend. the house wrote it.'"))
	add_npc("res://assets/sprites/npc-corpo.png", Vector3(-8.0, 0.9, -5.6), 3)
	add_npc("res://assets/sprites/npc-cyberpunk.png", Vector3(9.5, 0.9, -4.8), 3)

# ── shared game-menu plumbing ────────────────────────────────────────────
func _open_game(title: String, entries: Array, accent: Color,
		handler: Callable, footer := "") -> void:
	_menu_open = true
	_menu = ListMenuScript.new()
	add_child(_menu)
	_menu.picked.connect(handler)
	_menu.closed.connect(func():
		_menu_open = false
		_menu = null)
	_menu.open(title, entries, accent,
		footer + ("" if footer == "" else "   ·   ") + "credits: %d" % GameState.credits)
