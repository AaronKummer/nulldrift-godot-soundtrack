## Item database — minimal port of hacking-game/src/data/itemDatabase.js.
## Just the items the early game needs; bigger catalog comes when we port shops.
class_name Items
extends Object

const ALL := {
	"cyberDeck": {
		"id": "cyberDeck",
		"name": "CyberDeck",
		"kind": "tool",
		"description": "Standard street deck. Old, scratched, glows faint green.",
		"price": 0,
		"color": Color(0.0, 1.0, 0.53),
		"icon": "cyberdeck",
		"tags": ["quest"],
	},
	"pizzaSlice": {
		"id": "pizzaSlice",
		"name": "Pizza Slice",
		"kind": "consumable",
		"description": "Cold. Tony would be furious.",
		"price": 8,
		"hp_restore": 15,
		"color": Color(1.0, 0.6, 0.2),
		"tags": ["food"],
	},
	"creditChip": {
		"id": "creditChip",
		"name": "Credit Chip",
		"kind": "currency",
		"description": "Untraceable. Spends anywhere.",
		"price": 1,
		"color": Color(0.27, 1.0, 0.53),
		"tags": ["money"],
	},
	"monofilamentWhip": {
		"id": "monofilamentWhip",
		"name": "Monofilament Whip",
		"kind": "weapon",
		"description": "Snaps neon-red through chrome.",
		"damage": 22,
		"price": 4500,
		"color": Color(1.0, 0.1, 0.04),
		"tags": ["melee", "exotic"],
	},
}

static func get_item(id: String) -> Dictionary:
	return ALL.get(id, {})
