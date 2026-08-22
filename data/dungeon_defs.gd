## Dungeon definitions — data-driven configs for the reusable dungeon scene.
## Port of hacking-game/src/data/dungeonDefs.js.
##
## Every dungeon (sewer, abandoned office, corpo tower...) is one entry here:
## palette, enemy roster, spawner counts, loot, objective prop. The maze
## itself is PROCEDURAL — scripts/systems/dungeon_gen.gd rolls a fresh
## layout every visit. Adding a new dungeon = adding a dict, not a scene.
class_name DungeonDefs
extends Object

const DEFS := {
	"sewer": {
		"name": "THE SEWERS",
		"exit_label": "climb back to the street",
		"exit_spawn": "from_sewer",          # marker in the city
		# Maze shape
		"grid_w": 23, "grid_h": 19,
		"rooms": 7, "room_min": 3, "room_max": 6,
		"water_room_chance": 0.45,           # big rooms flood, bridge across
		"flavor_chance": 0.35,               # some rooms get the moss look
		# Look
		"pal": {
			"floor": Color(0.098, 0.104, 0.118),          # cold concrete
			"floor_flavor": Color(0.060, 0.135, 0.085),   # mossy rooms
			"wall": Color(0.130, 0.142, 0.165),           # brushed steel
			"wall_rim": Color(0.22, 0.26, 0.32),
			"water": Color(0.050, 0.110, 0.160),
			"water_shine": Color(0.15, 0.40, 0.55),
			"bridge": Color(0.19, 0.21, 0.25),            # metal treads
			"sconce": Color(0.6, 1.3, 1.7),               # cyan tube lights
			"flavor_light": Color(0.35, 1.5, 0.55),       # moss glow
			"accent": Color(0.3, 1.4, 0.5),
			"conduit": Color(0.25, 1.4, 1.7),             # wall cable runs
		},
		# Roster (Phaser dungeonDefs stats)
		"enemies": {
			"rat": { "sheet": "rat", "hp": 1, "speed": 115.0, "size": 12.0,
				"dmg": 5, "credits": 3, "tint": Color(1.2, 1.15, 1.1), "scale": 1.3,
				"drops": false },
			"mutant": { "sheet": "mutant", "hp": 6, "speed": 52.0, "size": 18.0,
				"dmg": 12, "credits": 10, "tint": Color(1.05, 1.1, 1.0), "scale": 1.1 },
			"gator": { "sheet": "gator", "hp": 18, "speed": 55.0, "size": 26.0,
				"dmg": 26, "credits": 28, "tint": Color(1.05, 1.1, 1.0), "scale": 1.6,
				"lunge": true, "drops": false },
		},
		"grate_pool": ["rat", "rat", "rat", "mutant", "mutant", "gator"],
		"hole_pool": ["rat"],
		"grates": 4, "rat_holes": 3, "chests": 2,
		"medkits_min": 2, "medkits_max": 4,
		"stash_credits": 150,
		"objective_prop": "relay",           # story pylon, one-time interact
		"objective_flag": "sewerRelayFound",
		"objective_credits": 200,
		"seal_reward": 25, "seal_all_reward": 200,
	},

	# ── THE UNDERLINE — flooded metro under downtown. Pure grind: squatter
	# husks, track rats, a tunneler brute. No story, just loot + a lost-and-
	# found stash. Entered from a downtown subway stair. ──────────────────
	"subway": {
		"name": "THE UNDERLINE",
		"exit_label": "back up the subway stairs",
		"exit_scene": "street_downtown",
		"exit_spawn": "from_subway",
		"grid_w": 27, "grid_h": 19,
		"rooms": 9, "room_min": 3, "room_max": 7,
		"water_room_chance": 0.5,
		"flavor_chance": 0.3,
		"pal": {
			"floor": Color(0.090, 0.098, 0.115),
			"floor_flavor": Color(0.070, 0.110, 0.130),
			"wall": Color(0.135, 0.130, 0.120),          # tiled tunnel
			"wall_rim": Color(0.24, 0.23, 0.20),
			"water": Color(0.045, 0.090, 0.120),
			"water_shine": Color(0.15, 0.35, 0.45),
			"bridge": Color(0.20, 0.19, 0.18),
			"sconce": Color(1.2, 1.0, 0.5),              # sodium platform lights
			"flavor_light": Color(0.4, 0.9, 1.2),
			"accent": Color(1.0, 0.8, 0.35),
			"conduit": Color(1.1, 0.85, 0.3),
		},
		"enemies": {
			"track_rat": { "sheet": "rat", "hp": 1, "speed": 120.0, "size": 12.0,
				"dmg": 5, "credits": 3, "tint": Color(1.1, 1.05, 1.0), "scale": 1.2,
				"drops": false },
			"husk": { "sheet": "thug", "hp": 5, "speed": 48.0, "size": 17.0,
				"dmg": 10, "credits": 11, "tint": Color(0.75, 0.9, 0.8), "scale": 1.0 },
			"tunneler": { "sheet": "mutant", "hp": 8, "speed": 54.0, "size": 19.0,
				"dmg": 14, "credits": 16, "tint": Color(0.95, 1.05, 1.0), "scale": 1.15 },
			"brute": { "sheet": "troll", "hp": 22, "speed": 50.0, "size": 26.0,
				"dmg": 24, "credits": 40, "tint": Color(1.0, 0.95, 0.95), "scale": 1.5,
				"lunge": true, "drops": false },
		},
		"grate_pool": ["track_rat", "track_rat", "husk", "husk", "tunneler", "brute"],
		"hole_pool": ["track_rat", "husk"],
		"grates": 5, "rat_holes": 3, "chests": 3,
		"medkits_min": 2, "medkits_max": 4,
		"stash_credits": 400,
		"objective_prop": "relay",
		"objective_flag": "subwayStashFound",
		"objective_credits": 250,
		"seal_reward": 25, "seal_all_reward": 250,
	},

	# ── THE SCRAPYARD — Chrome Jackals' chop-shop overflow in the warzone.
	# Leftover gangers + guard dogs, a safe to crack. Grind. ──────────────
	"scrapyard": {
		"name": "THE SCRAPYARD",
		"exit_label": "squeeze back through the fence",
		"exit_scene": "street_warzone",
		"exit_spawn": "from_scrapyard",
		"grid_w": 25, "grid_h": 21,
		"rooms": 9, "room_min": 4, "room_max": 7,
		"water_room_chance": 0.0,
		"flavor_chance": 0.25,
		"pal": {
			"floor": Color(0.105, 0.098, 0.090),
			"floor_flavor": Color(0.125, 0.100, 0.055),
			"wall": Color(0.140, 0.128, 0.115),          # rust + corrugated steel
			"wall_rim": Color(0.28, 0.22, 0.16),
			"water": Color(0.05, 0.05, 0.04),
			"water_shine": Color(0.12, 0.12, 0.10),
			"bridge": Color(0.20, 0.18, 0.15),
			"sconce": Color(1.5, 0.8, 0.3),              # work-light amber
			"flavor_light": Color(1.4, 0.6, 0.2),
			"accent": Color(1.4, 0.65, 0.25),
			"conduit": Color(1.3, 0.7, 0.25),
		},
		"enemies": {
			"scrapper": { "sheet": "yak1", "hp": 4, "speed": 110.0, "size": 15.0,
				"dmg": 10, "credits": 12, "tint": Color(1.05, 1.0, 0.9), "scale": 1.0 },
			"welder": { "sheet": "yak2", "hp": 9, "speed": 55.0, "size": 19.0,
				"dmg": 15, "credits": 18, "tint": Color(1.1, 0.95, 0.8), "scale": 1.15 },
			"junk_dog": { "sheet": "cat", "hp": 3, "speed": 130.0, "size": 12.0,
				"dmg": 8, "credits": 8, "tint": Color(1.2, 0.9, 0.7), "scale": 0.9,
				"drops": false },
		},
		"grate_pool": ["scrapper", "scrapper", "junk_dog", "welder", "junk_dog"],
		"hole_pool": ["junk_dog"],
		"grates": 5, "rat_holes": 2, "chests": 3,
		"medkits_min": 2, "medkits_max": 3,
		"stash_credits": 500,
		"objective_prop": "relay",
		"objective_flag": "scrapyardSafeCracked",
		"objective_credits": 300,
		"seal_reward": 30, "seal_all_reward": 250,
	},

	# ── Future dungeons — same engine, new data. Wire an entrance, done. ──
	"garage": {
		"name": "THE GARAGE — CHROME JACKALS",
		"exit_label": "roll out under the door",
		"exit_scene": "street_warzone",
		"exit_spawn": "from_garage",
		"grid_w": 29, "grid_h": 23,
		"rooms": 10, "room_min": 4, "room_max": 7,
		"water_room_chance": 0.0,
		"flavor_chance": 0.25,               # oil-slick bays, sodium glow
		# Hand-authored floor plan (Aaron: "doesn't have to be random") —
		# service bays top-left, Rezz's shop-floor arena top-right, drive
		# aisle, office maze, Patch's cage in the locked back room.
		"layout": [
			"##############################",
			"#....G....#...C...#..........#",
			"#..FF.....#.FF....#....FF....#",
			"#..FF.....+..FF...+..B.......#",
			"#.........#.......#..........#",
			"#####.#########.###....S.....#",
			"#...............#............#",
			"#.G..........M..#......G.....#",
			"#...............##.....##..###",
			"######.#####.....#....#####..#",
			"#....#.#...##.#####.###...#..#",
			"#.M..+.#.C..+.#...+.#..M..+..#",
			"#....#.#....#.#.G.#.#.....#..#",
			"##.###.######.#...#.#..H..#..#",
			"#..#........#.#####.#######..#",
			"#..#.FF..G..+.......+........#",
			"#..+.FF.....#..###..#..####..#",
			"#..#........#..#O#..#..#C....#",
			"#..#...H....#..#.#..#..#.....#",
			"#E.#........#..+.+..#..+..M..#",
			"##############################",
		],
		"pal": {
			"floor": Color(0.105, 0.100, 0.095),
			"floor_flavor": Color(0.130, 0.095, 0.045),
			"wall": Color(0.140, 0.135, 0.125),
			"wall_rim": Color(0.26, 0.24, 0.20),
			"water": Color(0.03, 0.03, 0.04),
			"water_shine": Color(0.1, 0.1, 0.12),
			"bridge": Color(0.2, 0.19, 0.17),
			"sconce": Color(1.5, 0.9, 0.3),
			"flavor_light": Color(1.4, 0.7, 0.2),
			"accent": Color(1.4, 0.6, 0.2),
			"conduit": Color(1.3, 0.7, 0.2),
		},
		"enemies": {
			"jackal_runner": { "sheet": "yak1", "hp": 4, "speed": 115.0, "size": 15.0,
				"dmg": 10, "credits": 12, "tint": Color(1.1, 0.95, 0.8), "scale": 1.0 },
			"jackal_bruiser": { "sheet": "yak2", "hp": 10, "speed": 55.0, "size": 19.0,
				"dmg": 15, "credits": 18, "tint": Color(1.1, 0.9, 0.75), "scale": 1.15 },
			# Keeps distance and shoots — dodge or close the gap
			"jackal_gunner": { "sheet": "yak3", "hp": 6, "speed": 70.0, "size": 16.0,
				"dmg": 6, "credits": 22, "tint": Color(0.95, 0.9, 1.05), "scale": 1.0,
				"shoot": { "range": 380.0, "cd": 1.7, "dmg": 8, "keep": 240.0 } },
			# Chromed-up knife jackal — gator-style lunge, dies fast
			"jackal_blade": { "sheet": "ninja", "hp": 3, "speed": 95.0, "size": 14.0,
				"dmg": 13, "credits": 16, "tint": Color(1.3, 1.3, 1.45), "scale": 1.0,
				"lunge": true },
			"jackal_boss": { "sheet": "yakboss", "hp": 20, "speed": 62.0, "size": 22.0,
				"dmg": 22, "credits": 60, "tint": Color(1.2, 0.9, 0.7), "scale": 1.35,
				"lunge": true },
		},
		"grate_pool": ["jackal_runner", "jackal_runner", "jackal_bruiser",
			"jackal_gunner", "jackal_gunner", "jackal_blade", "jackal_boss"],
		"hole_pool": ["jackal_runner", "jackal_blade"],
		"grates": 6, "rat_holes": 3, "chests": 3,
		"medkits_min": 3, "medkits_max": 4,
		"stash_credits": 300,
		"objective_prop": "cage",
		"objective_kind": "rescue",
		"rescue_name": "PATCH",
		"objective_flag": "patchRescued",
		"objective_credits": 500,
		"seal_reward": 30, "seal_all_reward": 250,
		# REZZ — Chrome Jackals leader. Canon Act 1 boss: flees at low HP
		# ("flees to return as a dungeon encounter"), clearing sets
		# garageCleared (Hank reacts, act one progresses).
		"boss": {
			"name": "REZZ", "sheet": "yakboss", "hp": 70, "speed": 80.0,
			"size": 26.0, "dmg": 18, "scale": 1.6,
			"tint": Color(1.35, 0.85, 0.55),
			"charge": true,
			"spray": { "count": 6, "dmg": 8, "cd": 4.5 },
			"summon": { "pool": ["jackal_runner", "jackal_blade"],
				"count": 2, "cd": 9.0, "max": 5 },
			"flee_at": 0.15,
			"credits": 400,
			"flag": "garageCleared",
			"drops": ["power_fist"],
			"bark_intro": "REZZ: 'you're the pizza rat been cutting up my crew? chrome him, boys.'",
			"bark_flee": "REZZ: 'this ain't over, rat. the jackals remember.'",
		},
	},

	"office": {
		"name": "NEXUS TOWER (ABANDONED)",
		"exit_label": "take the elevator down",
		"exit_scene": "street_warzone",
		"exit_spawn": "from_dump",
		"grid_w": 23, "grid_h": 19,
		"rooms": 8, "room_min": 3, "room_max": 7,
		"water_room_chance": 0.0,
		"flavor_chance": 0.30,               # server rooms, blue glow
		"pal": {
			"floor": Color(0.120, 0.115, 0.128),
			"floor_flavor": Color(0.070, 0.090, 0.150),
			"wall": Color(0.180, 0.172, 0.190),
			"wall_rim": Color(0.275, 0.265, 0.285),
			"water": Color(0.03, 0.03, 0.05),
			"water_shine": Color(0.1, 0.1, 0.16),
			"bridge": Color(0.2, 0.2, 0.22),
			"sconce": Color(0.5, 0.9, 1.5),
			"flavor_light": Color(0.3, 0.7, 1.6),
			"accent": Color(0.4, 0.8, 1.5),
		},
		"enemies": {
			"squatter": { "sheet": "thug", "hp": 4, "speed": 70.0, "size": 17.0,
				"dmg": 8, "credits": 8, "tint": Color(0.9, 0.85, 0.8), "scale": 1.0 },
			"drone": { "sheet": "cat", "hp": 2, "speed": 105.0, "size": 12.0,
				"dmg": 6, "credits": 6, "tint": Color(0.7, 0.9, 1.3), "scale": 0.7 },
			"ex_guard": { "sheet": "cop", "hp": 6, "speed": 60.0, "size": 18.0,
				"dmg": 11, "credits": 14, "tint": Color(0.8, 0.85, 1.1), "scale": 1.0 },
		},
		"grate_pool": ["squatter", "drone", "drone", "ex_guard"],
		"hole_pool": ["drone"],
		"grates": 3, "rat_holes": 4, "chests": 2,
		"medkits_min": 2, "medkits_max": 3,
		"stash_credits": 250,
		"objective_prop": "relay",
		"objective_flag": "officeRelayFound",
		"objective_credits": 300,
		"seal_reward": 30, "seal_all_reward": 250,
		# WHISTLER — rogue phreaker squatting the dead tower (canon bounty
		# target). Spray-and-pray, hides behind summoned drones, fights to
		# the end.
		"boss": {
			"name": "WHISTLER", "sheet": "thug", "hp": 40, "speed": 95.0,
			"size": 18.0, "dmg": 12, "scale": 1.25,
			"tint": Color(0.8, 1.0, 1.2),
			"spray": { "count": 4, "dmg": 7, "cd": 3.0 },
			"summon": { "pool": ["drone"], "count": 2, "cd": 7.0, "max": 6 },
			"credits": 300,
			"flag": "whistlerDefeated",
			"drops": ["smg"],
			"bark_intro": "WHISTLER: 'this tower's MINE. every dead floor of it. leave or get unplugged.'",
		},
	},
	"corpo": {
		"name": "CORTEX HQ",
		"exit_label": "extract via the loading dock",
		"exit_scene": "street_stack",
		"exit_spawn": "from_corpo",
		"grid_w": 25, "grid_h": 21,
		"rooms": 9, "room_min": 4, "room_max": 7,
		"water_room_chance": 0.0,
		"flavor_chance": 0.35,               # labs, magenta glow
		"pal": {
			"floor": Color(0.128, 0.122, 0.142),
			"floor_flavor": Color(0.135, 0.072, 0.142),
			"wall": Color(0.195, 0.185, 0.205),
			"wall_rim": Color(0.300, 0.290, 0.320),
			"water": Color(0.03, 0.03, 0.05),
			"water_shine": Color(0.1, 0.1, 0.16),
			"bridge": Color(0.2, 0.2, 0.22),
			"sconce": Color(1.5, 0.4, 1.0),
			"flavor_light": Color(1.5, 0.3, 1.2),
			"accent": Color(1.4, 0.3, 1.0),
		},
		# Neuromancer floor: silver samurai bots + corpo ninjas
		"enemies": {
			"corpo_ninja": { "sheet": "ninja", "hp": 6, "speed": 95.0, "size": 16.0,
				"dmg": 12, "credits": 20, "tint": Color(0.7, 0.7, 0.9), "scale": 1.0 },
			"silver_samurai": { "sheet": "ninja", "hp": 12, "speed": 80.0, "size": 17.0,
				"dmg": 16, "credits": 35, "tint": Color(1.5, 1.5, 1.7), "scale": 1.1 },
			"mech_sentry": { "sheet": "thug", "hp": 16, "speed": 40.0, "size": 20.0,
				"dmg": 18, "credits": 40, "tint": Color(1.2, 1.2, 1.4), "scale": 1.15 },
		},
		"grate_pool": ["corpo_ninja", "corpo_ninja", "silver_samurai", "mech_sentry"],
		"hole_pool": ["corpo_ninja"],
		"grates": 4, "rat_holes": 2, "chests": 3,
		"medkits_min": 1, "medkits_max": 3,
		"stash_credits": 500,
		"objective_prop": "relay",
		"objective_flag": "corpoRelayFound",
		"objective_credits": 600,
		"seal_reward": 40, "seal_all_reward": 400,
		# THE COMPLIANCE OFFICER — corporate enforcement made flesh (canon
		# Cortex HQ boss). Slow, armored, hits like a severance package.
		"boss": {
			"name": "COMPLIANCE OFFICER", "sheet": "cop", "hp": 90,
			"speed": 65.0, "size": 26.0, "dmg": 20, "scale": 1.6,
			"tint": Color(0.85, 0.9, 1.3),
			"charge": true,
			"spray": { "count": 8, "dmg": 9, "cd": 5.0 },
			"summon": { "pool": ["corpo_ninja"], "count": 2, "cd": 10.0, "max": 5 },
			"credits": 600,
			"flag": "corpoBossDefeated",
			"drops": ["tesla_blade"],
			"bark_intro": "COMPLIANCE OFFICER: 'unauthorized presence detected. initiating termination review.'",
		},
	},
}

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["sewer"])
