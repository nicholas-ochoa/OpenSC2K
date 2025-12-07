#!/usr/bin/env python3
"""Read-only CTL3D sheet metadata and per-cell hashes; never export pixels."""
import hashlib
import json
import struct
from collections import Counter
from pathlib import Path

from extract_pe_icons import PeResources
from inventory_graphics import resource_leaves

ROOT = Path(__file__).resolve().parents[1]


def build_audit(root):
    data = (root / 'SIMCITY.EXE').read_bytes()
    pe = PeResources(data)
    payload = next(p for keys, p in resource_leaves(pe) if keys == (2, 'CTL3D_3DCHECK', 1033))
    header, width, height, planes, bits, compression = struct.unpack_from('<IiiHHI', payload)
    assert (header, width, height, planes, bits, compression) == (40, 70, 39, 1, 4, 0)
    color_count = struct.unpack_from('<I', payload, 32)[0] or 16
    assert color_count == 16
    stride = ((width * bits + 31) // 32) * 4
    assert len(payload) == 40 + color_count * 4 + stride * height
    pixels = []
    for y in range(height):
        row = payload[40 + color_count * 4 + (height - 1 - y) * stride:]
        pixels.extend((row[x // 2] >> (4 if x % 2 == 0 else 0)) & 15 for x in range(width))
    cells = []
    for row in range(3):
        for column in range(5):
            cell = bytes(pixels[(row * 13 + y) * 70 + column * 14 + x] for y in range(13) for x in range(14))
            cells.append({'column': column, 'row': row, 'index_counts': dict(sorted(Counter(cell).items())),
                          'sha256': hashlib.sha256(cell).hexdigest()})
    return {'source': 'SIMCITY.EXE', 'source_sha256': hashlib.sha256(data).hexdigest(),
            'resource': 'CTL3D_3DCHECK', 'language': 1033, 'width': width, 'height': height,
            'bits': bits, 'stride': stride, 'dib_sha256': hashlib.sha256(payload).hexdigest(),
            'cells': cells, 'boundary': 'Cell pixels and counts confirmed; state names and external CTL3D behavior are not proved by this audit.'}


if __name__ == '__main__':
    print(json.dumps(build_audit(ROOT / 'references'), indent=2))
