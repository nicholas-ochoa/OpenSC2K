#!/usr/bin/env python3
"""Print one numeric PE32 RT_DIALOG resource as JSON."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any

from extract_pe_icons import PeResources


DS_SETFONT = 0x40
CONTROL_CLASSES = {
    0x80: "Button",
    0x81: "Edit",
    0x82: "Static",
    0x83: "ListBox",
    0x84: "ScrollBar",
    0x85: "ComboBox",
}


class DialogReader:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.offset = 0

    def align(self, amount: int) -> None:
        self.offset = (self.offset + amount - 1) & ~(amount - 1)

    def take(self, fmt: str) -> tuple[int, ...]:
        size = struct.calcsize(fmt)
        if self.offset + size > len(self.data):
            raise ValueError("dialog resource is truncated")
        values = struct.unpack_from(fmt, self.data, self.offset)
        self.offset += size
        return values

    def word_value(self) -> None | str | dict[str, int | str]:
        first = self.take("<H")[0]
        if first == 0:
            return None
        if first == 0xFFFF:
            ordinal = self.take("<H")[0]
            return {
                "ordinal": ordinal,
                "class_name": CONTROL_CLASSES.get(ordinal, ""),
            }
        values = [first]
        while True:
            value = self.take("<H")[0]
            if value == 0:
                break
            values.append(value)
        return b"".join(struct.pack("<H", value) for value in values).decode(
            "utf-16-le"
        )


def style(value: int) -> str:
    return f"0x{value:08x}"


def parse_dialog(data: bytes) -> dict[str, Any]:
    reader = DialogReader(data)
    extended = len(data) >= 4 and struct.unpack_from("<HH", data, 0) == (1, 0xFFFF)
    if extended:
        version, signature, help_id, ex_style, window_style, count = reader.take(
            "<HHIIIH"
        )
        x, y, width, height = reader.take("<hhhh")
        result: dict[str, Any] = {
            "extended": True,
            "version": version,
            "signature": signature,
            "help_id": help_id,
            "extended_style": style(ex_style),
            "style": style(window_style),
            "item_count": count,
            "rect_dlu": [x, y, width, height],
        }
    else:
        window_style, ex_style, count = reader.take("<IIH")
        x, y, width, height = reader.take("<hhhh")
        result = {
            "extended": False,
            "extended_style": style(ex_style),
            "style": style(window_style),
            "item_count": count,
            "rect_dlu": [x, y, width, height],
        }
    result["menu"] = reader.word_value()
    result["window_class"] = reader.word_value()
    result["title"] = reader.word_value()
    if window_style & DS_SETFONT:
        point_size = reader.take("<H")[0]
        font: dict[str, Any] = {"point_size": point_size}
        if extended:
            weight, italic, charset = reader.take("<HBB")
            font.update({"weight": weight, "italic": italic, "charset": charset})
        font["typeface"] = reader.word_value()
        result["font"] = font

    items = []
    for _index in range(count):
        reader.align(4)
        if extended:
            help_id, ex_style, item_style = reader.take("<III")
            x, y, width, height = reader.take("<hhhh")
            item_id = reader.take("<I")[0]
            item: dict[str, Any] = {
                "help_id": help_id,
                "extended_style": style(ex_style),
                "style": style(item_style),
                "rect_dlu": [x, y, width, height],
                "id": item_id,
            }
        else:
            item_style, ex_style = reader.take("<II")
            x, y, width, height, item_id = reader.take("<hhhhH")
            item = {
                "extended_style": style(ex_style),
                "style": style(item_style),
                "rect_dlu": [x, y, width, height],
                "id": item_id,
            }
        item["class"] = reader.word_value()
        item["title"] = reader.word_value()
        extra_size = reader.take("<H")[0]
        item["creation_data_bytes"] = extra_size
        if extra_size:
            if reader.offset + extra_size > len(data):
                raise ValueError("dialog item creation data is truncated")
            reader.offset += extra_size
        items.append(item)
    result["items"] = items
    result["resource_bytes"] = len(data)
    result["parsed_bytes"] = reader.offset
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("executable", type=Path)
    parser.add_argument("resource_id", type=lambda value: int(value, 0))
    args = parser.parse_args()
    resources = PeResources(args.executable.read_bytes())
    print(json.dumps(parse_dialog(resources.resource(5, args.resource_id)), indent=2))


if __name__ == "__main__":
    main()
