"""Strict TI2 palette/RLE decoder, with transparent coverage kept separately.

Format reference reviewed as source only: tony1223/PakViewer MTil.cs at
fbad69239e3e3c12ec18dfc7722bed284be093cc. No external executable is used.
The decoder preserves RGB565 palette precision instead of converting to RGB555.
"""
import struct
from PIL import Image


def decompress(data, limit=8*1024*1024):
    """Use the installed standard Brotli decoder with an explicit output cap."""
    import ctypes
    import ctypes.util
    name = ctypes.util.find_library('brotlidec')
    if not name:
        raise RuntimeError('Install the standard libbrotlidec library to decode TI2')
    library = ctypes.CDLL(name)
    function = library.BrotliDecoderDecompress
    function.argtypes = [ctypes.c_size_t, ctypes.c_void_p, ctypes.POINTER(ctypes.c_size_t), ctypes.c_void_p]
    function.restype = ctypes.c_int
    output = ctypes.create_string_buffer(limit)
    length = ctypes.c_size_t(limit)
    if function(len(data), data, ctypes.byref(length), output) != 1:
        raise ValueError('Invalid Brotli stream or TI2 exceeds bounded decoded size')
    return output.raw[:length.value]


def read_ti2(data):
    return parse(decompress(data))


class Reader:
    def __init__(self, data):
        if not 4 <= len(data) <= 8*1024*1024:
            raise ValueError("TI2 file outside bounded size")
        self.data, self.pos = data, 0

    def take(self, count):
        if count < 0 or self.pos+count > len(self.data):
            raise ValueError(f"Truncated TI2 at {self.pos}")
        result = self.data[self.pos:self.pos+count]
        self.pos += count
        return result

    def byte(self):
        return self.take(1)[0]


def parse(data):
    r = Reader(data)
    header, = struct.unpack('<I', r.take(4))
    count = header & 4095
    palette = []
    if header & 4096:
        size = r.byte() or 256
        palette = list(struct.unpack('<'+'H'*size, r.take(size*2)))
    flags = r.take(count)
    blocks = []
    for flag in flags:
        if flag & 64:
            offset = [0, 0]
            widths = list(range(2, 25, 2))+list(range(22, 0, -2))
            runs = [(0 if flag & 1 else 24-width, width, 1) for width in widths]
            raw_runs = []
        else:
            offset = [r.byte(), r.byte()]
            size = r.byte()
            raw_runs = list(struct.unpack('<'+'H'*size, r.take(size*2))) if size else []
            runs = [(v & 31, (v >> 5) & 31, (v >> 10) & 31) for v in raw_runs]
        blocks.append({'flags': flag, 'offset': offset, 'runs': runs, 'raw_runs': raw_runs, 'pixel_count': sum(v[1] for v in runs)})
    for block in blocks:
        block['pixels'] = r.take(block['pixel_count'])
        if block['pixels'] and (not palette or max(block['pixels']) >= len(palette)):
            raise ValueError("TI2 palette reference outside original palette")
    if r.pos != len(data):
        raise ValueError(f"Uninterpreted TI2 tail: {len(data)-r.pos} bytes")
    return {'header': header, 'palette': palette, 'blocks': blocks}


def render(block, palette, display_alpha=False):
    image = Image.new('RGBA', (24, 24))
    x_origin, y = block['offset']
    x_base = x_origin
    at = 0
    for skip, count, row_step in block['runs']:
        x = x_base+skip
        for px in range(x, x+count):
            if at >= len(block['pixels']):
                raise ValueError("RLE consumes beyond TI2 pixels")
            color = palette[block['pixels'][at]]
            at += 1
            if 0 <= px < 24 and 0 <= y < 24:
                red, green, blue = color >> 11, (color >> 5) & 63, color & 31
                alpha = 255
                if display_alpha:
                    flags = block['flags']
                    if flags & 48:
                        # Display alpha rules from the reviewed helper. Keep the
                        # original RGB565 color; do not invent a smoke color.
                        rgb555 = (red << 10) | ((green >> 1) << 5) | blue
                        brightness = max(red, green >> 1, blue)
                        alpha = ((31-brightness) if flags & 32 else brightness)*255//31
                        if rgb555 in (0, 0x0421, 0x7fff, 0x7fe0) or alpha < 8:
                            alpha = 0
                    elif flags & 4:
                        alpha = 128
                image.putpixel((px, y), ((red << 3) | (red >> 2), (green << 2) | (green >> 4), (blue << 3) | (blue >> 2), alpha))
        if row_step:
            y += row_step
            x_base = x_origin
        else:
            x_base = x+count
    if at != len(block['pixels']):
        raise ValueError("Unconsumed TI2 pixels")
    return image
