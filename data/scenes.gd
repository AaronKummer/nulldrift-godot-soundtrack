## Scene definitions — declarative room geometry, lights, interactables, NPCs.
##
## Each scene script (scripts/scenes/apartment.gd etc.) is a thin shell that
## reads its definition from here and asks SceneBuilder + Interaction + NPCs
## to materialize it. No geometry lives in scene scripts — it lives here.
##
## Schema:
##   id, name, music_category
##   camera: { size, position [x,y,z], look_at [x,y,z], perspective:bool }
##   environment: { glow_intensity, glow_threshold, glow_strength, glow_bloom,
##                  ambient_color [r,g,b], ambient_energy, tonemap, ssao }
##   room: { size [w,h,d], wall_thickness, floor_color, wall_color, door_gap }
##   furniture: array of { type, position, … type-specific fields }
##   lights:    array of { type, position, color, energy, range, attenuation, shadow }
##   interactables: array of { type, position, prompt, action, target? }
##   npcs: array of npc ids (resolved via NPCs.for_scene)
##   player_spawn: [x,y,z]
class_name Scenes
extends Object

const APARTMENT := {
	"id": "apartment",
	"name": "YOUR APARTMENT",
	"music_category": "apartment",

	"camera": {
		"size": 12.0,
		"position": Vector3(8, 10, 8),
		"look_at": Vector3(0, 0.8, 0),
		"perspective": false,
	},

	"environment": {
		"bg_color": Color(0.005, 0.005, 0.012),
		"glow_intensity": 0.55,
		"glow_strength": 1.05,
		"glow_bloom": 0.04,
		"glow_threshold": 1.4,
		"ambient_color": Color(0.18, 0.16, 0.22),
		"ambient_energy": 1.3,
		"tonemap": "aces",
		"tonemap_exposure": 1.0,
		"ssao": true,
		"ssao_intensity": 0.8,
	},

	"room": {
		"size": Vector3(14, 4, 10),
		"wall_thickness": 0.3,
		"floor_color": Color(0.18, 0.14, 0.12),
		"wall_color": Color(0.18, 0.16, 0.22),
		"wall_color_back": Color(0.2, 0.17, 0.24),
		"wall_color_front": Color(0.14, 0.12, 0.16),
		"door_side": "right",
		"door_gap_size": 1.4,
		"door_gap_position": 2.5,  # along the door wall
	},

	"furniture": [
		# Desk + monitor + neon strip — the working corner
		{ "type": "desk",
		  "position": Vector3(3.5, 0, -4.1),
		  "size": Vector3(2.2, 0.08, 1.2),
		  "color": Color(0.18, 0.13, 0.1) },
		{ "type": "monitor",
		  "position": Vector3(3.5, 1.55, -4.1),
		  "screen_color": Color(0.0, 1.0, 0.53),
		  "screen_energy": 1.8 },
		{ "type": "neon_strip",
		  "position": Vector3(3.5, 0.05, -4.5),
		  "size": Vector3(2.0, 0.04, 0.08),
		  "color": Color(1.0, 0.0, 0.4),
		  "energy": 4.0 },

		# Sleeping corner
		{ "type": "bed",
		  "position": Vector3(-5.5, 0, 3.2),
		  "frame_size": Vector3(2.0, 0.3, 3.0),
		  "blanket_color": Color(0.05, 0.18, 0.22) },

		# Window with night-city view
		{ "type": "window",
		  "position": Vector3(-1.5, 2.2, -4.85),
		  "size": Vector3(3.5, 1.8, 0.02),
		  "view_color": Color(0.55, 0.15, 0.95),
		  "view_energy": 0.9 },

		# Ceiling lamp
		{ "type": "ceiling_lamp",
		  "position": Vector3(0, 3.7, 0),
		  "bulb_color": Color(1.0, 0.85, 0.55) },
	],

	"lights": [
		{ "type": "omni", "position": Vector3(0, 3.65, 0),
		  "color": Color(1.0, 0.88, 0.6), "energy": 3.5, "range": 14.0,
		  "attenuation": 1.0, "shadow": true },
		{ "type": "omni", "position": Vector3(0, 2.0, 0),
		  "color": Color(0.65, 0.55, 0.85), "energy": 1.2, "range": 10.0,
		  "attenuation": 1.4, "shadow": false },
		{ "type": "omni", "position": Vector3(-1.5, 2.2, -3.5),
		  "color": Color(0.6, 0.3, 1.0), "energy": 1.2, "range": 7.0,
		  "attenuation": 1.5, "shadow": false },
		{ "type": "omni", "position": Vector3(3.5, 1.55, -3.5),
		  "color": Color(0.0, 1.0, 0.53), "energy": 0.9, "range": 3.5,
		  "attenuation": 1.9, "shadow": false },
		{ "type": "omni", "position": Vector3(3.5, 0.2, -4.5),
		  "color": Color(1.0, 0.0, 0.4), "energy": 1.0, "range": 3.5,
		  "attenuation": 1.6, "shadow": false },
	],

	"interactables": [
		{ "id": "terminal",   "position": Vector3(3.5, 1.0, -3.6),
		  "radius": 1.0, "prompt": "[E] JACK IN", "action": "open_terminal" },
		{ "id": "bed",        "position": Vector3(-5.5, 0.5, 3.2),
		  "radius": 1.4, "prompt": "[E] SLEEP", "action": "sleep" },
		{ "id": "window",     "position": Vector3(-1.5, 2.2, -3.6),
		  "radius": 1.0, "prompt": "[E] LOOK OUT WINDOW", "action": "view_window" },
		{ "id": "door",       "position": Vector3(6.5, 1.0, 2.5),
		  "radius": 1.2, "prompt": "[E] LEAVE", "action": "exit_scene",
		  "target": "city" },
	],

	"npcs": ["apartment_cat"],
	"player_spawn": Vector3(0, 0.85, 2.0),

	"hud_title": "YOUR APARTMENT",
}

const TITLE := {
	"id": "title",
	"name": "NULL//DRIFT",
	"music_category": "title",
	"camera": {
		"perspective": true,
		"fov": 45.0,
		"position": Vector3(0, 0, 14),
	},
	"environment": {
		"bg_color": Color.BLACK,
		"glow_intensity": 0.55,
		"glow_strength": 1.1,
		"glow_bloom": 0.05,
		"glow_threshold": 1.0,
		"ambient_color": Color(0.07, 0.07, 0.14),
		"ambient_energy": 0.3,
		"tonemap": "reinhardt",
		"tonemap_exposure": 1.0,
	},
}

const CITY := {
	"id": "city",
	"name": "NEO CITY · BLOCK 7",
	"music_category": "story",

	"camera": {
		"size": 22.0,
		"position": Vector3(15, 17, 15),
		"rotation_degrees": Vector3(-35.264, 45, 0),
		"perspective": false,
	},

	"environment": {
		"bg_color": Color(0.005, 0.005, 0.012),
		"glow_intensity": 0.6,
		"glow_strength": 1.1,
		"glow_bloom": 0.04,
		"glow_threshold": 1.4,
		"ambient_color": Color(0.08, 0.08, 0.12),
		"ambient_energy": 0.7,
		"tonemap": "aces",
		"tonemap_exposure": 1.0,
		"ssao": true,
		"ssao_intensity": 0.8,
		"fog": true,
		"fog_color": Color(0.015, 0.012, 0.025),
		"fog_density": 0.012,
	},

	# Outdoor "ground plate" — replaces room walls for exterior scenes
	"ground": {
		"size": Vector3(40, 0.1, 40),
		"color": Color(0.015, 0.015, 0.02),
	},

	"roads": [
		# East-west main street
		{ "position": Vector3(0, 0.01, 0), "size": Vector3(40, 0.02, 6),
		  "color": Color(0.025, 0.025, 0.03) },
		# North-south cross street
		{ "position": Vector3(-5, 0.01, 0), "size": Vector3(6, 0.02, 40),
		  "color": Color(0.025, 0.025, 0.03) },
	],

	"sidewalks": [
		{ "position": Vector3(5, 0.08, -4.5),  "size": Vector3(22, 0.16, 2) },
		{ "position": Vector3(5, 0.08, 4.5),   "size": Vector3(22, 0.16, 2) },
		{ "position": Vector3(-9.5, 0.08, -7), "size": Vector3(2, 0.16, 14) },
		{ "position": Vector3(-9.5, 0.08, 7),  "size": Vector3(2, 0.16, 14) },
		{ "position": Vector3(-1.5, 0.08, -7), "size": Vector3(1.5, 0.16, 14) },
		{ "position": Vector3(-1.5, 0.08, 7),  "size": Vector3(1.5, 0.16, 14) },
	],

	"buildings": [
		# North side (-z) of east-west road
		{ "position": Vector3(3, 0, -8),    "size": Vector3(4, 7, 4),  "windows": true },
		{ "position": Vector3(7.5, 0, -8),  "size": Vector3(3.5, 10, 4), "windows": true,
		  "rooftop_light": true, "id": "apartment_building" },
		{ "position": Vector3(11.5, 0, -8), "size": Vector3(4, 5, 4),  "windows": true },
		{ "position": Vector3(16, 0, -8),   "size": Vector3(3, 12, 4), "windows": true,
		  "rooftop_light": true },
		# South side
		{ "position": Vector3(2, 0, 7),     "size": Vector3(3, 6, 3),  "windows": true },
		{ "position": Vector3(6, 0, 7),     "size": Vector3(5, 8, 3),  "windows": true },
		{ "position": Vector3(12, 0, 7),    "size": Vector3(4, 14, 3), "windows": true,
		  "rooftop_light": true },
		{ "position": Vector3(16.5, 0, 7.5),"size": Vector3(3, 5, 4),  "windows": true },
		# West of cross street
		{ "position": Vector3(-12, 0, -8),  "size": Vector3(4, 9, 4),  "windows": true },
		{ "position": Vector3(-16, 0, -8),  "size": Vector3(3, 6, 4),  "windows": true },
		{ "position": Vector3(-12, 0, 7),   "size": Vector3(4, 7, 3),  "windows": true },
		{ "position": Vector3(-16, 0, 7),   "size": Vector3(3, 11, 3), "windows": true,
		  "rooftop_light": true },
	],

	"neon_signs": [
		{ "position": Vector3(6, 4.5, 5.52),  "size": Vector3(3, 0.2, 0.08),
		  "color": Color(0.95, 0.0, 0.4),  "energy": 8.0 },
		{ "position": Vector3(12.01, 8, 7),   "size": Vector3(0.08, 3, 0.15),
		  "color": Color(0.5, 0.0, 0.85),  "energy": 7.0 },
		{ "position": Vector3(7.52, 4.5, -7.5),"size": Vector3(0.08, 0.2, 2.5),
		  "color": Color(0.0, 0.6, 0.9),   "energy": 7.0 },
		{ "position": Vector3(-12, 4.0, 5.52),"size": Vector3(2.0, 0.15, 0.08),
		  "color": Color(1.0, 0.4, 0.0),   "energy": 6.0 },
		{ "position": Vector3(3, 3.8, -5.98), "size": Vector3(2.5, 0.1, 0.06),
		  "color": Color(0.95, 0.0, 0.4),  "energy": 5.5 },
	],

	"streetlights": [
		Vector3(0, 0, 3.8),
		Vector3(8, 0, 3.8),
		Vector3(16, 0, -3.8),
		Vector3(8, 0, -3.8),
		Vector3(-8, 0, 3.8),
		Vector3(-14, 0, -3.8),
	],

	"interactables": [
		# Door back to the apartment building
		{ "id": "apartment_door", "position": Vector3(7.5, 0.8, -5.8),
		  "radius": 1.4, "prompt": "[E] ENTER APARTMENT",
		  "action": "exit_scene", "target": "apartment" },
	],

	"npcs": ["nyx_city"],
	"player_spawn": Vector3(0, 0.85, 3.5),
	"hud_title": "NEO CITY",
	"outdoor": true,
}

const SOUNDTRACK := {
	"id": "soundtrack",
	"name": "NULL//DRIFT FM",
	"music_category": "",  # scene controls its own player (jukebox)

	# Close 3rd-person chase. The scene script tweaks position each frame
	# for a hand-held bob, so this is the resting pose.
	"camera": {
		"perspective": true,
		"fov": 52.0,
		"position": Vector3(0.0, 1.45, -3.2),
		"look_at": Vector3(0.0, 0.65, 4.0),
	},

	"environment": {
		# Pure black night. Glow is restrained so only the brightest sources
		# (headlights, taillights, lamps) bloom — keeps the scene from
		# turning into a milky pink wash.
		"bg_color": Color(0.0, 0.0, 0.0),
		"glow_intensity": 0.45,
		"glow_strength": 0.95,
		"glow_bloom": 0.05,
		"glow_threshold": 1.1,
		"ambient_color": Color(0.06, 0.03, 0.12),
		"ambient_energy": 0.20,
		"tonemap": "aces",
		"tonemap_exposure": 0.85,
		"fog": true,
		"fog_color": Color(0.030, 0.020, 0.055),
		"fog_density": 0.006,
	},
}

const ALL := {
	"title": TITLE,
	"apartment": APARTMENT,
	"city": CITY,
	"soundtrack": SOUNDTRACK,
}

static func get_scene(id: String) -> Dictionary:
	return ALL.get(id, {})
