import fs from 'fs';
import bmp from 'bmp-ts';
import config from 'config';

// parse BMP file into a palette of 256 colors
export function parse(): any[] {
  const buffer: Buffer = fs.readFileSync(config.get('paths.import.pal_mstr_bmp'));
  const file: any = bmp.decode(buffer);
  const image: any[] = [];
  const palette: any[] = [];
  let offset: number = 0;

  for (let y: number = 0; y < file.height; y++) {
    for (let x: number = 0; x < file.width; x++) {
      if (image[x] === undefined) {
        image[x] = [];
      }

      image[x][y] = {
        r: file.data[offset + 3],
        g: file.data[offset + 2],
        b: file.data[offset + 1],
        a: 255,
      };

      // offset by 4 bytes (rgba) for each pixel
      offset += 4;

      if (file.data[offset] === undefined) {
        break;
      }
    }
  }

  // loop through each palette color in the
  // source bmp and index them in order
  // left to right, top to bottom (16x16)
  for (let y: number = 1; y <= 16; y++) {
    for (let x: number = 1; x <= 16; x++) {
      // offset 1 px from left, colors are 6 px wide
      const cX = 1 + x * 6;

      // offset 15 px from top, rows are 5 px tall
      const cY = 15 + y * 5;

      palette.push(image[cX][cY]);
    }
  }

  return palette;
}
