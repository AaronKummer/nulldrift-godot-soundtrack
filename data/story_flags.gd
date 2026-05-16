## Story flag constants — every flag the game might set. Centralized so we
## get autocomplete and can't typo. Mirrors hacking-game's scattered flag
## strings (we found ~40 unique flag names by grepping for setFlag).
class_name StoryFlags
extends Object

# Act 1 — apartment → ATM → CyberDeck → diner
const LEFT_APARTMENT       := "leftApartment"
const ATM_EVENT_DONE       := "atmEventDone"
const HAS_CYBERDECK        := "hasCyberDeck"
const FIRST_HACK_DONE      := "firstHackDone"
const PENDING_DINER_MEETING := "pendingDinerMeeting"
const MET_NYX              := "metNyx"
const GARAGE_CLEARED       := "garageCleared"

# Act 2 — relay nodes → Severin → arrest → Mama Chrome
const ACT_TWO_STARTED      := "actTwoStarted"
const ZEPHYR_REVEALED      := "zephyrRevealed"
const RELAY_NODES_DESTROYED := "relayNodesDestroyed"
const KERRY_IS_SICK        := "kerryIsSick"
const VOHL_DEFEATED        := "vohlDefeated"
const NYX_CAPTURED         := "nyxCaptured"
const VERA_CORPO           := "veraCorpo"
const SIGNAL_JAMMER_BUILT  := "signalJammerBuilt"
const REZZ_REVEALED        := "rezzCorpoRevealed"

# Act 3 — tower → final boss → ending
const ACT_TWO_COMPLETE     := "actTwoComplete"
const VIOLET_TRUTH         := "violetTruthRevealed"
const TOWER_ENTERED        := "towerEntered"
const NYX_FREED            := "nyxFreed"
const FINAL_BOSS_DEFEATED  := "finalBossDefeated"
const ENDING_DESTROY       := "endingDestroy"
const ENDING_REDIRECT      := "endingRedirect"
