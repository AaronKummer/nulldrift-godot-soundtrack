## Quest definitions — full port of hacking-game/src/data/quests.js
## (13 canon quests: 3 acts + side chain) plus the Godot-native fishFood
## tutorial. Text is canon verbatim; flags mapped to this port's names
## where content already exists (relays = sewer/office/corpo RelayFound,
## chad = chadBeaten, cafe date = kerryDated).
##
## States: LOCKED → AVAILABLE → ACTIVE → COMPLETED
## Objective types: flag (auto-checked), collect (auto-checked),
## scene/talk/hack/custom (completed by scene code calling complete_quest).
class_name Quests
extends Object

enum State { LOCKED, AVAILABLE, ACTIVE, COMPLETED }

const ALL := {
	# ── tutorial (Godot-native) ──────────────────────────────────────────
	"fishFood": {
		"id": "fishFood",
		"title": "Feed Your Damn Fish",
		"description": "Your fish look hungry. Buy fish food at the pet store and feed them. Maybe that stray cat at your door will follow you home if you actually take care of something for once.",
		"type": "side",
		"prerequisites": [],
		"objectives": [
			{ "type": "collect", "item": "fish_food",
			  "description": "Buy fish food at PAWS+ on the block" },
			{ "type": "flag", "flag": "fish_fed",
			  "description": "Feed the fish" },
		],
		"on_complete": { "set_flags": ["fed_the_fish"], "credits": 0 },
	},

	# ── ACT 1: AWAKENING ─────────────────────────────────────────────────
	"wakeUp": {
		"id": "wakeUp",
		"title": "Wake Up",
		"description": "Get out of bed and figure out what happened last night.",
		"type": "main",
		"auto_start": true,
		"prerequisites": [],
		"objectives": [
			{ "type": "scene", "scene": "hallway", "description": "Leave the apartment" },
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
			{ "type": "flag", "flag": "atmEventDone",
			  "description": "Explore the city — head toward the crowd near the ATM" },
			{ "type": "collect", "item": "cyberDeck",
			  "description": "Grab the CyberDeck she dropped" },
		],
		"on_complete": { "set_flags": ["hasCyberDeck"] },
	},

	"firstHack": {
		"id": "firstHack",
		"title": "First Hack",
		"description": "Use the CyberDeck to jack into an ATM and try your hand at hacking.",
		"type": "main",
		"prerequisites": ["hasCyberDeck"],
		"objectives": [
			{ "type": "flag", "flag": "firstHackDone",
			  "description": "Walk up to any ATM and press E to jack in and hack it" },
		],
		"on_complete": { "credits": 200 },
	},

	"dinerMeeting": {
		"id": "dinerMeeting",
		"title": "Diner Meeting",
		"description": "Someone wants to meet you at the diner. The message just says: 'booth two. i know you, ghost.'",
		"type": "main",
		"prerequisites": ["firstHackDone"],
		"objectives": [
			{ "type": "flag", "flag": "metCyberGirl",
			  "description": "Meet her at booth two in HANK'S DINER" },
		],
		"on_complete": { "set_flags": ["metNyx"], "credits": 500 },
	},

	"garageInvestigation": {
		"id": "garageInvestigation",
		"title": "Garage Investigation",
		"description": "She told you about the Chrome Jackals hiding in a parking garage. Investigate.",
		"type": "main",
		"prerequisites": ["metCyberGirl"],
		"objectives": [
			{ "type": "flag", "flag": "garageCleared",
			  "description": "Clear out the Chrome Jackals in Packard Rows garage" },
		],
		"on_complete": { "set_flags": ["rezzDefeated"] },
	},

	"goingDeeper": {
		"id": "goingDeeper",
		"title": "Going Deeper",
		"description": "The Chrome Jackals are connected to something bigger. Find out what.",
		"type": "main",
		"prerequisites": ["garageCleared", "metCyberGirl"],
		"objectives": [
			{ "type": "flag", "flag": "securedTerminalHacked",
			  "description": "Hack the secured terminal in the arcade back corner" },
			{ "type": "flag", "flag": "reportedToNyx",
			  "description": "Report back to Nyx at the diner" },
		],
		"on_complete": { "set_flags": ["actOneComplete"] },
	},

	# ── ACT 2: FOLLOW THE SIGNAL ─────────────────────────────────────────
	"relayNodes": {
		"id": "relayNodes",
		"title": "Relay Nodes",
		"description": "Nyx says Cortex has relay nodes hidden across the city. Take them out.",
		"type": "main",
		"prerequisites": ["actOneComplete"],
		"on_start": { "set_flags": ["actTwoStarted"] },
		"objectives": [
			{ "type": "flag", "flag": "sewerRelayFound",
			  "description": "Destroy Relay Node Alpha (the sewers)" },
			{ "type": "flag", "flag": "officeRelayFound",
			  "description": "Destroy Relay Node Beta (Nexus Tower)" },
			{ "type": "flag", "flag": "corpoRelayFound",
			  "description": "Destroy Relay Node Gamma (Cortex HQ)" },
		],
		"on_complete": { "set_flags": ["relayNodesDestroyed"] },
	},

	"movingIn": {
		"id": "movingIn",
		"title": "Getting Closer",
		"description": "Things with Kerry are heating up. Ask her out.",
		"type": "main",
		"prerequisites": ["actOneComplete"],
		"objectives": [
			{ "type": "flag", "flag": "kerryMatched",
			  "description": "Open your phone and match with Kerry on the dating app" },
			{ "type": "flag", "flag": "kerryDated",
			  "description": "Meet Kerry for a date at the café downtown" },
		],
		"on_complete": { "set_flags": ["kerryMovedIn", "kerryTogether"] },
	},

	"kerrySick": {
		"id": "kerrySick",
		"title": "Something's Wrong",
		"description": "Settle in with Kerry — but she's been coughing, and it's getting worse.",
		"type": "main",
		"prerequisites": ["kerryTogether", "relayNodesDestroyed"],
		"objectives": [
			{ "type": "flag", "flag": "kerryIsSick",
			  "description": "Head home and spend the evening with Kerry" },
			{ "type": "flag", "flag": "foundVohlClue",
			  "description": "Talk to Kerry, then check your phone for a lead" },
		],
		"on_complete": { "set_flags": ["kerryQuestDone", "vohlClueFound"] },
	},

	"vohlLab": {
		"id": "vohlLab",
		"title": "Vohl's Lab",
		"description": "The trail leads to Vohl Pharmaceuticals. Find out what they're making down there. Destroy the lab equipment before facing Vohl, or the plague goes citywide.",
		"type": "main",
		"prerequisites": ["kerryQuestDone"],
		"objectives": [
			{ "type": "flag", "flag": "vohlDefeated",
			  "description": "Reach Dr. Vohl at Vohl Pharmaceuticals (Financial District)" },
		],
		"on_complete": { "set_flags": ["actTwoComplete"] },
	},

	# ── ACT 3: GHOST IN THE MACHINE ──────────────────────────────────────
	"cureKerry": {
		"id": "cureKerry",
		"title": "The Antidote",
		"description": "You pulled a stabilized antidote out of Vohl's lab. Kerry is waiting. Go home.",
		"type": "main",
		"prerequisites": ["actTwoComplete"],
		"on_start": { "set_flags": ["actThreeStarted"] },
		"objectives": [
			{ "type": "flag", "flag": "kerryCured",
			  "description": "Bring the antidote home to Kerry" },
		],
		"on_complete": {},
	},

	"nyxBetrayal": {
		"id": "nyxBetrayal",
		"title": "Her... or Me",
		"description": "Nyx texted: \"can i come over and watch movies with you guys?\" You said yes. You had to.",
		"type": "main",
		"prerequisites": ["kerryCured"],
		"objectives": [
			{ "type": "flag", "flag": "nyxRevealed",
			  "description": "Head home — movie night with Kerry and Nyx" },
		],
		"on_complete": { "set_flags": ["actThreeComplete", "kerryKidnapped"] },
	},

	"vvsTower": {
		"id": "vvsTower",
		"title": "Ghost in the Machine",
		"description": "Nyx flew Kerry to the top of VVS Tower — where Violet is caged behind Leon Tusk's dragon. Get them both back.",
		"type": "main",
		"prerequisites": ["actThreeComplete"],
		"objectives": [
			{ "type": "flag", "flag": "dragonDefeated",
			  "description": "Fight to the top of VVS Tower and slay the Violet Dragon" },
			{ "type": "flag", "flag": "kerryRescued",
			  "description": "Find Kerry at the summit" },
			{ "type": "flag", "flag": "violetFreed",
			  "description": "Free Violet" },
		],
		"on_complete": { "set_flags": ["gameComplete"] },
	},

	# ── SIDE QUESTS ──────────────────────────────────────────────────────
	"catRescue": {
		"id": "catRescue",
		"title": "Stray Signal",
		"description": "A stray cat is wandering near your apartment. Maybe you should rescue it.",
		"type": "side",
		"prerequisites": ["leftApartment"],
		"objectives": [
			{ "type": "flag", "flag": "catRescued",
			  "description": "Rescue the stray cat near your apartment" },
		],
		"on_complete": { "credits": 400 },
	},

	"beatChad": {
		"id": "beatChad",
		"title": "Beat Chad's Score",
		"description": "Chad at the arcade thinks he's unbeatable. Show him otherwise.",
		"type": "side",
		"prerequisites": ["leftApartment"],
		"objectives": [
			{ "type": "flag", "flag": "chadBeaten",
			  "description": "Beat Chad's NEON SURVIVORS score at the arcade" },
		],
		"on_complete": { "credits": 300, "set_flags": ["chadDefeated"] },
	},

	"garageRematch": {
		"id": "garageRematch",
		"title": "Garage Rematch",
		"description": "The Chrome Jackals are back. Clear the garage again — harder this time.",
		"type": "side",
		"prerequisites": ["garageCleared"],
		"objectives": [
			{ "type": "flag", "flag": "garageLevel2Cleared",
			  "description": "Clear garage level 2+" },
		],
		"on_complete": { "credits": 1000, "set_flags": ["garageRematchDone"] },
	},

	"contractor": {
		"id": "contractor",
		"title": "The Contractor",
		"description": "Every bounty board in the city is a paycheck waiting. Take contracts and collect. Word gets around.",
		"type": "side",
		"prerequisites": ["hasCyberDeck"],
		"objectives": [
			{ "type": "flag", "flag": "bountyOneDone",
			  "description": "Collect your first bounty contract" },
			{ "type": "flag", "flag": "bountyThreeDone",
			  "description": "Collect 3 bounty contracts total" },
		],
		"on_complete": { "credits": 3000, "set_flags": ["bountyLicense"] },
	},

	"madeMan": {
		"id": "madeMan",
		"title": "Made Man",
		"description": "You have a name on these streets now. Clean up the loose ends and the whole city knows it.",
		"type": "side",
		"prerequisites": ["bountyLicense"],
		"objectives": [
			{ "type": "flag", "flag": "garageLevel2Cleared",
			  "description": "Clear the Chrome Jackals' garage rematch" },
			{ "type": "flag", "flag": "catRescued",
			  "description": "Rescue the stray cat near your apartment" },
		],
		"on_complete": { "credits": 5000, "set_flags": ["cityLegend"] },
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

## Is a single objective satisfied right now? flag/collect auto-check;
## scene/talk/hack are completed by scene code, so they read false here.
static func objective_done(obj: Dictionary, flags: Dictionary, inventory: Array) -> bool:
	match obj.get("type", ""):
		"flag":
			return flags.get(obj.get("flag", ""), false)
		"collect":
			return inventory.has(obj.get("item", ""))
	return false

## True when every auto-checkable objective is met AND the quest has no
## manual (scene/talk/hack) objectives left unmet.
static func all_objectives_done(quest_id: String, flags: Dictionary, inventory: Array) -> bool:
	var q := get_quest(quest_id)
	if q.is_empty():
		return false
	for obj in q.get("objectives", []):
		var t: String = obj.get("type", "")
		if t == "flag" or t == "collect":
			if not objective_done(obj, flags, inventory):
				return false
		else:
			return false   # manual objective — scene code must complete it
	return true
