## News articles — phone "NEWS" app data. Headlines, sources, bodies.
## Some articles can be gated behind story flags (require_flag).
##
## Articles may have a `stock_effect` key — when the player views (or the
## game "publishes") the article, StocksState applies the effect.
## Effect shape: { "TICKER": pct_change_float, ... }
class_name NewsArticles
extends Object

const ARTICLES := [
	{
		"id": "chrome_jackals_garage",
		"headline": "CHROME JACKALS SEIZE PARKING GARAGE",
		"source": "NightCity Wire",
		"time": "11:58 PM",
		"body": "The Chrome Jackals gang has claimed the downtown parking structure as their new base of operations. Residents report hearing screams and cybernetic grinding noises at all hours. NCPD spokesperson stated they \"have no plans to investigate at this time\" citing \"budget constraints\" and \"not wanting to die.\"",
		"stock_effect": { "CJKL": 25.0, "NCPD": -8.0 },
	},
	{
		"id": "mci_nanobot_scandal",
		"headline": "MEGACORP STOCK CRASHES 40% AFTER NANOBOT SCANDAL",
		"source": "CredNet Financial",
		"time": "10:30 PM",
		"body": "MegaCorp Industries shares plummeted after leaked internal memos revealed their new NanoHealth nanobots were actually mining cryptocurrency inside patients' bloodstreams. CEO issued a statement calling it \"an innovative dual-purpose healthcare solution.\" Lawsuits pending.",
		"stock_effect": { "MCI": -40.0 },
	},
	{
		"id": "pizza_driver_mugged",
		"headline": "PIZZA DELIVERY DRIVER MUGGED FOR 3RD TIME THIS WEEK",
		"source": "NightCity Wire",
		"time": "9:15 PM",
		"body": "An unidentified pizza delivery driver was attacked again near Sector 7. The driver, described as \"surprisingly resilient for someone who makes minimum wage,\" fought off two assailants before completing the delivery. Tony's Pizza has declined to comment or provide hazard pay.",
		"stock_effect": { "PZZA": -8.4 },
	},
	{
		"id": "glitch_streets",
		"headline": "NEW CYBER-DRUG \"GLITCH\" FLOODS STREETS",
		"source": "Underground Herald",
		"time": "8:00 PM",
		"body": "A new synthetic compound known as \"Glitch\" has appeared in the city's underground markets. Users report experiencing reality fragmentation, temporary x-ray vision, and an overwhelming desire to reorganize their inventory. Street doc Severin warns: \"Don't do Glitch. Or do. I get paid either way.\"",
		"stock_effect": { "GLCH": 45.3 },
	},
	{
		"id": "arcade_riot",
		"headline": "ARCADE HIGH SCORE BROKEN, CROWD RIOTS",
		"source": "GameGrid Daily",
		"time": "6:45 PM",
		"body": "Chaos erupted at the downtown arcade after a player known only as \"Chad\" claimed a new high score on Neon Survivors. Several witnesses dispute the score, citing \"suspicious button mashing\" and \"his mom was blocking the screen.\" Three arcade cabinets were destroyed in the ensuing riot.",
		"stock_effect": { "NEON": 12.7 },
	},
	{
		"id": "power_blackouts",
		"headline": "POWER GRID FAILURES LINKED TO CRYPTO MINING",
		"source": "NightCity Wire",
		"time": "5:30 PM",
		"body": "Rolling blackouts across sectors 4-9 have been traced to an illegal cryptocurrency mining operation running on the city's power grid. The miners, operating from an abandoned warehouse, were generating approximately $3.50 per day in DogeCoin. \"Worth it,\" said one miner before being arrested.",
	},
	{
		"id": "brother_neon",
		"headline": "STREET PREACHER ARRESTED FOR \"WEAPONIZED SERMONS\"",
		"source": "Underground Herald",
		"time": "4:15 PM",
		"body": "A street preacher known as \"Brother Neon\" was detained after his sidewalk sermons caused three cyborgs to simultaneously hard-reboot. NCPD classified his voice as a \"non-lethal sonic weapon.\" He was released after officers couldn't determine which precinct handles spiritual warfare.",
	},
	{
		"id": "atms_hacked",
		"headline": "CORPO DISTRICT ATMs HACKED, DISPENSING FREE CREDITS",
		"source": "CredNet Financial",
		"time": "3:00 PM",
		"body": "Multiple ATMs in the corporate district were compromised overnight, dispensing credits to anyone with a basic jack-in cable. NexaCorp has issued a statement calling the breach \"impossible\" while simultaneously replacing every ATM in a 6-block radius. Street-level hackers report the exploit was \"embarrassingly simple.\"",
	},
	{
		"id": "drone_ramen",
		"headline": "SURVEILLANCE DRONE CRASHES INTO RAMEN SHOP",
		"source": "NightCity Wire",
		"time": "1:45 PM",
		"body": "A MegaCorp surveillance drone malfunctioned during a routine patrol and crashed directly into Mama Tanaka's Noodle House. The drone's camera was still recording when it landed in a vat of tonkotsu broth. MegaCorp has offered to pay for damages in \"MegaCoin\" which Mama Tanaka described as \"not real money.\"",
		"stock_effect": { "MCI": -5.0 },
	},
	{
		"id": "scooter_theft",
		"headline": "SCOOTER THEFT EPIDEMIC HITS ALL-TIME HIGH",
		"source": "GameGrid Daily",
		"time": "12:30 PM",
		"body": "Scooter theft across all sectors has increased 400% this quarter. The NCPD has attributed the spike to \"one specific individual\" but declined to release a name or description. Rental companies are now requiring a DNA sample, retinal scan, and a signed promise not to drive into the warzone.",
	},
	{
		"id": "tusk_takeover",
		"headline": "LEON TUSK ACQUIRES MEGACORP IN HOSTILE TAKEOVER",
		"source": "CredNet Financial",
		"time": "2:00 PM",
		"body": "Billionaire industrialist Leon Tusk has completed his hostile acquisition of MegaCorp Industries for an undisclosed sum. Tusk, CEO of TuskCorp BioSystems, issued a statement via encrypted broadcast: \"MegaCorp's neural research complements my vision for human evolution.\" Tusk has not been seen in public since his... transformation.",
		"require_flag": "tuskTakeoverNews",
		"stock_effect": { "TUSK": 22.4, "MCI": -15.0 },
	},
	{
		"id": "tuskcorp_bioeng",
		"headline": "TUSKCORP BIOENGINEERING DIVISION UNDER INVESTIGATION",
		"source": "Underground Herald",
		"time": "9:30 PM",
		"body": "Leaked documents suggest TuskCorp's Gene Forge program produced more than just medical breakthroughs. Classified test logs describe \"apex predator integration\" and \"cryogenic genome splicing.\" One researcher, speaking anonymously: \"What walked out of Lab 7 was not the man who walked in.\"",
		"require_flag": "tuskInvestigation",
		"stock_effect": { "TUSK": -8.0 },
	},
	{
		"id": "tusk_spotted",
		"headline": "TUSK SPOTTED IN FINANCIAL DISTRICT — BYSTANDERS REPORT \"FEAR\"",
		"source": "NightCity Wire",
		"time": "11:45 PM",
		"body": "Multiple witnesses reported seeing Leon Tusk entering VVS Tower late last night, flanked by armed guards in white armor. Descriptions vary wildly. \"He's huge. Like, not human huge,\" said one food vendor.",
		"require_flag": "tuskSpotted",
		"stock_effect": { "VVS": 8.8 },
	},
	{
		"id": "vohl_tuskcorp",
		"headline": "VOHL PHARMACEUTICALS REVEALS TUSKCORP AS MAJORITY INVESTOR",
		"source": "CredNet Financial",
		"time": "4:00 PM",
		"body": "Financial filings reveal TuskCorp BioSystems holds a 71% stake in Vohl Pharmaceuticals. This connects Leon Tusk to Dr. Erasmus Vohl's controversial plague research. When reached for comment, Tusk's office replied: \"Mr. Tusk's investments are his own business. Evolution is not a crime.\"",
		"require_flag": "vohlNews",
		"stock_effect": { "VOHL": -31.5, "TUSK": -3.0 },
	},
]

static func visible(flags: Dictionary) -> Array:
	var out: Array = []
	for a in ARTICLES:
		var req: String = a.get("require_flag", "")
		if req == "" or flags.get(req, false):
			out.append(a)
	return out

static func get_article(id: String) -> Dictionary:
	for a in ARTICLES:
		if a.get("id", "") == id:
			return a
	return {}
