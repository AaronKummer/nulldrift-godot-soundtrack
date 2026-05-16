## Phone app registry — single source of truth for the home grid. Adding/
## removing/reordering apps = edit this file (CRUD).
##
## Schema:
##   id         - stable identifier the overlay uses to route taps
##   label      - displayed under the icon (≤8 chars looks best in the grid)
##   icon       - unicode glyph fallback (still used if icon_path missing)
##   icon_path  - res:// path to a Texture2D — preferred render
##   color      - accent / border color
##   gate       - optional gate ID checked against GameState flags
class_name PhoneApps
extends Object

const ICON_DIR := "res://assets/icons/phone/"

const APPS := [
	{ "id": "gear",     "label": "GEAR",     "icon": "⚒", "icon_path": "res://assets/icons/phone/gear.png",     "color": Color(1.0, 0.53, 0.0) },
	{ "id": "grimoire", "label": "GRIMOIRE", "icon": "✦", "icon_path": "res://assets/icons/phone/grimoire.png", "color": Color(0.73, 0.53, 1.0), "gate": "grimoire" },
	{ "id": "quests",   "label": "QUESTS",   "icon": "✓", "icon_path": "res://assets/icons/phone/quests.png",   "color": Color(1.0, 0.53, 0.8) },
	{ "id": "map",      "label": "MAP",      "icon": "◆", "icon_path": "res://assets/icons/phone/map.png",      "color": Color(0.22, 1.0, 0.08) },

	{ "id": "messages", "label": "MSGS",     "icon": "✉", "icon_path": "res://assets/icons/phone/messages.png", "color": Color(1.0, 0.0, 1.0) },
	{ "id": "uber",     "label": "UBER",     "icon": "▲", "icon_path": "res://assets/icons/phone/uber.png",     "color": Color(0.0, 0.8, 0.4) },
	{ "id": "runs",     "label": "RUNS",     "icon": "◉", "icon_path": "res://assets/icons/phone/runs.png",     "color": Color(1.0, 0.27, 0.27) },
	{ "id": "delivery", "label": "DELIV",    "icon": "▽", "icon_path": "res://assets/icons/phone/delivery.png", "color": Color(1.0, 0.4, 0.0) },

	{ "id": "stocks",   "label": "STOX",     "icon": "↗", "icon_path": "res://assets/icons/phone/stocks.png",   "color": Color(0.22, 1.0, 0.08) },
	{ "id": "dating",   "label": "DATE",     "icon": "♥", "icon_path": "res://assets/icons/phone/dating.png",   "color": Color(1.0, 0.27, 0.4) },
	{ "id": "email",    "label": "EMAIL",    "icon": "@", "icon_path": "res://assets/icons/phone/email.png",    "color": Color(0.27, 0.53, 1.0) },
	{ "id": "news",     "label": "NEWS",     "icon": "▤", "icon_path": "res://assets/icons/phone/news.png",     "color": Color(0.0, 0.87, 1.0) },

	{ "id": "profile",  "label": "PROFILE",  "icon": "◯", "icon_path": "res://assets/icons/phone/profile.png",  "color": Color(0.0, 1.0, 1.0) },
	{ "id": "catalog",  "label": "CATALOG",  "icon": "≡", "icon_path": "res://assets/icons/phone/catalog.png",  "color": Color(0.27, 0.87, 1.0) },
	{ "id": "deck",     "label": "DECK",     "icon": ">_","icon_path": "res://assets/icons/phone/deck.png",     "color": Color(0.22, 1.0, 0.08), "gate": "deck" },
	{ "id": "settings", "label": "SETTINGS", "icon": "⚙", "icon_path": "res://assets/icons/phone/settings.png", "color": Color(0.67, 0.67, 0.8) },
]

static func get_app(id: String) -> Dictionary:
	for a in APPS:
		if a.get("id", "") == id:
			return a
	return {}

static func visible(flags: Dictionary) -> Array:
	return APPS
