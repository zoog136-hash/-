#!/usr/bin/env python3
"""Create an invented Brotli SP2 near the sample limit. Requires Python brotli.

No original client bytes. Eight groups, 255 frames/blocks per group, 255 rows
of 31 samples per block. Output tests bounded input expansion, not real content.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def main():
    import brotli
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    body = bytearray([254, 0])
    for index in range(256):
        body.extend([index, (index * 7) & 127])
    body.append(255)
    for _ in range(8):
        body.append(255)
        for frame in range(255):
            body.extend(struct.pack('<hhhhHBBBH', 0, 0, 31, 255, 1, 0, 0, 0, frame))
        body.extend(struct.pack('<i', 255))
        for _ in range(255):
            body.extend(bytes([0, 0, 255]) + struct.pack('<H', (31 << 5) | (1 << 10)) * 255)
    samples = 8 * 255 * 255 * 31
    pattern = bytes((index * 13) % 256 for index in range(256))
    body.extend(pattern * (samples // 256) + pattern[:samples % 256])
    compressed = brotli.compress(bytes(body), quality=4)
    args.output.write_bytes(compressed)
    print(json.dumps({'synthetic_only': True, 'body_bytes': len(body),
                      'compressed_bytes': len(compressed), 'samples': samples,
                      'commands': 8 * 255 * 255,
                      'sha256': hashlib.sha256(compressed).hexdigest()}))


if __name__ == '__main__':
    main()
