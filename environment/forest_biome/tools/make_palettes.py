"""Derives dark-fantasy palette textures from the original Kytric palette.
The original texture is never modified. Run:  python3 make_palettes.py <path/to/original/texture.png> <out_dir>"""
import sys
from PIL import Image

def ramp(a, b, n):
    return [tuple(round(a[k] + (b[k] - a[k]) * i / max(n - 1, 1)) for k in range(3)) for i in range(n)]

def dusk(src):
    p = [src.getpixel((x, 0)) for x in range(256)]
    out = []
    for i, c in enumerate(p):
        r, g, b, a = c
        # generic grade: desaturate 45 %, darken 35 %, push to cool teal shadows
        l = 0.3 * r + 0.59 * g + 0.11 * b
        r, g, b = [(v * 0.55 + l * 0.45) * 0.65 for v in (r, g, b)]
        out.append((round(r * 0.92), round(g), round(min(255, b * 1.12)), a))
    m = {}
    m.update(zip(range(216, 219), [(30, 66, 80), (25, 57, 71), (20, 48, 61)]))           # water
    m.update(zip(range(232, 240), ramp((122, 92, 70), (66, 50, 42), 8)))                # dirt / path / bark
    m.update(zip(range(240, 247), ramp((40, 66, 50), (30, 50, 40), 7)))                 # forest floor moss (low contrast)
    m[247] = (34, 70, 58)                                                               # canopy (deep blue-green)
    m[248] = (24, 26, 33)
    m[249] = (158, 150, 130)                                                            # bone ivory
    m.update(zip(range(250, 255), ramp((112, 118, 118), (48, 53, 56), 5)))              # mossy slate stone
    for i, c in m.items():
        out[i] = c + (255,)
    return out

def variant(base, changes):
    out = list(base)
    for i, c in changes.items():
        out[i] = c + (255,)
    return out

def save(pal, path):
    im = Image.new("RGBA", (256, 1))
    im.putdata(pal)
    im.save(path)

if __name__ == "__main__":
    src = Image.open(sys.argv[1]).convert("RGBA")
    d = dusk(src)
    save(d, sys.argv[2] + "/forest_dusk_palette.png")
    save(variant(d, {239: (46, 84, 54)}), sys.argv[2] + "/forest_fern_palette.png")       # bushes -> ferns
    save(variant(d, {247: (72, 42, 86), 239: (52, 42, 46)}), sys.argv[2] + "/forest_blight_palette.png")  # cursed trees
    save(variant(d, {239: (92, 62, 52), 247: (70, 98, 74)}), sys.argv[2] + "/forest_ancient_palette.png") # hero tree, mossier
    save(variant(d, {239: (86, 62, 48), 247: (112, 72, 48)}), sys.argv[2] + "/forest_deadwood_palette.png") # fallen dead trees
