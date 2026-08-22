## Security definitions — who guards a place, who they call, and whether the
## cops are ever part of it. This is the spine of "going loud": each location
## has a POSTURE, and an alerted guard/receptionist radios up a BACKUP LADDER.
##
## Corps run on private security and mostly DON'T count on the police — a bank
## handles you in-house with ninjas and turrets. The street is the opposite:
## no garrison, straight to cops. calls_police controls whether the ladder's
## final rung is the law or just more of their own.
class_name SecurityDefs
extends Object

# ── enemy roster — stats in METERS (iso interior scale), not dungeon pixels ─
# kind: ranged (holds distance + shoots) | melee (closes + strikes) |
#       turret (static burst) | elite (charges, heavy)
const UNITS := {
	"guard": {
		"label": "SECURITY", "sheet": "res://assets/sprites/npc-cop2.png",
		"tint": Color(0.8, 0.85, 1.0), "kind": "ranged",
		"hp": 30, "speed": 2.4, "dmg": 7, "range": 14.0, "hold": 7.0,
		"fire_cd": 1.15, "credits": 40, "drops": true,
	},
	"corp_guard": {
		"label": "CORP SECURITY", "sheet": "res://assets/sprites/npc-corpo.png",
		"tint": Color(1.0, 0.9, 0.7), "kind": "ranged",
		"hp": 38, "speed": 2.6, "dmg": 9, "range": 15.0, "hold": 8.0,
		"fire_cd": 1.0, "credits": 60, "drops": true,
	},
	"ninja": {
		"label": "BLACKWING", "sheet": "res://assets/sprites/npc-ninja.png",
		"tint": Color(0.7, 0.75, 0.9), "kind": "melee",
		"hp": 26, "speed": 5.0, "dmg": 13, "range": 1.8, "lunge": 9.0,
		"fire_cd": 0.9, "credits": 80, "drops": true,
	},
	"turret": {
		"label": "AUTO-TURRET", "sheet": "", "kind": "turret",
		"hp": 45, "speed": 0.0, "dmg": 6, "range": 17.0, "hold": 0.0,
		"fire_cd": 0.45, "burst": 3, "credits": 0, "drops": false,
	},
	"laser_bot": {
		"label": "KATANA UNIT", "sheet": "", "kind": "elite",
		"hp": 130, "speed": 3.4, "dmg": 22, "range": 2.4, "charge": 9.5,
		"fire_cd": 1.2, "credits": 300, "drops": true, "boss": true,
	},
	"cop": {
		"label": "NCPD", "sheet": "res://assets/sprites/npc-cop.png",
		"tint": Color(0.9, 0.9, 1.0), "kind": "ranged",
		"hp": 26, "speed": 2.7, "dmg": 7, "range": 14.0, "hold": 7.0,
		"fire_cd": 1.1, "credits": 0, "drops": false,
	},
}

static func unit(id: String) -> Dictionary:
	return UNITS.get(id, UNITS["guard"])

# ── location postures ──────────────────────────────────────────────────────
# garrison: units already present, keyed by floor (0/1-based per scene).
# ladder:   backup rungs, in order. Each rung: {call, wave[], delay}. A hostile
#           guard/receptionist "radios" the next uncalled rung; it lands after
#           `delay` seconds from the entrances. Kill the caller mid-radio to
#           stall it.
# calls_police: does the ladder's cop rung actually fire? Banks = false (they
#           handle it in-house); corp towers = true (cops as a last resort).
const POSTURES := {
	# VOHL corp tower — own guards + elites, cops as a grudging last resort.
	"vohl": {
		"garrison": { 1: ["guard"], 2: ["guard", "guard"], 3: ["guard"],
			4: ["guard", "corp_guard"], 5: ["corp_guard"], 6: [] },
		"ladder": [
			{ "call": "SECURITY", "wave": ["guard", "guard"], "delay": 4.0 },
			{ "call": "ELITE UNIT", "wave": ["ninja", "laser_bot"], "delay": 9.0 },
			{ "call": "NCPD", "wave": ["cop", "cop", "cop"], "delay": 15.0 },
		],
		"calls_police": true,
	},
	# NEXUS BANK — a fortress. Ninjas + turrets up top; runs entirely in-house,
	# never counts on the cops.
	"nexusbank": {
		"garrison": { 1: ["corp_guard", "guard"], 2: ["guard"],
			3: ["ninja", "turret"] },
		"ladder": [
			{ "call": "SECURITY", "wave": ["corp_guard", "corp_guard"], "delay": 3.5 },
			{ "call": "BLACKWING", "wave": ["ninja", "ninja", "laser_bot"], "delay": 8.0 },
		],
		"calls_police": false,
	},
}

static func posture(id: String) -> Dictionary:
	return POSTURES.get(id, POSTURES["vohl"])
