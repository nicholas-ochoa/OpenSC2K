#!/usr/bin/env python3
"""Inventory supplied graphics metadata. Never export source pixels or text."""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from collections import Counter
from pathlib import Path

from extract_pe_icons import PeResources


def dib_dimensions(data: bytes, mask: bool = False) -> dict:
    header = struct.unpack_from('<I', data)[0]
    if header == 12:
        width, height, _planes, bits = struct.unpack_from('<HHHH', data, 4)
    elif header >= 40:
        width, height, _planes, bits = struct.unpack_from('<iiHH', data, 4)
    else:
        raise ValueError(f'Unsupported DIB header {header}')
    return {'width': width, 'height': abs(height) // (2 if mask else 1), 'bits': bits}


def resource_leaves(pe: PeResources, offset: int = 0, keys: tuple = ()):
    """Include named resources and all languages, unlike numeric convenience lookup."""
    if len(keys) > 3:
        raise ValueError('Unexpected PE resource depth')
    at = pe.root + offset
    named, numeric = struct.unpack_from('<HH', pe.data, at + 12)
    for index in range(named + numeric):
        name, target = struct.unpack_from('<II', pe.data, at + 16 + index * 8)
        if name & 0x80000000:
            name_at = pe.root + (name & 0x7fffffff)
            length = struct.unpack_from('<H', pe.data, name_at)[0]
            key = pe.data[name_at + 2:name_at + 2 + length * 2].decode('utf-16-le')
        else:
            key = name
        if target & 0x80000000:
            yield from resource_leaves(pe, target & 0x7fffffff, keys + (key,))
        else:
            rva, size = struct.unpack_from('<II', pe.data, pe.root + target)
            start = pe.rva_to_offset(rva)
            if start + size > len(pe.data):
                raise ValueError('Truncated PE resource')
            yield keys + (key,), pe.data[start:start + size]


def chunks(data: bytes, start: int, end: int):
    while start < end:
        tag, length = struct.unpack_from('>4sI', data, start)
        finish = start + 8 + length
        if finish > end:
            raise ValueError('Chunk extends past container')
        yield tag, data[start + 8:finish]
        start = finish  # These supplied formats do not pad odd chunks.


def build_inventory(root: Path) -> dict:
    entries = []
    sources = []

    def read(path: Path) -> tuple[str, bytes]:
        data = path.read_bytes()
        relative = path.relative_to(root).as_posix()
        sources.append({'path': relative, 'sha256': hashlib.sha256(data).hexdigest()})
        return relative, data

    def add(source: str, kind: str, identifier, **values):
        entries.append({'source': source, 'kind': kind, 'id': identifier, **values})

    for name in ('LARGE', 'SMALLMED', 'SPECIAL'):
        source, data = read(root / 'DATA' / f'{name}.DAT')
        count = struct.unpack_from('>H', data)[0]
        duplicates = Counter()
        for ordinal in range(count):
            identifier, _offset, height, width = struct.unpack_from('>HIHH', data, 2 + ordinal * 10)
            add(source, 'sprite', identifier, ordinal=ordinal, duplicate=duplicates[identifier], width=width, height=height)
            duplicates[identifier] += 1

    for name in ('SIMCITY.EXE', 'WINSCURK.EXE'):
        source, data = read(root / name)
        pe = PeResources(data)
        for keys, payload in resource_leaves(pe):
            if len(keys) != 3 or keys[0] not in (1, 2, 3, 12, 14):
                continue
            kind, identifier, language = keys
            if kind in (12, 14):
                reserved, group_type, count = struct.unpack_from('<HHH', payload)
                if reserved or group_type != (2 if kind == 12 else 1) or len(payload) != 6 + count * 14:
                    raise ValueError('Invalid icon or cursor group')
                members = [struct.unpack_from('<H', payload, 6 + i * 14 + 12)[0] for i in range(count)]
                add(source, 'cursor_group' if kind == 12 else 'icon_group', identifier, language=language, members=members)
            else:
                dims = dib_dimensions(payload[4:] if kind == 1 else payload, mask=kind != 2)
                extra = {'hotspot': list(struct.unpack_from('<HH', payload))} if kind == 1 else {}
                add(source, {1: 'cursor', 2: 'bitmap', 3: 'icon'}[kind], identifier, language=language, **dims, **extra)

    for path in sorted(root.rglob('*')):
        suffix = path.suffix.upper()
        if suffix == '.BMP':
            source, data = read(path)
            if data[:2] != b'BM':
                raise ValueError(f'Invalid BMP: {source}')
            add(source, 'bitmap_file', 0, **dib_dimensions(data[14:]))
        elif suffix == '.SCN':
            source, data = read(path)
            if data[:4] != b'FORM' or data[8:12] != b'SCDH':
                raise ValueError(f'Invalid scenario: {source}')
            for tag, payload in chunks(data, 12, len(data)):
                if tag == b'PICT':
                    width, height = struct.unpack_from('<HH', payload, 4)
                    add(source, 'scenario_picture', 0, width=width, height=height)
        elif suffix == '.MIF':
            source, data = read(path)
            if data[:4] != b'MIFF' or data[8:12] != b'SC2K':
                raise ValueError(f'Invalid MIF: {source}')
            duplicates = Counter()
            for tag, payload in chunks(data, 12, len(data)):
                if tag != b'TILE':
                    continue
                for ordinal, (piece, shape) in enumerate(chunks(payload, 2, len(payload))):
                    if piece == b'SHAP':
                        identifier, width, height, _size = struct.unpack_from('>HHHI', shape)
                        add(source, 'scurk_shape', identifier, ordinal=ordinal, duplicate=duplicates[identifier], width=width, height=height)
                        duplicates[identifier] += 1
        elif path.name.upper() == 'TILES.DB':
            source, data = read(path)
            count = struct.unpack_from('<H', data)[0]
            for ordinal in range(count):
                identifier, _offset, height, width = struct.unpack_from('<HIHH', data, 2 + ordinal * 10)
                add(source, 'scurk_database_sprite', identifier, ordinal=ordinal, width=width, height=height)

    return {
        'format': 'opensc2k-reference-graphics-inventory', 'version': 1,
        'evidence': 'confirmed: metadata read from supplied files; no artwork pixels or display text exported',
        'scope': 'DAT sprites; PE bitmap, icon, cursor and group resources; BMP files; SCN pictures; MIF shapes; TILES.DB records',
        'counts': dict(sorted(Counter(e['kind'] for e in entries).items())),
        'sources': sources, 'entries': entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('reference_root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    root = args.reference_root.resolve()
    if args.output.resolve().is_relative_to(root):
        parser.error('The inventory output must be outside the reference directory')
    inventory = build_inventory(root)
    header = json.dumps({key: value for key, value in inventory.items() if key != 'entries'}, indent=2)
    records = ',\n'.join('    ' + json.dumps(entry) for entry in inventory['entries'])
    args.output.write_text(header[:-2] + ',\n  \"entries\": [\n' + records + '\n  ]\n}\n')
    print(json.dumps(inventory['counts'], sort_keys=True))


if __name__ == '__main__':
    main()
