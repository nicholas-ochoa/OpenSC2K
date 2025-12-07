#!/usr/bin/env python3
"""Audit supplied PICT metadata and index hashes without exporting pictures."""
import hashlib
import json
import struct
from pathlib import Path

from inventory_graphics import chunks

ROOT = Path(__file__).resolve().parents[1]


def build_audit(root):
    records = []
    for path in sorted((root / 'SCENARIO').glob('*.SCN')):
        data = path.read_bytes()
        pict = next(payload for tag, payload in chunks(data, 12, len(data)) if tag == b'PICT')
        assert pict[:4] == b'\x80\0\0\0'
        width, height = struct.unpack_from('<HH', pict, 4)
        assert len(pict) == 8 + (width + 1) * height
        rows = [pict[8 + y * (width + 1):8 + y * (width + 1) + width] for y in range(height)]
        ends = [pict[8 + y * (width + 1) + width] for y in range(height)]
        assert set(ends) <= {0, 255}
        records.append({'source': path.relative_to(root).as_posix(),
                        'source_sha256': hashlib.sha256(data).hexdigest(),
                        'id': path.stem, 'width': width, 'height': height,
                        'pict_sha256': hashlib.sha256(pict).hexdigest(),
                        'top_down_indices_sha256': hashlib.sha256(b''.join(rows)).hexdigest(),
                        'zero_terminators': ends.count(0), 'ff_terminators': ends.count(255)})
    return {'evidence': 'confirmed: supplied payloads, dimensions, terminators and hashes; no raster or text export',
            'records': records}


if __name__ == '__main__':
    print(json.dumps(build_audit(ROOT / 'references'), indent=2))
