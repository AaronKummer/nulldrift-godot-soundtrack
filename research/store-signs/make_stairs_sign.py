# Teal neon STAIRS sign for the balcony stairwell — same neon-on-black style
# as the storefront signs (white-cored text with a colored glow + a glyph).
# Run from repo root:  python research/store-signs/make_stairs_sign.py
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 384, 256
BG = (10, 12, 12, 255)
FONT = "C:/Windows/Fonts/impact.ttf"
TEAL = (40, 230, 220)


def neon_text(base, text, cy, size, color, fill=(235, 250, 248)):
    font = ImageFont.truetype(FONT, size)
    tmp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    bbox = d.textbbox((0, 0), text, font=font, stroke_width=6)
    x = (W - (bbox[2] - bbox[0])) // 2 - bbox[0]
    y = cy - (bbox[3] - bbox[1]) // 2 - bbox[1]
    d.text((x, y), text, font=font, fill=color, stroke_width=6, stroke_fill=color)
    glow = tmp.filter(ImageFilter.GaussianBlur(9))
    base.alpha_composite(glow)
    base.alpha_composite(glow)
    d2 = ImageDraw.Draw(base)
    d2.text((x, y), text, font=font, fill=color, stroke_width=6, stroke_fill=color)
    d2.text((x, y), text, font=font, fill=fill, stroke_width=2, stroke_fill=fill)


def neon_lines(base, segs, color, width=6):
    tmp = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(tmp)
    for seg in segs:
        d.line(seg, fill=color, width=width, joint="curve")
    glow = tmp.filter(ImageFilter.GaussianBlur(7))
    base.alpha_composite(glow)
    base.alpha_composite(glow)
    base.alpha_composite(tmp)


img = Image.new("RGBA", (W, H), BG)
neon_text(img, "STAIRS", 66, 68, TEAL)
# Descending-steps glyph + a down chevron
cx = W // 2
steps = []
for i in range(4):
    x0 = cx - 70 + i * 34
    y0 = 150 + i * 22
    steps.append([(x0, y0), (x0 + 34, y0)])
    steps.append([(x0 + 34, y0), (x0 + 34, y0 + 22)])
neon_lines(img, steps, TEAL, width=6)
neon_lines(img, [[(cx + 44, 224), (cx + 60, 240)], [(cx + 76, 224), (cx + 60, 240)]],
           TEAL, width=6)

img.convert("RGB").save("assets/world/signs/stairs.png")
print("stairs.png written")
