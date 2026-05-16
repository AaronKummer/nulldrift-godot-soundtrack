## NPC definitions — ports hacking-game's namedNPCs.js schema.
##
## Each NPC: id, name, sprite path, scene, condition (flag-based), position,
## scale, facing, interactable, prompt. dialogue_id keys into Dialogue tree.
##
## Schema fields:
##   id           — unique
##   name         — display name
##   sprite       — res://assets/sprites/...
##   scene        — scene id (matches Scenes.gd key)
##   condition    — { "flag": "x", "not_flag": "y" } — all must match
##   position     — Vector3 in scene's local coords
##   scale        — uniform billboard scale
##   facing       — "up"|"down"|"left"|"right"
##   interactable — bool
##   interact_radius — float (meters)
##   prompt       — interact prompt text
##   dialogue_id  — key into Dialogue.gd trees
##   color        — speaker color (override Palette default)
class_name NPCs
extends Object

const ALL := {
	"apartment_cat": {
		"id": "apartment_cat",
		"name": "Cat",
		"sprite": "",  # tinted cube for now, sprite later
		"scene": "apartment",
		"condition": null,
		"position": Vector3(-3.0, 0.4, 1.5),
		"scale": 0.5,
		"facing": "down",
		"interactable": true,
		"interact_radius": 1.4,
		"prompt": "[E] PET CAT",
		"dialogue_id": "apartment_cat",
		"color": Color(0.9, 0.65, 0.3),
	},

	"nyx_diner": {
		"id": "nyx_diner",
		"name": "Nyx",
		"sprite": "",
		"scene": "diner",
		"condition": { "flag": "pendingDinerMeeting" },
		"position": Vector3(2.5, 0.85, -1.0),
		"scale": 0.55,
		"facing": "down",
		"interactable": true,
		"interact_radius": 1.6,
		"prompt": "[E] TALK TO NYX",
		"dialogue_id": "nyx",
		"color": Color(1.0, 0.53, 0.8),
	},

	"nyx_city": {
		"id": "nyx_city",
		"name": "Nyx",
		"sprite": "",
		"scene": "city",
		"condition": { "flag": "garageCleared", "not_flag": "actTwoComplete" },
		"position": Vector3(0, 0.85, 0),
		"scale": 0.30,
		"facing": "down",
		"interactable": true,
		"interact_radius": 1.6,
		"prompt": "[E] TALK TO NYX",
		"dialogue_id": "nyx",
		"color": Color(1.0, 0.53, 0.8),
	},

	"tony_pizza": {
		"id": "tony_pizza",
		"name": "Tony",
		"sprite": "",
		"scene": "pizza_shop",
		"condition": null,
		"position": Vector3(0, 0.85, 0),
		"scale": 0.55,
		"facing": "down",
		"interactable": true,
		"interact_radius": 1.6,
		"prompt": "[E] TALK TO TONY",
		"dialogue_id": "tony",
		"color": Color(1.0, 0.6, 0.2),
	},
}

static func get_npc(id: String) -> Dictionary:
	return ALL.get(id, {})

static func for_scene(scene_id: String, flags: Dictionary) -> Array:
	var out: Array = []
	for npc in ALL.values():
		if npc["scene"] != scene_id:
			continue
		if not _matches_condition(npc.get("condition"), flags):
			continue
		out.append(npc)
	return out

static func _matches_condition(cond: Variant, flags: Dictionary) -> bool:
	if cond == null:
		return true
	if cond.has("flag") and not flags.get(cond["flag"], false):
		return false
	if cond.has("not_flag") and flags.get(cond["not_flag"], false):
		return false
	return true
