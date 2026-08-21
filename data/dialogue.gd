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

	"miko": [
		{
			"condition": { "flag": "mikoHome" },
			"lines": [
				{ "speaker": "MIKO", "text": "you again. good. sit. i already ordered for you.", "color": Color(1.0, 0.6, 0.75) },
				{ "speaker": "MIKO", "text": "i told the tower recruiter no this morning. out loud. in public.", "color": Color(1.0, 0.6, 0.75) },
				{ "speaker": "", "text": "Under the table, her hand finds yours like it's been doing it for years.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
		{
			"condition": { "flag": "mikoWarm" },
			"lines": [
				{ "speaker": "MIKO", "text": "sake again? you're either interested or an expense account.", "color": Color(1.0, 0.6, 0.75) },
				{ "speaker": "MIKO", "text": "eight years in compliance. i signed things that outlive both of us. don't look impressed.", "color": Color(1.0, 0.6, 0.75) },
				{ "speaker": "MIKO", "text": "my place has a real window. actual sky. you should verify that. tonight.", "color": Color(1.0, 0.6, 0.75) },
				{ "speaker": "", "text": "She's already standing. Compliance never asks twice.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
		{
			"condition": { "flag": "mikoMet" },
			"lines": [
				{ "speaker": "MIKO", "text": "still here? most people see the corpo posture and pick another table.", "color": Color(1.0, 0.6, 0.75) },
				{ "speaker": "MIKO", "text": "buy the next round and i might tell you what i did at omnicorp.", "color": Color(1.0, 0.6, 0.75) },
			],
		},
		{
			"condition": null,
			"lines": [
				{ "speaker": "MIKO", "text": "if you're selling something, the answer is no. if you're the pizza guy, you're very lost.", "color": Color(1.0, 0.6, 0.75) },
				{ "speaker": "MIKO", "text": "...you're not leaving. fine. miko. formerly omnicorp compliance. currently drinking.", "color": Color(1.0, 0.6, 0.75) },
				{ "speaker": "", "text": "She pours herself another and, after a beat, gestures at the empty seat.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
	],

	"kerry_date": [
		{
			"condition": null,
			"lines": [
				{ "speaker": "KERRY", "text": "you came! i was worried you'd ghost me. ...pun intended.", "color": Color(1.0, 0.55, 0.6) },
				{ "speaker": "GHOST", "text": "couldn't resist. you had me at 'not a bot.'", "color": Color(0.4, 1.0, 0.9) },
				{ "speaker": "KERRY", "text": "so... an unemployed programmer. bold of you to put that in the bio.", "color": Color(1.0, 0.55, 0.6) },
				{ "speaker": "GHOST", "text": "the AI took the job. figured honesty was the only thing it couldn't automate.", "color": Color(0.4, 1.0, 0.9) },
				{ "speaker": "KERRY", "text": "*laughs* i lost half my design clients to AI too. we're both dinosaurs.", "color": Color(1.0, 0.55, 0.6) },
				{ "speaker": "GHOST", "text": "i'm building a game though. vibe coding it with the AI.", "color": Color(0.4, 1.0, 0.9) },
				{ "speaker": "KERRY", "text": "wait — you're using the thing that replaced you to build something new?", "color": Color(1.0, 0.55, 0.6) },
				{ "speaker": "KERRY", "text": "that's either genius or insane.", "color": Color(1.0, 0.55, 0.6) },
				{ "speaker": "GHOST", "text": "why not both?", "color": Color(0.4, 1.0, 0.9) },
				{ "speaker": "KERRY", "text": "*smiles* i like you, ghost. ...aaron. can i call you aaron?", "color": Color(1.0, 0.55, 0.6) },
				{ "speaker": "", "text": "It's the third time this week you've shut this cafe down together. The texts never really stopped.", "color": Color(0.53, 0.53, 0.53) },
				{ "speaker": "KERRY", "text": "ok. insane idea. my lease is up, my place is a shoebox, and i hate going home when you're here.", "color": Color(1.0, 0.55, 0.6) },
				{ "speaker": "KERRY", "text": "move in with me. tell me it's too fast. then say yes anyway.", "color": Color(1.0, 0.55, 0.6) },
				{ "speaker": "GHOST", "text": "it's too fast. ...yes.", "color": Color(0.4, 1.0, 0.9) },
				{ "speaker": "", "text": "The coffee gets cold. Neither of you notices.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
	],

	"bulletin_board": [
		{
			"condition": null,
			"lines": [
				{ "speaker": "BULLETIN BOARD", "text": "LOST: one cybernetic arm. responds to the name 'lefty'. reward.", "color": Color(0.9, 0.85, 0.7) },
				{ "speaker": "BULLETIN BOARD", "text": "FOR SALE: slightly used neural implant. only crashed twice.", "color": Color(0.9, 0.85, 0.7) },
				{ "speaker": "BULLETIN BOARD", "text": "WANTED: someone to fix my smart fridge. it keeps ordering pizza.", "color": Color(0.9, 0.85, 0.7) },
				{ "speaker": "BULLETIN BOARD", "text": "BAND LOOKING FOR DRUMMER: must have at least 2 organic arms.", "color": Color(0.9, 0.85, 0.7) },
				{ "speaker": "BULLETIN BOARD", "text": "FREE KITTENS: warning — may be slightly irradiated.", "color": Color(0.9, 0.85, 0.7) },
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

	# ── NYX — the diner meeting and its Act 1 follow-ups (Phaser canon,
	# ordered most-progressed first so the right branch resolves). She sits
	# at booth two in HANK'S DINER; talking advances the story. ──────────
	"nyx_diner": [
		# After the secured-terminal hack: she reads the relay data, closes Act 1
		{
			"condition": { "flag": "securedTerminalHacked", "not_flag": "actOneComplete" },
			"lines": [
				{ "speaker": "NYX", "text": "You got the data? Let me see...", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Relay node coordinates. The Jackals were guarding Cortex hardware.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "There are more of these across the city. This is bigger than we thought.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "I know someone on the inside. Let me dig around.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "", "text": "Your phone buzzes. A message from an unknown number.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
		# After clearing the garage: she sends you to hack the terminal
		{
			"condition": { "flag": "garageCleared", "not_flag": "securedTerminalHacked" },
			"lines": [
				{ "speaker": "NYX", "text": "You actually did it. Rezz ran like a coward.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "But the Jackals... they're connected to something bigger.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "I need you to hack into one of their secured terminals. Get me intel.", "color": Color(1.0, 0.53, 0.8) },
			],
		},
		# Met her, still hasn't cleared the garage
		{
			"condition": { "flag": "metCyberGirl", "not_flag": "garageCleared" },
			"lines": [
				{ "speaker": "NYX", "text": "Still here? Go check out that garage I told you about.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "And be careful. Rezz doesn't play nice.", "color": Color(1.0, 0.53, 0.8) },
			],
		},
		# THE MEETING — first sit-down (quest dinerMeeting active via firstHackDone)
		{
			"condition": { "flag": "firstHackDone", "not_flag": "metCyberGirl" },
			"lines": [
				{ "speaker": "???", "text": "Booth two, Ghost. ...God, you look terrible.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "GHOST", "text": "...Nyx? HR Nyx? From Quantix?", "color": Color(0.0, 1.0, 1.0) },
				{ "speaker": "NYX", "text": "EX-Quantix. They automated HR six weeks after they automated you. Karma's efficient.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "The girl at the ATM works for me. The deck landing at your feet wasn't luck. It was a test.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "I saw what you did with it. Not bad for a laid-off code monkey.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "I read your file for five years. I WROTE half of it. You're wasted on unemployment.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "There's a gang — the Chrome Jackals. They've been terrorizing this block.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Their boss, Rezz, holes up in the parking garage in the warzone.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "NYX", "text": "Clear them out. I'll make it worth your while.", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "", "text": "Nyx slides 500 credits across the table.", "color": Color(0.27, 1.0, 0.53) },
			],
		},
		# Before the first hack — she won't talk yet
		{
			"condition": null,
			"lines": [
				{ "speaker": "???", "text": "...", "color": Color(1.0, 0.53, 0.8) },
				{ "speaker": "", "text": "She doesn't seem interested in talking right now.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
	],

	# ── GUS — pet store keeper, home street ──────────────────────────────
	"gus": [
		{
			"condition": { "flag": "fish_fed" },
			"lines": [
				{ "speaker": "GUS", "text": "fish look better. see? told you it wasn't the filter.", "color": Color(0.55, 0.85, 0.5) },
				{ "speaker": "GUS", "text": "animals are easy. you feed 'em, they love you. try getting that deal from a person.", "color": Color(0.55, 0.85, 0.5) },
			],
		},
		{
			"condition": null,
			"lines": [
				{ "speaker": "GUS", "text": "pizza kid. your fish are starving and my rent is due. we can fix one of those.", "color": Color(0.55, 0.85, 0.5) },
				{ "speaker": "GUS", "text": "everything in here is legal in THIS district. don't ask about the gecko.", "color": Color(0.55, 0.85, 0.5) },
				{ "speaker": "", "text": "Something in the back room knocks over a bowl. Gus doesn't flinch.", "color": Color(0.53, 0.53, 0.53) },
			],
		},
	],

	# ── HANK — diner owner (Phaser canon lines) ──────────────────────────
	"hank": [
		{
			"condition": { "flag": "garageCleared" },
			"lines": [
				{ "speaker": "HANK", "text": "Word on the street is you took on the Chrome Jackals.", "color": Color(1.0, 0.67, 0.27) },
				{ "speaker": "HANK", "text": "Either you're brave or stupid. Probably both.", "color": Color(1.0, 0.67, 0.27) },
			],
		},
		{
			"condition": null,
			"lines": [
				{ "speaker": "HANK", "text": "Another day, another dollar. Or credit. Whatever.", "color": Color(1.0, 0.67, 0.27) },
				{ "speaker": "HANK", "text": "Stay out of trouble, kid.", "color": Color(1.0, 0.67, 0.27) },
			],
		},
	],

	# ── ROXY — diner waitress (Phaser canon lines) ───────────────────────
	"roxy": [
		{
			"condition": { "flag": "sewerRelayFound" },
			"lines": [
				{ "speaker": "ROXY", "text": "I saw you talking to that girl at the diner.", "color": Color(0.93, 0.4, 1.0) },
				{ "speaker": "ROXY", "text": "Be careful. She's got connections you don't want to know about.", "color": Color(0.93, 0.4, 1.0) },
			],
		},
		{
			"condition": null,
			"lines": [
				{ "speaker": "ROXY", "text": "This neighborhood used to be quiet. Now look at it.", "color": Color(0.93, 0.4, 1.0) },
				{ "speaker": "ROXY", "text": "At least the ramen's still good.", "color": Color(0.93, 0.4, 1.0) },
			],
		},
	],

	# ── DEX — comic shop clerk ───────────────────────────────────────────
	"dex": [
		{
			"condition": { "flag": "comicsCollector" },
			"lines": [
				{ "speaker": "DEX", "text": "full set. you actually got the full set.", "color": Color(0.4, 0.9, 1.0) },
				{ "speaker": "DEX", "text": "i've only seen one other person do that. respect.", "color": Color(0.4, 0.9, 1.0) },
			],
		},
		{
			"condition": { "flag": "chadBeaten" },
			"lines": [
				{ "speaker": "DEX", "text": "wait. you're the one who dethroned chad at survivors.", "color": Color(0.4, 0.9, 1.0) },
				{ "speaker": "DEX", "text": "he pre-ordered a figure of himself. i still have to sell it to him. don't tell him i told you.", "color": Color(0.4, 0.9, 1.0) },
			],
		},
		{
			"condition": null,
			"lines": [
				{ "speaker": "DEX", "text": "welcome to PAGE ZERO. everything's mint unless you touch it.", "color": Color(0.4, 0.9, 1.0) },
				{ "speaker": "DEX", "text": "new KING CROC dropped. it's about a guy. who is a crocodile. in the sewer. based on a true story.", "color": Color(0.4, 0.9, 1.0) },
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
