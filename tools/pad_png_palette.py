#!/usr/bin/env python3
"""Pad an indexed PNG palette to 256 entries without changing pixel indices."""
import argparse
import struct
import zlib
from pathlib import Path

SIGNATURE = b'\x89PNG\r\n\x1a\n'


def pad_palette(data: bytes) -> bytes:
    if not data.startswith(SIGNATURE):
        raise ValueError('Invalid PNG signature')
    output = bytearray(SIGNATURE)
    position = 8
    found_palette = False
    finished = False
    while position + 12 <= len(data):
        length = struct.unpack_from('>I', data, position)[0]
        kind = data[position + 4:position + 8]
        payload = data[position + 8:position + 8 + length]
        if position + 12 + length > len(data):
            raise ValueError('Truncated PNG chunk')
        checksum = struct.unpack_from('>I', data, position + 8 + length)[0]
        if checksum != zlib.crc32(kind + payload):
            raise ValueError('Invalid PNG checksum')
        if position == 8 and (kind != b'IHDR' or length != 13 or payload[8:10] != b'\x08\x03'):
            raise ValueError('Expected an 8-bit indexed PNG')
        if kind == b'PLTE':
            if found_palette or not 3 <= length <= 768 or length % 3:
                raise ValueError('Invalid PNG palette')
            found_palette = True
            payload += bytes(768 - length)
        # Remove volatile export timestamps. Pixel data and color metadata stay intact.
        if kind not in (b'tIME', b'tEXt', b'zTXt', b'iTXt'):
            output += struct.pack('>I', len(payload)) + kind + payload
            output += struct.pack('>I', zlib.crc32(kind + payload))
        position += length + 12
        if kind == b'IEND':
            finished = True
            break
    if not found_palette or not finished or position != len(data):
        raise ValueError('Incomplete PNG or trailing data')
    return bytes(output)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.write_bytes(pad_palette(args.input.read_bytes()))


if __name__ == '__main__':
    main()
