#!/usr/bin/env python3
"""Decode the small Godot GIF fixture with Pillow and check its complete cycle."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile

from PIL import Image


def check_export(path):
    metadata = json.loads(Path(str(path) + '.json').read_text())
    pixels = metadata['pixels']
    expected = []
    for tick, mapping in enumerate(metadata['frames']):
        rgba = bytes(channel for pixel in pixels for channel in
                     ((0, 0, 0, 0) if pixel < 0 else (mapping[pixel],) * 3 + (255,)))
        if not expected or expected[-1][1] != rgba:
            expected.append((tick, rgba))
    with Image.open(path) as image:
        assert image.size == (metadata['width'], metadata['height'])
        assert image.info['loop'] == 0, 'Animation must repeat'
        assert image.n_frames == len(expected) > 1
        duration = 0
        for index, (tick, rgba) in enumerate(expected):
            image.seek(index)
            assert image.convert('RGBA').tobytes() == rgba, f'Decoded pixels/transparency differ in frame {index}'
            end = expected[index + 1][0] if index + 1 < len(expected) else 120
            # Godot roundi rounds positive half values upwards, unlike Python round.
            delay = (((end * 11 + 1) // 2) - ((tick * 11 + 1) // 2)) * 10
            assert image.info['duration'] == delay, f'Wrong duration in frame {index}'
            duration += delay
        assert duration == 6600
    print(f'PASS: independent GIF decode, {len(expected)} frames, all pixels, transparency, timing and loop')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--project', default=str(Path(__file__).resolve().parents[1] / 'game'))
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='city-gif-') as folder:
        path = Path(folder) / 'cycle.gif'
        subprocess.run([sys.executable, str(Path(__file__).with_name('run_godot_check.py')),
                        args.godot, '--headless', '--audio-driver', 'Dummy', '--path', args.project,
                        '--script', 'res://tests/scurk_gif_export_test.gd', '--', str(path)], check=True)
        check_export(path)


if __name__ == '__main__':
    main()
