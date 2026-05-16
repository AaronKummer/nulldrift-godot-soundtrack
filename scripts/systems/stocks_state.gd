## StocksState — autoload. Ticks every TICK_INTERVAL seconds, performing a
## small random walk on every ticker scaled by its volatility. Game events
## (news articles, story flags) call `apply_event(effect)` to nudge prices.
##
## The phone STOX app simply reads `current_price(symbol)` and
## `change_pct(symbol)` — no UI logic lives here.
##
## Saved/restored via SaveManager.
extends Node

const StocksData := preload("res://data/stocks.gd")

const TICK_INTERVAL := 30.0    # seconds between random walk ticks
const RANDOM_WALK_SCALE := 0.012 # base per-tick swing as a fraction of vol

signal price_changed(symbol: String, price: float, change_pct: float)

# Live values, all keyed by ticker:
var prices: Dictionary = {}      # { "MCI": 142.50, ... }
var change_pct: Dictionary = {}  # { "MCI": -2.4, ... }   (recent change %)
# Effects already applied (so a news article doesn't double-fire on re-read)
var applied_events: Dictionary = {}

var _t := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_reset_to_base()

func _process(delta: float) -> void:
	_t += delta
	if _t < TICK_INTERVAL:
		return
	_t = 0.0
	_tick()

# ─────────────────────────────────────────────────────────────────────
# READ
# ─────────────────────────────────────────────────────────────────────

func current_price(symbol: String) -> float:
	return float(prices.get(symbol, _base_of(symbol)))

func current_change_pct(symbol: String) -> float:
	return float(change_pct.get(symbol, 0.0))

## A snapshot for the phone STOX list: array of { ticker, name, price, change }
func snapshot() -> Array:
	var out: Array = []
	for t in StocksData.TICKERS:
		var sym: String = t.get("ticker", "")
		out.append({
			"ticker": sym,
			"name": t.get("name", sym),
			"price": current_price(sym),
			"change": current_change_pct(sym),
		})
	return out

# ─────────────────────────────────────────────────────────────────────
# WRITE — events come from the game world (news, story flags, scenes)
# ─────────────────────────────────────────────────────────────────────

## Apply a percent change to one or more tickers. `event_id` is an opt-in
## idempotency key so re-publishing the same article won't double-apply.
func apply_event(effect: Dictionary, event_id: String = "") -> void:
	if event_id != "" and applied_events.has(event_id):
		return
	for symbol in effect.keys():
		_nudge(symbol, float(effect[symbol]))
	if event_id != "":
		applied_events[event_id] = true

# ─────────────────────────────────────────────────────────────────────
# INTERNAL
# ─────────────────────────────────────────────────────────────────────

func _reset_to_base() -> void:
	prices.clear()
	change_pct.clear()
	for t in StocksData.TICKERS:
		var sym: String = t.get("ticker", "")
		prices[sym] = float(t.get("base", 1.0))
		change_pct[sym] = 0.0

func _base_of(symbol: String) -> float:
	var t: Dictionary = StocksData.get_ticker(symbol)
	return float(t.get("base", 1.0))

func _vol_of(symbol: String) -> float:
	var t: Dictionary = StocksData.get_ticker(symbol)
	return float(t.get("vol", 0.05))

func _tick() -> void:
	for t in StocksData.TICKERS:
		var sym: String = t.get("ticker", "")
		var vol: float = _vol_of(sym)
		var delta_pct: float = _rng.randfn(0.0, vol * 100.0 * RANDOM_WALK_SCALE)
		_nudge(sym, delta_pct)

func _nudge(symbol: String, pct: float) -> void:
	var p: float = current_price(symbol)
	var new_p: float = max(0.001, p * (1.0 + pct / 100.0))
	prices[symbol] = new_p
	change_pct[symbol] = current_change_pct(symbol) + pct
	price_changed.emit(symbol, new_p, change_pct[symbol])

# ─────────────────────────────────────────────────────────────────────
# Save/Load
# ─────────────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"prices": prices.duplicate(),
		"change_pct": change_pct.duplicate(),
		"applied_events": applied_events.duplicate(),
	}

func from_dict(d: Dictionary) -> void:
	prices = d.get("prices", {})
	change_pct = d.get("change_pct", {})
	applied_events = d.get("applied_events", {})
	if prices.is_empty():
		_reset_to_base()
