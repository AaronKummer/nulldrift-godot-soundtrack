## Messages — phone "MSGS" app data. Each thread is a conversation between
## the player and an NPC, with optional player-choice branches.
##
## Schema:
##   id           - stable identifier (used by save state for read/choice tracking)
##   from         - sender name as displayed
##   color        - sender accent color
##   time         - timestamp string ("11:42 PM")
##   preview      - one-line snippet shown in the thread list
##   require_flag - optional StoryFlag that must be set for the thread to appear
##   thread       - array of messages:
##                    { sender: "nyx"|"you"|"them"|..., text: "..." }
##                    { sender: "you", choices: [{ text, reply }, ...] }
##
## This file is pure data. Adding/removing/editing threads is a CRUD op
## against this constant. Runtime state (which threads have been read,
## which choices the player picked) lives in GameState, not here.
class_name Messages
extends Object

const THREADS := [
	{
		"id": "nyx_arcade",
		"from": "Nyx",
		"color": Color(1.0, 0.0, 1.0),
		"time": "11:42 PM",
		"preview": "come play neon survivors w me...",
		"thread": [
			{ "sender": "nyx", "text": "hey ghost 💜" },
			{ "sender": "nyx", "text": "im at the arcade rn" },
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
			{ "sender": "them", "text": "what matters is MegaCorp knows too." },
			{ "sender": "them", "text": "watch your back. the corps have eyes everywhere." },
			{ "sender": "you", "choices": [
				{ "text": "tell me more", "reply": "the relay nodes. find them." },
				{ "text": "i dont trust you", "reply": "smart. but youll need me." },
			]},
			{ "sender": "them", "text": "ill be in touch. dont die before then." },
		],
	},
	{
		"id": "tony_pizza",
		"from": "TONY'S PIZZA",
		"color": Color(1.0, 0.4, 0.0),
		"time": "9:30 PM",
		"preview": "WHERE ARE MY DELIVERIES?!",
		"thread": [
			{ "sender": "tony", "text": "GHOST" },
			{ "sender": "tony", "text": "WHERE ARE MY DELIVERIES?!" },
			{ "sender": "tony", "text": "I GOT 4 ORDERS WAITING" },
			{ "sender": "you", "choices": [
				{ "text": "sorry boss", "reply": "SORRY DOESNT DELIVER PIZZAS" },
				{ "text": "im done with pizza", "reply": "YOURE FIRED. wait. UNFIRED. get back here." },
			]},
			{ "sender": "tony", "text": "nobody else will deliver to sector 7" },
			{ "sender": "you", "choices": [
				{ "text": "fine ill come in", "reply": "DOUBLE SHIFT. no excuses." },
				{ "text": "pay me more", "reply": "DOUBLE?? I BARELY PAY YOU SINGLE" },
			]},
			{ "sender": "tony", "text": "AND BRING YOUR OWN HELMET THIS TIME" },
		],
	},
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
	{
		"id": "megacorp_ads",
		"from": "MEGACORP ADS",
		"color": Color(0.27, 0.27, 0.4),
		"time": "7:00 PM",
		"preview": "UPGRADE YOUR BRAIN TODAY!",
		"thread": [
			{ "sender": "ad", "text": ">>> MEGACORP NEURAL IMPLANTS <<<" },
			{ "sender": "ad", "text": "Tired of thinking? Let us think FOR you!" },
			{ "sender": "ad", "text": "NOW with 40% less personality loss!" },
			{ "sender": "you", "choices": [
				{ "text": "STOP", "reply": "You have been subscribed to PREMIUM ADS!" },
				{ "text": "UNSUBSCRIBE", "reply": "UNSUBSCRIBE deprecated. Enjoy more ads!" },
			]},
			{ "sender": "ad", "text": "ONLY $49,999/month! (auto-deducted from neural wallet)" },
		],
	},
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
]

# ─────────────────────────────────────────────────────────────────────
# READ
# ─────────────────────────────────────────────────────────────────────

## Threads visible right now given the player's story flags.
## Hidden threads (require_flag not set) are filtered out.
static func visible_threads(flags: Dictionary) -> Array:
	var out: Array = []
	for t in THREADS:
		var req: String = t.get("require_flag", "")
		if req == "" or flags.get(req, false):
			out.append(t)
	return out

## Find one thread by id. Returns {} if not found.
static func get_thread(id: String) -> Dictionary:
	for t in THREADS:
		if t.get("id", "") == id:
			return t
	return {}
