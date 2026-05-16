## Color palette — the nulldrift neon look in one place.
## Mirrors hacking-game's hex constants used across PhoneUI, scenes, DialogueUI.
## Any scene/UI that wants brand colors should reach into here, never hardcode.
class_name Palette
extends Object

const NEON_GREEN    := Color(0.0, 1.0, 0.53)    # #00ff88 — protagonist / terminals / "good"
const NEON_CYAN     := Color(0.0, 1.0, 1.0)     # #00ffff — DRIFT, UI accents
const NEON_PURPLE   := Color(0.75, 0.37, 1.0)   # #bf5fff — NULL, Violet
const NEON_PINK     := Color(1.0, 0.0, 0.4)     # #ff0066 — frame, Rezz, danger
const NEON_MAGENTA  := Color(1.0, 0.18, 0.58)   # #ff2d95 — Nyx, hover state
const NEON_AQUA     := Color(0.0, 1.0, 0.96)    # #00fff5
const NEON_TEAL     := Color(0.27, 1.0, 0.84)   # #44ffd5
const NEON_ORANGE   := Color(1.0, 0.4, 0.0)     # #ff6600 — VOID, warning
const NEON_RED      := Color(1.0, 0.1, 0.04)    # corpo / hostile
const NEON_AMBER    := Color(1.0, 0.67, 0.0)    # window glow
const BLOOD_RED     := Color(0.6, 0.0, 0.0)
const WHITE         := Color.WHITE

const BG_VOID       := Color(0.005, 0.005, 0.012)   # main bg "almost black"
const BG_SHADOW     := Color(0.025, 0.025, 0.05)
const WALL_INTERIOR := Color(0.18, 0.16, 0.22)
const FLOOR_WARM    := Color(0.18, 0.14, 0.12)

const SPEAKER_NYX     := NEON_MAGENTA
const SPEAKER_PLAYER  := NEON_GREEN
const SPEAKER_VIOLET  := NEON_PURPLE
const SPEAKER_REZZ    := NEON_PINK
const SPEAKER_VERA    := Color(1.0, 0.8, 0.2)
const SPEAKER_TONY    := Color(1.0, 0.6, 0.2)
const SPEAKER_HAYES   := Color(0.5, 0.7, 1.0)
const SPEAKER_NARRATOR := Color(0.53, 0.53, 0.53)
