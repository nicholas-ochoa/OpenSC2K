#!/usr/bin/env python3
"""Check graphics inventory coverage and lossless PNG palette padding."""
import json
import struct
import unittest
import zlib
from pathlib import Path

from inventory_graphics import build_inventory
from audit_pointer_resources import build_audit
from audit_check_controls import build_audit as build_check_audit
from audit_scenario_pictures import build_audit as build_scenario_audit
from pad_png_palette import pad_palette

ROOT = Path(__file__).resolve().parents[1]


def chunk(kind, payload):
    return struct.pack('>I', len(payload)) + kind + payload + struct.pack('>I', zlib.crc32(kind + payload))


class GraphicsToolsTest(unittest.TestCase):
    def test_scenario_picture_audit_and_coverage(self):
        expected = json.loads((ROOT / 'data/formats/scenario-picture-audit.json').read_text())
        self.assertEqual(build_scenario_audit(ROOT / 'references' / 'SIMCITY2000'), expected)

    def test_check_sheet_audit_and_complete_bitmap_coverage(self):
        expected = json.loads((ROOT / 'data/formats/check-control-audit.json').read_text())
        self.assertEqual(json.loads(json.dumps(build_check_audit(ROOT / 'references' / 'SIMCITY2000'))), expected)

    def test_desktop_resource_audit_and_pack_coverage(self):
        expected = json.loads((ROOT / 'data/formats/desktop-resource-audit.json').read_text())
        self.assertEqual(build_audit(ROOT / 'references' / 'SIMCITY2000'), expected)
        self.assertEqual(len(expected['images']), 153)
        self.assertEqual(len(expected['groups']), 144)

    def test_palette_padding_preserves_encoded_indices(self):
        header = struct.pack('>IIBBBBB', 2, 1, 8, 3, 0, 0, 0)
        pixels = zlib.compress(bytes([0, 1, 0]))
        original = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', header)
                    + chunk(b'PLTE', bytes([20, 30, 40]) * 2)
                    + chunk(b'tRNS', b'\0') + chunk(b'IDAT', pixels) + chunk(b'IEND', b''))
        padded = pad_palette(original)
        self.assertEqual(pad_palette(padded), padded)
        self.assertIn(chunk(b'PLTE', bytes([20, 30, 40]) * 2 + bytes(762)), padded)
        self.assertIn(chunk(b'IDAT', pixels), padded)
        self.assertIn(chunk(b'tRNS', b'\0'), padded)
        for broken in [original[:-1], original + b'\0', original[:50] + b'\xff' + original[51:]]:
            with self.assertRaises(ValueError):
                pad_palette(broken)




    def test_supplied_inventory_matches_recorded_metadata(self):
        expected = json.loads((ROOT / 'data/formats/graphics-inventory.json').read_text())
        actual = build_inventory(ROOT / 'references' / 'SIMCITY2000')
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
