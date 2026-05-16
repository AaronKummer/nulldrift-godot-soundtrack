## Dialogue trees — port of hacking-game/src/data/dialogueTrees.js.
##
## Each NPC has an array of branches { condition, lines }. First branch whose
## condition matches GameState.flags wins. Lines are { speaker, text, color }.
## condition fields: { "flag": "x", "not_flag": "y", "quest": "id", "state": "ACTIVE" }
class_name Dialogue
extends Object

const TREES := {
	"apartment_cat": [
		{
			"condition": null,
			"lines": [
				{ "speaker": "CAT", "text": "*meow*", "color": Color(0.9, 0.65, 0.3) },
				{ "speaker": "", "text": "The cat blinks slowly, then ignores you.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
	],

	"nyx": [
		# Act 3: betrayal revealed
		{
			"condition": { "flag": "violetTruthRevealed" },
			"lines": [
				{ "speaker": "NYX", "text": "I was wondering when she'd tell you.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Everything I did, I did for us. You just couldn't see it.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Violet was mine. MY creation. MY mind uploaded into silicon.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "MegaCorp offered me the world. And I took it.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "", "text": "Her eyes flash red for a moment.", "color": Color(1.0, 0.27, 0.27) },
				{ "speaker": "NYX", "text": "Kerry's with me now. Come find me. The arcade. Where it all started.", "color": Color(1.0, 0.0, 0.27) },
			],
		},
		# Act 2: relay nodes
		{
			"condition": { "flag": "actTwoStarted", "not_flag": "relayNodesDestroyed" },
			"lines": [
				{ "speaker": "NYX", "text": "Those relay nodes are MegaCorp's nervous system.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "One in the sewers. One in OmniCorp. One in MegaCorp HQ.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Take them all out and we blind them.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "", "text": "She smiles. It doesn't quite reach her eyes.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
		# Act 1: original diner meeting
		{
			"condition": { "quest": "dinerMeeting", "state": "ACTIVE" },
			"lines": [
				{ "speaker": "NYX", "text": "Hey. You're the one from the ATM, right?", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "I saw what you did with that CyberDeck. Not bad for a pizza guy.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Name's Nyx. I need someone with your... talents.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "The Chrome Jackals. They've been terrorizing this block.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Their boss, Rezz, holes up in the parking garage on the east side.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Clear them out. I'll make it worth your while.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "", "text": "Nyx slides 500 credits across the table.", "color": Color(0.27, 1.0, 0.53) },
			],
		},
		# Fallback
		{
			"condition": null,
			"lines": [
				{ "speaker": "NYX", "text": "Not now. Come back when something interesting happens.", "color": Color(1.0, 0.53, 0.8) },
			],
		},
	],

	"tony": [
		{
			"condition": { "not_flag": "leftApartment" },
			"lines": [
				{ "speaker": "TONY", "text": "You're late again, kid.", "color": Color(1.0, 0.6, 0.2) },
				{ "speaker": "TONY", "text": "Twelve deliveries. Don't burn 'em.", "color": Color(1.0, 0.6, 0.2) },
			],
		},
		{
			"condition": null,
			"lines": [
				{ "speaker": "TONY", "text": "Got nothin' for ya right now. Try later.", "color": Color(1.0, 0.6, 0.2) },
			],
		},
	],
}

static func resolve(npc_id: String, flags: Dictionary, active_quest: String = "",
		quest_state: String = "") -> Array:
	var tree: Array = TREES.get(npc_id, [])
	for branch in tree:
		if _matches(branch.get("condition"), flags, active_quest, quest_state):
			return branch.get("lines", [])
	return []

static func _matches(cond: Variant, flags: Dictionary, active_quest: String,
		quest_state: String) -> bool:
	if cond == null:
		return true
	if cond.has("flag") and not flags.get(cond["flag"], false):
		return false
	if cond.has("not_flag") and flags.get(cond["not_flag"], false):
		return false
	if cond.has("quest") and cond["quest"] != active_quest:
		return false
	if cond.has("state") and cond["state"] != quest_state:
		return false
	return true
