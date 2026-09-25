#!/usr/bin/env python3
"""Check the Godot GIF codec against Pillow in both directions."""
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


def check_static(path):
    metadata = json.loads(Path(str(path) + '.json').read_text())
    with Image.open(path) as image:
        assert image.size == (metadata['width'], metadata['height'])
        assert getattr(image, 'n_frames', 1) == 1
        transparent = image.info.get('transparency')
        indices = list(image.getdata())
        actual = [-1 if index == transparent else index for index in indices]
        assert actual == metadata['pixels'], 'Indexed pixels or transparency differ'
        # Pillow opens a GIF with a gray-scale palette in L mode, where the index is the gray value.
        assert image.mode in ('P', 'L')
        if image.mode == 'P':
            palette = image.getpalette()[:768]
            assert palette == [value for index in range(256) for value in (index, index, index)], 'Palette order differs'
    print('PASS: independent decode of the single-frame indexed GIF')


def _image_descriptor(data):
    position = 13 + (3 * (2 << (data[10] & 7)) if data[10] & 0x80 else 0)
    while data[position] == 0x21:
        position += 2
        while data[position]:
            position += data[position] + 1
        position += 1
    assert data[position] == 0x2c
    return position


def _expected(path, screen=None, offset=(0, 0)):
    with Image.open(path) as image:
        width, height = image.size
        transparent = image.info.get('transparency')
        indices = list(image.getdata())
        palette = image.getpalette()
    screen_width, screen_height = screen or (width, height)
    pixels = [-1] * (screen_width * screen_height)
    for y in range(height):
        for x in range(width):
            index = indices[y * width + x]
            pixels[(y + offset[1]) * screen_width + x + offset[0]] = -1 if index == transparent else index
    colors = [palette[index * 3:index * 3 + 3] for index in range(len(palette) // 3)]
    return {'width': screen_width, 'height': screen_height, 'pixels': pixels, 'colors': colors}


def make_fixtures(folder):
    """Write Pillow GIF files and the indices that Pillow decodes from them."""
    cases = []
    small = Image.new('P', (4, 3))
    small.putpalette([0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255])
    small.putdata([0, 1, 2, 3, 3, 2, 1, 0, 1, 1, 2, 2])
    small.save(folder / 'small.gif', transparency=2)
    cases.append(('small.gif', _expected(folder / 'small.gif')))

    # Pillow interlaces only images that are at least 16 pixels in each direction.
    interlaced = Image.new('P', (20, 19))
    interlaced.putpalette([value for index in range(16) for value in (index * 16, 255 - index * 16, index * 8)])
    interlaced.putdata([(x + y * 3) % 16 for y in range(19) for x in range(20)])
    interlaced.save(folder / 'interlaced.gif', interlace=True)
    data = (folder / 'interlaced.gif').read_bytes()
    assert data[_image_descriptor(data) + 9] & 0x40, 'Pillow did not interlace the fixture'
    cases.append(('interlaced.gif', _expected(folder / 'interlaced.gif')))

    # Many distinct runs grow the LZW codes to 12 bits and need clear codes.
    large = Image.new('P', (128, 96))
    large.putpalette([value for index in range(256) for value in (index, (index * 7) % 256, (index * 13) % 256)])
    large.putdata([(x * 7 + y * 13 + (x * y) % 11) % 256 for y in range(96) for x in range(128)])
    large.save(folder / 'large.gif')
    cases.append(('large.gif', _expected(folder / 'large.gif')))

    # Move the global color table into the image descriptor.
    data = bytearray((folder / 'small.gif').read_bytes())
    table_size = 3 * (2 << (data[10] & 7))
    table = data[13:13 + table_size]
    descriptor = _image_descriptor(data) - table_size
    flags = data[10]
    del data[13:13 + table_size]
    data[10] = flags & 0x70
    data[descriptor + 9] |= 0x80 | (flags & 7)
    data[descriptor + 10:descriptor + 10] = table
    (folder / 'local.gif').write_bytes(bytes(data))
    cases.append(('local.gif', _expected(folder / 'small.gif')))

    # Place the same image at an offset on a larger logical screen.
    data = bytearray((folder / 'small.gif').read_bytes())
    data[6:10] = (7).to_bytes(2, 'little') + (6).to_bytes(2, 'little')
    descriptor = _image_descriptor(data)
    data[descriptor + 1:descriptor + 5] = (2).to_bytes(2, 'little') + (1).to_bytes(2, 'little')
    (folder / 'offset.gif').write_bytes(bytes(data))
    cases.append(('offset.gif', _expected(folder / 'small.gif', (7, 6), (2, 1))))

    (folder / 'fixtures.json').write_text(json.dumps([dict(file=name, **expected) for name, expected in cases]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--project', default=str(Path(__file__).resolve().parents[1] / 'game'))
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='city-gif-') as folder:
        folder = Path(folder)
        path = folder / 'cycle.gif'
        fixtures = folder / 'fixtures'
        fixtures.mkdir()
        make_fixtures(fixtures)
        subprocess.run([sys.executable, str(Path(__file__).with_name('run_godot_check.py')),
                        args.godot, '--headless', '--audio-driver', 'Dummy', '--path', args.project,
                        '--script', 'res://tests/scurk_gif_export_test.gd', '--', str(path), str(fixtures)], check=True)
        check_export(path)
        check_static(folder / 'static.gif')


if __name__ == '__main__':
    main()
