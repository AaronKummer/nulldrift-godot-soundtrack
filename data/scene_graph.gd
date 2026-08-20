## Scene graph — single source of truth for how rooms/maps connect.
##
## Each scene id maps to a .tscn path and a list of doors. Each door has:
##   id       - stable identifier inside the source scene
##   target   - scene id to transition to (or "" / null if locked / dead-end)
##   spawn    - name of the Node3D marker to teleport the player to in target
##   locked   - true if door can't be used yet
##   label    - text to show when player is near (E to use / "locked" / ...)
##
## To add a new room: add an entry here. The scene reads its own door list
## via `doors_for(id)` — no per-scene hardcoding.
class_name SceneGraph
extends Object

const SCENES := {
	"apartment": "res://scenes/apartment.tscn",
	"hallway":   "res://scenes/hallway.tscn",
	"balcony":   "res://scenes/balcony.tscn",
	"city":      "res://scenes/city.tscn",
	"title":     "res://scenes/title.tscn",
	"arcade":    "res://scenes/arcade.tscn",
	"dungeon":   "res://scenes/dungeon.tscn",
	"bar":       "res://scenes/interiors/bar.tscn",
	"street_downtown": "res://scenes/streets/downtown.tscn",
	"library":   "res://scenes/interiors/library.tscn",
	"mages_guild": "res://scenes/interiors/mages_guild.tscn",
	"cathode":   "res://scenes/interiors/cathode.tscn",
	"street_warzone": "res://scenes/streets/warzone.tscn",
	"snake":     "res://scenes/minigames/snake.tscn",
	"breakout":  "res://scenes/minigames/breakout.tscn",
	"invaders":  "res://scenes/minigames/invaders.tscn",
	"survivors": "res://scenes/minigames/survivors.tscn",
	"pong":      "res://scenes/minigames/pong.tscn",
}

const DOORS := {
	"apartment": [
		{ "id": "main_door", "target": "hallway", "spawn": "from_apt_404",
		  "label": "exit to hallway" },
	],

	"hallway": [
		# Player's own apartment — always unlocked
		{ "id": "apt_404", "target": "apartment", "spawn": "from_hall",
		  "label": "room 404 (yours)" },
		# Other rooms — locked for now (future NPCs / quests)
		{ "id": "apt_401", "target": null, "locked": true,
		  "label": "401 — locked" },
		{ "id": "apt_402", "target": null, "locked": true,
		  "label": "402 — sounds inside" },
		{ "id": "apt_403", "target": null, "locked": true,
		  "label": "403 — locked" },
		{ "id": "apt_405", "target": null, "locked": true,
		  "label": "405 — locked" },
		{ "id": "apt_406", "target": null, "locked": true,
		  "label": "406 — out of order" },
		# End-cap exits
		{ "id": "balcony_door", "target": "balcony", "spawn": "from_hall",
		  "label": "balcony" },
		{ "id": "elevator", "target": "city", "spawn": "from_elevator",
		  "label": "elevator → street" },
	],

	"balcony": [
		{ "id": "back_door", "target": "hallway", "spawn": "from_balcony",
		  "label": "back to hallway" },
	],

	"city": [
		# city already has its own exit-to-apartment; route through hallway
		# instead so the elevator is the canonical entry/exit.
		{ "id": "elevator_back", "target": "hallway", "spawn": "from_elevator",
		  "label": "elevator → apartment 404" },
		{ "id": "arcade_door", "target": "arcade", "spawn": "from_city",
		  "label": "ARCADE" },
	],

	"arcade": [
		{ "id": "exit_door", "target": "city", "spawn": "from_arcade",
		  "label": "exit to street" },
	],
}

## Return the door list for a given scene id (empty array if unknown).
static func doors_for(scene_id: String) -> Array:
	return DOORS.get(scene_id, [])

## Resolve a scene id to a .tscn path (empty string if unknown).
static func path_of(scene_id: String) -> String:
	return SCENES.get(scene_id, "")
