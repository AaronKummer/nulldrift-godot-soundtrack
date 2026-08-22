# Financial District neon signs — same neon-on-black storefront style.
# Run from repo root:  python research/store-signs/make_financial_signs.py
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 384, 256
FONT = "C:/Windows/Fonts/impact.ttf"


def neon_text(base, text, cy, size, color, fill=(240, 245, 250)):
    font = ImageFont.truetype(FONT, size)
    tmp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    bbox = d.textbbox((0, 0), text, font=font, stroke_width=6)
    x = (W - (bbox[2] - bbox[0])) // 2 - bbox[0]
    y = cy - (bbox[3] - bbox[1]) // 2 - bbox[1]
    d.text((x, y), text, font=font, fill=color, stroke_width=6, stroke_fill=color)
    glow = tmp.filter(ImageFilter.GaussianBlur(9))
    base.alpha_composite(glow); base.alpha_composite(glow)
    dd = ImageDraw.Draw(base)
    dd.text((x, y), text, font=font, fill=color, stroke_width=6, stroke_fill=color)
    dd.text((x, y), text, font=font, fill=fill, stroke_width=2, stroke_fill=fill)


def sign(name, lines, color):
    img = Image.new("RGBA", (W, H), (10, 10, 14, 255))
    if len(lines) == 1:
        neon_text(img, lines[0], 128, 64, color)
    else:
        neon_text(img, lines[0], 80, 58, color)
        neon_text(img, lines[1], 165, 58, color)
    img.convert("RGB").save(f"assets/world/signs/{name}.png")
    print(name, "written")


sign("nexusbank", ["NEXUS", "BANK"], (255, 210, 90))       # gold
sign("platinum", ["PLATINUM", "ARMS"], (200, 210, 230))    # silver/chrome
sign("vohl", ["VOHL", "PHARMA"], (120, 230, 120))          # sickly green
sign("vvs", ["VVS", "TOWER"], (185, 110, 255))             # violet
