import PNGImage from 'pngjs-image';
import hex from 'crypto-js/enc-hex';
import md5 from 'crypto-js/md5';
import tileData from '../tiles/data';

class tilemap {
  constructor (options) {
    this.stack = options.stack;
    this.tiles = [];
    this.data = [];

    this.loadTiles();
  }


  //
  // add tilemap json data
  //
  addTilemapData (tileId, x, y, width, height) {
    this.data[tileId] = {
      frame: { x: x, y: y, w: width, h: height },
      rotated: false,
      trimmed: false,
      spriteSourceSize: { x: 0, y: 0, w: width, h: height },
      sourceSize: { w: width, h: height }
    };
  }


  //
  // load tile data from DB
  // creates tile image objects for each frame based on image stack data
  //
  loadTiles () {
    let tiles = tileData;

    for (let i = 0; i < tiles.length; i++) {
      let frames = [];

      for (let f = 0; f < tiles[i].frames; f++)
        frames[f] = this.stack[tiles[i].image + '_' + f].data;

      this.tiles.push({
        id:         tiles[i].id,
        type:       tiles[i].type,
        frames:     tiles[i].frames,
        imageName:  tiles[i].image,
        width:      this.stack[tiles[i].image + '_0'].width,
        height:     this.stack[tiles[i].image + '_0'].height,
        image:      frames,
        outline:    tiles[i].outline,
        loaded:     false
      });
    }

    this.createTilemap();
  }


  //
  // creates a tilemap from the extracted image file resources
  //
  createTilemap () {
    let tilemapWidth = 2048;
    let tilemapHeight = 2048;
    let tilemap = PNGImage.createImage(tilemapWidth, tilemapHeight);

    let x = 1;
    let y = 1;
    let w = 0;
    let h = 0;

    let maxWidth = 16;
    let maxHeight = 8;
    let rowMaxY = 0;

    let tileId;
    let padding = 1;


    // // draw line based tiles used for heightmaps
    // // looping 32 times to draw each layer of the heightmap
    // for (let layer = 0; layer < this.heightmap.length; layer++) {
        
    //   // loop for each tile (256 through 269 only for now)
    //   for (let i = 256; i <= 269; i++) {
    //     let tile = this.tiles[i];

    //     if (tile.polygon === null)
    //       continue;

    //     // get image dimensions
    //     w = tile.width;
    //     h = tile.height;

    //     tileId = tile.imageName + '_V_' + layer;

    //     // max tile height in this row
    //     if (h > rowMaxY)
    //       rowMaxY = h;

    //     // exceeds tilemap width, start a new row
    //     if (x + w > tilemapWidth) {
    //       y += rowMaxY + padding;
    //       rowMaxY = 0;
    //       x = 1;
    //     }

    //     // draw to canvas
    //     let tempCanvas = document.createElement('canvas');
    //     tempCanvas.width = tile.width;
    //     tempCanvas.height = tile.height;
    //     let tempCtx = tempCanvas.getContext('2d');

    //     this.drawVectorTile(tile.id, this.heightmap[layer].fill, this.heightmap[layer].stroke, this.heightmap[layer].lines, 0, 0, tempCtx);

    //     // draw actual tile first?
    //     // used to debug the vector tile shapes
    //     // drawImage(tile.image[0], x, y);

    //     // draw to canvas
    //     drawImage(tempCanvas, x, y);

    //     // add tilemap data
    //     this.addTilemapData(tileId, x, y, w, h);

    //     // move drawing position + padding
    //     x += w + padding;
    //   }
    // }

    // looping 128 times here to sort tiles by size
    // this shuffles the smaller tiles to the front of the tilemap
    for (let loop = 0; loop < 128; loop++) {

      // loop for each tile
      for (let i = 0; i < this.tiles.length; i++) {
        let tile = this.tiles[i];

        // check tile type
        if (!['building', 'power', 'road', 'rail', 'highway', 'terrain', 'water', 'zone'].includes(tile.type))
          continue;

        //'overlay', 'underground', 'subway', 'pipe', 'actor', 'sign', 'monster', 'explosion', 'fire', 'traffic'

        // skip tiles that were already flagged as loaded
        if (tile.loaded)
          continue;

        // get image dimensions
        w = tile.width;
        h = tile.height;

        // skip anything that exceeds the current maximum
        if (w > maxWidth || h > maxHeight)
          continue;

        // loop on every frame
        for (let f = 0; f < tile.frames; f++) {
          // max tile height in this row
          if (h > rowMaxY)
            rowMaxY = h;

          // exceeds tilemap width, start a new row
          if (x + w > tilemapWidth) {
            x = 1;
            y += rowMaxY + padding;
            rowMaxY = 0;
          }

          // // exceeds tilemap height, save canvas to stack and start a new tilemap canvas
          if (y + h > tilemapHeight) {
            console.log('out of bounds called');
            continue;
          }

          // draw to canvas
          let png = PNGImage.loadImageSync(tile.image[f]);
          png.getImage().bitblt(tilemap.getImage(), 0, 0, w, h, x, y);

          // add tilemap data
          this.addTilemapData(tile.imageName + '_' + f, x, y, w, h);

          // move drawing position + padding
          x += w + padding;
          
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

    tilemap.writeImageSync(__dirname+'/../../test/tilemap.png');
    console.log(this.data);
  }


  //
  // draws a "vector" tile shape to a canvas context
  //
  drawVectorTile (tileId, fillColor, strokeColor, innerStrokeColor, offsetX, offsetY, renderContext) {
    let tile = this.vectorTiles[tileId];

    let canvas = document.createElement('canvas');
    let context = canvas.getContext('2d');
    context.canvas.width = 128;
    context.canvas.height = 128;

    let offsets = 64;
    let lineWidth = 2;
    let lineWidthHalf = 1;

    offsetX = 32;

    if (tile.hasOwnProperty('polygon'))
      if (tile.polygon !== '')
        this.drawPoly(tile.polygon, context, fillColor, strokeColor, offsets, offsets, lineWidth);

    if (tile.hasOwnProperty('lines'))
      if (tile.lines !== '')
        this.drawLines(tile.lines, context, innerStrokeColor, offsets, offsets, lineWidthHalf);

    renderContext.drawImage(canvas, offsetX - offsets, offsetY - offsets);
  }


  //
  // draws a vector polygon
  //
  drawPoly (polygon, renderContext, fillColor = 'rgba(255, 0, 0, .25)', strokeColor = 'rgba(255, 0, 0, .9)', offsetX = 0, offsetY = 0, width = 1) {
    if (polygon == null)
      return;

    renderContext.fillStyle = fillColor;
    renderContext.strokeStyle = strokeColor;
    renderContext.lineWidth = width;
    renderContext.beginPath();

    let x = 0;
    let y = 0;

    x = polygon[0].x + offsetX;
    y = polygon[0].y + offsetY;
    renderContext.moveTo(x, y);

    for (let i = 1; i < polygon.length; i++) {
      x = polygon[i].x + offsetX;
      y = polygon[i].y + offsetY;
      renderContext.lineTo(x, y);
    }

    renderContext.stroke();
    renderContext.fill();
    renderContext.closePath();
  }


  //
  // draws an array of vector lines
  //
  drawLines (lines, renderContext, strokeColor = 'rgba(255, 0, 0, .9)', offsetX = 0, offsetY = 0, width = 1) {
    if (lines == null)
      return;

    for (let i = 0; i < lines.length; i++) {
      if (lines[i].alpha !== undefined) {
        strokeColor = strokeColor.replace('.5', '1');
        width = 2;
      }

      renderContext.strokeStyle = strokeColor;
      renderContext.lineWidth = width;
      renderContext.beginPath();
      renderContext.moveTo(Math.floor(lines[i].x1 + offsetX), Math.floor(lines[i].y1 + offsetY));
      renderContext.lineTo(Math.floor(lines[i].x2 + offsetX), Math.floor(lines[i].y2 + offsetY));
      renderContext.stroke();
      renderContext.closePath();
    }
  }

}

export default tilemap;