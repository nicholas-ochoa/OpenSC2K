import fs from 'fs';
import tiles from 'tiles';
import palette from 'palette';
import config from 'config';
import { image } from 'utils';

export function createTexture(): void {
  let x: number = 1;
  let y: number = 1;
  let maxWidth: number = 16;
  let maxHeight: number = 8;
  let rowMaxY: number = 0;
  const size: number = 4096;
  const json: any = {};
  const padding: number = 1;
  const img = image.create(size, size);

  // looping 128 times here to sort tiles by size
  // this shuffles the smaller tiles to the front of the tilemap
  for (let loop = 0; loop < 128; loop++) {
    for (let i = 1; i < tiles.data.length; i++) {
      const tile = tiles.data[i];

      // skip tiles that were already flagged as loaded
      if (tile.loaded) {
        continue;
      }

      // skip anything that exceeds the current maximum
      if (tile.header.width > maxWidth || tile.header.height > maxHeight) {
        continue;
      }

      // loop on every frame
      for (let f = 0; f < tile.frames; f++) {
        // max tile height in this row
        if (tile.header.height > rowMaxY) {
          rowMaxY = tile.header.height;
        }

        // exceeds tilemap width, start a new row
        if (x + tile.header.width > size) {
          x = 1;
          y += rowMaxY + padding;
          rowMaxY = 0;
        }

        // drop any colors?
        // used to foribly remove certain palette indexes
        // from tiles (example: traffic tiles)
        if (tile?.importOptions?.dropColor) {
          tile.importOptions.dropColor.forEach((index, i) => {
            if (Number.isInteger(index)) {
              tile.importOptions.dropColor[i] = palette.getColorString(index, 0);
            }
          });
        }

        for (let ty = 0; ty < tile.header.block.length; ty++) {
          for (let tx = 0; tx < tile.header.block[ty].pixels.length; tx++) {
            // palette index value
            let index = tile.header.block[ty].pixels[tx];

            // drop out specific palette colors and transparency
            if (tile?.importOptions?.dropColor?.includes(palette.getColorString(index, f))) {
              index = -1;
            }

            // set color and canvas x/y index
            //bitmap.setPixel(x + tx, y + ty, palette.getColor(index, f));
            image.setPixel(img, x + tx, y + ty, palette.getColor(index, f));
          }
        }

        // add tilemap data
        json[`${tile.header.imageName}_${f}`] = {
          frame: { x, y, w: tile.header.width, h: tile.header.height },
          rotated: false,
          trimmed: false,
          spriteSourceSize: { x: 0, y: 0, w: tile.header.width, h: tile.header.height },
          sourceSize: { w: tile.header.width, h: tile.header.height },
        };

        // move drawing position + padding
        x += tile.header.width + padding;

        // flag tile as loaded if the frame count matches the current frame
        // or if the tile has no frames
        if (tile.frames == f + 1 || tile.frames == 1) {
          tile.loaded = true;
        }
      }
    }

    // increase tile size next loop
    maxWidth = maxWidth + 4;
    maxHeight = maxHeight + 4;
  }

  // sort keys and save tilemap data
  const jsonData = {};
  Object.keys(json)
    .sort()
    .forEach(key => {
      jsonData[key] = json[key];
    });

  fs.writeFileSync(config.get('paths.tilemap.data'), JSON.stringify({ frames: jsonData }));

  // save tilemap image
  image.save(img, config.get('paths.tilemap.image'));
}
