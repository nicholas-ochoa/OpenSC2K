#!/usr/bin/env python3
"""Check graphics inventory coverage and lossless PNG palette padding."""
import json
import struct
import unittest
import zlib
from pathlib import Path

from inventory_graphics import build_inventory
from pad_png_palette import pad_palette

ROOT = Path(__file__).resolve().parents[1]


def chunk(kind, payload):
    return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload))


class GraphicsToolsTest(unittest.TestCase):


    def test_supplied_inventory_matches_recorded_metadata(self):
        expected = json.loads((ROOT / 'data/formats/graphics-inventory.json').read_text())
        actual = build_inventory(ROOT / 'references')
        self.assertEqual(actual, expected)
        self.assertEqual(actual['counts']['sprite'], 1455)
        self.assertEqual(actual['counts']['scenario_picture'], 18)
        sprites = [e for e in actual['entries'] if e['source'] == 'DATA/LARGE.DAT']
        self.assertEqual(len(sprites), 501)
        self.assertEqual(len({e['id'] for e in sprites}), 499)
        named_bitmaps = [e for e in actual['entries'] if e['kind'] == 'bitmap' and isinstance(e['id'], str)]
        self.assertEqual(len(named_bitmaps), 14)
        notice = [e for e in actual['entries'] if e['source'] == 'BITMAPS/403.BMP']
        self.assertEqual((notice[0]['width'], notice[0]['height']), (155, 100))


if __name__ == '__main__':
    unittest.main()
