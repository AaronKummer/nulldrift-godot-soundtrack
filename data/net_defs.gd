## Net definitions — the deep-hacking layer, adapted from the sprawl
## prototype (~/code/sprawl) into 0xFADE. The net is a nested graph that
## mirrors real-world ownership: district → building LAN → devices/people
## → servers → the prize. You reach a node only if it's internet-facing,
## or you've cracked the gateway of its network (which REVEALS its
## children), or you hold a credential that unlocks it.
##
## Every node is a real security concept, so cracking it teaches something
## (the `lesson` line surfaces in the console). That's the educational hook.
class_name NetDefs
extends Object

# yield kinds a cracked node can produce:
#   money   — credits (× value)          intel  — reveals/uncovers, lowers heat cost
#   wifi    — LAN gateway credential      cred   — a reusable login (may be REUSED elsewhere)
#   master  — domain admin, opens a whole corp net
#   control — flips a real-world thing (lock/camera/lights) — flavor + objectives
#   dirt    — kompromat off a person's phone → blackmail path
#   power   — SCADA/grid seizure (endgame prize)      none — flavor only
const CATALOG := {
	# ── IoT footholds — weak, everywhere, the way in ──────────────────────
	"doorbell_cam":  { "cat": "iot", "sec": 1, "yield": "intel", "label": "doorbell cam",
		"lesson": "internet-facing IoT with a default password is the front door. literally." },
	"security_cam":  { "cat": "iot", "sec": 2, "yield": "intel", "label": "security camera" },
	"smart_lock":    { "cat": "iot", "sec": 1, "yield": "control", "label": "smart lock",
		"lesson": "your deadbolt has a wifi chip now. that was a choice someone made." },
	"smart_tv":      { "cat": "iot", "sec": 1, "yield": "none", "label": "smart TV" },
	"robot_vacuum":  { "cat": "iot", "sec": 1, "yield": "intel", "label": "robot vacuum",
		"lesson": "it mapped every room in the house. now so have you." },
	"smart_speaker": { "cat": "iot", "sec": 2, "yield": "intel", "label": "smart speaker" },
	"badge_reader":  { "cat": "iot", "sec": 3, "yield": "control", "label": "badge reader" },
	# ── devices + people ──────────────────────────────────────────────────
	"printer":       { "cat": "device", "sec": 2, "yield": "cred", "label": "network printer",
		"lesson": "the printer stored the admin's scan-to-email password in plaintext. they always do." },
	"phone":         { "cat": "person_dev", "sec": 2, "yield": "dirt", "label": "personal phone",
		"lesson": "people keep their whole life here. including things worth leverage." },
	"laptop":        { "cat": "computer", "sec": 3, "yield": "cred", "label": "personal laptop",
		"lesson": "they reused their work password at home. the single most common way in." },
	"workstation":   { "cat": "computer", "sec": 3, "yield": "cred", "label": "workstation" },
	# ── infrastructure (gateways — cracking these REVEALS the sub-net) ────
	"home_router":   { "cat": "infra", "sec": 2, "yield": "wifi", "gateway": true, "label": "home router",
		"lesson": "one gateway, and the whole LAN behind it lights up." },
	"vpn_gateway":   { "cat": "infra", "sec": 4, "yield": "none", "gateway": true, "label": "corp VPN",
		"ice": true, "lesson": "the VPN is the corp's moat. it also watches who crosses it." },
	"corp_firewall": { "cat": "infra", "sec": 5, "yield": "none", "gateway": true, "label": "firewall",
		"ice": true },
	# ── servers — the meat ────────────────────────────────────────────────
	"mail_server":   { "cat": "server", "sec": 4, "yield": "cred", "label": "mail server" },
	"file_server":   { "cat": "server", "sec": 4, "yield": "intel", "label": "file server" },
	"ad_server":     { "cat": "server", "sec": 5, "yield": "master", "ice": true, "label": "domain controller",
		"lesson": "domain admin is the master key. own this and you own every machine on the net." },
	"db_server":     { "cat": "server", "sec": 5, "yield": "cred", "label": "database" },
	"payment_server":{ "cat": "server", "sec": 5, "yield": "money", "value": 60000, "ice": true,
		"label": "payment processor",
		"lesson": "this is where the money actually moves. it is also where the alarms actually live." },
	# ── public money / control ───────────────────────────────────────────
	"atm":           { "cat": "public", "sec": 3, "yield": "money", "value": 4000, "label": "ATM" },
	"pos_terminal":  { "cat": "public", "sec": 2, "yield": "money", "value": 1200, "label": "POS terminal" },
	"billboard":     { "cat": "public", "sec": 2, "yield": "control", "label": "billboard" },
	"traffic_light": { "cat": "public", "sec": 3, "yield": "control", "label": "traffic control" },
	# ── SCADA / grid — the endgame prize ─────────────────────────────────
	"scada_gw":      { "cat": "scada", "sec": 6, "yield": "none", "gateway": true, "ice": true, "label": "SCADA gateway" },
	"grid_control":  { "cat": "scada", "sec": 6, "yield": "power", "ice": true, "label": "grid control",
		"lesson": "the city's power in one console. the deepest thing on the net, and the loudest." },
	# ── story nodes (Cortex relay net etc. — wired as the plot needs) ─────
	"relay_node":    { "cat": "server", "sec": 5, "yield": "intel", "ice": true, "label": "Cortex relay node",
		"story": true },
	"bio_scada":     { "cat": "scada", "sec": 5, "yield": "control", "gateway": true, "ice": true,
		"label": "containment SCADA", "story": true,
		"lesson": "the sublevel airlocks and vats run on the same industrial bus as a factory floor. it was never meant to face the net." },
	"research_core": { "cat": "server", "sec": 6, "yield": "control", "ice": true,
		"label": "VOHL research core", "story": true,
		"lesson": "the thing he was growing is wired to this console. seize it and you can vent the whole wing from your bedroom." },
}

static func node(id: String) -> Dictionary:
	return CATALOG.get(id, CATALOG["doorbell_cam"])

## Site templates — each hackable jack-in point in the world spins up one of
## these as a nested net. `layers` lists tiers from the entry inward; a
## gateway tier reveals the next when cracked. `heat` scales the sea hag's
## interest in the whole site (an ATM barely registers; a bank's core is loud).
const SITES := {
	# The ATM you jack in Act 1 — small, forgiving, teaches the pivot
	"atm_branch": {
		"name": "CORTEX ATM · branch net",
		"heat": 0.4,
		"entry": "atm",
		"layers": [
			{ "gateway": "home_router", "children": ["security_cam", "pos_terminal", "printer"] },
			{ "gateway": "vpn_gateway", "children": ["db_server", "payment_server"] },
		],
		"prize": "payment_server",
	},
	# Your own apartment building — the tutorial sandbox, near-zero stakes
	"home_block": {
		"name": "your building · resident LAN",
		"heat": 0.1,
		"entry": "doorbell_cam",
		"layers": [
			{ "gateway": "home_router", "children": ["smart_lock", "robot_vacuum", "smart_tv", "phone", "laptop"] },
		],
		"prize": "laptop",
	},
	# A corp office — the real chain: reuse → VPN → domain admin → money+grid cred
	"corp_office": {
		"name": "ArkLight office · corp net",
		"heat": 1.0,
		"entry": "doorbell_cam",
		"layers": [
			{ "gateway": "home_router", "children": ["phone", "laptop", "smart_speaker"] },
			{ "gateway": "vpn_gateway", "children": ["workstation", "mail_server", "file_server", "printer"] },
			{ "gateway": "corp_firewall", "children": ["ad_server", "db_server", "payment_server"] },
		],
		"prize": "ad_server",
	},
	# VOHL PHARMA's net — the remote road to the same ending as the basement
	# dungeon. Deep, ICE-heavy: you need a leveled deck (crack the smaller
	# nets first) to reach the research core without getting your rig fried.
	# Cracking the core vents the sublevels — vohlDefeated, from your bedroom.
	"vohl_net": {
		"name": "VOHL PHARMA · research net",
		"heat": 1.4,
		"entry": "security_cam",
		"layers": [
			{ "gateway": "home_router", "children": ["badge_reader", "phone", "laptop"] },
			{ "gateway": "vpn_gateway", "children": ["workstation", "mail_server", "file_server", "printer"] },
			{ "gateway": "corp_firewall", "children": ["ad_server", "db_server"] },
			{ "gateway": "bio_scada", "children": ["research_core"] },
		],
		"prize": "research_core",
	},
}

static func site(id: String) -> Dictionary:
	return SITES.get(id, SITES["atm_branch"])
