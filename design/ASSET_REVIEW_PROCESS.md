# Asset Review Process

Aaron's directive: **review before using. delete bad ones. don't import junk.**

## Pipeline

1. **Pick a candidate folder** from `~/code/assets/` (e.g.
   `3d/scifi_shooter_pack/EnvironmentProxy/`).
2. **Render previews of every file** in that folder via Blender to a single
   PNG per asset. Save to `assets-review/<folder-name>/<asset>.png`.
3. **Visually inspect each preview** with the Read tool. Grade each:
   - ✅ USE — fits the cyberpunk city aesthetic, good quality
   - 🟡 MAYBE — could work with material override or modification
   - ❌ DELETE — bad / off-style / ugly. Remove from `~/code/assets/` so it
     never tempts a future agent.
4. **Write the verdict** in `assets-review/<folder-name>/VERDICT.md`.
5. **Then** import the ✅ assets into the nulldrift project.

## Why this exists

Earlier I imported assets blindly (scifi-shooter walls, Mixamo mannequins)
without rendering previews. Several looked nothing like a cyberpunk city —
they were fantasy or off-aesthetic, but I shoehorned them in anyway and the
results were ugly. The asset library has hundreds of files across fantasy,
sci-fi, abstract, etc. — most are wrong for this project.

## Tools available

- `~/code/assets/render_glb_preview.py` — Blender background script for
  rendering a single GLB to PNG
- `~/code/assets/gen_previews.py` — bulk preview script (already exists)
- pixellab MCP — for generating pixel-art sprites
- gpt-image-1 via OpenAI API — for concept art, storefront signage
- Meshy API — for 3D model generation (if needed)

## When to generate vs use shared library

- Building geometry / common props → use scifi_shooter_pack if it fits
- Pixel-art NPCs → pixellab (cop, hacker, shopkeeper, mugger — specific characters)
- Storefront sign artwork (logos, lettering) → DALL-E / gpt-image-1
- Unique hero props that don't exist anywhere → Meshy or custom Blender
