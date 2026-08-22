## PLATINUM ARMS — the financial district's high-end arms dealer. Same
## walk-in shop as GUNS+, but no price cap: this is where the god-tier
## weapons live. Reuses guns.gd wholesale, just overriding the config.
extends "res://scripts/interiors/guns.gd"

func _price_cap() -> int: return 100000000
func _shop_title() -> String: return "PLATINUM ARMS"
func _dealer_sheet() -> String: return "res://assets/sprites/npc-corpo.png"
func _exit_scene_id() -> String: return "street_financial"
func _exit_marker() -> String: return "from_platinum"

func _ambient() -> Color:
	return Color(0.20, 0.22, 0.30)   # cold corporate chrome
