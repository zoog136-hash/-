"""Conservative cutouts for dark Inven mattes in ground-only thumbnails.

Inventory icons and original PNGs remain unchanged. Previously transparent
representatives bypass this step. Reviewed green-backed weapon masks are
restricted to the actual weapon corridors; general dark mattes use an
outside-connected flood only, never erase all similarly colored interior pixels.
"""
from collections import deque
from PIL import Image, ImageDraw

DARK_MATTES = {
    "rifle": 72, "cannon": 72, "chain": 72, "bracelet": 72,
    "badge": 72, "seal": 72, "crystal": 72, "catalyst": 72,
    "rune": 72, "potion_hp": 78, "potion_mp": 78, "potion_buff": 78,
    "elixir": 78, "dragon_gem": 78, "coins": 78, "ore": 72,
    "leather": 72, "cloth": 72, "powder": 72, "gem": 72,
    "recipe": 72, "arrow": 72, "bullet": 78, "shoulder": 72,
    "box": 72, "material": 72, "misc": 72,
}
GREEN_WEAPONS = {"scythe", "runesword"}

def cleanup(source: Image.Image, category: str) -> Image.Image:
    image = source.convert("RGBA").copy()
    w, h = image.size
    if not (1 <= w <= 512 and 1 <= h <= 512):
        raise ValueError("Unexpected source image dimensions")
    if category not in DARK_MATTES and category not in GREEN_WEAPONS:
        return image
    pixels = image.load()
    if category in GREEN_WEAPONS:
        # Paths are defined in original 64x64 source coordinates; the weapon
        # extends diagonally across an unrelated green gradient and wordmark.
        guide = Image.new("L", (64, 64), 0)
        pen = ImageDraw.Draw(guide)
        if category == "scythe":
            pen.polygon([(5,13),(19,14),(32,20),(43,28),(48,37),
                         (46,41),(39,32),(30,25),(19,20),(6,18)], fill=255)
            pen.line([(18,63),(27,53),(39,42),(51,27)], fill=255, width=7)
            pen.line([(45,34),(49,39),(53,48)], fill=255, width=7)
            pen.ellipse((40,29,48,40), fill=255)
        else:
            pen.line([(6,56),(17,49),(28,39),(38,29),(48,17),(54,11)],
                     fill=255, width=12)
            pen.line([(41,26),(38,17)], fill=255, width=7)
            pen.line([(41,20),(49,28)], fill=255, width=7)
        if (w,h) != (64,64):
            guide = guide.resize((w,h), Image.Resampling.NEAREST)
        keep = guide.load()
        for y in range(h):
            for x in range(w):
                r,g,b,a = pixels[x,y]
                is_green = g > r*1.27 and g > b*1.25 and g > 15
                if not keep[x,y] or is_green or max(r,g,b) < 15:
                    pixels[x,y] = (r,g,b,0)
        return image
    # Remove only smooth dark surroundings connected to the image border.
    # A dark enclosed groove or ornament remains part of the object.
    limit = DARK_MATTES[category]
    def background(pixel):
        if pixel[3] == 0:
            return True
        return max(pixel[:3]) < limit and sum(pixel[:3])/3 < limit*.83
    queue = deque([(x,0) for x in range(w)] + [(x,h-1) for x in range(w)] +
                  [(0,y) for y in range(h)] + [(w-1,y) for y in range(h)])
    seen = set()
    while queue:
        x,y = queue.popleft()
        if not (0 <= x < w and 0 <= y < h) or (x,y) in seen:
            continue
        seen.add((x,y))
        pixel = pixels[x,y]
        if not background(pixel):
            continue
        pixels[x,y] = (*pixel[:3],0)
        queue.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
    # The neutral publisher wordmark is printed across the bottom. Restrict
    # removal to neutral lettering in the lower middle, retaining colored art.
    if category not in ("arrow","rune","box","material","misc","shoulder"):
        for y in range(max(0,round(h*.77)),h):
            for x in range(round(w*.11),round(w*.90)):
                r,g,b,a = pixels[x,y]
                if a and max(r,g,b)-min(r,g,b) <= 24 and 18 <= max(r,g,b) <= 210:
                    pixels[x,y] = (r,g,b,0)
    return image
