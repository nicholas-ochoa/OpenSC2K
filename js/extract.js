game.extract = {

  //
  // display file open prompt
  //
  openFile: function() {
    //let largeDatFile = '/assets/LARGE.DAT';
    //let bytes = game.fs.readFileSync(__dirname + largeDatFile);

    game.app.dialog.showOpenDialog((fileNames) => {
      if (fileNames === undefined){
        return;
      }

      game.fs.readFile(fileNames[0], (err, data) => {
        if (err) {
          console.log('Error reading file: '+err.message);
          return;
        }

        let bytes = new Uint8Array(data);
        this.parse(bytes);

      });
    });
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
  parse: function(bytes) {
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
        context.fillStyle = this.palette(pixelValue);
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
  palette: function(value){
    if (value === null)
      return 'rgba(0,0,0,0)';

    var palette = [];
    var color = 0;

    for (c = 0; c < 256; c++) {
      var rgba = {};

      rgba.r = color;
      color += 7;

      rgba.g = color;
      color += 7;

      rgba.b = color;
      color += 7;

      rgba.a = 1;

      palette[c] = rgba;
    }

    palette[0] = { r: 0, g: 0, b: 0, a: 1 };
    palette[0xA4] = { r: 103, g: 103, b: 103, a: 1 };
    palette[0xA0] = { r: 159, g: 159, b: 159, a: 1 };
    palette[0x9F] = { r: 171, g: 171, b: 171, a: 1 };
    palette[0xA1] = { r: 143, g: 143, b: 143, a: 1 };
    palette[0xFF] = { r: 255, g: 255, b: 255, a: 1 };
    palette[0x48] = { r: 7, g: 115, b: 0, a: 1 };
    palette[0x46] = { r: 7, g: 167, b: 0, a: 1 };
    palette[0x49] = { r: 7, g: 91, b: 0, a: 1 };
    palette[0x27] = { r: 175, g: 63, b: 27, a: 1 };
    palette[0x2B] = { r: 255, g: 159, b: 159, a: 1 };
    palette[0x73] = { r: 203, g: 199, b: 135, a: 1 };
    palette[0x55] = { r: 107, g: 199, b: 219, a: 1 };
    palette[0x58] = { r: 19, g: 123, b: 183, a: 1 };
    palette[0x59] = { r: 0, g: 99, b: 171, a: 1 };
    palette[0x33] = { r: 191, g: 179, b: 43, a: 1 };
    palette[0x31] = { r: 231, g: 231, b: 75, a: 1 };
    palette[0x26] = { r: 199, g: 87, b: 43, a: 1 };
    palette[0xA5] = { r: 87, g: 87, b: 87, a: 1 };
    palette[0x47] = { r: 7, g: 139, b: 0, a: 1 };
    palette[0x4A] = { r: 7, g: 67, b: 0, a: 1 };
    palette[0x4F] = { r: 0, g: 207, b: 207, a: 1 };
    palette[0x29] = { r: 127, g: 23, b: 7, a: 1 };
    palette[0x7D] = { r: 107, g: 71, b: 27, a: 1 };
    palette[0xA3] = { r: 115, g: 115, b: 115, a: 1 };
    palette[0xA8] = { r: 47, g: 47, b: 47, a: 1 };
    palette[0xA7] = { r: 59, g: 59, b: 59, a: 1 };
    palette[0x9E] = { r: 187, g: 187, b: 187, a: 1 };
    palette[0x73] = { r: 203, g: 199, b: 135, a: 1 };
    palette[0x74] = { r: 191, g: 183, b: 119, a: 1 };
    palette[0x9D] = { r: 199, g: 199, b: 199, a: 1 };
    palette[0x2E] = { r: 255, g: 67, b: 67, a: 1 };
    palette[0x2F] = { r: 255, g: 35, b: 35, a: 1 };
    palette[0x9A] = { r: 243, g: 243, b: 243, a: 1 };
    palette[0x87] = { r: 19, g: 183, b: 243, a: 1 };
    palette[0x88] = { r: 15, g: 167, b: 219, a: 1 };
    palette[0x51] = { r: 0, g: 115, b: 115, a: 1 };
    palette[0x52] = { r: 0, g: 67, b: 67, a: 1 };
    palette[0xA6] = { r: 75, g: 75, b: 75, a: 1 };
    palette[0xE0] = { r: 201, g: 2, b: 2, a: 1 };
    palette[0x8A] = { r: 27, g: 119, b: 211, a: 1 };
    palette[0x8F] = { r: 0, g: 0, b: 119, a: 1 };
    palette[0x7A] = { r: 135, g: 107, b: 51, a: 1 };
    palette[0x78] = { r: 155, g: 135, b: 71, a: 1 };
    palette[0x89] = { r: 7, g: 147, b: 215, a: 1 };
    palette[0x9B] = { r: 227, g: 227, b: 227, a: 1 };
    palette[0x76] = { r: 171, g: 159, b: 95, a: 1 };
    palette[0x7C] = { r: 115, g: 83, b: 35, a: 1 };
    palette[0x37] = { r: 111, g: 87, b: 0, a: 1 };
    palette[0xA9] = { r: 37, g: 37, b: 37, a: 1 };
    palette[0x21] = { r: 119, g: 0, b: 0, a: 1 };
    palette[0xA2] = { r: 131, g: 131, b: 131, a: 1 };
    palette[0x9C] = { r: 215, g: 215, b: 215, a: 1 };
    palette[0xAA] = { r: 19, g: 19, b: 19, a: 1 };
    palette[0x8B] = { r: 11, g: 83, b: 243, a: 1 };
    palette[0x86] = { r: 139, g: 223, b: 239, a: 1 };
    palette[0x63] = { r: 0, g: 0, b: 227, a: 1 };
    palette[0x5E] = { r: 67, g: 67, b: 255, a: 1 };
    palette[0x75] = { r: 183, g: 171, b: 107, a: 1 };
    palette[0x77] = { r: 163, g: 147, b: 83, a: 1 };
    palette[0x7B] = { r: 123, g: 95, b: 43, a: 1 };
    palette[0x80] = { r: 75, g: 39, b: 11, a: 1 };
    palette[0x82] = { r: 55, g: 23, b: 0, a: 1 };
    palette[0x79] = { r: 143, g: 119, b: 59, a: 1 };
    palette[0x34] = { r: 171, g: 155, b: 31, a: 1 };
    palette[0x3F] = { r: 99, g: 159, b: 0, a: 1 };
    palette[0x7E] = { r: 95, g: 59, b: 19, a: 1 };
    palette[0x5F] = { r: 35, g: 39, b: 255, a: 1 };
    palette[0x5D] = { r: 95, g: 99, b: 255, a: 1 };
    palette[0x64] = { r: 0, g: 0, b: 203, a: 1 };
    palette[0x67] = { r: 0, g: 0, b: 127, a: 1 };
    palette[0x69] = { r: 0, g: 0, b: 79, a: 1 };
    palette[0x62] = { r: 0, g: 0, b: 239, a: 1 };
    palette[0x65] = { r: 0, g: 0, b: 179, a: 1 };
    palette[0x1F] = { r: 171, g: 0, b: 0, a: 1 };
    palette[0x1E] = { r: 199, g: 0, b: 0, a: 1 };
    palette[0x1C] = { r: 255, g: 0, b: 0, a: 1 };
    palette[0x1D] = { r: 227, g: 0, b: 0, a: 1 };
    palette[0x20] = { r: 147, g: 0, b: 0, a: 1 };
    palette[0x22] = { r: 91, g: 0, b: 0, a: 1 };
    palette[0x60] = { r: 0, g: 7, b: 255, a: 1 };
    palette[0xCF] = { r: 73, g: 69, b: 255, a: 1 };
    palette[0xCE] = { r: 92, g: 119, b: 255, a: 1 };
    palette[0xCD] = { r: 39, g: 32, b: 255, a: 1 };
    palette[0xCC] = { r: 73, g: 69, b: 255, a: 1 };
    palette[0xCB] = { r: 92, g: 119, b: 255, a: 1 };
    palette[0xCA] = { r: 99, g: 155, b: 255, a: 1 };
    palette[0xC9] = { r: 16, g: 10, b: 255, a: 1 };
    palette[0xC8] = { r: 39, g: 32, b: 255, a: 1 };
    palette[0x2D] = { r: 255, g: 95, b: 95, a: 1 };
    palette[0x2C] = { r: 255, g: 127, b: 127, a: 1 };
    palette[0x28] = { r: 151, g: 39, b: 19, a: 1 };
    palette[0x23] = { r: 67, g: 0, b: 0, a: 1 };
    palette[0x2A] = { r: 103, g: 7, b: 0, a: 1 };
    palette[0x24] = { r: 251, g: 143, b: 75, a: 1 };
    palette[0x7F] = { r: 87, g: 51, b: 15, a: 1 };
    palette[0x81] = { r: 67, g: 31, b: 7, a: 1 };
    palette[0x83] = { r: 47, g: 15, b: 0, a: 1 };
    palette[0x30] = { r: 251, g: 255, b: 163, a: 1 };
    palette[0xE8] = { r: 0, g: 0, b: 0, a: 1 };
    palette[0x32] = { r: 211, g: 207, b: 59, a: 1 };
    palette[0x25] = { r: 223, g: 111, b: 55, a: 1 };
    palette[0x35] = { r: 151, g: 131, b: 19, a: 1 };
    palette[0x36] = { r: 131, g: 107, b: 11, a: 1 };
    palette[0x38] = { r: 91, g: 67, b: 0, a: 1 };
    palette[0x39] = { r: 199, g: 255, b: 67, a: 1 };
    palette[0x3C] = { r: 147, g: 231, b: 0, a: 1 };
    palette[0x3D] = { r: 131, g: 207, b: 0, a: 1 };
    palette[0x3E] = { r: 119, g: 183, b: 0, a: 1 };
    palette[0x43] = { r: 0, g: 239, b: 0, a: 1 };
    palette[0x44] = { r: 0, g: 215, b: 0, a: 1 };
    palette[0x45] = { r: 7, g: 191, b: 0, a: 1 };
    palette[0x41] = { r: 99, g: 255, b: 95, a: 1 };
    palette[0x40] = { r: 159, g: 255, b: 159, a: 1 };
    palette[0x8E] = { r: 0, g: 0, b: 215, a: 1 };
    palette[0x61] = { r: 0, g: 0, b: 255, a: 1 };
    palette[0xD0] = { r: 35, g: 39, b: 255, a: 1 };
    palette[0xD1] = { r: 35, g: 39, b: 255, a: 1 };
    palette[0xD2] = { r: 49, g: 62, b: 255, a: 1 };
    palette[0xD3] = { r: 35, g: 39, b: 255, a: 1 };
    palette[0x84] = { r: 39, g: 11, b: 0, a: 1 };
    palette[0x8C] = { r: 31, g: 0, b: 251, a: 1 };
    palette[0x90] = { r: 0, g: 0, b: 167, a: 1 };
    palette[0x8D] = { r: 0, g: 35, b: 247, a: 1 };
    palette[0x6D] = { r: 191, g: 67, b: 255, a: 1 };
    palette[0xC5] = { r: 64, g: 16, b: 3, a: 1 };
    palette[0xC3] = { r: 255, g: 15, b: 17, a: 1 };
    palette[0xC4] = { r: 255, g: 249, b: 6, a: 1 };
    palette[0x6B] = { r: 231, g: 187, b: 255, a: 1 };
    palette[0x6C] = { r: 211, g: 127, b: 255, a: 1 };
    palette[0x70] = { r: 99, g: 0, b: 159, a: 1 };
    palette[0x6F] = { r: 131, g: 0, b: 207, a: 1 };
    palette[0x6A] = { r: 0, g: 0, b: 67, a: 1 };
    palette[0x50] = { r: 0, g: 159, b: 159, a: 1 };
    palette[0x42] = { r: 35, g: 255, b: 35, a: 1 };
    palette[0x85] = { r: 187, g: 179, b: 135, a: 1 };
    palette[0x12] = { r: 16, g: 117, b: 101, a: 1 };
    palette[0x13] = { r: 20, g: 125, b: 109, a: 1 };
    palette[0x14] = { r: 24, g: 154, b: 134, a: 1 };
    palette[0x15] = { r: 24, g: 166, b: 142, a: 1 };
    palette[0x16] = { r: 28, g: 178, b: 154, a: 1 };
    palette[0x17] = { r: 28, g: 190, b: 166, a: 1 };
    palette[0x18] = { r: 32, g: 207, b: 178, a: 1 };
    palette[0x19] = { r: 255, g: 255, b: 255, a: 1 };
    palette[0x1A] = { r: 255, g: 85, b: 85, a: 1 };
    palette[0x1B] = { r: 255, g: 85, b: 255, a: 1 };
    palette[0x3A] = { r: 182, g: 255, b: 32, a: 1 };
    palette[0x3B] = { r: 162, g: 255, b: 0, a: 1 };
    palette[0x66] = { r: 0, g: 0, b: 154, a: 1 };
    palette[0x68] = { r: 0, g: 0, b: 89, a: 1 };

    return 'rgba('+palette[value].r+', '+palette[value].g+', '+palette[value].b+', '+palette[value].a+')';
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