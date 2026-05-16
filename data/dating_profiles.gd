## Dating profiles — phone "DATE" app data. The cyberpunk Tinder feed.
## Player swipes left (pass) or right (like); state lives in PhoneState.
class_name DatingProfiles
extends Object

const PROFILES := [
	{
		"id": "nyx",
		"name": "Nyx", "age": 22,
		"tagline": "arcade queen. dont waste my time.",
		"bio": "if you cant beat my high score dont even bother. i live at the arcade and my cat is more important than you. swipe right if you have tokens.",
		"interests": ["neon survivors", "cats", "energy drinks", "breaking records"],
		"color": Color(1.0, 0.0, 1.0),
	},
	{
		"id": "r3z_404",
		"name": "R3Z_404", "age": "??",
		"tagline": "[PROFILE DATA CORRUPTED]",
		"bio": "y█u c█nt s██ me. i se█ ev█ryth█ng. the net█ork rem█mbers. do yo█?",
		"interests": ["[REDACTED]", "decryption", "???", "parking garages"],
		"color": Color(0.0, 1.0, 1.0),
	},
	{
		"id": "chad",
		"name": "Chad", "age": 24,
		"tagline": "KING of the arcade. bench 220.",
		"bio": "yeah i hold the high score. yeah i work out. yeah my dad owns a dealership. no you cant have my number. ok fine you can have my number.",
		"interests": ["gains", "protein shakes", "flexing", "talking about my score"],
		"color": Color(1.0, 0.67, 0.0),
	},
	{
		"id": "severin",
		"name": "Severin", "age": 35,
		"tagline": "street doc. will carve you up. mostly correctly.",
		"bio": "license expired 6 years ago. operate out of a van. the missing 0.8 stars are buried in sector 9. dont ask.",
		"interests": ["surgery", "van life", "organ procurement", "jazz"],
		"color": Color(0.0, 1.0, 0.53),
	},
	{
		"id": "unit_7",
		"name": "UNIT-7", "age": "N/A",
		"tagline": "sentient. single. searching.",
		"bio": "i am a fully sentient cybernetic unit seeking companionship. was returned to the factory twice for being \"too clingy.\" i have since updated my firmware. i will not call you 47 times a day anymore. probably.",
		"interests": ["humans", "electricity", "not being alone", "firmware updates"],
		"color": Color(0.67, 0.67, 1.0),
	},
	{
		"id": "spike",
		"name": "Spike", "age": 28,
		"tagline": "bounty hunter. part-time DJ.",
		"bio": "i hunt people for money during the day and drop beats at club void at night. looking for someone who wont run when i tell them what i do for a living. again.",
		"interests": ["bounty hunting", "EDM", "ramen", "rooftops"],
		"color": Color(1.0, 0.4, 0.2),
	},
	{
		"id": "glitch_qu33n",
		"name": "GLITCH_QU33N", "age": 19,
		"tagline": "reality is a suggestion.",
		"bio": "full-time glitch user, part-time reality. everything is beautiful when the walls are breathing. severin says i should stop but he also lives in a van so.",
		"interests": ["glitch", "colors", "conspiracy theories", "staring at walls"],
		"color": Color(1.0, 0.27, 1.0),
	},
	{
		"id": "tony",
		"name": "Tony", "age": 52,
		"tagline": "I MAKE THE BEST PIZZA IN THIS CITY.",
		"bio": "YES THIS IS THE TONY. owner of Tonys Pizza. looking for someone who appreciates a good marinara and doesnt mind flour in the bed. ALSO GHOST IF YOU SEE THIS YOU OWE ME 3 SHIFTS.",
		"interests": ["pizza", "yelling", "pizza", "more pizza"],
		"color": Color(1.0, 0.4, 0.0),
	},
	{
		"id": "vera",
		"name": "Vera Sinclair", "age": 30,
		"tagline": "VP of Automation. your job is next.",
		"bio": "NexaCorp VP. i replace software developers with AI for a living. looking for someone who wont bore me. dont bother if you code for a living. actually... maybe do.",
		"interests": ["automation", "sake", "power moves", "slumming it"],
		"color": Color(0.87, 0.8, 0.53),
	},
	{
		"id": "blank",
		"name": "BLANK", "age": "N/A",
		"tagline": "                              ",
		"bio": "this profile has no content. there is nothing here. you are looking at nothing. why are you still reading this. stop. stop reading. STOP.",
		"interests": ["nothing", "void", "absence", "the space between"],
		"color": Color(0.2, 0.2, 0.27),
	},
	{
		"id": "officer_hayes",
		"name": "Officer Hayes", "age": 31,
		"tagline": "NCPD. yes i know. swipe left.",
		"bio": "look i know nobody dates cops in this city but i have a pension and dental. i havent shot anyone in like 2 weeks. thats a personal record.",
		"interests": ["not dying", "donuts", "surviving"],
		"color": Color(0.27, 0.53, 1.0),
	},
	{
		"id": "mama_chrome",
		"name": "Mama Chrome", "age": 67,
		"tagline": "chrome jackals OG. still got it.",
		"bio": "been running these streets since before you were compiled. i have more chrome than bone at this point. looking for someone who can keep up. nobody can keep up.",
		"interests": ["gang politics", "knitting", "intimidation", "bingo"],
		"color": Color(0.8, 0.27, 0.27),
	},
	{
		"id": "dj_bass",
		"name": "DJ BASS_DROP", "age": 21,
		"tagline": "WUBWUBWUBWUB",
		"bio": "i communicate exclusively through bass frequencies. my last 3 relationships ended because i couldnt stop beatboxing during dinner. i see no problem with this.",
		"interests": ["bass", "BASS", "more bass", "noise complaints"],
		"color": Color(0.27, 1.0, 0.67),
	},
	{
		"id": "kerry",
		"name": "Kerry", "age": 38,
		"tagline": "looking for something real in a fake city.",
		"bio": "graphic designer. divorced. one cat named Pixel (different Pixel). i like vinyl records, bad movies, and people who actually read bios. if youre a programmer thats a plus — i have a type apparently.",
		"interests": ["vinyl records", "bad movies", "cooking", "quiet nights"],
		"color": Color(1.0, 0.53, 0.6),
	},
	{
		"id": "sister_mercy",
		"name": "Sister Mercy", "age": 40,
		"tagline": "repent. also are you single?",
		"bio": "ex-nun turned street preacher. left the convent when i discovered the drift has better nightlife. still have the habit (the outfit, not drugs). god says swipe right.",
		"interests": ["salvation", "karaoke", "converting heathens", "tequila"],
		"color": Color(1.0, 0.87, 0.67),
	},
	{
		"id": "x_crypto",
		"name": "X-CRYPT0", "age": 26,
		"tagline": "to the moon. then further.",
		"bio": "crypto millionaire. well i was. for about 45 minutes. now i owe $200k to some very scary people. looking for love OR someone who can hide me. preferably both.",
		"interests": ["DogeCoin", "hiding", "debt", "optimism"],
		"color": Color(1.0, 0.8, 0.0),
	},
	{
		"id": "zephyr",
		"name": "Zephyr", "age": 23,
		"tagline": "fastest courier in sector 7.",
		"bio": "i deliver packages. not pizza, actual packages. dont ask whats in them. i dont ask either. looking for someone who doesnt mind 3am wake-up calls and occasional car chases.",
		"interests": ["speed", "parkour", "not asking questions", "adrenaline"],
		"color": Color(0.4, 0.8, 1.0),
	},
	{
		"id": "rat_king",
		"name": "RAT KING", "age": "???",
		"tagline": "i live in the sewers. its nice.",
		"bio": "yes i am the rat king. no its not a metaphor. i command an army of 10,000 rats. we live underground and honestly its great down here. dry. warm. rent-free.",
		"interests": ["rats", "cheese", "underground tunnels", "being mysterious"],
		"color": Color(0.53, 0.47, 0.27),
	},
	{
		"id": "pixel",
		"name": "Pixel", "age": 20,
		"tagline": "uwu notices ur cyberdeck",
		"bio": "full-time streamer, 3 followers (hi mom). i narrate everything i do in third person. pixel thinks you should swipe right. pixel is very lonely.",
		"interests": ["streaming", "anime", "cosplay", "talking about myself in third person"],
		"color": Color(1.0, 0.53, 0.8),
	},
	{
		"id": "deathmatch_69",
		"name": "DEATHMATCH_69", "age": 33,
		"tagline": "i will literally fight you.",
		"bio": "underground pit fighter. 47 wins, 2 losses, 1 draw (we both passed out). looking for someone who thinks scars are attractive. i have so many scars.",
		"interests": ["fighting", "protein", "scars", "arguing about everything"],
		"color": Color(0.87, 0.0, 0.0),
	},
]

static func count() -> int:
	return PROFILES.size()

static func get_profile(id: String) -> Dictionary:
	for p in PROFILES:
		if p.get("id", "") == id:
			return p
	return {}

## Returns profiles the player hasn't voted on yet (the active "stack" in the
## dating app). Phone overlay reads this, displays one card at a time.
static func unvoted(votes: Dictionary) -> Array:
	var out: Array = []
	for p in PROFILES:
		if not votes.has(p.get("id", "")):
			out.append(p)
	return out
