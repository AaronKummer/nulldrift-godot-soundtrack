## Rumor pool — overheard lines that point at REAL content. Patrons in
## interiors pull from this. Every rumor is a soft quest pointer; conditions
## let rumors appear/expire as the player actually does things.
##
## Entry fields:
##   text      — the line
##   req       — { flag_name: true/false } all must match GameState.flags
##                (false means "flag must be absent/false")
##   check     — optional Callable-style string handled in eligible():
##                "katana_lt_3", "has_credits_500", "score_survivors_0"
class_name Rumors
extends Object

const POOL := [
	# Arcade
	{ "text": "some kid named chad put 3000 on the survivors machine. nobody's touched it in months.",
	  "req": { "chadBeaten": false } },
	{ "text": "heard somebody finally knocked chad off the survivors board. he's been sulking by the vending machine.",
	  "req": { "chadBeaten": true } },
	{ "text": "the girl who hangs around the arcade at night? she's not playing the machines. she's watching them." },

	# Sewer / relay
	{ "text": "there's a hum under the manhole on this street. maintenance says there's nothing down there. maintenance is lying.",
	  "req": { "sewerRelayFound": false } },
	{ "text": "the rats in the sewer chew through cable for the taste. whatever's in that cable, i don't want it." },
	{ "text": "guy two stools down swears the grates down there SPAWN things. said you can seal them if your hands are steady." },

	# Warzone
	{ "text": "ridenet runs to the warzone now. thirty credits to get shot at. people pay it." },
	{ "text": "the dump out in the warzone pays real money if you make it back. that's a big if." },
	{ "text": "chop shop in the warzone sells medkits cheaper than anywhere. there's a reason demand is high out there." },
	{ "text": "the jackals took the whole east end of the warzone. cops just repainted the map instead of fighting them." },

	# Gear
	{ "text": "kid went into the sewer with no light last month. the rats sent his shoes back up. guns plus sells headlamps." },
	{ "text": "guns plus got mk-two blades in. five hundred credits. cuts twice as deep.",
	  "check": "katana_lt_2" },
	{ "text": "if you're swinging an mk-two, the mk-three is twelve hundred at guns plus. worth every credit.",
	  "check": "katana_lt_3_gte_2" },
	{ "text": "stims from the shop slow the whole world down. don't ask what they speed up." },

	# Downtown + jackals
	{ "text": "the jackals grabbed the chop shop kid, patch. they're holding her in their garage out east in the warzone.",
	  "req": { "patchRescued": false } },
	{ "text": "heard somebody walked into the jackals garage and walked back out. the kid didn't even say thanks. sounds like her.",
	  "req": { "patchRescued": true } },
	{ "text": "ex-corpo lady drinks alone at the sushi place downtown. omnicorp compliance, they say. don't bring up the tower." },
	{ "text": "lucky chrome pays out, sometimes. the pit boss remembers every face that wins twice." },

	# City flavor / future hooks
	{ "text": "perfect tommy plays the cathode downtown. the synth guy is unreal. godsnack nights are... something else." },
	{ "text": "downtown's got a casino now. the cathode, growler's, the whole strip. ridenet says soon. soon means soon." },
	{ "text": "don't swim the canal. i knew a guy. we don't talk about the guy." },
	{ "text": "the scooters on the sidewalk are free. nobody knows who charges them. nobody asks." },
	{ "text": "cops don't come down here after dark. the pizza kid does though. respect." },
	{ "text": "megacorp's buying up the stack, tower by tower. the lights go out one floor at a time." },
]

## Returns eligible rumors given current GameState.
static func eligible(flags: Dictionary, katana_level: int) -> Array:
	var out: Array = []
	for r in POOL:
		var ok := true
		var req: Dictionary = r.get("req", {})
		for f in req:
			if bool(flags.get(f, false)) != bool(req[f]):
				ok = false
				break
		var check: String = r.get("check", "")
		if check == "katana_lt_2" and katana_level >= 2:
			ok = false
		elif check == "katana_lt_3_gte_2" and (katana_level < 2 or katana_level >= 3):
			ok = false
		if ok:
			out.append(r["text"])
	return out
