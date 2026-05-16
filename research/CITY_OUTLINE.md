# Nulldrift — City Outline (v1)

Drafted after Aaron laid out the full vision. **Spec first, code later.**

---

## 1. Visual references (the look we're targeting)

| Reference | What we take from it |
|---|---|
| **SNES Zelda: A Link to the Past** | Pure top-down, character ~1/15th of screen height, world feels dense and "lived-in." Tilemap-based. Clear separation between path you can walk vs walls/obstacles. |
| **Eastward** (Pixpil, 2021) | **Strongest visual ref.** Slight 3/4 top-down with painted-pixel detail. Zoomed in tight. Streets feel like a stroll — vendors, signs, lit windows, NPCs doing things. Atmospheric volumetric light in some scenes. |
| **Akane** (cyberpunk top-down arena) | Neon-drenched tight-zoom palette. Magenta/cyan dominant. Fast-read silhouettes. Sharp pixel edges. |
| **Shenmue** (vibe, not visuals) | Lived-in, time-of-day, NPCs with routines, multiple shops with interiors, side quests around the city. Stroll-as-discovery. |

**Camera direction (decided):** zoomed-in top-down with a slight 3/4 tilt (~25–30° pitch). NOT iso 45°. NOT side-scroller. NOT current zoomed-out 3/4 — that's where the city died.

The player should occupy ~1/8th to 1/10th the screen height. Walking past 4 storefronts on a block should take ~12–15 seconds at normal pace.

---

## 2. World structure — the city is a HUB, not a scene

The mistake I've been making: treating "city" as one scene that has to be perfect. It isn't. It's a network of small connected scenes that you walk between.

```
                     ┌──────────────────────────────────────────┐
                     │  HALLWAY (404 = player's, others locked) │
                     └────────┬─────────────────┬────────────────┘
                              │                 │
                       apartment_404      balcony     elevator
                              │              │           │
                  ┌───────────┘              │           ▼
                  │                          │    BLOCK A (your apt's street)
              APARTMENT                       │     ├── stray cat → adoption
              (already built ok)              │     ├── ATM scene: cop chasing
                                              │     │   hacker (first quest hook)
                                              │     ├── small food vendor
                                              │     └── alley → mugging event
                                              ▼
                                        (jump to street via stairs from balcony)
                                              │
                                              ▼
                                         BLOCK A streets
                                              │
                  ┌───────────────┬───────────┴────────┬────────────────┬─────────┐
                  ▼               ▼                    ▼                ▼         ▼
              PET STORE       COMIC SHOP            ARCADE           BAR     CORPO HQ
              (fish food      (browseable          (mini-games        (NPCs,  (infiltratable
              first quest)    issues, lore)         playable)         dialog) sneak/hack)
                                                                                │
                                                                       ┌────────┴────────┐
                                                                       ▼                  ▼
                                                                  ┌────────┐         ┌────────┐
                                                                  │ SEWER  │         │  DUMP  │
                                                                  │  dungeon│         │ dungeon│
                                                                  │ rats/  │         │ ganks  │
                                                                  │ lizard │         │        │
                                                                  │ men    │         │        │
                                                                  └────────┘         └────────┘
```

Each box above = its own Godot scene. **The city is the hub.** Each street block can be its own scene (or a chunk of one big scene with camera zones — TBD).

---

## 3. Cold-open first scene (the player's first 2-3 minutes)

Aaron's spec, expanded:

1. **Start in apartment.** Fishtank visible (empty, fish swimming aimlessly). Phone messages already include one from a friend mentioning "feed your damn fish."
2. **Exit apartment door → hallway.**
3. **At your apartment door, a stray cat is sitting there.** Interact → "the cat looks at you." Don't take it yet — you'll come back for it.
4. **Take elevator (or balcony stairs) to the street.**
5. **Street level: BLOCK A.** First thing the player sees: at an ATM ~30m down the sidewalk, a cop is chasing a hooded figure who's hacking the machine. Scripted scene — they run off into an alley, leaving the ATM half-cracked.
6. **Walk the block.** Pass a food vendor (sushi cart?), a bar with lit windows + audible bassline, the comic shop. Discover the pet store.
7. **Pet store first quest:** clerk says "you need fish food? $20. While you're here, kid, take care of that cat you keep stepping over."
8. **Buy fish food → quest objective updates → return home → feed fish → cat follows you.** Cat becomes companion / apartment fixture.

This is the **tutorial loop**: door → hallway → balcony OR elevator → city stroll → first interaction → return home. Teaches every system that matters.

---

## 4. Tech approach — finally pinning it down

After many failed iterations, picking the path:

**Engine layer:** Godot 4.6 **2D**, not 3D. We're done thrashing on 3D for outdoor scenes.
- Pixel-art tilemap for streets/sidewalks/buildings (32×32 or 48×48 tiles)
- Sprite2D + AnimatedSprite2D for characters (existing pizza-guy sheet works at 1× scale, not stretched)
- Camera2D follows player with a fixed offset, zoomed in tight
- Lights via **Light2D** (Godot 4 has real 2D lighting + shadows + bloom + glow) — streetlamps cast actual light cones onto sprites and tiles
- No more procedural box geometry

**Why 2D not 3D:**
- Eastward/Akane are 2D, look better than my 3D attempts at half the dev time
- 3D for outdoor scenes was costing days of camera-angle fiddling for worse results
- Apartment stays 3D (it works there) — outdoor scenes go 2D
- Hybrid is OK. Different scenes use different render approaches as fits.

**Tilemap content:** procedurally generate tile assets via Python+PIL (same approach as the smoking_drifter sprite + balcony backdrop). Per-tile: street, sidewalk, building wall, building corner, neon sign, food cart, ATM, alley entrance, etc. **~30 tile types is enough for one neighborhood.**

**Lighting:** Light2D per streetlamp + per neon sign + per door spill. World ambient dark. Player's nearby lights pop. **This** is what gives Eastward/Akane their atmosphere — not procedural fog, real 2D lights on flat art.

---

## 5. Build order (concrete steps, no more thrashing)

### Phase 1 — pet a stray (1 night)
1. Set up Godot 2D city template: Node2D root, Camera2D with zoom 2.0, Sprite2D player, ColorRect ground placeholder
2. Generate **15 starter tiles** via Python+PIL: sidewalk plain, sidewalk-curb, asphalt, asphalt-yellow-line, building-wall-windowed, building-corner-NE/NW/SE/SW, doorway, neon-sign-vertical
3. Build a TileMap from those tiles for BLOCK A only (one screen wide × 3 screens long)
4. Add player walking with Camera2D follow
5. Add ONE Light2D streetlamp to verify the 2D lighting pipeline reads as cyberpunk

### Phase 2 — block A content (2 nights)
6. Hand-place: ATM with cop+hacker NPCs (scripted scene), food vendor cart, bar facade, comic shop facade, pet store facade with door-interactable
7. Stray cat NPC at apartment door (in hallway scene, on the way out)
8. Wire transitions to interior stubs (pet store interior = single ColorRect for now with shopkeeper dialog)

### Phase 3 — first quest loop wired (1 night)
9. Fishtank in apartment (already feasible — add as 3D mesh to existing apartment scene)
10. "Buy fish food" quest object in QuestData
11. Pet store dialog → buy fish food → return home → feed fish → cat companion

### Phase 4 — second block + more shops (later)
12. BLOCK B with arcade interior (1 minigame stub), corpo HQ entrance
13. Sewer + dump dungeon stubs

---

## 6. What I'm NOT building right now

- Procedural 3D city — abandoned, not coming back unless we hit a wall
- Warbly grid / WFC layout — overkill for a city
- Full traffic / car AI — fake it with sprite loops, real AI later
- All 12+ interior scenes at once — one at a time, tied to gameplay

---

## 7. Reference image queue (need to grab manually)

Aaron said put refs in `/research`. Auto-download failed (guessed URLs). To add:
- Eastward street screenshot (any town/city scene with neon)
- Akane top-down combat screenshot (palette ref)
- SNES Zelda LTTP village screenshot (scale ref)

Once we have those, pin them next to this doc.
