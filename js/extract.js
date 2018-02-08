game.extract = {
  palette: [],

  //
  // extract original game assets into something we can use
  //
  assets: function() {
    // parse palette BMP file
    this.parsePalette();

    // parse LARGE.DAT
    this.parseLargeDat();
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

    // create tile images
    console.log('Writing Files..');
    for (let imageId in images) {
      images[imageId].imageBlock = this.imageBlock(images[imageId].data);
      this.createTileImage(imageId, images[imageId]);
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






  createTileImage: function(imageId, data) {
    var canvas = document.createElement('canvas');
    canvas.width = data.width * 2;
    canvas.height = data.height * 2;
    var context = canvas.getContext('2d');
    context.scale(2,2);

    var x = 0;
    var y = 0;

    // for each row
    for (i = 0; i < data.imageBlock.length; i++){
      x = 0;

      // for each pixel
      for (p = 0; p < data.imageBlock[i].parsedData.length; p++){
        var pixelValue = data.imageBlock[i].parsedData[p];

        var tempCanvas = document.createElement('canvas');
        tempCanvas.width = 1;
        tempCanvas.height = 1;
        var tempCtx = tempCanvas.getContext('2d');

        // palette lookup
        context.fillStyle = this.getColorFromPalette(pixelValue);
        context.fillRect(x, y, 1, 1);

        x++;
      }

      y++;
    }

    // write to primary canvas context
    //setTimeout(function(){
    //  game.graphics.primaryContext.clearRect(10, 10, canvas.width, canvas.height);
    //  game.graphics.primaryContext.strokeStyle = 'rgba(255,0,0,.5)';
    //  game.graphics.primaryContext.strokeRect(10, 10, canvas.width, canvas.height);
    //  game.graphics.primaryContext.drawImage(canvas,10,10);
    //}, 100 + this.delay);
    //this.delay += 100

    // save canvas to file
    canvas.toBlob((blob) => {
      var fileReader = new FileReader();
      
      fileReader.onload = (event) => {
        var id = imageId;
        game.extract.writeFile(id, event.target.result);
      };

      fileReader.readAsArrayBuffer(blob);
    });
  },


  //
  // writes canvas blob to disk
  // temporary for testing, eventually will remove the need to write images to PNG files
  // and directly convert to tilemap
  // todo: utility function to support dumping images to disk for non-engine usage
  //
  writeFile: function(imageId, data) {
    game.fs.writeFileSync(__dirname + '/images/test/'+imageId+'.png', Buffer.from(new Uint8Array(data)));
  },



  //
  // hardcoded palette for now, need to rework and pull these values from
  // the original game palette files to support animation
  //
  getColorFromPalette: function(value){
    if (value === null)
      return 'rgba(0,0,0,0)';

    return this.palette[value];
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

    for (y = 1; y <= 16; y++) {
      for (x = 1; x <= 16; x++) {
        cX = startColumn + (x * colorWidth);
        cY = startRow + (y * colorHeight);
        color = 'rgba('+paletteData[cX][cY].r+', '+paletteData[cX][cY].g+', '+paletteData[cX][cY].b+', '+paletteData[cX][cY].a+')'
        this.palette.push(color);
      }
    }

    return paletteData;
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