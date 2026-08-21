# Normalize character sheets to the uniform standard: content height 57px,
# feet on y=62, inside 48x64 cells (3x4 billboard grid) — matching
# player-pizza and the npc recolors, so every character renders the same
# size with NO code-side scaling (Aaron: "we want uniform shit").
#
# Per-cell content bbox (native art has hard alpha), NEAREST resample only
# when the cell actually exceeds the standard, integer repositioning for
# feet alignment. Run from the repo root:
#   python research/store-signs/normalize_sprites.py
from PIL import Image

STD_H = 57
FEET_Y = 62

# sheets that exceed the standard (measured 2026-08-21):
#   lady 60-64/feet64, Yakuza1-3 + Boss up to 64/feet64  -> downscale + realign
#   cyberGirl 54-56/feet58 (right size, floats 4px)      -> shift down only
RESIZE = ["lady", "Yakuza1", "Yakuza2", "Yakuza3", "YakuzaBoss"]
SHIFT_ONLY = ["cyberGirl"]


def normalize(name, resize):
    path = f"assets/sprites/{name}.png"
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    cw, ch = w // 3, h // 4
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for r in range(4):
        for c in range(3):
            cell = img.crop((c * cw, r * ch, (c + 1) * cw, (r + 1) * ch))
            bbox = cell.split()[3].getbbox()
            if bbox is None:
                continue
            content = cell.crop(bbox)
            bw, bh = content.size
            if resize and bh > STD_H:
                nw = max(1, round(bw * STD_H / bh))
                content = content.resize((nw, STD_H), Image.NEAREST)
                bw, bh = content.size
            # feet on the ground line, horizontally centered like the source
            x = c * cw + (cw - bw) // 2
            y = r * ch + FEET_Y - bh
            out.paste(content, (x, y))
    out.save(path)
    print(f"{name}: normalized (resize={resize})")


for n in RESIZE:
    normalize(n, True)
for n in SHIFT_ONLY:
    normalize(n, False)
