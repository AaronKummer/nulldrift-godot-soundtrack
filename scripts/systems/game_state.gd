extends Node

## GameState — autoload. Owns story flags, player stats, scene history.
## Every system reads/writes through this. SaveManager serializes it whole.
##
## Mirrors hacking-game's window.gameState pattern but as a typed autoload.

signal flag_set(name: String)
signal flag_cleared(name: String)
signal credits_changed(new_amount: int)

var flags: Dictionary = {}
var credits: int = 0
var hp: int = 100
var hp_max: int = 100
var inventory: Array = []  # array of item ids
var active_quest: String = ""
var quest_states: Dictionary = {}  # quest_id → "ACTIVE"|"COMPLETED"|...
var last_scene_id: String = ""

func _ready() -> void:
	# Auto-start any quests flagged auto_start=true
	for qid in Quests.auto_start_quests():
		start_quest(qid)

# ── Flags ─────────────────────────────────────────────────────────────

func set_flag(name: String, value := true) -> void:
	if value:
		flags[name] = true
		flag_set.emit(name)
	else:
		clear_flag(name)

func clear_flag(name: String) -> void:
	if flags.erase(name):
		flag_cleared.emit(name)

func has_flag(name: String) -> bool:
	return flags.get(name, false)

# ── Quests ────────────────────────────────────────────────────────────

func start_quest(id: String) -> void:
	if quest_states.get(id, "") == "COMPLETED":
		return
	if not Quests.prerequisites_met(id, flags):
		return
	quest_states[id] = "ACTIVE"
	if active_quest == "":
		active_quest = id

func complete_quest(id: String) -> void:
	var q := Quests.get_quest(id)
	if q.is_empty():
		return
	quest_states[id] = "COMPLETED"
	var on_complete: Dictionary = q.get("on_complete", {})
	for f in on_complete.get("set_flags", []):
		set_flag(f)
	if on_complete.has("credits"):
		add_credits(on_complete["credits"])
	if active_quest == id:
		active_quest = ""

# ── Currency / inventory ──────────────────────────────────────────────

func add_credits(n: int) -> void:
	credits = max(0, credits + n)
	credits_changed.emit(credits)

## Consumables stack (one array entry per unit); gear stays unique.
const STACKABLE := ["medkit", "grenade", "stim"]
## Hotbar-assignable items and their HUD glyphs.
const HOTBAR_GLYPHS := { "medkit": "KIT", "grenade": "GRN", "stim": "STM" }
var hotbar: Dictionary = { "1": "medkit", "2": "grenade", "3": "stim",
	"4": "", "5": "", "6": "" }

func add_item(item_id: String) -> void:
	if STACKABLE.has(item_id) or not inventory.has(item_id):
		inventory.append(item_id)
	# Auto-assign new consumable types to the first empty slot
	if HOTBAR_GLYPHS.has(item_id) and not hotbar.values().has(item_id):
		for s in ["1", "2", "3", "4", "5", "6"]:
			if hotbar[s] == "":
				hotbar[s] = item_id
				break

func count_item(item_id: String) -> int:
	var n := 0
	for it in inventory:
		if it == item_id:
			n += 1
	return n

var arcade_scores: Dictionary = {}   # game id -> best score
var pending_dungeon: String = "sewer"   # which dungeon the next dungeon.tscn load builds
var dungeon_seeds: Dictionary = {}      # dungeon id -> layout seed (per save)
var katana_level: int = 1               # weapon-store upgrades (1-3)

func arcade_best(game: String) -> int:
	return int(arcade_scores.get(game, 0))

## Returns true if this run set a new high score.
func submit_arcade_score(game: String, score: int) -> bool:
	if score > arcade_best(game):
		arcade_scores[game] = score
		return true
	return false

func has_item(item_id: String) -> bool:
	return inventory.has(item_id)

# ── Serialize for SaveManager ─────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"credits": credits,
		"hp": hp,
		"hp_max": hp_max,
		"inventory": inventory.duplicate(),
		"active_quest": active_quest,
		"quest_states": quest_states.duplicate(true),
		"last_scene_id": last_scene_id,
		"arcade_scores": arcade_scores.duplicate(true),
		"katana_level": katana_level,
		"dungeon_seeds": dungeon_seeds.duplicate(true),
		"hotbar": hotbar.duplicate(true),
	}

func from_dict(d: Dictionary) -> void:
	flags = d.get("flags", {}).duplicate(true)
	credits = d.get("credits", 0)
	hp = d.get("hp", 100)
	hp_max = d.get("hp_max", 100)
	inventory = d.get("inventory", []).duplicate()
	active_quest = d.get("active_quest", "")
	quest_states = d.get("quest_states", {}).duplicate(true)
	arcade_scores = d.get("arcade_scores", {}).duplicate(true)
	katana_level = d.get("katana_level", 1)
	dungeon_seeds = d.get("dungeon_seeds", {}).duplicate(true)
	hotbar = d.get("hotbar", { "1": "medkit", "2": "grenade", "3": "stim",
		"4": "", "5": "", "6": "" }).duplicate(true)
	last_scene_id = d.get("last_scene_id", "")
