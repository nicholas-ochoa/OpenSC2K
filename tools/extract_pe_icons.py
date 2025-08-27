#!/usr/bin/env python3
"""Extract RT_GROUP_ICON resources from a PE32 executable."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


def unpack_from(fmt: str, data: bytes, offset: int) -> tuple[int, ...]:
    return struct.unpack_from(fmt, data, offset)


class PeResources:
    def __init__(self, data: bytes) -> None:
        self.data = data
        pe_offset = unpack_from("<I", data, 0x3C)[0]
        if data[pe_offset : pe_offset + 4] != b"PE\0\0":
            raise ValueError("input is not a PE executable")
        coff = pe_offset + 4
        section_count = unpack_from("<H", data, coff + 2)[0]
        optional_size = unpack_from("<H", data, coff + 16)[0]
        optional = coff + 20
        if unpack_from("<H", data, optional)[0] != 0x10B:
            raise ValueError("input is not PE32")
        resource_rva = unpack_from("<I", data, optional + 96 + 16)[0]
        section_table = optional + optional_size
        self.sections: list[tuple[int, int, int]] = []
        for index in range(section_count):
            entry = section_table + index * 40
            virtual_size, virtual_address, raw_size, raw_offset = unpack_from(
                "<IIII", data, entry + 8
            )
            self.sections.append(
                (virtual_address, max(virtual_size, raw_size), raw_offset)
            )
        self.root = self.rva_to_offset(resource_rva)

    def rva_to_offset(self, rva: int) -> int:
        for address, size, raw_offset in self.sections:
            if address <= rva < address + size:
                return raw_offset + rva - address
        raise ValueError(f"RVA 0x{rva:x} is outside all sections")

    def directory(self, relative_offset: int) -> dict[int, tuple[bool, int]]:
        offset = self.root + relative_offset
        named_count, id_count = unpack_from("<HH", self.data, offset + 12)
        result: dict[int, tuple[bool, int]] = {}
        for index in range(named_count + id_count):
            name, target = unpack_from("<II", self.data, offset + 16 + index * 8)
            if name & 0x80000000:
                continue
            result[name & 0xFFFF] = (
                bool(target & 0x80000000), target & 0x7FFFFFFF
            )
        return result

    def resource(self, type_id: int, resource_id: int) -> bytes:
        type_entry = self.directory(0).get(type_id)
        if type_entry is None or not type_entry[0]:
            raise ValueError(f"resource type {type_id} is missing")
        resource_entry = self.directory(type_entry[1]).get(resource_id)
        if resource_entry is None or not resource_entry[0]:
            raise ValueError(f"resource {type_id}:{resource_id} is missing")
        languages = self.directory(resource_entry[1])
        if not languages:
            raise ValueError(f"resource {type_id}:{resource_id} has no language")
        is_directory, data_entry = next(iter(languages.values()))
        if is_directory:
            raise ValueError(f"resource {type_id}:{resource_id} has invalid depth")
        data_rva, size = unpack_from("<II", self.data, self.root + data_entry)
        offset = self.rva_to_offset(data_rva)
        if offset + size > len(self.data):
            raise ValueError(f"resource {type_id}:{resource_id} is truncated")
        return self.data[offset : offset + size]

    def resource_ids(self, type_id: int) -> list[int]:
        type_entry = self.directory(0).get(type_id)
        if type_entry is None or not type_entry[0]:
            return []
        return sorted(self.directory(type_entry[1]))


def icon_file(resources: PeResources, group_id: int) -> bytes:
    group = resources.resource(14, group_id)
    if len(group) < 6:
        raise ValueError(f"icon group {group_id} is truncated")
    reserved, kind, count = unpack_from("<HHH", group, 0)
    if reserved != 0 or kind != 1 or len(group) < 6 + count * 14:
        raise ValueError(f"icon group {group_id} has an invalid header")
    entries = []
    images = []
    output_offset = 6 + count * 16
    for index in range(count):
        offset = 6 + index * 14
        width, height, colors, entry_reserved, planes, bits, size, icon_id = (
            unpack_from("<BBBBHHIH", group, offset)
        )
        image = resources.resource(3, icon_id)
        if len(image) != size:
            raise ValueError(f"icon image {icon_id} has a size mismatch")
        entries.append(
            struct.pack(
                "<BBBBHHII",
                width,
                height,
                colors,
                entry_reserved,
                planes,
                bits,
                size,
                output_offset,
            )
        )
        images.append(image)
        output_offset += size
    return struct.pack("<HHH", 0, 1, count) + b"".join(entries) + b"".join(images)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("executable", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    resources = PeResources(args.executable.read_bytes())
    args.output_directory.mkdir(parents=True, exist_ok=True)
    group_ids = resources.resource_ids(14)
    if not group_ids:
        raise ValueError("the executable has no icon groups")
    for group_id in group_ids:
        output = args.output_directory / f"icon-{group_id}.ico"
        output.write_bytes(icon_file(resources, group_id))
        print(output)


if __name__ == "__main__":
    main()
