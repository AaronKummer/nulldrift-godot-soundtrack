## Menu definitions — title screen, pause menu, options. Lifted from
## IntroSequence.vue's computed menuItems.
class_name Menus
extends Object

const TITLE := {
	"items": [
		{ "id": "continue",   "label": "CONTINUE",   "requires_save": true },
		{ "id": "newgame",    "label": "NEW GAME",   "requires_save": false },
		{ "id": "controls",   "label": "CONTROLS",   "requires_save": false },
		{ "id": "options",    "label": "OPTIONS",    "requires_save": false },
		{ "id": "soundtrack", "label": "SOUNDTRACK", "requires_save": false },
	]
}

const PAUSE := {
	"items": [
		{ "id": "resume",   "label": "RESUME" },
		{ "id": "controls", "label": "CONTROLS" },
		{ "id": "options",  "label": "OPTIONS" },
		{ "id": "save",     "label": "SAVE" },
		{ "id": "title",    "label": "QUIT TO TITLE" },
	]
}

static func title_items(has_save: bool) -> Array:
	var out: Array = []
	for item in TITLE["items"]:
		if item["requires_save"] and not has_save:
			continue
		out.append(item)
	return out
