#!/usr/bin/env python3
"""Read-only SPR_0 / unwrapped RGB555+palette SPR inspector and RGBA renderer.

Standard library for inspection; Pillow is the only render dependency.
No game executable, DLL, original client, network, or repository import is used.
This is a structural decoder, NOT an authenticated original-runtime renderer.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

VERSION = "1.0"
TILE_SIZE = 24
MAX_INPUT_BYTES = 64 * 1024 * 1024
MAX_CANVAS_PIXELS = 16 * 1024 * 1024
MAX_DECODED_BLOCK_BYTES = 128 * 1024 * 1024
SYSTEMS = ("original-grid", "reference-client")
LIMITATIONS = [
    "Foot/ground anchor unknown; named origins are coordinate conventions, not anatomy.",
    "Reference-client means local nonofficial l1j-client source, not original runtime validation.",
    "Opaque reference byte t/hflag and two frame-header uint16 fields are preserved, not interpreted.",
    "Only encoded RGB555 samples are opaque; RLE gaps are transparent. Runtime color-key, blend, shadow and lighting behavior are not reproduced.",
    "No action timing, direction semantics, attachments, sound, events, or original PAK load precedence is implemented.",
    "SPR_1 and other SPR wrappers are unsupported; no frame clamping or automatic resampling occurs.",
]


class DecodeError(ValueError):
    """Malformed, unsupported, out-of-bounds, or resource-limited input."""


class Reader:
    def __init__(self, data, start=0, end=None):
        self.data = data
        self.pos = start
        self.end = len(data) if end is None else end

    def read(self, fmt):
        size = struct.calcsize(fmt)
        if self.pos < 0 or self.pos + size > self.end:
            raise DecodeError(f"Truncated field at byte {self.pos}: need {size}, boundary {self.end}")
        values = struct.unpack_from(fmt, self.data, self.pos)
        self.pos += size
        return values[0] if len(values) == 1 else values


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def grid_xy(x, y):
    """Original preview grid; Python // deliberately floors negative odd x."""
    half = x // 2
    return (24 * (y + x - half), 12 * (y - half))


def ref_client_xy(x, y):
    """Equivalent to nonofficial sprite_motion.cpp 306-320 at drawat(0,0).

    Block x0/y0 are already incorporated in the 24x24 decoded block.
    The frame x1/y1 additions and subtractions cancel in that implementation.
    """
    gx, gy = grid_xy(x, y)
    return (gx - 24, gy + 36)


def union_bounds(bounds):
    bounds = [b for b in bounds if b is not None]
    if not bounds:
        return None
    return [min(b[0] for b in bounds), min(b[1] for b in bounds),
            max(b[2] for b in bounds), max(b[3] for b in bounds)]


def translate_bounds(bounds, dx, dy):
    return None if bounds is None else [bounds[0]+dx, bounds[1]+dy,
                                        bounds[2]+dx, bounds[3]+dy]


class Sprite:
    def __init__(self, data: bytes, *, max_bytes=MAX_INPUT_BYTES):
        if not isinstance(data, bytes):
            data = bytes(data)
        if len(data) > max_bytes:
            raise DecodeError(f"Input exceeds {max_bytes}-byte safety limit")
        self.data = data
        self.sha256 = sha256(data)
        self.wrapper = "SPR_0" if data.startswith(b"SPR_0") else None
        if data.startswith(b"SPR_") and self.wrapper is None:
            raise DecodeError(f"Unsupported wrapper {data[:5]!r}")
        self.payload_offset = 5 if self.wrapper else 0
        reader = Reader(data, self.payload_offset)
        self.first_byte = reader.read("<B")
        self.palette = None
        self.palette_count_byte = None
        if self.first_byte == 255:
            self.palette_count_byte = reader.read("<B")
            count = self.palette_count_byte or 256
            self.palette = [reader.read("<H") for _ in range(count)]
            frame_count = reader.read("<B")
        else:
            frame_count = self.first_byte
        self.frames = []
        for index in range(frame_count):
            start = reader.pos
            header = reader.read("<4h3H")
            refs = []
            for ref_index in range(header[6]):
                pos = reader.pos
                x, y, t, block = reader.read("<bbBH")
                refs.append({"reference_index": ref_index, "byte_offset": pos,
                             "raw_hex": data[pos:reader.pos].hex(),
                             "x": x, "y": y, "t_opaque_uint8": t,
                             "t_signed_interpretation_not_semantics": t if t < 128 else t-256,
                             "block": block,
                             "original_grid_xy": list(grid_xy(x, y)),
                             "reference_client_xy": list(ref_client_xy(x, y))})
            self.frames.append({"index": index, "header_byte_offset": start,
                                "raw_header_hex": data[start:start+14].hex(),
                                "raw_header_format": "<4h3H",
                                "raw_header_values": list(header),
                                "reference_source_field_names": {
                                    "x1_unknown": header[0], "y1_unknown": header[1],
                                    "x2_unknown": header[2], "y2_unknown": header[3],
                                    "unknown_uint16_0": header[4], "unknown_uint16_1": header[5],
                                    "reference_count": header[6]},
                                "references": refs})
        self.block_count = reader.read("<I")
        # Each offset alone consumes 4 bytes; bound before allocating a list.
        if self.block_count > 1000000 or self.block_count > (len(data)-reader.pos-4)//4:
            raise DecodeError("Invalid or resource-limited block offset count")
        self.block_offsets = [reader.read("<I") for _ in range(self.block_count)]
        self.opaque_after_offsets_uint32 = reader.read("<I")
        self.block_data_start = reader.pos
        for frame in self.frames:
            for ref in frame["references"]:
                if ref["block"] >= self.block_count:
                    raise DecodeError(f"Frame {frame['index']} references nonexistent block {ref['block']}")
        self.blocks_by_offset = {}
        unique_offsets = sorted(set(self.block_offsets))
        if len(unique_offsets) * 24 * 24 * 4 > MAX_DECODED_BLOCK_BYTES:
            raise DecodeError("Decoded tile data exceeds 128 MiB safety limit")
        self.warnings = []
        for oi, offset in enumerate(unique_offsets):
            start = self.block_data_start + offset
            boundary = (self.block_data_start + unique_offsets[oi+1]
                        if oi+1 < len(unique_offsets) else len(data))
            if start > len(data) or boundary > len(data):
                raise DecodeError(f"Block offset outside input: {offset}")
            reader = Reader(data, start, boundary)
            x0, y0, width_raw, lines = reader.read("<4B")
            if x0 > TILE_SIZE or y0 + lines > TILE_SIZE:
                raise DecodeError(f"Block at {start} exceeds 24x24 supported tile grid")
            pixels = bytearray(TILE_SIZE * TILE_SIZE * 4)
            pixel_count = odd_gaps = high_bit_samples = 0
            for row in range(lines):
                x = x0
                for _ in range(reader.read("<B")):
                    gap, count = reader.read("<2B")
                    odd_gaps += gap & 1
                    x += gap // 2
                    if x + count > TILE_SIZE:
                        raise DecodeError(f"RLE run exceeds tile width at byte {reader.pos}")
                    for _ in range(count):
                        if self.palette is not None:
                            palette_index = reader.read("<B")
                            if palette_index >= len(self.palette):
                                raise DecodeError(f"Palette index {palette_index} is out of range")
                            color = self.palette[palette_index]
                        else:
                            color = reader.read("<H")
                        high_bit_samples += bool(color & 0x8000)
                        rgba = (((color >> 10) & 31)*255//31,
                                ((color >> 5) & 31)*255//31,
                                (color & 31)*255//31, 255)
                        at = ((y0+row)*TILE_SIZE+x)*4
                        pixels[at:at+4] = bytes(rgba)
                        x += 1
                        pixel_count += 1
            if odd_gaps:
                self.warnings.append(f"Block offset {offset}: {odd_gaps} odd gap bytes; floor(gap/2) applied, semantics unverified")
            self.blocks_by_offset[offset] = {
                "pixels_rgba": bytes(pixels),
                "metadata": {"relative_offset": offset, "byte_offset": start,
                             "encoded_end_exclusive": reader.pos,
                             "encoded_size": reader.pos-start,
                             "encoded_sha256": sha256(data[start:reader.pos]),
                             "raw_block_header_hex": data[start:start+4].hex(),
                             "raw_block_header_values": [x0,y0,width_raw,lines],
                             "x0": x0, "y0": y0, "width_byte_preserved": width_raw,
                             "encoded_row_count": lines, "decoded_grid_size": [24,24],
                             "encoded_pixel_count": pixel_count, "odd_gap_count": odd_gaps,
                             "rgb555_bit15_set_samples": high_bit_samples,
                             "decoded_rgba_sha256": sha256(pixels)}}
        self.blocks = [self.blocks_by_offset[o] for o in self.block_offsets]
        self.consumed_end = max([self.block_data_start] +
                               [b["metadata"]["encoded_end_exclusive"] for b in self.blocks])
        self.trailing_bytes = len(data)-self.consumed_end
        if self.trailing_bytes:
            self.warnings.append(f"{self.trailing_bytes} trailing bytes retained in original input, not interpreted")

    def frame_bounds(self, frame, coordinate_system="original-grid"):
        self._check_frame(frame)
        if coordinate_system not in SYSTEMS:
            raise DecodeError(f"Unknown coordinate system {coordinate_system}")
        key = "original_grid_xy" if coordinate_system == "original-grid" else "reference_client_xy"
        return union_bounds([[r[key][0],r[key][1],r[key][0]+24,r[key][1]+24]
                             for r in self.frames[frame]["references"]])

    def file_bounds(self, coordinate_system="original-grid"):
        return union_bounds([self.frame_bounds(i, coordinate_system) for i in range(len(self.frames))])

    def _check_frame(self, frame):
        if not isinstance(frame, int) or not (0 <= frame < len(self.frames)):
            raise DecodeError(f"Frame {frame!r} invalid; valid range is 0..{len(self.frames)-1}; no clamping")

    def metadata(self):
        frames = []
        for frame in self.frames:
            f = dict(frame)
            f["tile_grid_bounds_original_grid"] = self.frame_bounds(f["index"])
            f["tile_grid_bounds_reference_client"] = self.frame_bounds(f["index"], "reference-client")
            frames.append(f)
        return {"decoder_version": VERSION, "input_sha256": self.sha256,
                "input_size": len(self.data), "wrapper": self.wrapper,
                "payload_byte_offset": self.payload_offset,
                "format_first_byte": self.first_byte, "frame_count": len(self.frames),
                "palette_count_byte": self.palette_count_byte,
                "palette_rgb555_uint16": self.palette,
                "block_count": self.block_count,
                "block_offsets_relative_to_block_data": self.block_offsets,
                "opaque_uint32_after_offsets": self.opaque_after_offsets_uint32,
                "block_data_byte_offset": self.block_data_start,
                "blocks": [dict(b["metadata"], block_index=i) for i,b in enumerate(self.blocks)],
                "frames": frames,
                "file_union_tile_bounds_original_grid": self.file_bounds(),
                "file_union_tile_bounds_reference_client": self.file_bounds("reference-client"),
                "consumed_end_exclusive": self.consumed_end,
                "trailing_bytes": self.trailing_bytes,
                "coordinate_contract": {
                    "bounds": "[left, top, right_exclusive, bottom_exclusive], native pixels",
                    "original_grid_origin": [0,0],
                    "reference_client_origin_in_original_grid": [24,-36],
                    "reference_client_xy_equals_original_grid_xy_plus": [-24,36],
                    "foot_anchor": None,
                    "foot_anchor_status": "not inferred or runtime verified",
                    "frame_header_shift": "Preserved but not applied: x1/y1 cancel in reference source"},
                "warnings": self.warnings, "limitations": LIMITATIONS}

    def render(self, frame, *, fixed_canvas=False, canvas_bounds=None,
               coordinate_system="original-grid", max_pixels=MAX_CANVAS_PIXELS):
        """Return (Pillow RGBA image, render metadata); never clamp/crop pixels.

        fixed_canvas=True uses all frames' tile-grid union within THIS file.
        canvas_bounds=(L,T,R,B) lets the caller share a union across many files.
        No alpha-bbox crop is performed. Explicit canvas must contain all tiles.
        """
        self._check_frame(frame)
        from PIL import Image
        frame_bounds = self.frame_bounds(frame, coordinate_system)
        if canvas_bounds is not None:
            if len(canvas_bounds) != 4 or any(not isinstance(v, int) for v in canvas_bounds):
                raise DecodeError("Canvas bounds must be four integer coordinates")
            bounds = list(canvas_bounds)
            policy = "caller_explicit_canvas"
        elif fixed_canvas:
            bounds = self.file_bounds(coordinate_system) or [0,0,1,1]
            policy = "file_union_tile_grid"
        else:
            bounds = frame_bounds or [0,0,1,1]
            policy = "frame_tile_grid_not_alpha_crop"
        left, top, right, bottom = bounds
        width, height = right-left, bottom-top
        if width <= 0 or height <= 0 or width*height > max_pixels:
            raise DecodeError(f"Invalid/resource-limited canvas {bounds}; max pixels {max_pixels}")
        if frame_bounds and not (left <= frame_bounds[0] and top <= frame_bounds[1]
                                and right >= frame_bounds[2] and bottom >= frame_bounds[3]):
            raise DecodeError("Explicit canvas excludes frame tile extent; implicit clipping is forbidden")
        im = Image.new("RGBA", (width,height), (0,0,0,0))
        key = "original_grid_xy" if coordinate_system == "original-grid" else "reference_client_xy"
        for ref in self.frames[frame]["references"]:
            x,y = ref[key]
            tile = Image.frombytes("RGBA", (24,24), self.blocks[ref["block"]]["pixels_rgba"])
            im.alpha_composite(tile, (x-left,y-top))
        alpha_bbox = im.getchannel("A").getbbox()
        grid_origin = (0,0) if coordinate_system == "original-grid" else (-24,36)
        client_origin = (24,-36) if coordinate_system == "original-grid" else (0,0)
        result = {"frame": frame, "coordinate_system": coordinate_system,
                  "canvas_policy": policy, "canvas_bounds": bounds,
                  "size": [width,height], "mode": "RGBA", "resampled": False,
                  "frame_tile_grid_bounds": frame_bounds,
                  "alpha_bbox_in_canvas": list(alpha_bbox) if alpha_bbox else None,
                  "alpha_bounds_in_coordinate_system": translate_bounds(alpha_bbox,left,top),
                  "original_grid_origin_in_canvas": [grid_origin[0]-left,grid_origin[1]-top],
                  "reference_client_origin_in_canvas": [client_origin[0]-left,client_origin[1]-top],
                  "anchor_is_foot": False, "foot_anchor": None,
                  "rgba_sha256": sha256(im.tobytes()),
                  "nonzero_alpha_pixels": sum(v != 0 for v in im.getchannel("A").tobytes()),
                  "composition": "RLE samples opaque, gaps transparent; source reference order; t byte ignored but preserved"}
        return im, result


def write_json(value, output):
    encoded = json.dumps(value, ensure_ascii=False, indent=2) + "\n"
    if output is None or str(output) == "-":
        sys.stdout.write(encoded)
    else:
        Path(output).write_text(encoded, encoding="utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    inspect = sub.add_parser("inspect", help="Validate all encoded blocks; write all frame metadata JSON")
    inspect.add_argument("input", type=Path)
    inspect.add_argument("--output", type=Path, help="JSON path; stdout if omitted or -")
    render = sub.add_parser("render", help="Render one exact frame to RGBA PNG and metadata JSON")
    render.add_argument("input", type=Path)
    render.add_argument("--frame", type=int, required=True, help="Zero-based; invalid values error, never clamp")
    render.add_argument("--output", type=Path, required=True, help="PNG output path")
    render.add_argument("--metadata", type=Path, help="JSON output, default <PNG>.json; - for stdout")
    render.add_argument("--coordinate-system", choices=SYSTEMS, default="original-grid")
    canvas = render.add_mutually_exclusive_group()
    canvas.add_argument("--fixed-canvas", action="store_true", help="All-frame tile bounds union within this SPR")
    canvas.add_argument("--canvas", nargs=4, type=int, metavar=("LEFT","TOP","RIGHT","BOTTOM"),
                        help="Explicit shared canvas in selected coordinate system; no clipping")
    args = parser.parse_args(argv)
    try:
        if args.input.stat().st_size > MAX_INPUT_BYTES:
            raise DecodeError(f"Input exceeds {MAX_INPUT_BYTES} bytes")
        # Input is only ever opened read-only. Refuse output aliases of it.
        output_paths = [getattr(args,"output",None), getattr(args,"metadata",None)]
        if args.command == "render" and args.metadata is None:
            args.metadata = Path(str(args.output) + ".json")
            output_paths.append(args.metadata)
        for output in output_paths:
            if output is not None and str(output) != "-":
                if (output.resolve() == args.input.resolve() or
                    (output.exists() and output.samefile(args.input))):
                    raise DecodeError("Refusing to overwrite input SPR")
        if args.command == "render":
            same_outputs = args.output.resolve() == args.metadata.resolve()
            if args.output.exists() and args.metadata.exists():
                same_outputs = same_outputs or args.output.samefile(args.metadata)
            if same_outputs:
                raise DecodeError("PNG and metadata outputs must be different files")
        sprite = Sprite(args.input.read_bytes())
        metadata = sprite.metadata()
        metadata["input_path"] = str(args.input)
        if args.command == "inspect":
            write_json(metadata, args.output)
        else:
            im, rendering = sprite.render(args.frame, fixed_canvas=args.fixed_canvas,
                                          canvas_bounds=args.canvas,
                                          coordinate_system=args.coordinate_system)
            im.save(args.output, format="PNG")
            rendering["png_output"] = str(args.output)
            rendering["png_sha256"] = sha256(args.output.read_bytes())
            metadata["render"] = rendering
            write_json(metadata, args.metadata)
        return 0
    except (DecodeError, OSError, ImportError) as error:
        print(f"spr_decode: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
