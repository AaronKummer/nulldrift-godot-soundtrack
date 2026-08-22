extends RefCounted

## NetState — one deep-hack session over a nested net (sprawl model, ported
## to 0xFADE). Build from a site id, then crack nodes: gateways REVEAL their
## children, credentials unlock deeper nodes, money pays out, and every
## second connected plus every crack raises TRACE. Trace topping out spikes
## EXPOSURE; enough exposure wakes the sea hag (the apex tracer that
## eventually finds your apartment). Reaching far above your skill hits ICE.
##
## Pure sim — no UI. The net overlay renders and drives it. Verified
## headlessly end to end (entry → pivot → prize).

const Defs := preload("res://data/net_defs.gd")

# node instance: { uid, id, label, sec, revealed, cracked, gateway, ice,
#                  yield, value, layer, parent }
var nodes: Array = []
var creds: Array = []            # credential scopes held ("wifi:home_router", "master", ...)
var trace := 0.0                 # 0..100 this session; tops out → exposure spike
var exposure := 0.0             # persists into GameState after the run
var money_taken := 0
var site_id := ""
var site_heat := 0.4
var hacking_skill := 1          # from GameState later; gates ICE risk
var log_lines: Array = []       # console feed
var done := false
var busted := false

func build(site: String, skill: int = 1) -> void:
	site_id = site
	var s: Dictionary = Defs.site(site)
	site_heat = s.get("heat", 0.4)
	hacking_skill = maxi(1, skill)
	var uid := 0
	# Entry node — internet-facing, revealed from the start
	var entry := _mk(uid, s.entry, 0, -1)
	entry.revealed = true
	nodes.append(entry)
	uid += 1
	var parent_uid: int = entry.uid
	for i in s.get("layers", []).size():
		var layer: Dictionary = s.layers[i]
		var gw := _mk(uid, layer.gateway, i + 1, parent_uid)
		gw.revealed = (i == 0)   # first gateway visible off the entry; rest revealed by pivoting
		nodes.append(gw)
		uid += 1
		var gw_uid: int = gw.uid
		for child_id in layer.get("children", []):
			var c := _mk(uid, child_id, i + 1, gw_uid)
			nodes.append(c)
			uid += 1
		parent_uid = gw_uid
	_log("connected to %s" % s.get("name", site))
	_log("one node is internet-facing. crack it and pivot inward.")

func _mk(uid: int, id: String, layer: int, parent: int) -> Dictionary:
	var d: Dictionary = Defs.node(id)
	return {
		"uid": uid, "id": id, "label": d.get("label", id),
		"sec": d.get("sec", 1), "yield": d.get("yield", "none"),
		"value": d.get("value", 0), "gateway": d.get("gateway", false),
		"ice": d.get("ice", false), "lesson": d.get("lesson", ""),
		"revealed": false, "cracked": false, "layer": layer, "parent": parent,
	}

func node_by_uid(uid: int) -> Dictionary:
	for n in nodes:
		if n.uid == uid:
			return n
	return {}

func revealed_nodes() -> Array:
	return nodes.filter(func(n): return n.revealed)

## Can you even attempt this node? Must be revealed and not already cracked.
func can_attempt(uid: int) -> bool:
	var n := node_by_uid(uid)
	return not n.is_empty() and n.revealed and not n.cracked and not done

## The crack. Returns a result dict the UI narrates. Success reveals a
## gateway's children, banks yields, and always raises trace by node.sec.
## ICE nodes reached above your skill bite back (exposure spike, run ends).
func crack(uid: int) -> Dictionary:
	var n := node_by_uid(uid)
	if n.is_empty() or not can_attempt(uid):
		return { "ok": false, "msg": "can't reach that node." }
	# Black ICE check — reaching too far above your tools
	if n.ice and n.sec > hacking_skill + 3:
		exposure += 25.0
		trace = minf(100.0, trace + 30.0)
		busted = true
		done = true
		_log("!! BLACK ICE on %s — it bit back. deck fried. bail." % n.label)
		return { "ok": false, "ice_burn": true, "msg": "black ICE. get out." }
	n.cracked = true
	trace = minf(100.0, trace + n.sec * 3.0)
	_log("cracked %s [sec %d]" % [n.label, n.sec])
	if n.lesson != "":
		_log("  · " + n.lesson)
	# Gateways reveal the whole tier they guard
	if n.gateway:
		var revealed_count := 0
		for c in nodes:
			if c.parent == n.uid and not c.revealed:
				c.revealed = true
				revealed_count += 1
		if revealed_count > 0:
			_log("  → %d nodes behind it just appeared." % revealed_count)
		_reveal_next_gateway(n)
	# Yields
	var res := { "ok": true, "node": n, "yield": n.yield }
	match n.yield:
		"money":
			var take: int = n.value if n.value > 0 else 500
			money_taken += take
			_log("  $ exfiltrated %d credits." % take)
			res["money"] = take
		"wifi", "cred", "master":
			var scope := "%s:%d" % [n.yield, n.uid]
			creds.append(scope)
			_log("  ⚿ credential lifted (%s)." % n.yield)
			res["cred"] = scope
		"dirt":
			creds.append("dirt:%d" % n.uid)
			_log("  ✎ kompromat on their phone — leverage for the social path.")
		"control":
			_log("  > real-world control seized.")
		"intel":
			_log("  ℹ intel gathered — the map got clearer.")
		"power":
			done = true
			_log("  ⚡ GRID SEIZED. the city's lights are yours.")
			res["win"] = true
	if _prize_cracked():
		_log("prize secured. jack out (that trace won't stop climbing).")
	return res

func _reveal_next_gateway(_gw: Dictionary) -> void:
	# Reveal any gateway whose parent is now cracked (chain inward)
	for n in nodes:
		if n.gateway and not n.revealed:
			var p := node_by_uid(n.parent)
			if not p.is_empty() and p.cracked:
				n.revealed = true

func _prize_cracked() -> bool:
	var pz: String = Defs.site(site_id).get("prize", "")
	for n in nodes:
		if n.id == pz and n.cracked:
			return true
	return false

## Per-frame trace creep while connected. Returns true if the sea hag has
## locked on (caller ends the run with a raid warning).
func tick(delta: float) -> bool:
	if done:
		return false
	trace = minf(100.0, trace + site_heat * delta * 1.5)
	if trace >= 100.0:
		exposure += 10.0 * delta
	# The sea hag scales with what you've grabbed, not just time: petty
	# theft stays beneath her notice; reaching for millions wakes her.
	var hag := exposure + float(money_taken) / 2000.0 + site_heat * 20.0
	return hag >= 100.0

## Bank the run into GameState: credits earned, exposure carried forward.
func settle() -> void:
	if money_taken > 0:
		GameState.add_credits(money_taken)
	GameState.exposure = minf(100.0, GameState.exposure + exposure * 0.5)

func _log(s: String) -> void:
	log_lines.append(s)
