# Pixel flashlight icon for the phone LIGHT app — 48x48 RGBA, matching the
# hand-drawn phone-icon style (emoji don't render on Aaron's box, so every
# phone app needs a real PNG). Run from repo root:
#   python research/store-signs/make_light_icon.py
from PIL import Image, ImageDraw

S = 48
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# Beam cone — widening translucent yellow wedge from the lens (top-left → out)
for i in range(14):
    a = int(120 - i * 7)
    y0 = 12 - i
    y1 = 20 + i
    x = 16 + i * 2
    d.line([(15, 16), (x, (y0 + y1) // 2)], fill=(255, 240, 150, max(0, a)), width=1)
d.polygon([(14, 13), (14, 23), (44, 4), (44, 32)], fill=(255, 235, 130, 40))

# Lens — bright
d.ellipse([9, 11, 17, 21], fill=(255, 250, 210, 255))
d.ellipse([11, 13, 15, 19], fill=(255, 255, 255, 255))

# Body — dark metal barrel, diagonal down-right
d.line([(13, 16), (30, 33)], fill=(70, 80, 95, 255), width=7)
d.line([(13, 16), (30, 33)], fill=(120, 135, 155, 255), width=3)
# Grip end cap — teal accent
d.line([(28, 31), (34, 37)], fill=(60, 220, 220, 255), width=6)
d.line([(28, 31), (34, 37)], fill=(120, 255, 255, 255), width=2)

img.save("assets/icons/phone/light.png")
print("light.png written")
