## Quest definitions — port of hacking-game/src/data/quests.js.
##
## States: LOCKED → AVAILABLE → ACTIVE → COMPLETED
## Objective types: talk, goto, collect, kill, hack, scene, flag, custom
class_name Quests
extends Object

enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETED }

const ALL := {
	# First quest the player triggers — kicks off when they interact with
	# the fishtank in the apartment and discover the fish are hungry.
	"fishFood": {
		"id": "fishFood",
		"title": "Feed Your Damn Fish",
		"description": "Your fish look hungry. Buy fish food at the pet store and feed them. Maybe that stray cat at your door will follow you home if you actually take care of something for once.",
		"type": "main",
		"prerequisites": [],
		"objectives": [
			{ "type": "flag", "flag": "fish_food_seen",
			  "description": "Notice the fish are hungry" },
			{ "type": "goto", "scene": "city",
			  "description": "Find the pet store on the block" },
			{ "type": "collect", "item": "fish_food",
			  "description": "Buy fish food from the shopkeeper" },
			{ "type": "flag", "flag": "fish_fed",
			  "description": "Feed the fish" },
		],
		"on_complete": { "set_flags": ["fed_the_fish"], "credits": 0 },
	},

	"wakeUp": {
		"id": "wakeUp",
		"title": "Wake Up",
		"description": "Get out of bed and figure out what happened last night.",
		"type": "main",
		"auto_start": true,
		"prerequisites": [],
		"objectives": [
			{ "type": "scene", "scene": "city", "description": "Leave the apartment" },
		],
		"on_complete": { "set_flags": ["leftApartment"] },
	},

	"atmWitness": {
		"id": "atmWitness",
		"title": "ATM Witness",
		"description": "You witnessed someone hacking an ATM. The cops showed up — she dropped something.",
		"type": "main",
		"prerequisites": ["leftApartment"],
		"objectives": [
			{ "type": "flag", "flag": "atmEventDone", "description": "Witness the ATM incident" },
			{ "type": "collect", "item": "cyberDeck", "description": "Pick up the dropped CyberDeck" },
		],
		"on_complete": { "set_flags": ["hasCyberDeck"] },
	},

	"firstHack": {
		"id": "firstHack",
		"title": "First Hack",
		"description": "Use the CyberDeck to jack into an ATM.",
		"type": "main",
		"prerequisites": ["hasCyberDeck"],
		"objectives": [
			{ "type": "hack", "description": "Successfully hack an ATM" },
		],
		"on_complete": { "set_flags": ["firstHackDone"], "credits": 200 },
	},

	"dinerMeeting": {
		"id": "dinerMeeting",
		"title": "Meeting at the Diner",
		"description": "A mysterious hacker wants to meet you at the diner.",
		"type": "main",
		"prerequisites": ["firstHackDone"],
		"objectives": [
			{ "type": "talk", "npc": "nyx_diner", "description": "Find Nyx at the diner" },
		],
		"on_complete": { "set_flags": ["metNyx", "pendingDinerMeeting"] },
	},
}

static func get_quest(id: String) -> Dictionary:
	return ALL.get(id, {})

static func auto_start_quests() -> Array:
	var out: Array = []
	for q in ALL.values():
		if q.get("auto_start", false):
			out.append(q["id"])
	return out

static func prerequisites_met(quest_id: String, flags: Dictionary) -> bool:
	var q := get_quest(quest_id)
	if q.is_empty():
		return false
	for prereq in q.get("prerequisites", []):
		if not flags.get(prereq, false):
			return false
	return true
