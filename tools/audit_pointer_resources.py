#!/usr/bin/env python3
"""Read original icon/cursor masks and emit only metadata and comparison hashes."""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path

from extract_pe_icons import PeResources


def inspect_image(payload: bytes, cursor: bool) -> dict:
    hotspot = list(struct.unpack_from('<HH', payload)) if cursor else [0, 0]
    dib = payload[4:] if cursor else payload
    header, width, double_height, planes, bits, compression = struct.unpack_from('<IiiHHI', dib)
    assert header == 40 and planes == 1 and compression == 0
    assert bits in (1, 4, 8) and double_height > 0 and double_height % 2 == 0
    height = double_height // 2
    count = struct.unpack_from('<I', dib, 32)[0] or 1 << bits
    palette = [tuple(dib[40 + i * 4:43 + i * 4][::-1]) for i in range(count)]
    start = header + count * 4
    xor_stride = ((width * bits + 31) // 32) * 4
    and_stride = ((width + 31) // 32) * 4
    mask_start = start + xor_stride * height
    assert len(dib) >= mask_start + and_stride * height
    composited = bytearray()
    transparent = bytearray()
    inverting = 0
    for row in reversed(range(height)):
        xor_row = int.from_bytes(dib[start + row * xor_stride:start + (row + 1) * xor_stride], 'big')
        and_row = int.from_bytes(dib[mask_start + row * and_stride:mask_start + (row + 1) * and_stride], 'big')
        for x in range(width):
            index = (xor_row >> (xor_stride * 8 - bits * (x + 1))) & ((1 << bits) - 1)
            mask = (and_row >> (and_stride * 8 - x - 1)) & 1
            rgb = palette[index]
            inverting += bool(mask and any(rgb))
            composited.extend((component ^ (backdrop if mask else 0)) for component, backdrop in zip(rgb, (37, 83, 149)))
            composited.append(255)
            transparent.extend((0, 0, 0, 0) if mask else (*rgb, 255))
    return dict(width=width, height=height, bits=bits, hotspot=hotspot,
                inverting_pixels=inverting, trailing_bytes=len(dib) - mask_start - and_stride * height,
                composite_sha256=hashlib.sha256(composited).hexdigest(),
                transparent_sha256=None if inverting else hashlib.sha256(transparent).hexdigest())


def build_audit(root: Path) -> dict:
    images = []
    groups = []
    sources = []
    for source in ('SIMCITY.EXE', 'WINSCURK.EXE'):
        data = (root / source).read_bytes()
        pe = PeResources(data)
        sources.append(dict(path=source, sha256=hashlib.sha256(data).hexdigest()))
        for kind, type_id in (('icon', 3), ('cursor', 1)):
            for identifier in pe.resource_ids(type_id):
                payload = pe.resource(type_id, identifier)
                images.append(dict(source=source, kind=kind, id=identifier,
                                   resource_sha256=hashlib.sha256(payload).hexdigest(),
                                   **inspect_image(payload, kind == 'cursor')))
            for identifier in pe.resource_ids(14 if kind == 'icon' else 12):
                payload = pe.resource(14 if kind == 'icon' else 12, identifier)
                reserved, group_type, count = struct.unpack_from('<HHH', payload)
                assert reserved == 0 and group_type == (1 if kind == 'icon' else 2)
                assert len(payload) == 6 + count * 14
                members = []
                for i in range(count):
                    at = 6 + 14 * i
                    length, member = struct.unpack_from('<IH', payload, at + 8)
                    assert len(pe.resource(type_id, member)) == length
                    members.append(member)
                groups.append(dict(source=source, kind=kind, id=identifier, members=members))
    return dict(version=1, evidence='Confirmed from supplied resources; independent Python AND/XOR composition. No source pixels exported.',
                background_rgb=[37, 83, 149], sources=sources, images=images, groups=groups)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference_root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(args.reference_root.resolve()):
        parser.error('The output must be outside the reference directory')
    audit = build_audit(args.reference_root)
    args.output.write_text(json.dumps(audit, indent=2) + '\n')
    print(f"Audited {len(audit['images'])} images and {len(audit['groups'])} groups; metadata and hashes only")


if __name__ == '__main__':
    main()
