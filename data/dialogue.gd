## Dialogue trees — port of hacking-game/src/data/dialogueTrees.js.
##
## Each NPC has an array of branches { condition, lines }. First branch whose
## condition matches GameState.flags wins. Lines are { speaker, text, color }.
## condition fields: { "flag": "x", "not_flag": "y", "quest": "id", "state": "ACTIVE" }
class_name Dialogue
extends Object

const TREES := {
	"roz": [
		# After the sewer relay: Roz knows things
		{
			"condition": { "flag": "sewerRelayFound" },
			"lines": [
				{ "speaker": "ROZ", "text": "you went down there. i can smell it. don't sit on the good stool.", "color": Color(1.0, 0.55, 0.3) },
				{ "speaker": "ROZ", "text": "that relay you cracked wasn't city property. somebody paid to keep it humming.", "color": Color(1.0, 0.55, 0.3) },
				{ "speaker": "ROZ", "text": "somebody's going to notice. drink while it's quiet.", "color": Color(1.0, 0.55, 0.3) },
			],
		},
		# After beating Chad
		{
			"condition": { "flag": "chadBeaten" },
			"lines": [
				{ "speaker": "ROZ", "text": "heard you took the survivors crown off that kid chad.", "color": Color(1.0, 0.55, 0.3) },
				{ "speaker": "ROZ", "text": "he came in after. ordered a volt cola. didn't finish it.", "color": Color(1.0, 0.55, 0.3) },
				{ "speaker": "", "text": "She almost smiles. The neon flickers.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
		# Default
		{
			"condition": null,
			"lines": [
				{ "speaker": "ROZ", "text": "pizza kid. you drinking or loitering? both is extra.", "color": Color(1.0, 0.55, 0.3) },
				{ "speaker": "ROZ", "text": "the suit's on his fourth. the regular never orders. the shark cheats.", "color": Color(1.0, 0.55, 0.3) },
				{ "speaker": "ROZ", "text": "everything worth knowing in this city gets said at this counter eventually.", "color": Color(1.0, 0.55, 0.3) },
			],
		},
	],

	"laura": [
		{
			"condition": { "flag": "guildDiscovered" },
			"lines": [
				{ "speaker": "LAURA", "text": "you found the rare books section.", "color": Color(0.75, 0.6, 1.0) },
				{ "speaker": "LAURA", "text": "i was starting to think nobody in this city could read.", "color": Color(0.75, 0.6, 1.0) },
				{ "speaker": "", "text": "She stamps a return card that has nothing on it.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
		{
			"condition": null,
			"lines": [
				{ "speaker": "LAURA", "text": "quiet please. the books prefer it.", "color": Color(0.75, 0.6, 1.0) },
				{ "speaker": "LAURA", "text": "somebody keeps shelving spellbooks in the fiction section. they keep reshelving themselves.", "color": Color(0.75, 0.6, 1.0) },
				{ "speaker": "LAURA", "text": "if you find one, it belongs in rare books. we don't have a rare books section.", "color": Color(0.75, 0.6, 1.0) },
			],
		},
	],

	"brian": [
		{
			"condition": null,
			"lines": [
				{ "speaker": "BRIAN", "text": "i'm supposed to be the IT guy but half the 'technology' here runs on ACTUAL MAGIC.", "color": Color(0.4, 0.9, 1.0) },
				{ "speaker": "BRIAN", "text": "the catalog system? literal magic. i filed a ticket. the ticket caught fire.", "color": Color(0.4, 0.9, 1.0) },
				{ "speaker": "BRIAN", "text": "don't touch anything glowing in the stacks. or do. i get paid either way.", "color": Color(0.4, 0.9, 1.0) },
			],
		},
	],

	"archmage": [
		{
			"condition": { "flag": "grimoire" },
			"lines": [
				{ "speaker": "ARCHMAGE", "text": "back again. the circle remembers your footprints.", "color": Color(0.85, 0.5, 1.4) },
				{ "speaker": "ARCHMAGE", "text": "study the grimoire. spells are just code the universe forgot to deprecate.", "color": Color(0.85, 0.5, 1.4) },
			],
		},
		{
			"condition": null,
			"lines": [
				{ "speaker": "ARCHMAGE", "text": "you placed the book. good. it gets restless when it's misfiled.", "color": Color(0.85, 0.5, 1.4) },
				{ "speaker": "ARCHMAGE", "text": "welcome to rare books. membership is automatic and non-refundable.", "color": Color(0.85, 0.5, 1.4) },
				{ "speaker": "ARCHMAGE", "text": "check your phone. we installed something. the paperwork signed itself.", "color": Color(0.85, 0.5, 1.4) },
				{ "speaker": "", "text": "The GRIMOIRE app shimmers onto your home screen.", "color": Color(0.7, 0.4, 1.2) },
			],
		},
	],

	"zee": [
		{
			"condition": null,
			"lines": [
				{ "speaker": "ZEE", "text": "first time? perfect tommy nights get loud. godsnack nights get weird.", "color": Color(1.0, 0.4, 0.9) },
				{ "speaker": "ZEE", "text": "aaron killed it on the ultranova last week. brian's voice is unreal live.", "color": Color(1.0, 0.4, 0.9) },
				{ "speaker": "ZEE", "text": "greg? greg once played a forty minute song about a parking structure. people cried.", "color": Color(1.0, 0.4, 0.9) },
				{ "speaker": "", "text": "The bass hits so hard your fillings vibrate.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
	],

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

	"chad": [
		{
			"condition": { "flag": "chadBeaten" },
			"lines": [
				{ "speaker": "CHAD", "text": "Whatever dude, I wasn't even trying.", "color": Color(0.87, 0.80, 0.53) },
				{ "speaker": "CHAD", "text": "I could beat that score in my sleep.", "color": Color(0.87, 0.80, 0.53) },
			],
		},
		{
			"condition": null,
			"lines": [
				{ "speaker": "CHAD", "text": "Oh great, the unemployed ghost is here.", "color": Color(0.87, 0.80, 0.53) },
				{ "speaker": "CHAD", "text": "My high score is 3000. Good luck beating THAT, loser.", "color": Color(0.87, 0.80, 0.53) },
				{ "speaker": "", "text": "He doesn't take his eyes off NEON SURVIVORS the whole time.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
	],

	"nyx_arcade": [
		{
			"condition": { "flag": "chadBeaten" },
			"lines": [
				{ "speaker": "NYX", "text": "Not bad... not bad at all.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Maybe you're not just a delivery boy after all.", "color": Color(1.0, 0.53, 0.8) },
			],
		},
		{
			"condition": null,
			"lines": [
				{ "speaker": "NYX", "text": "Don't mind Chad, he's all talk.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Show me what you've got.", "color": Color(1.0, 0.53, 0.8) },
			],
		},
	],

	"blitz": [
		{
			"condition": null,
			"lines": [
				{ "speaker": "BLITZ", "text": "You look fast. Wanna race?", "color": Color(1.0, 0.53, 0.0) },
				{ "speaker": "BLITZ", "text": "Three laps, five credits. Think you can hang?", "color": Color(1.0, 0.53, 0.0) },
				{ "speaker": "", "text": "He pats the second racing pod. The screen is dead.", "color": Color(0.53, 0.53, 0.53) },
				{ "speaker": "BLITZ", "text": "...soon as they fix the link, anyway.", "color": Color(1.0, 0.53, 0.0) },
			],
		},
	],

	"arcade_drifter": [
		{
			"condition": null,
			"lines": [
				{ "speaker": "DRIFTER", "text": "the vending machine ate my last cred in 2047.", "color": Color(0.6, 0.65, 0.7) },
				{ "speaker": "DRIFTER", "text": "I'm still here. it knows what it did.", "color": Color(0.6, 0.65, 0.7) },
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
