## DungeonGen — procedural maze generator for the reusable dungeon scene.
##
## generate(def, seed) rolls a fresh layout every call: scattered rooms
## connected by L-corridors, optional flooded rooms with plank bridges,
## flavor-tagged rooms (moss grottos / server rooms / labs), spawner grates,
## rat holes, item pickups, a stash in the farthest room, and an objective
## prop along the way. Rooms chain-connect, so everything is reachable.
##
## Tiles: 0 wall · 1 floor · 2 water · 3 bridge
class_name DungeonGen
extends Object

const T_WALL := 0
const T_FLOOR := 1
const T_WATER := 2
const T_BRIDGE := 3

static func generate(def: Dictionary, rng_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var w: int = def.grid_w
	var h: int = def.grid_h
	var tiles: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(T_WALL)
		tiles.append(row)

	# ── Rooms: entrance first (top-left region), then scatter ──
	var rooms: Array = []   # Rect2i
	var entrance_room := Rect2i(2, 2, 3, 3)
	rooms.append(entrance_room)
	var want: int = def.rooms
	var attempts := 0
	while rooms.size() < want + 1 and attempts < 200:
		attempts += 1
		var rw: int = rng.randi_range(def.room_min, def.room_max)
		var rh: int = rng.randi_range(def.room_min, def.room_max)
		var rx: int = rng.randi_range(1, w - rw - 2)
		var ry: int = rng.randi_range(1, h - rh - 2)
		var cand := Rect2i(rx, ry, rw, rh)
		var ok := true
		for r in rooms:
			if cand.grow(1).intersects(r):
				ok = false
				break
		if ok:
			rooms.append(cand)
	# Carve rooms
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				tiles[y][x] = T_FLOOR

	# ── Corridors: chain each room to the nearest already-connected one ──
	var connected: Array = [rooms[0]]
	var pending: Array = rooms.slice(1)
	while not pending.is_empty():
		var best_i := 0
		var best_j := 0
		var best_d := 1.0e12
		for i in pending.size():
			var ci: Vector2 = Vector2(pending[i].get_center())
			for j in connected.size():
				var d: float = ci.distance_squared_to(Vector2(connected[j].get_center()))
				if d < best_d:
					best_d = d
					best_i = i
					best_j = j
		var a: Vector2i = pending[best_i].get_center()
		var b: Vector2i = connected[best_j].get_center()
		_carve_l(tiles, a, b, rng.randf() < 0.5)
		connected.append(pending[best_i])
		pending.remove_at(best_i)

	# ── Water rooms: big rooms flood, straight bridge through the middle ──
	var water_rooms: Array = []
	for r in rooms.slice(1):
		if r.size.x >= 4 and r.size.y >= 4 and rng.randf() < def.water_room_chance:
			water_rooms.append(r)
			for y in range(r.position.y + 1, r.end.y - 1):
				for x in range(r.position.x + 1, r.end.x - 1):
					tiles[y][x] = T_WATER
			# Bridge across the shorter axis, through the center
			var c: Vector2i = r.get_center()
			if r.size.x >= r.size.y:
				for x in range(r.position.x, r.end.x):
					if tiles[c.y][x] == T_WATER:
						tiles[c.y][x] = T_BRIDGE
			else:
				for y in range(r.position.y, r.end.y):
					if tiles[y][c.x] == T_WATER:
						tiles[y][c.x] = T_BRIDGE

	# ── Flavor rooms (moss / servers / labs) — never the entrance/water ──
	var flavor_cells := {}
	for r in rooms.slice(1):
		if not water_rooms.has(r) and rng.randf() < def.flavor_chance:
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if tiles[y][x] == T_FLOOR:
						flavor_cells[Vector2i(x, y)] = true

	# ── Feature placement ──
	var entrance: Vector2i = entrance_room.get_center()
	# Rooms sorted far → near from the entrance
	var by_dist: Array = rooms.slice(1)
	by_dist.sort_custom(func(ra, rb):
		return Vector2(ra.get_center()).distance_squared_to(Vector2(entrance)) > \
			Vector2(rb.get_center()).distance_squared_to(Vector2(entrance)))
	var stash: Vector2i = _floor_spot(tiles, by_dist[0], rng) if by_dist.size() > 0 else entrance
	var objective: Vector2i = _floor_spot(tiles, by_dist[1], rng) if by_dist.size() > 1 else entrance

	# Grates: spread across distinct non-entrance rooms
	var grates: Array = []
	var grate_rooms: Array = rooms.slice(1).duplicate()
	_shuffle(grate_rooms, rng)
	for r in grate_rooms:
		if grates.size() >= def.grates:
			break
		var spot := _floor_spot(tiles, r, rng)
		if spot != stash and spot != objective:
			grates.append(spot)

	# Rat holes: floor cells hugging a wall
	var holes: Array = []
	attempts = 0
	while holes.size() < def.rat_holes and attempts < 200:
		attempts += 1
		var r: Rect2i = rooms[rng.randi_range(1, rooms.size() - 1)]
		var spot := _floor_spot(tiles, r, rng)
		if _next_to_wall(tiles, spot) and not holes.has(spot) \
				and spot != stash and spot != objective:
			holes.append(spot)

	# Medkits scattered in random rooms
	var medkits: Array = []
	var kit_count: int = rng.randi_range(def.medkits_min, def.medkits_max)
	attempts = 0
	while medkits.size() < kit_count and attempts < 200:
		attempts += 1
		var r: Rect2i = rooms[rng.randi_range(1, rooms.size() - 1)]
		var spot := _floor_spot(tiles, r, rng)
		if not medkits.has(spot) and spot != stash and spot != objective \
				and not grates.has(spot):
			medkits.append(spot)

	# Locked chests — lockpick loot, scattered like medkits
	var chests: Array = []
	var chest_count: int = def.get("chests", 2)
	attempts = 0
	while chests.size() < chest_count and attempts < 200:
		attempts += 1
		var r: Rect2i = rooms[rng.randi_range(1, rooms.size() - 1)]
		var spot := _floor_spot(tiles, r, rng)
		if not chests.has(spot) and not medkits.has(spot) and not grates.has(spot) 				and spot != stash and spot != objective:
			chests.append(spot)

	return {
		"w": w, "h": h, "tiles": tiles, "rooms": rooms,
		"flavor": flavor_cells, "entrance": entrance,
		"grates": grates, "holes": holes, "medkits": medkits,
		"chests": chests, "stash": stash, "objective": objective,
	}

static func _carve_l(tiles: Array, a: Vector2i, b: Vector2i, x_first: bool) -> void:
	var corner := Vector2i(b.x, a.y) if x_first else Vector2i(a.x, b.y)
	for p in [[a, corner], [corner, b]]:
		var from: Vector2i = p[0]
		var to: Vector2i = p[1]
		var d: Vector2i = (to - from).sign()
		var cur := from
		while cur != to:
			if tiles[cur.y][cur.x] == T_WALL:
				tiles[cur.y][cur.x] = T_FLOOR
			cur += d
		if tiles[to.y][to.x] == T_WALL:
			tiles[to.y][to.x] = T_FLOOR

static func _floor_spot(tiles: Array, r: Rect2i, rng: RandomNumberGenerator) -> Vector2i:
	for i in 30:
		var p := Vector2i(rng.randi_range(r.position.x, r.end.x - 1),
			rng.randi_range(r.position.y, r.end.y - 1))
		if tiles[p.y][p.x] == T_FLOOR:
			return p
	return r.get_center()

static func _next_to_wall(tiles: Array, p: Vector2i) -> bool:
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = p + off
		if q.y >= 0 and q.y < tiles.size() and q.x >= 0 and q.x < tiles[0].size():
			if tiles[q.y][q.x] == T_WALL:
				return true
	return false

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
