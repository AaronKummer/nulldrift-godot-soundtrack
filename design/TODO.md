# Nulldrift Master TODO

Ranked by "what makes the game playable in a meaningful demo." Strikethrough
when shipped. Phase boundaries are checkpoints — show Aaron, then continue.

## P0 — get the visual look right (blocking everything else)
- [ ] Render preview of every candidate asset in shared `~/code/assets/` (scifi-shooter-pack meshes, PBR textures, shaders) → `assets-review/`
- [ ] Pass/fail each asset by visual inspection. Delete the bad ones from the asset library so future-me doesn't reach for them.
- [ ] Copy proven scenes from `scifi-asset-godot-testproject` (streetlight.tscn, neon_strip.tscn, car.tscn, door.tscn) into `nulldrift-godot/scenes/world/`
- [ ] Lift the Environment + lighting recipe from `scifi-asset-godot-testproject/scenes/city_block.tscn` into a shared `res://systems/city_env.tscn`
- [ ] Build ONE hand-detailed city block using the assets above (apartment exterior + ATM + alley + pet store across the street). Iterate via headless capture until it looks at least as good as the scifi-asset reference screenshot.
- [ ] Validate camera angle: 3/4 view (~28° pitch), player ~1/8 screen height

## P1 — first scene loop wired
- [ ] Fishtank in apartment (3D mesh, animated fish billboards). Interact triggers fish food quest.
- [ ] Stray cat NPC outside player's apartment door (sits, animates). Interact = "the cat looks at you."
- [ ] ATM scene-event: cop chases hooded hacker, runs into alley. Scripted, one-shot.
- [ ] Pet store storefront (interactable door) + interior stub with shopkeeper dialog → buy fish food (-$20).
- [ ] Return-home loop: feed fish (interact fishtank) → cat follows you in.
- [ ] Quest log entry in phone tracks the loop.

## P2 — second block content
- [ ] Comic shop interior (browseable issues, NPC dialog)
- [ ] Arcade interior + 1 playable minigame (port one from hacking-game)
- [ ] Bar interior (NPCs, atmosphere)
- [ ] Food vendor cart on sidewalk
- [ ] Mugging-in-alley event

## P3 — hacking systems (the OTHER playthrough route)
- [ ] Desk computer interactable in apartment → launches hacking UI
- [ ] Hacking minigame design doc → prototype (node-based point-and-click)
- [ ] Cyberdeck inventory item — same minigame portable
- [ ] Story flags advance via hacks too (parallel to action route)

## P4 — corpo HQ + dungeons
- [ ] Corpo HQ exterior + sneak-in stealth scene
- [ ] Sewer dungeon (rats, lizard men)
- [ ] Dump dungeon (ganks)

## P5 — polish
- [ ] Animated rain on city (proven in apartment)
- [ ] Phone icons v2 wired in
- [ ] Touch-control overlay for mobile

## Open questions
- [ ] Do we generate unique 3D buildings via Meshy/Blender, or compose from scifi-shooter-pack modular pieces?
- [ ] Pixellab for proper HD-2D NPC sprites (replace generic smoking sprites with characters: cop, hacker, shopkeeper, mugger)?
- [ ] DALL-E for storefront sign art (each shop gets a unique sign asset)?
