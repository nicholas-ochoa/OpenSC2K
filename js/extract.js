game.extract = {

  palette: [],
  animatedPaletteIndexes: [],
  imageStack: [],

  //
  // extract original game assets into something we can use
  //
  assets: function() {
    // parse palette BMP file
    this.parsePalette();

    // parse LARGE.DAT
    this.parseLargeDat();

    // write tiles to png on disk
    this.writeImagesToDisk();
  },




  //
  // validates the selected file header matches expected LARGE.DAT
  // todo: change from sc2 to large.dat sig
  //
  validFile: function(bytes) {
    // check IFF header
    if(bytes[0] !== 0x46 ||
       bytes[1] !== 0x4F ||
       bytes[2] !== 0x52 ||
       bytes[3] !== 0x4D) {
      return false;
    }

    // check sc2k header
    if(bytes[8] !== 0x53 ||
       bytes[9] !== 0x43 ||
       bytes[10] !== 0x44 ||
       bytes[11] !== 0x48) {
      return false;
    }

    return true;
  },






  //
  // parses the LARGE.dat
  //
  parseLargeDat: function() {
    let bytes = game.fs.readFileSync(__dirname + '/assets/LARGE.DAT');
    let fileSize = bytes.byteLength;
    let imageHeaderSize = 10;

    //todo: validate file here

    let view = new DataView(bytes.buffer);
    let imageCount = view.getUint16(0x00);
    let imageData = new DataView(bytes.buffer, 2, imageCount * imageHeaderSize);
    var offset = 0;

    var images = {};
    var imageArray = [];

    console.log('Parsing Images..');

    // calculate image ids, offsets and dimensions
    for (i = 0; i < imageCount; i++) {
      var image = {};

      image.id            = imageData.getUint16(offset);
      image.offsetBegin   = imageData.getUint32(offset + 2);
      image.height        = imageData.getUint16(offset + 6);
      image.width         = imageData.getUint16(offset + 8);

      imageArray.push(image);

      offset += 10;
    }

    // calculate image offset ends, size
    // get each image from the raw data
    imageCount = 0;

    for (i = 0; i < imageArray.length; i++) {
      // image offset ends
      if (imageArray[i+1] !== undefined)
        imageArray[i].offsetEnd = imageArray[i+1].offsetBegin - 1;
      else
        imageArray[i].offsetEnd = fileSize;

      imageArray[i].size = imageArray[i].offsetEnd - imageArray[i].offsetBegin;
      imageArray[i].data = bytes.subarray(imageArray[i].offsetBegin, imageArray[i].offsetEnd);

      // only count unique images (1204 and 1183 are duplicated)
      if (images[imageArray[i].id] === undefined)
        imageCount++;

      // save the last entry for each image id to the images object
      images[imageArray[i].id] = imageArray[i];
    }

    console.log('Completed');


    // create tile images
    console.log('Creating tile images');

    for (let imageId in images) {
      // decode image block
      images[imageId].imageBlock = this.imageBlock(images[imageId].data);

      // any animated pixels?
      images[imageId].animated = this.animatedTile(images[imageId]);

      // create tile images
      this.createTileImage(images[imageId]);
    }

    console.log('Completed');
  },






  imageBlock: function(bytes) {
    let length = 0;
    let offset = 0;
    let img = [];

    while (true) {
      let row = {};

      row.length = parseInt(bytes.subarray(offset + 0, offset + 1));
      row.more = bytes.subarray(offset + 1, offset + 2);

      offset += 2;
      
      row.data = bytes.subarray(offset, offset + row.length);
      row.parsedData = this.imageRow(row.data);

      img.push(row);

      if (row.more != 1)
        break;

      offset += row.length;
    }

    return img;
  },





  imageRow: function(bytes) {
    let data = bytes;
    let padding = 0;
    let length = 0;
    let extra = 0;
    let pixels = null;
    let count = data[0];
    let mode = data[1];
    let imageArray = [];
    let bytesParsed = 0;
    let headerLength = 0;

    // loop through the row chunks
    while (true) {
      data = data.subarray(bytesParsed);

      // special case for multi-chunk rows, drop first byte if zero
      if (data[0] == 0x00 && bytesParsed > 0)
        data = data.subarray(1);

      if (data.length <= 0)
        break;

      bytesParsed = 0;
      mode = data[1]; // read mode

      if (mode == 0 || mode == 3) {
        padding = data[0]; // padding pixels from the left edge
        length = data[2]; // pixels in the row to draw
        extra = data[3]; // extra bit / flag

        if (length == 0 && extra == 0) {
          length = data[4];
          extra = data[5];
          pixels = data.subarray(6, 6 + length);
          headerLength = 6;
        } else {
          pixels = data.subarray(4, 4 + length);
          headerLength = 4;
        }

      } else if (mode == 4) {
        length = data[0];
        pixels = data.subarray(2, 2 + length);
        headerLength = 2;
      }

      // byte offset for the next loop
      bytesParsed += headerLength + length;

      // save padding pixels (transparent) as null
      for (i = 0; i < parseInt(padding); i++)
        imageArray.push(null);

      // save pixel data afterwards
      for (i = 0; i < pixels.length; i++)
        imageArray.push(pixels[i]);

    }

    return imageArray;
  },






  createTileImage: function(image) {
    var x = 0;
    var y = 0;
    var paletteIndex = 0;
    var stack = {};
    var animations = {};
    var frameCount = 1;
    var doubleFrameCount = 0;

    if (image.animated)
      frameCount = 24;

    // loop on each frame
    for (var frame = 0; frame < frameCount; frame++) {
      var canvas = document.createElement('canvas');
      canvas.width = image.width * 2;
      canvas.height = image.height * 2;
      var context = canvas.getContext('2d');
      context.scale(2,2);

      x = 0;
      y = 0;

      // for each row
      for (var iY = 0; iY < image.imageBlock.length; iY++){
        x = 0;

        // for each pixel in a row
        for (var iX = 0; iX < image.imageBlock[iY].parsedData.length; iX++){

          // get palette index for imageblock x/y coordinate
          paletteIndex = image.imageBlock[iY].parsedData[iX];
          animations = this.animations(paletteIndex);

          // animated pixel? shift palette index by frame offset
          if (this.animatedPaletteIndexes.includes(paletteIndex)){
            for (f = 0; f < frame; f++){
              if (paletteIndex >= animations.end){
                paletteIndex = animations.start;
              }else{
                if (animations.showFramesTwice){
                  if (doubleFrameCount % 2 == 0){
                    paletteIndex += 1;
                  }

                  doubleFrameCount++;
                }else{
                  paletteIndex += 1;
                }
              }
            }
          }
            
          // palette lookup and draw pixel
          context.fillStyle = this.getColorFromPalette(paletteIndex);
          context.fillRect(x, y, 1, 1);

          x++;
        }

        y++;
      }

      // save to the image stack
      data = canvas.toDataURL();
      this.imageStack.push({ id: image.id, frame: frame, data: data });
    }
  },





  //
  // writes canvas blob to disk
  // temporary for testing, eventually will remove the need to write images to PNG files
  // and directly convert to tilemap
  // todo: utility function to support dumping images to disk for non-engine usage
  //
  writeImagesToDisk: function() {
    console.log('Writing Files');

    for (var i = 0; i < this.imageStack.length; i++) {
      let imageId = this.imageStack[i].id;
      let frameId = this.imageStack[i].frame;
      let data = this.imageStack[i].data.replace(/^data:image\/\w+;base64,/, "");
      let buffer = new Buffer(data, 'base64');

      game.fs.writeFileSync(__dirname + '/images/test/'+imageId+'_'+frameId+'.png', buffer);
    }

    console.log('Completed');
  },






  //
  // look up rgba color for a palette index
  //
  getColorFromPalette: function(idx){
    if (idx === null)
      return 'rgba(0,0,0,0)';

    return this.palette[idx];
  },



  //
  // determines the type of animation based on the palette indexes utilized in the tile
  // returns the animation details (type, frames, start index) when it finds any pixel
  // that utilizes an animated palette index
  //
  animatedTile: function (image) {
    var x = 0, y = 0;

    for (i = 0; i < image.imageBlock.length; i++){
      x = 0;

      for (p = 0; p < image.imageBlock[i].parsedData.length; p++){

        // if any animated pixels found, return true
        if (this.animatedPaletteIndexes.includes(image.imageBlock[i].parsedData[p]))
          return true;

        x++;
      }

      y++;
    }

    return false;
  },



  //
  // returns the animation details (type, frames, start index) based on palette index provided
  //
  animations: function (paletteIndex) {
    var animation = { type: null, showFramesTwice: false, frames: 24, start: 0 };

    if ([200,201,202,203,204,205,206,207,208,209,210,211].includes(paletteIndex)) {
      animation.type = 'blue';
      animation.showFramesTwice = false;
      animation.start = 200;
      animation.end = 211;

    } else if ([171,172,173,174,175,176,177,178].includes(paletteIndex)) {
      animation.type = 'grey_blue_short';
      animation.showFramesTwice = false;
      animation.start = 171;
      animation.end = 178;

    } else if ([179,180,181,182,183,184,185,186].includes(paletteIndex)) {
      animation.type = 'grey_black';
      animation.showFramesTwice = false;
      animation.start = 179;
      animation.end = 186;

    } else if ([187,188,189,190,191,192,193,194].includes(paletteIndex)) {
      animation.type = 'grey_blue_long';
      animation.showFramesTwice = false;
      animation.start = 187;
      animation.end = 194;

    } else if ([212,213,214,215,216,217,218,219].includes(paletteIndex)) {
      animation.type = 'grey_brown';
      animation.showFramesTwice = false;
      animation.start = 212;
      animation.end = 219;

    } else if ([195,196,197,198].includes(paletteIndex)) {
      animation.type = 'brown_red_yellow_black';
      animation.showFramesTwice = false;
      animation.start = 195;
      animation.end = 198;

    } else if ([224,225].includes(paletteIndex)) {
      animation.type = 'flash_red';
      animation.showFramesTwice = true;
      animation.start = 224;
      animation.end = 225;

    } else if ([226,227].includes(paletteIndex)) {
      animation.type = 'flash_yellow';
      animation.showFramesTwice = true;
      animation.start = 226;
      animation.end = 227;

    } else if ([228,229].includes(paletteIndex)) {
      animation.type = 'flash_green';
      animation.showFramesTwice = true;
      animation.start = 228;
      animation.end = 229;

    } else if ([230,231].includes(paletteIndex)) {
      animation.type = 'flash_blue';
      animation.showFramesTwice = true;
      animation.start = 230;
      animation.end = 231;
    }

    return animation;
  },





  //
  // parse sc2k BMP palette file
  //
  parsePalette: function() {
    // decode BMP file into an array of pixels (rgba)
    var bmp = require('bmp-js');
    var buffer = game.fs.readFileSync(__dirname + '/assets/PAL_MSTR.BMP');
    var data = bmp.decode(buffer);
    var width = data.width;
    var height = data.height;
    var offset = 0;
    var c = {}, paletteData = [];

    // build array of BMP image data
    for (y = 0; y < height; y++){
      for (x = 0; x < width; x++){
        c = {};

        c.b = data.data[offset + 0];
        c.g = data.data[offset + 1];
        c.r = data.data[offset + 2];
        c.a = data.data[offset + 3];

        if (paletteData[x] === undefined)
          paletteData[x] = [];

        if (paletteData[x][y] === undefined)
          paletteData[x][y] = [];

        paletteData[x][y] = c;

        // offset + 4 since we're reading 4 bytes (rgba) for each pixel
        offset += 4;

        if (data.data[offset] === undefined)
          break;
      }
    }

    // get palette colors from BMP pixel array
    var startRow = 15;
    var startColumn = 1;
    var colorWidth = 6;
    var colorHeight = 5;
    var cX, cY, color = null;

    // loop through each palette color in the source BMP and index them in order
    // left to right, top to bottom (16x16)
    for (y = 1; y <= 16; y++) {
      for (x = 1; x <= 16; x++) {
        cX = startColumn + (x * colorWidth);
        cY = startRow + (y * colorHeight);
        color = 'rgba('+paletteData[cX][cY].r+', '+paletteData[cX][cY].g+', '+paletteData[cX][cY].b+', '+paletteData[cX][cY].a+')'
        this.palette.push(color);
      }
    }

    // these palette indexes are used for the 'animations' when rotating palettes
    this.animatedPaletteIndexes = [
      200,201,202,203,204,205,206,207,208,209,210,211,171,172,
      173,174,175,176,177,178,179,180,181,182,183,184,185,186,
      187,188,189,190,191,192,193,194,212,213,214,215,216,217,
      218,219,195,196,197,198,224,225,226,227,228,229,230,231
    ];
  },














  //
  // creates a tilemap from the extracted LARGE.dat resources
  // todo: utilize LARGE.DAT extraction to avoid writing PNG files
  // todo: clean up, remove redundancy if possible
  // todo: display results in a separate window?
  // todo: interface
  //
  createTilemap: function() {
    var tilemap = {};

    var x = 0;
    var y = 0;
    var w = 0;
    var h = 0;

    var tilemapWidth = 4096;
    var tilemapHeight = 4096;

    var maxWidth = 64;
    var maxHeight = 64;
    var rowMaxY = 0;
    var canvasCount = 0;

    var tiles = game.data.tiles;
    var tileCount = tiles.length;

    var scaling = 1;
    var drawStroke = false;

    //this.primaryContext.scale(scaling,scaling);
    //this.primaryCanvas.width = tilemapWidth;
    //this.primaryCanvas.height = tilemapHeight;

    var canvas = document.createElement('canvas');
    canvas.width = tilemapWidth;
    canvas.height = this.primaryCanvas.height;
    var context = canvas.getContext('2d');

    context.strokeStyle = 'white';
    //context.fillStyle = 'blue';
    //context.fillRect(0,0,tilemapWidth,tilemapHeight);

    //this.primaryContext.drawImage(canvas, 0, 0);

    // add tilemap loaded flag
    for (i = 0; i < 500; i++) {
      tiles[i].tilemapLoaded = false;
    }

    // draw all tiles + framaes
    for (loop = 0; loop < 16; loop++) {
      for (i = 0; i < 500; i++) {
        for (f = 0; f < tiles[i].image.length; f++){

          if (tiles[i].tilemapLoaded)
            continue;
  
          w = tiles[i].image[f].width;
          h = tiles[i].image[f].height;
  
          if (w > maxWidth || h > maxHeight)
            continue;
  
          // max tile height in this row
          if (h > rowMaxY)
            rowMaxY = h;
  
          if (x + w > tilemapWidth) {
            y += rowMaxY;
            rowMaxY = 0;
            x = 0;
          }

          // flush canvas
          if (y + h > tilemapHeight) {
            //this.primaryContext.drawImage(canvas, tilemapWidth * canvasCount, 0);
            canvas.toBlob(function(blob){
              game.extract.writeTilemapToFile(blob, canvasCount);
            });
            context.clearRect(0,0,tilemapWidth,tilemapHeight);
            //context.fillStyle = 'blue';
            //context.fillRect(0,0,tilemapWidth,tilemapHeight);
            canvasCount++;
            this.tilemapCount++;
            y = 0;
            x = 0;
            rowMax = y;
          }

          context.drawImage(tiles[i].image[f], x, y);

          var tilemapId = tiles[i].id+'_'+f;
          tilemap[tilemapId] = { t: canvasCount, x: x, y: y, w: w, h: h };

          if (drawStroke){
            context.strokeStyle = 'blue';
            context.strokeRect(x, y, w, h);
          }
  
          x += w;

          if (tiles[i].frames == f + 1 || tiles[i].frames == 0)
            tiles[i].tilemapLoaded = true;
        }
      }

      maxWidth = maxWidth + 32;
      maxHeight = maxHeight + 32;
    }

    // reinitialize
    for (i = 0; i < 500; i++) {
      tiles[i].tilemapLoaded = false;
    }

    y += rowMaxY;
    maxWidth = 64;
    maxHeight = 64;
    rowMaxY = 0;

    // once again, only including tiles that are flagged to flip horizontally
    for (loop = 0; loop < 16; loop++) {
      for (i = 0; i < 500; i++) {
        for (f = 0; f < tiles[i].image.length; f++){

          if (tiles[i].flip_h != 'Y')
            continue;

          if (tiles[i].tilemapLoaded)
            continue;
  
          w = tiles[i].image[f].width;
          h = tiles[i].image[f].height;
  
          if (w > maxWidth || h > maxHeight)
            continue;
  
          // max tile height in this row
          if (h > rowMaxY)
            rowMaxY = h;
  
          if (x + w > tilemapWidth) {
            y += rowMaxY;
            rowMaxY = 0;
            x = 0;
          }

          // flush canvas
          if (y + h > tilemapHeight) {
            //this.primaryContext.drawImage(canvas, tilemapWidth * canvasCount, 0);
            canvas.toBlob(function(blob){
              game.extract.writeTilemapToFile(blob, canvasCount);
            });
            context.clearRect(0,0,tilemapWidth,tilemapHeight);
            //context.fillStyle = 'blue';
            //context.fillRect(0,0,tilemapWidth,tilemapHeight);
            canvasCount++;
            this.tilemapCount++;
            y = 0;
            x = 0;
            rowMax = y;
          }

          // flip image
          var tempCanvas = document.createElement('canvas');
          tempCanvas.width = tiles[i].image[f].width;
          tempCanvas.height = tiles[i].image[f].height;
          var tempCtx = tempCanvas.getContext('2d');
          tempCtx.scale(-1,1);
          tempCtx.translate(-tempCanvas.width - tiles[i].image[f].width, 0);
          tempCtx.drawImage(tiles[i].image[f], tempCanvas.width, 0);

          // draw to tilemap
          context.drawImage(tempCanvas, x, y);

          if (drawStroke){
            context.strokeStyle = 'green';
            context.strokeRect(x, y, w, h);
          }
  
          var tilemapId = tiles[i].id+'_H_'+f;
          tilemap[tilemapId] = { t: canvasCount, x: x, y: y, w: w, h: h };

          x += w;

          if (tiles[i].frames == f + 1 || tiles[i].frames == 0)
            tiles[i].tilemapLoaded = true;
        }
      }

      maxWidth = maxWidth + 32;
      maxHeight = maxHeight + 32;
    }



    // finally, one last round to generate all of the "vector" based tiles used for various purposes
    y += rowMaxY;
    maxWidth = 64;
    maxHeight = 64;
    rowMaxY = 0;

    for (i = 256; i < 269; i++) {
      for (p = 0; p < 32; p++) {
        if (tiles[i].polygon === null)
          continue;

        var f = 0;

        w = tiles[i].image[f].width;
        h = tiles[i].image[f].height;

        // max tile height in this row
        if (h > rowMaxY)
          rowMaxY = h;

        if (x + w > tilemapWidth / 2) {
          y += rowMaxY;
          rowMaxY = 0;
          x = 0;
        }

        // flush canvas
        if (y + h > tilemapHeight) {
          this.primaryContext.drawImage(canvas, tilemapWidth * canvasCount, 0);
          canvas.toBlob(function(blob){
            game.extract.writeTilemapToFile(blob, canvasCount);
          });
          context.clearRect(0,0,tilemapWidth,tilemapHeight);
          //context.fillStyle = 'blue';
          //context.fillRect(0,0,tilemapWidth,tilemapHeight);
          canvasCount++;
          this.tilemapCount++;
          y = 0;
          x = 0;
          rowMax = y;
        }

        var tempCanvas = document.createElement('canvas');
        tempCanvas.width = tiles[i].image[f].width;
        tempCanvas.height = tiles[i].image[f].height;
        var tempCtx = tempCanvas.getContext('2d');

        // shift id by 16 for water height map
        if (p > 15) {
          var o = p - 16;
          this.drawVectorTile(tiles[i].id, game.tiles.waterHeightMap[o].fill, game.tiles.waterHeightMap[o].stroke, game.tiles.waterHeightMap[o].lines, 0+32, 0, tempCtx);
          var tilemapId = tiles[i].id+'_VW_'+o;
        }else{
          this.drawVectorTile(tiles[i].id, game.tiles.landHeightMap[p].fill, game.tiles.landHeightMap[p].stroke, game.tiles.landHeightMap[p].lines, 0+32, 0, tempCtx);
          var tilemapId = tiles[i].id+'_VT_'+p;
        }

        // draw to tilemap
        context.drawImage(tempCanvas, x, y);

        tilemap[tilemapId] = { t: canvasCount, x: x, y: y, w: w, h: h };

        if (drawStroke){
          context.strokeStyle = 'red';
          context.strokeRect(x, y, w, h);
        }

        x += w;
      }
    }

    canvas.toBlob(function(blob){
      game.extract.writeTilemapToFile(blob, canvasCount);
    });

    //this.primaryContext.drawImage(canvas, 0, tilemapHeight);

    var tilemapString = JSON.stringify(tilemap);

    game.fs.writeFileSync(__dirname + '/images/tilemap/tilemap.json', tilemapString);
  },




  //
  // quick and dirty function to write the blob contents of the tilemap canvas to a file
  // todo: clean this up, make it generic
  //
  writeTilemapToFile: function (blob, canvasCount) {
    var c = canvasCount;
    var fileReader = new FileReader();

    fileReader.onload = function(){
      var x = 0;

      while (game.fs.existsSync(__dirname + '/images/tilemap/tilemap_'+x+'.png'))
        x++;

      console.log('Writing file: tilemap_'+x);
      game.fs.writeFileSync(__dirname + '/images/tilemap/tilemap_'+x+'.png', Buffer.from(new Uint8Array(this.result)));
    };

    fileReader.readAsArrayBuffer(blob);
  },



}