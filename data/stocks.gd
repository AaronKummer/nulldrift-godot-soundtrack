## Stocks — phone "STOX" app data. Just the definitions (ticker, name, base
## price, volatility). Live prices + changes live in StocksState (autoload),
## which ticks once a minute and applies news effects.
class_name Stocks
extends Object

const TICKERS := [
	{ "ticker": "MCI",  "name": "MegaCorp Industries",     "base": 142.50,  "vol": 0.04 },
	{ "ticker": "CJKL", "name": "Chrome Jackals LLC",      "base": 0.42,    "vol": 0.15 },
	{ "ticker": "KRNX", "name": "Kuronex Corp",            "base": 1205.00, "vol": 0.02 },
	{ "ticker": "NCPD", "name": "NCPD Pension Fund",       "base": 5.12,    "vol": 0.08 },
	{ "ticker": "GLCH", "name": "Glitch Labs",             "base": 8.88,    "vol": 0.18 },
	{ "ticker": "PZZA", "name": "Tony's Pizza Inc",        "base": 1.50,    "vol": 0.05 },
	{ "ticker": "VOID", "name": "VoidNet Systems",         "base": 0.01,    "vol": 0.50 },
	{ "ticker": "NEON", "name": "Neon Arcade Group",       "base": 33.33,   "vol": 0.07 },
	{ "ticker": "TUSK", "name": "TuskCorp BioSystems",     "base": 8840.00, "vol": 0.03 },
	{ "ticker": "VOHL", "name": "Vohl Pharmaceuticals",    "base": 67.20,   "vol": 0.05 },
	{ "ticker": "VVS",  "name": "Violet Vector Syndicate", "base": 420.69,  "vol": 0.06 },
]

static func get_ticker(symbol: String) -> Dictionary:
	for t in TICKERS:
		if t.get("ticker", "") == symbol:
			return t
	return {}
