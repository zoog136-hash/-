"""Remove exterior white matte without deleting enclosed white highlights.

No colour replacement or threshold over the complete image: only white pixels
reachable from the outside through transparent/white pixels are removed. Eight
neighbours handle diagonally touching legacy pixel-art outlines. Inputs remain
unchanged. This is a floor-display transform, never an inventory/source edit.
"""
from collections import deque
from PIL import Image


def clear_white_border(source: Image.Image) -> Image.Image:
    image = source.convert('RGBA').copy()
    width, height = image.size
    if not 1 <= width <= 512 or not 1 <= height <= 512:
        raise ValueError('Unexpected ground image dimensions')
    pixels = image.load()
    border = ([(x, 0) for x in range(width)] + [(x, height-1) for x in range(width)]
              + [(0, y) for y in range(1, height-1)] + [(width-1, y) for y in range(1, height-1)])
    def white(pixel):
        return min(pixel[:3]) >= 250 and max(pixel[:3])-min(pixel[:3]) <= 5
    # Look at the actual perimeter, not a vote by three of four corners.
    # A single exposed metallic glint is not sufficient evidence of a matte.
    if sum(pixels[x, y][3] > 0 and white(pixels[x, y]) for x, y in border) < 2:
        return image
    pending = deque(border)
    seen = set()
    while pending:
        x, y = pending.popleft()
        if not (0 <= x < width and 0 <= y < height) or (x, y) in seen:
            continue
        seen.add((x, y))
        pixel = pixels[x, y]
        if pixel[3] != 0 and not white(pixel):
            continue
        pixels[x, y] = (*pixel[:3], 0)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx or dy:
                    pending.append((x+dx, y+dy))
    return image
