extends Node

## GameState — autoload. Owns story flags, player stats, scene history.
## Every system reads/writes through this. SaveManager serializes it whole.
##
## Mirrors hacking-game's window.gameState pattern but as a typed autoload.

signal flag_set(name: String)
signal flag_cleared(name: String)
signal credits_changed(new_amount: int)
signal quest_completed(id: String, title: String, credits: int)

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
	_apply_dev_bankroll()
	_ensure_weapon()

## Debug builds start flush so testing never stalls on credits.
## Exported release builds are unaffected (is_debug_build() is false).
func _apply_dev_bankroll() -> void:
	if OS.is_debug_build():
		credits = maxi(credits, 100_000)

# ── Flags ─────────────────────────────────────────────────────────────

func set_flag(name: String, value := true) -> void:
	if value:
		flags[name] = true
		flag_set.emit(name)
		_recheck_quests()
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
	var q := Quests.get_quest(id)
	for f in q.get("on_start", {}).get("set_flags", []):
		set_flag(f)
	if active_quest == "":
		active_quest = id

func complete_quest(id: String) -> void:
	var q := Quests.get_quest(id)
	if q.is_empty() or quest_states.get(id, "") == "COMPLETED":
		return
	quest_states[id] = "COMPLETED"
	var on_complete: Dictionary = q.get("on_complete", {})
	for f in on_complete.get("set_flags", []):
		set_flag(f)
	if on_complete.has("credits"):
		add_credits(on_complete["credits"])
	if active_quest == id:
		active_quest = ""
	quest_completed.emit(id, q.get("title", id), int(on_complete.get("credits", 0)))

## The quest engine — flags drive everything (the Phaser QuestManager
## pattern): unlocked quests auto-activate, quests whose auto-checkable
## objectives are all met auto-complete, and completions chain (their
## flags can unlock and finish the next link in the same pass).
var _quest_recheck_busy := false

func _recheck_quests() -> void:
	if _quest_recheck_busy:
		return
	_quest_recheck_busy = true
	var changed := true
	while changed:
		changed = false
		for qid in Quests.ALL:
			var st: String = quest_states.get(qid, "")
			if st == "COMPLETED":
				continue
			if st != "ACTIVE" and Quests.prerequisites_met(qid, flags):
				start_quest(qid)
				changed = true
			if quest_states.get(qid, "") == "ACTIVE" 					and Quests.all_objectives_done(qid, flags, inventory):
				complete_quest(qid)
				changed = true
	_quest_recheck_busy = false

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
	_recheck_quests()
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
var dungeon_floor: int = 0              # current floor of a multi-floor dungeon (0-based; reset on street entry)
var vohl_floor: int = 1                 # current floor of the Vohl office tower (1-6; elevator reloads the scene)
var dungeon_seeds: Dictionary = {}      # dungeon id -> layout seed (per save)
var katana_level: int = 1               # legacy MK ladder (superseded by equipment)
var settings: Dictionary = { "lights": "full" }   # "full" | "low" (weak GPUs)

# ── Equipment — ported from the Phaser InventoryManager model ─────────
const Equip := preload("res://data/equipment.gd")

var equipped_weapon := "katana"
var equipment: Array = []            # gear ids, max 2 slots (canon)
var weapon_ammo: Dictionary = {}     # weapon id -> rounds left in the mag
var ammo_reserve: Dictionary = { "ballistic": 0, "energy": 0 }  # spare rounds by type; reload draws from here
var shield_hp := 0.0                 # transient; generators recharge it
var exposure := 0.0                  # deep-hack heat carried between net runs; feeds the sea hag
var phone_light := false             # phone flashlight toggle — a weak light anywhere, free
var hack_skill := 1                  # deep-hack proficiency; gates ICE risk, climbs as you clear nets

## Bump the deck rating (harder sites become survivable). Called when the
## player cracks a site's prize for the first time.
func raise_hack_skill(to_at_least: int) -> void:
	hack_skill = maxi(hack_skill, to_at_least)

## Best light the player currently has underground: 2 headlamp (bright,
## hands-free) > 1 phone flashlight (weak, free) > 0 nothing (eyes adjust).
func light_level() -> int:
	if headlamp_on():
		return 2
	if phone_light:
		return 1
	return 0

func weapon_def() -> Dictionary:
	return Equip.weapon(equipped_weapon)

func equip_weapon(id: String) -> bool:
	if not Equip.is_weapon(id) or not has_item(id):
		return false
	equipped_weapon = id
	return true

## Toggle a gear piece in/out of the 2 slots. Returns true if now equipped.
func toggle_gear(id: String) -> bool:
	if equipment.has(id):
		equipment.erase(id)
		shield_hp = minf(shield_hp, max_shield())
		return false
	if equipment.size() >= 2 or not Equip.is_gear(id) or not has_item(id):
		return false
	equipment.append(id)
	# Generators come online charged (canon recalc behavior)
	shield_hp = max_shield()
	return true

func _gear_sum(stat: String) -> float:
	var total := 0.0
	for id in equipment:
		total += float(Equip.gear(id).get(stat, 0))
	return total

func armor_rating() -> int:
	return int(_gear_sum("armor"))

func max_shield() -> float:
	return _gear_sum("shield")

func shield_recharge() -> float:
	return _gear_sum("recharge")

func damage_bonus() -> float:
	return _gear_sum("damage_bonus")

func hp_regen() -> float:
	return _gear_sum("hp_regen")

func gear_speed_mult() -> float:
	return 1.0 + _gear_sum("speed_bonus") - _gear_sum("speed_penalty")

## Canon damage-taken formula (DungeonScene.js): flat armor reduction
## (never below 1), then shields absorb before health.
func take_damage(amount: int) -> void:
	var amt := amount
	if armor_rating() > 0:
		amt = maxi(1, amt - armor_rating())
	if shield_hp > 0.0:
		var absorbed := minf(float(amt), shield_hp)
		shield_hp -= absorbed
		amt -= int(absorbed)
	hp = maxi(0, hp - amt)

## Headlamp is owned gear with a switch (GEAR app) — on by default
func headlamp_on() -> bool:
	return has_item("headlamp") and not has_flag("headlampOff")

func ammo_left(id: String) -> int:
	return int(weapon_ammo.get(id, Equip.weapon(id).get("max_ammo", 0)))

func set_ammo(id: String, n: int) -> void:
	weapon_ammo[id] = n

## Spare-ammo reserve, by type ("ballistic"/"energy") — reload draws here
func reserve_of(atype: String) -> int:
	return int(ammo_reserve.get(atype, 0))

func add_ammo(atype: String, n: int) -> void:
	if atype == "":
		return
	ammo_reserve[atype] = maxi(0, reserve_of(atype) + n)

## Try to reload a weapon's mag from its type reserve. Returns rounds loaded
## (0 = reserve dry; caller keeps the weapon empty and prompts a swap).
func reload_from_reserve(id: String) -> int:
	var atype: String = Equip.ammo_type(id)
	var reserve: int = reserve_of(atype)
	if reserve <= 0:
		return 0
	var mag: int = int(Equip.weapon(id).get("max_ammo", 1))
	var load_n: int = mini(mag, reserve)
	add_ammo(atype, -load_n)
	set_ammo(id, load_n)
	return load_n

## Everyone owns their starter blade — grant + equip if missing (new games
## and legacy saves from the katana_level era alike)
func _ensure_weapon() -> void:
	if not has_item("katana"):
		inventory.append("katana")
	if not Equip.is_weapon(equipped_weapon) or not has_item(equipped_weapon):
		equipped_weapon = "katana"

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
		"settings": settings.duplicate(true),
		"equipped_weapon": equipped_weapon,
		"equipment": equipment.duplicate(),
		"weapon_ammo": weapon_ammo.duplicate(true),
		"exposure": exposure,
		"ammo_reserve": ammo_reserve.duplicate(),
		"phone_light": phone_light,
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
	settings = d.get("settings", { "lights": "full" }).duplicate(true)
	equipped_weapon = d.get("equipped_weapon", "katana")
	equipment = d.get("equipment", []).duplicate()
	weapon_ammo = d.get("weapon_ammo", {}).duplicate(true)
	exposure = d.get("exposure", 0.0)
	ammo_reserve = d.get("ammo_reserve", { "ballistic": 0, "energy": 0 }).duplicate()
	phone_light = d.get("phone_light", false)
	shield_hp = max_shield()
	_apply_dev_bankroll()
	_ensure_weapon()
	last_scene_id = d.get("last_scene_id", "")
