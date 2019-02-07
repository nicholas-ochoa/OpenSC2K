import Phaser from 'phaser';
import data from './tiles';
import * as CONST from '../constants';
import { polygonUnion } from '../utils';

export default class artwork {
  constructor (options) {
    this.scene       = options.scene;
    this.data        = this.scene.cache.binary.get(CONST.LARGE_DAT);
    this.palette     = this.scene.palette;
    this.tiles       = data;
    this.textureSize = 4096;
    this.texture     = this.scene.textures.createCanvas('temp', this.textureSize, this.textureSize);
    this.json        = {};
    this.canvas      = null;

    this.polygonUnion = polygonUnion;

    this.parse();
    this.createTexture();
  }


  //
  // parse dat file into raw image data for each frame
  //
  parse () {
    let view       = new DataView(this.data);
    let imageCount = view.getUint16(0x00);
    let img        = new DataView(this.data, 2, imageCount * 10);

    // calculate image ids, offsets and dimensions
    // each image header is stored as a 10 byte chunk
    // only store unique images (1204 and 1183 are duplicated)
    for (let offset = 0; offset < imageCount * 10; offset += 10) {
      let id = img.getUint16(offset) - 1000;
      let data = {};

      data.imageName  = img.getUint16(offset);
      data.startBytes = img.getUint32(offset + 2);
      data.height     = img.getUint16(offset + 6);
      data.width      = img.getUint16(offset + 8);

      // use the offset start of the next frame to determine the end of this frame
      if (offset + 10 <= img.byteLength - 2)
        data.nextId = img.getUint16(offset + 10) - 1000;

      this.tiles[id].data = data;
    }

    // calculate image ending offset
    // separate loop so we can easily get the end byte of the following frame
    for (let i = 1; i < this.tiles.length; i++) {
      let tile = this.tiles[i];

      // image block data
      tile.data.endBytes = (tile.data.nextId !== undefined ? this.tiles[tile.data.nextId].data.startBytes : this.data.byteLength);
      tile.data.size     = tile.data.endBytes - tile.data.startBytes;
      tile.data.rawData  = new DataView(this.data.slice(tile.data.startBytes, tile.data.endBytes));
      tile.data.block    = this.block(tile.data);

      tile.loaded   = false;
      tile.animated = this.isAnimatedImage(tile.data.block);
      tile.frames   = tile.frames || this.getFrameCount(tile.data);
      tile.width    = tile.data.width * CONST.SCALE;
      tile.height   = tile.data.height * CONST.SCALE;
      tile.rotate   = tile.rotate || [tile.id, tile.id, tile.id, tile.id];
      tile.hitbox   = this.shape(tile.hitbox || tile.heightmap || this.tiles[256].heightmap);

      tile.textures = [];
      
      for (let t = 0; t <= tile.frames; t++)
        tile.textures.push(tile.image+'_'+t);

      this.tiles[i] = tile;
    }

    delete this.tiles[0];
  }


  //
  // converts x/y data array to a Phaser polygon
  //
  shape (hitbox) {
    let polygon = [];

    if (hitbox.reference)
      hitbox = this.tiles[hitbox.reference].hitbox || this.tiles[hitbox.reference].heightmap;

    if (hitbox instanceof Phaser.Geom.Polygon)
      hitbox = { upper: hitbox.points };

    // merge all sides of the shape into a single array of points
    let shape = [].concat(
      (hitbox.lower         ? hitbox.lower         : []),
      (hitbox.upper         ? hitbox.upper         : []),
      (hitbox.south         ? hitbox.south         : []),
      (hitbox.east          ? hitbox.east          : []),
      (hitbox.west          ? hitbox.west          : []),
      (hitbox.southEast     ? hitbox.southEast     : []),
      (hitbox.southWest     ? hitbox.southWest     : []),
      (hitbox.northEast     ? hitbox.northEast     : []),
      (hitbox.northWest     ? hitbox.northWest     : []),
      (hitbox.rockTop       ? hitbox.rockTop       : []),
      (hitbox.rockSouthWest ? hitbox.rockSouthWest : []),
      (hitbox.rockSouthEast ? hitbox.rockSouthEast : []),
    );

    // combine into a single polygon with an exterior wall
    shape = polygonUnion(shape, shape);

    for (let i = 0; i < shape.length; i++)
      polygon.push(new Phaser.Geom.Point((shape[i].x), (shape[i].y)));

    return new Phaser.Geom.Polygon(polygon);
  }



  //
  // get the lowest common multiplier for all palette animation sequences
  //
  getFrameCount (image) {
    let frames = [];

    for (let y = 0; y < image.block.length; y++)
      for (let x = 0; x < image.block[y].pixels.length; x++)
        frames.push(this.palette.getFrameCountFromIndex(image.block[y].pixels[x]));

    if (frames.length <= 1)
      return 1;
    else
      return this.lcm.apply(null, frames);
  }


  //
  // check if image contains any palette indexes that cycle with each frame (animated)
  //
  isAnimatedImage (image) {
    for (var y = 0; y < image.length; y++)
      for (var x = 0; x < image[y].pixels.length; x++)
        if (this.palette.animatedIndexes.includes(image[y].pixels[x]))
          return true;

    return false;
  }


  //
  // processes image bytes into individual image data rows / chunks
  //
  block (image) {
    let offset = 0;
    let img    = [];

    while (offset <= image.size) {
      let row = {};

      row.length = image.rawData.getUint8(offset);
      row.more   = image.rawData.getUint8(offset + 1);

      offset += 2;
      row.pixels = this.imageRow(image.rawData.buffer.slice(offset, offset + row.length));

      img.push(row);

      if (row.more == 2)
        break;

      offset += row.length;
    }

    return img;
  }


  //
  // process image rows / chunks
  //
  imageRow (data) {
    let bytes   = new DataView(data);
    let padding = 0;
    let length  = 0;
    let extra   = 0;
    let pixels  = null;
    let mode    = null;
    let image   = [];
    let offset  = 0;
    let header  = 0;

    if (bytes.byteLength == 0)
      return image;

    // loop through the row chunks
    while (offset < bytes.byteLength - 1) {
      // special case for multi-chunk rows, drop first byte if zero
      if (bytes.getUint8(offset + 0x00) == 0x00 && offset > 0)
        offset++;

      // get chunk mode
      mode = bytes.getUint8(offset + 0x01);

      if (mode == 0x00 || mode == 0x03) {
        padding = bytes.getUint8(offset + 0x00); // padding pixels from the left edge
        length  = bytes.getUint8(offset + 0x02); // pixels in the row to draw
        extra   = bytes.getUint8(offset + 0x03); // extra bit / flag

        if (length == 0 && extra == 0x00) {
          header = 0x06;
          length = bytes.getUint8(offset + 0x04);
          extra  = bytes.getUint8(offset + 0x05);
          pixels = new DataView(bytes.buffer.slice(offset + header, offset + header + length));
        } else {
          header = 0x04;
          pixels = new DataView(bytes.buffer.slice(offset + header, offset + header + length));
        }

      } else if (mode == 0x04) {
        header = 0x02;
        length = bytes.getUint8(offset + 0x00);
        pixels = new DataView(bytes.buffer.slice(offset + header, offset + header + length));
      }

      // byte offset for the next loop
      offset += header + length;

      // save padding pixels (transparent) as null
      for (let i = 0; i < padding; i++)
        image.push(null);

      // save pixel data afterwards
      for (let i = 0; i < pixels.byteLength; i++)
        image.push(pixels.getUint8(i));
    }

    return image;
  }


  createTexture () {
    let x           = 1;
    let y           = 1;
    let maxWidth    = 16;
    let maxHeight   = 8;
    let rowMaxY     = 0;
    let padding     = 1;
    let imageData   = this.texture.getData(0, 0, this.textureSize, this.textureSize);
    let buffer      = new ArrayBuffer(imageData.data.length);
    let buffer8     = new Uint8ClampedArray(buffer);
    let buffer32    = new Uint32Array(buffer);


    // looping 128 times here to sort tiles by size
    // this shuffles the smaller tiles to the front of the tilemap
    for (let loop = 0; loop < 128; loop++) {
      // loop for each tile
      for (let i = 1; i < this.tiles.length; i++) {
        let tile = this.tiles[i];

        // skip tiles that were already flagged as loaded
        if (tile.loaded) continue;

        // skip anything that exceeds the current maximum
        if (tile.data.width > maxWidth || tile.data.height > maxHeight) continue;

        // loop on every frame
        for (let f = 0; f < tile.frames; f++) {
          // max tile height in this row
          if (tile.data.height > rowMaxY)
            rowMaxY = tile.data.height;

          // exceeds tilemap width, start a new row
          if (x + tile.data.width > this.textureSize) {
            x = 1;
            y += rowMaxY + padding;
            rowMaxY = 0;
          }

          // drop any colors?
          // used to foribly remove certain palette indexes
          // from tiles (example: traffic tiles)
          if (tile.importOptions && tile.importOptions.dropColor)
            tile.importOptions.dropColor.forEach((index, i) => {
              if (Number.isInteger(index))
                tile.importOptions.dropColor[i] = this.palette.getColorString(index, 0);
            });

          for (let ty = 0; ty < tile.data.block.length; ty++) {
            for (let tx = 0; tx < tile.data.block[ty].pixels.length; tx++) {
              // palette index value
              let index = tile.data.block[ty].pixels[tx];

              // drop out specific palette colors and transparency
              if (tile.importOptions && tile.importOptions.dropColor && tile.importOptions.dropColor.includes(this.palette.getColorString(index, f)))
                index = null;

              // set color and canvas x/y index
              let color = this.palette.getColor(index, f);
              let cx = x + tx;
              let cy = y + ty;
              let idx = cy * this.textureSize + cx;

              buffer32[idx] = (color.alpha << 24) | (color.blue << 16) | (color.green << 8) | (color.red << 0);
            }
          }

          // add tilemap data
          this.json[tile.data.imageName + '_' + f] = {
            frame: { x: x, y: y, w: tile.data.width, h: tile.data.height },
            rotated: false,
            trimmed: false,
            spriteSourceSize: { x: 0, y: 0, w: tile.data.width, h: tile.data.height },
            sourceSize: { w: tile.data.width, h: tile.data.height }
          };

          // move drawing position + padding
          x += tile.data.width + padding;
          
          // flag tile as loaded if the frame count matches the current frame
          // or if the tile has no frames
          if (tile.frames == f + 1 || tile.frames == 1)
            tile.loaded = true;
        }
      }

      // increase tile size next loop
      maxWidth = maxWidth + 4;
      maxHeight = maxHeight + 4;
    }

    // save buffer to texture and wrap json object
    imageData.data.set(buffer8);
    this.texture.putData(imageData, 0, 0);
    this.texture.refresh();
    this.canvas = this.texture.getCanvas();
    this.json = { frames: this.json };


    // load texture atlas
    this.scene.textures.addAtlas(CONST.TILE_ATLAS, this.canvas, this.json);


    // remove temp canvas
    this.scene.textures.remove('temp');


    // add animations
    for (let i = 1; i < this.tiles.length; i++) {
      let tile = this.tiles[i];

      // set up animations
      if (tile.frames > 1) {
        this.scene.anims.create({
          key: tile.data.imageName,
          frames: this.scene.anims.generateFrameNames(CONST.TILE_ATLAS, {
            prefix: tile.data.imageName + '_',
            start: (tile.reverseAnimation ? tile.frames : 0),
            end: (tile.reverseAnimation ? 0 : tile.frames)
          }),
          repeat: -1,
          frameRate: tile.frameRate || 2,
          delay: tile.animationDelay || 0
        });

        this.scene.anims.create({
          key: tile.data.imageName+'_R',
          frames: this.scene.anims.generateFrameNames(CONST.TILE_ATLAS, {
            prefix: tile.data.imageName + '_',
            start: (tile.reverseAnimation ? 0 : tile.frames),
            end: (tile.reverseAnimation ? tile.frames : 0)
          }),
          repeat: -1,
          frameRate: tile.frameRate || 2,
          delay: tile.animationDelay || 0
        });
      }

      this.tiles[i] = tile;
    }
  }


  lcm (min, max) {
    function range (min, max) {
      let out = [];
  
      for (let i = min; i <= max; i++)
        out.push(i);

      return out;
    }

    function gcd (a, b) {
      return !b ? a : gcd(b, a % b);
    }

    function lcm (a, b) {
      return (a * b) / gcd(a, b);
    }

    let multiple = min;

    range(min, max).forEach(function(n) {
      multiple = lcm(multiple, n);
    });

    return multiple;
  }
}