## Equipment — verbatim port of hacking-game's weapon/armor tables
## (src/data/itemDatabase.js WEAPON_ITEM_DEFINITIONS + equipment.js).
## Stats are canon; do not rebalance here. Phaser units: range in world px
## (melee 6-35, ranged 80-600), speed in ms between attacks.
## The dungeon converts: reach_px = range * DUNGEON_SCALE, cooldown_s = speed/1000.
class_name Equipment
extends Object

const WEAPONS := {
	# ── melee ────────────────────────────────────────────────────────────
	"knife":        { "name": "KNIFE",        "type": "melee", "damage": 1,  "range": 6,  "speed": 150, "price": 0 },
	"baton":        { "name": "BATON",        "type": "melee", "damage": 1,  "range": 12, "speed": 200, "price": 400 },
	"pipe":         { "name": "PIPE",         "type": "melee", "damage": 2,  "range": 18, "speed": 260, "price": 700 },
	"bat":          { "name": "BAT",          "type": "melee", "damage": 2,  "range": 20, "speed": 280, "price": 900 },
	"machete":      { "name": "MACHETE",      "type": "melee", "damage": 3,  "range": 16, "speed": 220, "price": 1500 },
	"katana":       { "name": "KATANA",       "type": "melee", "damage": 4,  "range": 24, "speed": 180, "price": 3500 },
	"power_fist":   { "name": "POWER FIST",   "type": "melee", "damage": 6,  "range": 10, "speed": 350, "status": "stun", "drop": true },
	"mono_whip":    { "name": "MONO WHIP",    "type": "melee", "damage": 5,  "range": 35, "speed": 280, "piercing": true, "price": 25000 },
	"monoblade":    { "name": "MONOBLADE",    "type": "melee", "damage": 7,  "range": 26, "speed": 200, "status": "regen_block", "drop": true },
	"tesla_blade":  { "name": "TESLA BLADE",  "type": "melee", "damage": 5,  "range": 22, "speed": 200, "status": "emp", "price": 28000 },
	"gravity_hammer": { "name": "GRAVITY HAMMER", "type": "melee", "damage": 8, "range": 14, "speed": 500, "status": "slow", "price": 40000 },
	"chronoblade":  { "name": "CHRONOBLADE",  "type": "melee", "damage": 9,  "range": 26, "speed": 100, "double_strike": true, "price": 10000 },
	"mjolnir":      { "name": "MJOLNIR",      "type": "melee", "damage": 15, "range": 16, "speed": 450, "chain": 3, "price": 10000 },
	"soul_reaper":  { "name": "SOUL REAPER",  "type": "melee", "damage": 10, "range": 28, "speed": 200, "life_steal": 0.2, "drop": true },
	"void_blade":   { "name": "VOID BLADE",   "type": "melee", "damage": 12, "range": 30, "speed": 160, "piercing": true, "drop": true },
	"dragon_slayer": { "name": "DRAGON SLAYER", "type": "melee", "damage": 15, "range": 32, "speed": 220, "boss_multiplier": 3, "drop": true },

	# ── ranged ───────────────────────────────────────────────────────────
	"taser":        { "name": "TASER",        "type": "ranged", "damage": 1,  "range": 150, "speed": 400,  "max_ammo": 3,  "status": "stun", "price": 2000 },
	"pistol":       { "name": "PISTOL",       "type": "ranged", "damage": 5,  "range": 250, "speed": 1800, "max_ammo": 17, "price": 5000 },
	"shotgun":      { "name": "SHOTGUN",      "type": "ranged", "damage": 5,  "range": 80,  "speed": 800,  "max_ammo": 6,  "pellets": 4, "price": 8000 },
	"smg":          { "name": "SMG",          "type": "ranged", "damage": 2,  "range": 160, "speed": 180,  "max_ammo": 30, "burst": 3, "price": 12000 },
	"revolver":     { "name": "REVOLVER",     "type": "ranged", "damage": 8,  "range": 250, "speed": 900,  "max_ammo": 6,  "price": 18000 },
	"plasma_pistol": { "name": "PLASMA PISTOL", "type": "ranged", "damage": 4, "range": 180, "speed": 600, "max_ammo": 8, "explosive": true, "status": "burn", "price": 22000 },
	"fusion_carbine": { "name": "FUSION CARBINE", "type": "ranged", "damage": 6, "range": 220, "speed": 300, "max_ammo": 20, "burst": 2, "status": "burn", "price": 30000 },
	"tesla_rifle":  { "name": "TESLA RIFLE",  "type": "ranged", "damage": 3,  "range": 140, "speed": 250,  "max_ammo": 40, "chain": 2, "status": "emp", "price": 35000 },
	"rail_gun":     { "name": "RAIL GUN",     "type": "ranged", "damage": 15, "range": 400, "speed": 2500, "max_ammo": 3,  "piercing": true, "price": 50000 },
	"plasma_cannon": { "name": "PLASMA CANNON", "type": "ranged", "damage": 10, "range": 240, "speed": 700, "max_ammo": 5, "explosive": true, "status": "burn", "price": 500000 },
	"nyxs_gift":    { "name": "NYX'S GIFT",   "type": "ranged", "damage": 12, "range": 280, "speed": 400,  "max_ammo": 20, "piercing": true, "explosive": true, "drop": true },
	"singularity_cannon": { "name": "SINGULARITY CANNON", "type": "ranged", "damage": 25, "range": 500, "speed": 4000, "max_ammo": 1, "piercing": true, "explosive": true, "drop": true },
	"gods_hand":    { "name": "GOD'S HAND",   "type": "ranged", "damage": 50, "range": 600, "speed": 3000, "max_ammo": 3,  "piercing": true, "explosive": true, "price": 500000 },
}

## Wearable/passive equipment — 2 slots max, canon (equipment.js)
const GEAR := {
	"flak_vest":      { "name": "FLAK VEST",      "armor": 1, "price": 3000 },
	"combat_armor":   { "name": "COMBAT ARMOR",   "armor": 2, "price": 8000 },
	"heavy_plate":    { "name": "HEAVY PLATE",    "armor": 3, "speed_penalty": 0.15, "price": 15000 },
	"stealth_suit":   { "name": "STEALTH SUIT",   "armor": 1, "detection_reduction": 0.3, "price": 12000 },
	"nanoweave":      { "name": "NANOWEAVE",      "armor": 4, "hp_regen": 0.1, "drop": true },
	"phantom_rig":    { "name": "PHANTOM RIG",    "armor": 5, "speed_bonus": 0.2, "price": 12000 },
	"pf_generator":   { "name": "PF GENERATOR",   "shield": 15, "recharge": 0.5, "price": 20000 },
	"rf_generator":   { "name": "RF GENERATOR",   "shield": 25, "recharge": 0.3, "price": 35000 },
	"quantum_shield": { "name": "QUANTUM SHIELD", "shield": 50, "recharge": 2.0, "drop": true },
	"berserker_stim": { "name": "BERSERKER STIM", "damage_bonus": 0.5, "hp_regen": 0.5, "speed_bonus": 0.15, "price": 8000 },
}

# Energy weapons draw from the "energy" reserve (cells); everything else
# ballistic (rounds). Melee returns "" — no ammo, always usable.
const ENERGY_WEAPONS := ["taser", "plasma_pistol", "fusion_carbine", "tesla_rifle",
	"plasma_cannon", "singularity_cannon", "nyxs_gift", "gods_hand"]

static func ammo_type(id: String) -> String:
	var w: Dictionary = WEAPONS.get(id, {})
	if w.get("type", "") != "ranged":
		return ""
	return "energy" if ENERGY_WEAPONS.has(id) else "ballistic"

static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["knife"])

static func gear(id: String) -> Dictionary:
	return GEAR.get(id, {})

static func is_weapon(id: String) -> bool:
	return WEAPONS.has(id)

static func is_gear(id: String) -> bool:
	return GEAR.has(id)

## Short label for hotbar slots
static func glyph(id: String) -> String:
	var n: String = WEAPONS.get(id, GEAR.get(id, {})).get("name", id.to_upper())
	return n.substr(0, 4).strip_edges()
