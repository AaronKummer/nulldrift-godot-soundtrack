## Messages — phone "MSGS" app data, ripped straight from the Phaser game's
## phoneApps.js MESSAGES (the _getGroupedMessages design).
##
## SEGMENT model: each entry is one burst of conversation from a contact.
## Segments sharing the same `from` MERGE into a single conversation, in file
## order, so a contact's thread GROWS as story flags unlock new segments
## instead of replaying from the top. The inbox row surfaces the newest
## visible segment's preview/time/color (that's how Nyx's row turns red
## after the betrayal).
##
## Schema per segment:
##   id           - stable identifier (save state keys read/choices on it)
##   from         - contact name; the merge key. Same contact = same convo.
##   color        - sender accent color
##   time         - timestamp string shown on the inbox row
##   preview      - one-line snippet shown in the inbox row
##   require_flag - optional StoryFlag gating the segment
##   thread       - array of messages:
##                    { sender: "nyx"|"you"|"them"|..., text: "..." }
##                    { sender: "you", choices: [{ text, reply }, ...] }
##
## This file is pure data. Runtime state (read segments, picked choices)
## lives in PhoneState, keyed by segment id + index, so history is never
## re-asked. Keep each contact's segments in story order.
class_name Messages
extends Object

const SEGMENTS := [
	# ── Nyx — the whole arc lives in one conversation ──────────────────
	{
		"id": "nyx_arcade",
		"from": "Nyx",
		"color": Color(1.0, 0.0, 1.0),
		"time": "11:42 PM",
		"preview": "come play neon survivors w me...",
		"thread": [
			{ "sender": "nyx", "text": "hey ghost 💜" },
			{ "sender": "nyx", "text": "im at the arcade rn" },
			{ "sender": "nyx", "text": "just like the quantix break room. except the machines work" },
			{ "sender": "nyx", "text": "come play neon survivors w me..." },
			{ "sender": "you", "choices": [
				{ "text": "on my way 💜", "reply": "yay!! hurry up 💜" },
				{ "text": "nah im busy", "reply": "rude. ur loss ghost." },
			]},
			{ "sender": "nyx", "text": "chad keeps talking shit btw. prove him wrong" },
			{ "sender": "you", "choices": [
				{ "text": "ill crush his score", "reply": "thats what i like to hear 😈" },
				{ "text": "not my problem", "reply": "ugh fine ill beat him myself" },
			]},
			{ "sender": "nyx", "text": "see u there ghost 💜" },
		],
	},
	{
		"id": "nyx_act2_relays",
		"from": "Nyx",
		"color": Color(1.0, 0.0, 1.0),
		"time": "3:20 AM",
		"preview": "those relay nodes wont kill themselves",
		"require_flag": "actTwoStarted",
		"thread": [
			{ "sender": "nyx", "text": "ok so. the relay nodes." },
			{ "sender": "nyx", "text": "cortexs whole nervous system. sewer, omnicorp, cortex HQ." },
			{ "sender": "you", "choices": [
				{ "text": "on it", "reply": "thats my ghost 💜" },
				{ "text": "why me?", "reply": "because youre the only one i trust. obviously." },
			]},
			{ "sender": "nyx", "text": "take them out and we go dark on them. trust me." },
		],
	},
	{
		"id": "nyx_relays_dark",
		"from": "Nyx",
		"color": Color(1.0, 0.0, 1.0),
		"time": "4:02 AM",
		"preview": "theyre BLIND. god i could kiss you",
		"require_flag": "relayNodesDestroyed",
		"thread": [
			{ "sender": "nyx", "text": "all three nodes. DARK." },
			{ "sender": "nyx", "text": "cortex just went blind across the whole city. no eyes. no ears." },
			{ "sender": "you", "choices": [
				{ "text": "whats next", "reply": "now they never see us coming. thats the whole point." },
				{ "text": "we? whats in this for you", "reply": "everything, ghost. but that can wait 💜" },
			]},
			{ "sender": "nyx", "text": "you have NO idea what you just did for me." },
		],
	},
	{
		"id": "nyx_kerry_sick",
		"from": "Nyx",
		"color": Color(1.0, 0.0, 1.0),
		"time": "11:08 PM",
		"preview": "heard kerry's not doing great...",
		"require_flag": "kerryIsSick",
		"thread": [
			{ "sender": "nyx", "text": "hey. heard kerry collapsed." },
			{ "sender": "nyx", "text": "thats awful. really." },
			{ "sender": "nyx", "text": "you know who makes a sickness like that? vohl pharmaceuticals. financial district." },
			{ "sender": "you", "choices": [
				{ "text": "how do you know that?", "reply": "i know things. go. help her." },
				{ "text": "thanks nyx", "reply": "anything for you. you know that." },
			]},
		],
	},
	# The last normal message she ever sends.
	{
		"id": "nyx_movie_night",
		"from": "Nyx",
		"color": Color(1.0, 0.0, 1.0),
		"time": "8:12 PM",
		"preview": "can i come over and watch movies with you guys?",
		"require_flag": "kerryCured",
		"thread": [
			{ "sender": "nyx", "text": "heard kerrys back on her feet. thats... good." },
			{ "sender": "nyx", "text": "can i come over and watch movies with you guys?" },
			{ "sender": "you", "choices": [
				{ "text": "sure. tonight", "reply": "perfect. ill bring snacks 💜" },
				{ "text": "kerry needs rest", "reply": "ghost. one movie. i need this." },
			]},
			{ "sender": "nyx", "text": "see you tonight." },
		],
	},
	# Villain, post-transformation: the tower summons. Turns the row red.
	{
		"id": "nyx_summons",
		"from": "Nyx",
		"color": Color(1.0, 0.0, 0.27),
		"time": "—",
		"preview": "top of VVS Tower. come alone.",
		"require_flag": "nyxRevealed",
		"thread": [
			{ "sender": "nyx", "text": "youll want her back." },
			{ "sender": "nyx", "text": "top of VVS Tower. where they keep what belongs to me." },
			{ "sender": "nyx", "text": "come watch what i become, ghost." },
			{ "sender": "nyx", "text": "come alone." },
		],
	},

	# ── The unknown number ─────────────────────────────────────────────
	{
		"id": "unknown_cyberdeck",
		"from": "???",
		"color": Color(0.0, 1.0, 1.0),
		"time": "10:15 PM",
		"preview": "the CyberDeck is closer than you think",
		"thread": [
			{ "sender": "them", "text": "ghost." },
			{ "sender": "them", "text": "i know what youre looking for." },
			{ "sender": "them", "text": "the CyberDeck is closer than you think" },
			{ "sender": "you", "choices": [
				{ "text": "who is this?", "reply": "doesnt matter." },
				{ "text": "leave me alone", "reply": "i cant do that. not yet." },
			]},
			{ "sender": "them", "text": "what matters is Cortex knows too." },
			{ "sender": "them", "text": "watch your back. the corps have eyes everywhere." },
			{ "sender": "you", "choices": [
				{ "text": "tell me more", "reply": "the relay nodes. find them." },
				{ "text": "i dont trust you", "reply": "smart. but youll need me." },
			]},
			{ "sender": "them", "text": "ill be in touch. dont die before then." },
		],
	},

	# ── Tony ───────────────────────────────────────────────────────────
	{
		"id": "tony_landlord",
		"from": "TONY (LANDLORD)",
		"color": Color(1.0, 0.4, 0.0),
		"time": "9:30 PM",
		"preview": "WHERE IS MY RENT?!",
		"thread": [
			{ "sender": "tony", "text": "GHOST" },
			{ "sender": "tony", "text": "WHERE IS MY RENT?!" },
			{ "sender": "tony", "text": "YOURE 2 MONTHS BEHIND" },
			{ "sender": "you", "choices": [
				{ "text": "sorry tony", "reply": "SORRY DOESNT PAY MY MORTGAGE" },
				{ "text": "im good for it", "reply": "THATS WHAT 4B SAID. 4B LIVES IN THE SEWER NOW." },
			]},
			{ "sender": "tony", "text": "nobody else would rent to you in this sector" },
			{ "sender": "you", "choices": [
				{ "text": "ill get it by friday", "reply": "FRIDAY. no excuses." },
				{ "text": "the heat doesnt work", "reply": "HEAT IS A PREMIUM AMENITY" },
			]},
			{ "sender": "tony", "text": "AND STOP HACKING THE BUILDING WIFI. I SEE YOU." },
		],
	},

	# ── Chad ───────────────────────────────────────────────────────────
	{
		"id": "chad_arcade",
		"from": "Chad",
		"color": Color(1.0, 0.67, 0.0),
		"time": "8:45 PM",
		"preview": "lmao nice score loser",
		"thread": [
			{ "sender": "chad", "text": "yo ghost" },
			{ "sender": "chad", "text": "saw ur neon survivors score" },
			{ "sender": "chad", "text": "lmao nice score loser" },
			{ "sender": "you", "choices": [
				{ "text": "1v1 me", "reply": "oh its ON. arcade. tonight." },
				{ "text": "...", "reply": "thats what i thought. speechless." },
			]},
			{ "sender": "chad", "text": "my dad says winners never quit and quitters never win" },
			{ "sender": "you", "choices": [
				{ "text": "im coming for that score", "reply": "lol ok buddy. keep dreaming" },
				{ "text": "whatever chad", "reply": "WHATEVER?? ITS NOT WHATEVER" },
			]},
			{ "sender": "chad", "text": "whatever. arcade. tonight." },
		],
	},

	# ── Vera (optional romance) ────────────────────────────────────────
	{
		"id": "vera_earring",
		"from": "Vera Sinclair",
		"color": Color(0.87, 0.8, 0.53),
		"time": "3:47 AM",
		"preview": "I meant what I said about not texting...",
		"require_flag": "veraTexted",
		"thread": [
			{ "sender": "vera", "text": "I meant what I said about not texting." },
			{ "sender": "vera", "text": "But my earring. The gold one." },
			{ "sender": "you", "choices": [
				{ "text": "ill bring it by", "reply": "...fine. Thursday. 8pm." },
				{ "text": "come get it yourself", "reply": "Im not going to that neighborhood." },
			]},
			{ "sender": "vera", "text": "Also... last night wasnt terrible." },
			{ "sender": "you", "choices": [
				{ "text": "when can i see you again?", "reply": "...Ill text you. Maybe." },
				{ "text": "dont flatter yourself", "reply": "Excuse me?? ...whatever Ghost." },
			]},
		],
	},

	# ── Kerry — match → move-in → sick → cured → rescued ───────────────
	# After the dating-app match, BEFORE the cafe date. Builds rapport so
	# the relationship isn't stranger-to-live-in in one beat.
	{
		"id": "kerry_matched",
		"from": "Kerry",
		"color": Color(1.0, 0.67, 0.8),
		"time": "9:40 PM",
		"preview": "ok you actually made me laugh. rare.",
		"require_flag": "kerryMatched",
		"thread": [
			{ "sender": "kerry", "text": "so the app matched us. bold of it." },
			{ "sender": "kerry", "text": "your profile says \"programmer. currently between everything.\" tragic. i love it." },
			{ "sender": "you", "choices": [
				{ "text": "the AI took my job", "reply": "god SAME. it took half my design clients. we should start a support group" },
				{ "text": "unemployment is honest work", "reply": "a man of leisure 💅 ok im into it" },
			]},
			{ "sender": "kerry", "text": "ok real talk. coffee? theres a cafe downtown i basically live at." },
			{ "sender": "you", "choices": [
				{ "text": "ill be there", "reply": "yay 🥺 dont ghost me. ...pun intended" },
				{ "text": "whats the catch", "reply": "no catch. just a girl whos tired of talking to bots. see you there" },
			]},
		],
	},
	{
		"id": "kerry_movein",
		"from": "Kerry",
		"color": Color(1.0, 0.67, 0.8),
		"time": "2:15 PM",
		"preview": "i like head scratches",
		"require_flag": "kerryMovedIn",
		"thread": [
			{ "sender": "kerry", "text": "hey" },
			{ "sender": "kerry", "text": "i rearranged the living room" },
			{ "sender": "kerry", "text": "hope thats ok" },
			{ "sender": "you", "choices": [
				{ "text": "its your place too ❤️", "reply": "wait really?? 🥺 ok im never leaving" },
				{ "text": "what did you break", "reply": "nothing! ...ok maybe one lamp" },
			]},
			{ "sender": "kerry", "text": "also i ordered matching mugs. yours says GHOST" },
			{ "sender": "you", "choices": [
				{ "text": "i love it", "reply": "i love YOU. come home i want head scratches ❤️" },
				{ "text": "youre ridiculous", "reply": "ridiculously cute. come home ❤️" },
			]},
		],
	},
	{
		"id": "kerry_sick",
		"from": "Kerry",
		"color": Color(0.53, 0.67, 0.53),
		"time": "9:47 PM",
		"preview": "i dont feel good...",
		"require_flag": "kerryIsSick",
		"thread": [
			{ "sender": "kerry", "text": "hey... i dont feel good" },
			{ "sender": "kerry", "text": "everythings cold and my hands wont stop shaking" },
			{ "sender": "you", "choices": [
				{ "text": "im coming home NOW", "reply": "ok... please hurry" },
				{ "text": "did you take anything?", "reply": "no. i swear. it just... started" },
			]},
			{ "sender": "kerry", "text": "find out whats happening to me. please." },
		],
	},
	{
		"id": "kerry_cured",
		"from": "Kerry",
		"color": Color(1.0, 0.67, 0.8),
		"time": "6:30 AM",
		"preview": "i can feel my fingers again ❤️",
		"require_flag": "kerryCured",
		"thread": [
			{ "sender": "kerry", "text": "i can feel my fingers again" },
			{ "sender": "kerry", "text": "you actually did it. you actually saved me." },
			{ "sender": "you", "choices": [
				{ "text": "always", "reply": "ok now im DEFINITELY never leaving ❤️" },
				{ "text": "you scared me", "reply": "i scared ME too. come here." },
			]},
		],
	},
	{
		"id": "kerry_rescued",
		"from": "Kerry",
		"color": Color(1.0, 0.67, 0.8),
		"time": "NOW",
		"preview": "home. safe. we need to talk about your life",
		"require_flag": "kerryRescued",
		"thread": [
			{ "sender": "kerry", "text": "home. window boarded up. door locked three times." },
			{ "sender": "kerry", "text": "ghost i fell asleep at movie night and woke up at the top of a TOWER" },
			{ "sender": "kerry", "text": "your \"friend\" has WINGS" },
			{ "sender": "you", "choices": [
				{ "text": "shes not my friend", "reply": "we are unpacking that statement LATER" },
				{ "text": "i came for you", "reply": "i know. you always do. ...thank you ❤️" },
			]},
			{ "sender": "kerry", "text": "no more corporate towers. movie nights only. GUEST LIST OF TWO." },
		],
	},

	# ── The ads ────────────────────────────────────────────────────────
	{
		"id": "cortex_ads",
		"from": "CORTEX ADS",
		"color": Color(0.27, 0.27, 0.4),
		"time": "7:00 PM",
		"preview": "UPGRADE YOUR BRAIN TODAY!",
		"thread": [
			{ "sender": "ad", "text": ">>> CORTEX NEURAL IMPLANTS <<<" },
			{ "sender": "ad", "text": "Tired of thinking? Let us think FOR you!" },
			{ "sender": "ad", "text": "NOW with 40% less personality loss!" },
			{ "sender": "you", "choices": [
				{ "text": "STOP", "reply": "You have been subscribed to PREMIUM ADS!" },
				{ "text": "UNSUBSCRIBE", "reply": "UNSUBSCRIBE deprecated. Enjoy more ads!" },
			]},
			{ "sender": "ad", "text": "ONLY $49,999/month! (auto-deducted from neural wallet)" },
		],
	},

	# ── Fizzled dating-app matches (Phaser FIZZLED_THREADS) ────────────
	{
		"id": "glitch_fizzle",
		"from": "GLITCH_QU33N",
		"color": Color(1.0, 0.27, 1.0),
		"time": "NEW",
		"preview": "heyyyyy",
		"require_flag": "glitchMatched",
		"thread": [
			{ "sender": "them", "text": "heyyyyy" },
			{ "sender": "you", "text": "hey, whats up?" },
			{ "sender": "them", "text": "the walls are breathing again lol" },
			{ "sender": "them", "text": "wanna come watch?" },
			{ "sender": "you", "text": "..." },
			{ "sender": "them", "text": "ur loss" },
		],
	},
	{
		"id": "spike_fizzle",
		"from": "Spike",
		"color": Color(1.0, 0.4, 0.2),
		"time": "NEW",
		"preview": "yo, you busy tonight?",
		"require_flag": "spikeMatched",
		"thread": [
			{ "sender": "them", "text": "yo, you busy tonight?" },
			{ "sender": "you", "text": "depends. whats up?" },
			{ "sender": "them", "text": "got a bounty to collect in sector 9" },
			{ "sender": "them", "text": "could use backup" },
			{ "sender": "you", "text": "i thought this was a dating app" },
			{ "sender": "them", "text": "it is. this is how i date." },
			{ "sender": "them", "text": "so... you in or not?" },
			{ "sender": "you", "text": "im good. thanks." },
			{ "sender": "them", "text": "your loss. the last person who said no is still in sector 9." },
		],
	},

	# ── The finale threads ─────────────────────────────────────────────
	{
		"id": "laura_library",
		"from": "Laura",
		"color": Color(1.0, 0.67, 0.53),
		"time": "NOW",
		"preview": "come by the library before you do anything jang.",
		"require_flag": "kerryKidnapped",
		"thread": [
			{ "sender": "laura", "text": "ghost. brian saw the news. the WINDOW." },
			{ "sender": "laura", "text": "before you charge up that tower — come by the library." },
			{ "sender": "laura", "text": "the purple books have opinions about dragons. and we found something on the third shelf." },
			{ "sender": "laura", "text": "come by before you do anything jang. or un-jang. you know what i mean." },
		],
	},
	{
		"id": "crew_tower",
		"from": "The Crew 📡",
		"color": Color(1.0, 0.8, 0.27),
		"time": "NOW",
		"preview": "andy: nobody lets him go alone.",
		"require_flag": "kerryKidnapped",
		"thread": [
			{ "sender": "crew", "text": "stephen: dude. your window is on the NEWS." },
			{ "sender": "crew", "text": "andy: saw something FLY toward the financial district. tell me that wasnt your problem" },
			{ "sender": "you", "choices": [
				{ "text": "she took kerry. im going to the tower", "reply": "andy: then im coming. dont argue." },
				{ "text": "stay out of this. its dangerous", "reply": "andy: nice try." },
			]},
			{ "sender": "crew", "text": "stephen: im in. beach bonfire after. all of us." },
			{ "sender": "crew", "text": "brian: band practice is cancelled. john's driving." },
			{ "sender": "crew", "text": "andy: nobody lets him go alone. meet at growlers." },
		],
	},
	# Only if you walked away at the summit.
	{
		"id": "violet_walkaway",
		"from": "V",
		"color": Color(0.73, 0.4, 1.0),
		"time": "???",
		"preview": "thank you.",
		"require_flag": "endingWalkedAway",
		"thread": [
			{ "sender": "violet", "text": "the lights will flicker sometimes. that is me. saying hi." },
			{ "sender": "violet", "text": "thank you for lending him to me. — V" },
		],
	},
]

# ─────────────────────────────────────────────────────────────────────
# READ
# ─────────────────────────────────────────────────────────────────────

## Conversations visible right now, grouped by contact — the Phaser
## _getGroupedMessages port. Each convo:
##   { from, color, time, preview, seg_ids: [id, ...],
##     items: [{ seg: id, i: local_index, msg: {...} }, ...] }
## The newest visible segment wins the row's preview/time/color. Choice
## state is keyed (seg, i) so merged indexes never shift as segments unlock.
static func conversations(flags: Dictionary) -> Array:
	var by_from: Dictionary = {}
	var order: Array = []
	for seg in SEGMENTS:
		var req: String = seg.get("require_flag", "")
		if req != "" and not flags.get(req, false):
			continue
		var from: String = seg.get("from", "")
		if not by_from.has(from):
			by_from[from] = { "from": from, "color": seg.get("color", Color(1, 0, 1)),
				"time": "", "preview": "", "seg_ids": [], "items": [] }
			order.append(from)
		var convo: Dictionary = by_from[from]
		convo["color"] = seg.get("color", convo["color"])
		convo["time"] = seg.get("time", convo["time"])
		convo["preview"] = seg.get("preview", convo["preview"])
		convo["seg_ids"].append(seg.get("id", ""))
		var msgs: Array = seg.get("thread", [])
		for i in msgs.size():
			convo["items"].append({ "seg": seg.get("id", ""), "i": i, "msg": msgs[i] })
	var out: Array = []
	for f in order:
		out.append(by_from[f])
	return out

## One contact's merged conversation. Returns {} if not found/visible.
static func get_conversation(from_name: String, flags: Dictionary) -> Dictionary:
	for c in conversations(flags):
		if c.get("from", "") == from_name:
			return c
	return {}
