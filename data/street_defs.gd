## Street roster — Signal Hollow as authored east-west streets connected by
## RIDENET. Derived from the Phaser Uber destination list (PhoneUI.js):
## every canon destination lives on one of these streets. Streets with an
## empty "scene" show as [SOON] in the RIDENET menu until they're built.
class_name StreetDefs
extends Object

const STREETS := {
	"home": {
		"name": "HOME STREET", "cost": 10, "scene": "city",
		"stops": ["home", "arcade", "comics", "diner", "bar", "pets", "guns"],
	},
	"warzone": {
		"name": "THE WARZONE", "cost": 30, "scene": "street_warzone",
		"stops": ["the dump", "chop shop", "jackals turf"],
	},
	"downtown": {
		"name": "DOWNTOWN", "cost": 15, "scene": "street_downtown",
		"stops": ["casino", "the cathode", "growlers", "sushi", "cafe",
			"tech shop", "library"],
	},
	"suburbs": {
		"name": "THE SUBURBS", "cost": 20, "scene": "",
		"stops": ["houses", "stephens beach house", "central park"],
	},
	"stack": {
		"name": "THE STACK", "cost": 25, "scene": "street_stack",
		"stops": ["omnicorp", "nexus tower", "cortex hq"],
	},
	"financial": {
		"name": "FINANCIAL DISTRICT", "cost": 35, "scene": "",
		"stops": ["nexus bank", "vvs hq", "platinum arms"],
	},
}

const ORDER := ["home", "warzone", "downtown", "suburbs", "stack", "financial"]

static func street_list() -> Array:
	var out: Array = []
	for id in ORDER:
		var st: Dictionary = STREETS[id].duplicate()
		st["id"] = id
		out.append(st)
	return out
