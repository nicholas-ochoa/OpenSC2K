import fs from 'fs';
import { parseBlock } from './parseBlock';
import { isAnimatedImage } from './isAnimatedImage';
import { getFrameCount } from './getFrameCount';
import { createTexture } from './createTexture';
import { shape } from './shape';
import config from 'config';
import tiles from 'tiles';

// parse dat file into raw image data for each frame
export function load(): void {
  const buffer: Buffer = fs.readFileSync(config.get('paths.import.large_dat'));
  const arrayBuffer: ArrayBuffer = new Uint8Array(buffer).buffer;

  // determine how many images to extract
  const imageCount: number = new DataView(arrayBuffer).getUint16(0x00);

  const data: DataView = new DataView(arrayBuffer, 2, imageCount * 10);

  // calculate image ids, offsets and dimensions
  // each image header is stored as a 10 byte chunk
  // only store unique images (1204 and 1183 are duplicated)
  for (let offset = 0; offset < imageCount * 10; offset += 10) {
    const idx = data.getUint16(offset) - 1000;
    const id: number = data.getUint16(offset);
    const start: number = data.getUint32(offset + 2);
    const height: number = data.getUint16(offset + 6);
    const width: number = data.getUint16(offset + 8);
    let next: number;

    // use the offset start of the next frame to determine the end of this frame
    if (offset + 10 <= data.byteLength - 2) {
      next = data.getUint16(offset + 10) - 1000;
    }

    tiles.data[idx].header = {
      id,
      start,
      height,
      width,
      next,
    };
  }

  // calculate image ending offset
  // separate loop so we can easily get the end byte of the following frame
  for (let i = 1; i < tiles.data.length; i++) {
    const tile: any = tiles.data[i];

    tile.header.imageName = `${tile.id + 1000}`;
    tile.header.end = tile.header.next ? tiles.data[tile.header.next].header.start : data.buffer.byteLength;
    tile.header.size = tile.header.end - tile.header.start;
    tile.header.data = new DataView(data.buffer.slice(tile.header.start, tile.header.end));
    tile.header.block = parseBlock(tile.header);

    tile.loaded = false;
    tile.animated = isAnimatedImage(tile.header.block);
    tile.frames = tile.frames ?? getFrameCount(tile.header);
    tile.width = tile.header.width;
    tile.height = tile.header.height;
    tile.rotate = tile.rotate ?? [i, i, i, i];
    tile.hitbox = shape(tile.hitbox ?? tile.heightmap ?? tiles.data[256].heightmap);

    tile.textures = [];

    for (let t = 0; t < tile.frames; t++) {
      tile.textures.push(`${tile.id + 1000}_${t}`);
    }
  }

  createTexture();

  // remove raw data from tiles object
  for (let i = 1; i < tiles.data.length; i++) {
    delete tiles.data[i].header;
    delete tiles.data[i].loaded;
  }
}
