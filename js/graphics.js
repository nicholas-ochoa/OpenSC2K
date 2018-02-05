game.graphics = {
  tilePath: 'images/tiles/',
  imageFormat: 'png',

  primaryCanvas: undefined,
  primaryContext: undefined,

  interfaceCanvas: undefined,
  interfaceContext: undefined,

  tilemap: {},
  tilemapImages: {},
  totalTilemaps: 4,
  loadedTilemaps: 0,
  ready: false,

  drawFrame: true, // if true a frame draw occurs
  animationFrame: 0, //frame number
  animationFrameRate: 500, // ms between each frame
  maxAnimationFrames: 512,
  currentFrame: 0,

  tileHeight: 32,
  tileWidth: 64,
  layerOffset: 24,

  scale: 1,

  tileCache: {},
  vectorTileCache: {},
  transformedTileCache: {},

  clipOffset: {
    top: 50,
    right: -100,
    bottom: -200,
    left: -100
  },

  clipBoundary: {
    top: 0,
    right: 0,
    bottom: 0,
    left: 0
  },



  //
  // create the initial rendering canvas for primary and interface components
  //
  createRenderingCanvas: function() {
    this.primaryCanvas = document.querySelectorAll('#primaryCanvas');
    this.primaryContext = this.primaryCanvas[0].getContext('2d');

    this.interfaceCanvas = document.querySelectorAll('#interfaceCanvas');
    this.interfaceContext = this.interfaceCanvas[0].getContext('2d');

    this.scaledInterfaceCanvas = document.querySelectorAll('#interfaceCanvas');
    this.scaledInterfaceContext = this.interfaceCanvas[0].getContext('2d');

    // set initial properties
    var width = document.documentElement.clientWidth;
    var height = document.documentElement.clientHeight;

    this.primaryContext.canvas.width  = width;
    this.primaryContext.canvas.height = height;

    this.interfaceContext.canvas.width  = width;
    this.interfaceContext.canvas.height = height;

    this.scaledInterfaceContext.canvas.width  = width;
    this.scaledInterfaceContext.canvas.height = height;

    this.primaryContext.imageSmoothingEnabled = false;
    this.interfaceContext.imageSmoothingEnabled = false;
    this.scaledInterfaceContext.imageSmoothingEnabled = false;

    this.loadTilemaps();
  },

  //
  // initial loading message while images and resources load
  //
  loadingMessage: function() {
    this.interfaceContext.font = '24px Verdana';
    this.interfaceContext.fillStyle = 'rgba(255, 255, 255, 1)';
    this.interfaceContext.textAlign = 'center';
    this.interfaceContext.fillText('Loading resources..', document.documentElement.clientWidth / 2, document.documentElement.clientHeight / 2);
    this.interfaceContext.textAlign = 'left';
  },


  //
  // checks whether the tilemap images are loaded
  //
  checkLoad: function(){
    if (this.totalTilemaps === this.loadedTilemaps)
      this.ready = true;
    else
      this.ready = false;

    if (this.ready)
      console.log('Tilemaps Loaded');
  },


  //
  // loads the tilemaps into memory
  //
  loadTilemaps: function() {
    console.log('Loading Tilemaps..');

    var tilemapJson = game.fs.readFileSync(__dirname + '/images/tilemap/tilemap.json');
    this.tilemap = JSON.parse(tilemapJson);

    for (i = 0; i < this.totalTilemaps; i++){
      var img = new Image();
      img.src = 'images/tilemap/tilemap_'+i+'.png';
      img.setAttribute('tilemap_id', i);
      img.onload = function(){
        var tilemapId = this.getAttribute('tilemap_id');
        var canvas = document.createElement('canvas');
        canvas.width = this.width;
        canvas.height = this.height;
        var context = canvas.getContext('2d');
        context.drawImage(this, 0, 0);
        game.graphics.tilemapImages[tilemapId] = canvas;
        game.graphics.loadedTilemaps++;
        console.log(' - tilemap_'+tilemapId+'.png loaded');
        game.graphics.checkLoad();
      }
    }
  },


  //
  // called on page load, resize events
  // updates the canvas width and height
  // updates the camera clipping bounds
  // updates all map cell coordinates
  // sets the game origin X/Y coordinates
  //
  updateCanvasSize: function() {
    this.drawFrame = true;
    
    var width = document.documentElement.clientWidth;
    var height = document.documentElement.clientHeight;

    this.primaryCanvas.width  = width;
    this.primaryCanvas.height = height;

    this.interfaceCanvas.width  = width;
    this.interfaceCanvas.height = height;

    game.originX = (width / 2 - game.tilesX * this.tileWidth / 2) + game.ui.cameraOffsetX;
    game.originY = (height / 2) + game.ui.cameraOffsetY;

    for(var tX = (game.tilesX - 1); tX >= 0; tX--)
      for(var tY = 0; tY < game.tilesY; tY++)
        game.data.map[tX][tY].coordinates = this.getCoordinates(game.data.map[tX][tY]);

    // set viewport clipping boundary
    this.clipBoundary = {
      top: 0 + (this.clipOffset.top + game.debug.clipOffset),
      right: 0 + this.primaryContext.canvas.width - (this.clipOffset.right + game.debug.clipOffset),
      bottom: 0 + this.primaryContext.canvas.height - (this.clipOffset.bottom + game.debug.clipOffset),
      left: 0 + (this.clipOffset.left + game.debug.clipOffset)
    };
  },



  setScale: function(scale) {
    this.scale = scale;

    this.primaryContext.scale(this.scale, this.scale);
    this.scaledInterfaceContext.scale(this.scale, this.scale);
  },




  //
  // calculate cell coordinates during tile load
  // used for positioning tiles when drawing to the canvas
  //
  getCoordinates: function(cell){
    // originally cell.width, needed?
    var cellWidth = 1;

    var offX = cell.x * this.tileWidth / 2 + cell.y * this.tileWidth / 2 + game.originX;
    var offY = cell.y * this.tileHeight / 2 - cell.x * this.tileHeight / 2 + game.originY;

    if (cell.z > 1)
      offY = offY - (game.layerOffset * cell.z) + game.layerOffset;

    var topX = offX + this.tileWidth / 2;
    var topY = offY + this.tileHeight - ((this.tileHeight) * cellWidth);

    var rightX = offX + (this.tileWidth / 2) + ((this.tileWidth / 2) * cellWidth);
    var rightY = offY + this.tileHeight - ((this.tileHeight / 2) * cellWidth);

    var bottomX = (offX + this.tileWidth / 2);
    var bottomY = (offY + this.tileHeight);

    var leftX = offX + (this.tileWidth / 2) - ((this.tileWidth / 2) * cellWidth);
    var leftY = offY + this.tileHeight - ((this.tileHeight / 2) * cellWidth);

    var centerX = leftX + ((rightX - leftX) / 2);
    var centerY = topY - ((topY - bottomY) / 2);

    var polygon = new Array;
    polygon.push({ x: topX, y: topY });
    polygon.push({ x: rightX, y: rightY });
    polygon.push({ x: rightX, y: rightY + game.layerOffset });
    polygon.push({ x: bottomX, y: bottomY + game.layerOffset });
    polygon.push({ x: leftX, y: leftY + game.layerOffset });
    polygon.push({ x: leftX, y: leftY });
    polygon.push({ x: topX, y: topY });

    var coordinates = {
      top: { x: topX, y: topY },
      right: { x: rightX, y: rightY },
      bottom: { x: bottomX, y: bottomY },
      left: { x: leftX, y: leftY },
      center: { x: centerX, y: centerY },
      polygon: polygon
    };

    return coordinates;
  },



  //
  // game animation loop
  // every 500ms (this.animationFrameRate), this increases the frame counter by 1
  // sets draw frame to true to force an update
  //
  animationFrames: function() {
    this.animationFrame--;

    if (this.animationFrame < 0)
      this.animationFrame = this.maxAnimationFrames;

    self = this;

    game.graphics.drawFrame = true;

    setTimeout(function(){
      self.animationFrames();
    }, this.animationFrameRate);
  },


  //
  // sets draw frame to false at the end of a draw frame
  //
  loopEnd: function() {
    this.drawFrame = false;
  },


  //
  // set draw frame to true to force update of primary canvas
  //
  setDrawFrame: function() {
    this.drawFrame = true;
  },


  //
  // clears the interface canvas every tick
  // clears the primary canvas once per draw frame
  //
  clearCanvas: function() {
    var width = document.documentElement.clientWidth;
    var height = document.documentElement.clientHeight;
    
    this.interfaceContext.clearRect(0, 0, width, height);
    this.scaledInterfaceContext.clearRect(0, 0, width, height);
    
    if (this.drawFrame)
      this.primaryContext.clearRect(0, 0, width, height);
  },


  //
  // calculates if the provided cell object exists within the camera clipping boundary
  //
  isCellInsideClipBoundary: function(cell) {
    if (cell.coordinates.center.x < this.clipBoundary.left || cell.coordinates.center.x > this.clipBoundary.right)
      return false;

    if (cell.coordinates.center.y < this.clipBoundary.top || cell.coordinates.center.y > this.clipBoundary.bottom)
      return false;

    return true;
  },


  //
  // calculates if the provided x/y coordinates are within the camera clipping boundary
  //
  isInsideClipBoundary: function(x, y) {
    if (x < this.clipBoundary.left - (this.tileHeight * 4) || x > this.clipBoundary.right + (this.tileHeight * 3))
      return false;

    if (y < this.clipBoundary.top - (this.tileWidth) || y > this.clipBoundary.bottom + (this.tileWidth * 3))
      return false;

    return true;
  },


  //
  // returns true if the tile should be flipped horizontally (mirrored)
  // based on the tile object, cell object, current map rotation and original city rotation
  // todo: needs work, does not work as expected
  //
  flipTile: function(tile, cell) {
    if (tile.id > 110) //256
      return false;

    if (tile.flip_h == 'N')
      return;

    if (game.data.cityRotation == 0) {

      if ([0,2].includes(game.mapRotation))
        if (cell.rotate == 'Y')
          return false;
        else
          return true;

      if ([1,3].includes(game.mapRotation))
        if (cell.rotate == 'Y')
          return false;
        else
          return true;

    } else if (game.data.cityRotation == 1) {

      if ([0,2].includes(game.mapRotation))
        if (cell.rotate == 'Y')
          return false;
        else
          return true;

      if ([1,3].includes(game.mapRotation))
        if (cell.rotate == 'Y')
          return false;
        else
          return true;



    } else if (game.data.cityRotation == 2) {

      if ([0,2].includes(game.mapRotation))
        if (cell.rotate == 'Y')
          return false;
        else
          return true;

      if ([1,3].includes(game.mapRotation))
        if (cell.rotate == 'Y')
          return false;
        else
          return true;



    } else if (game.data.cityRotation == 3) {

      if ([0,2].includes(game.mapRotation))
        if (cell.rotate == 'Y')
          return false;
        else
          return true;

      if ([1,3].includes(game.mapRotation))
        if (cell.rotate == 'Y')
          return false;
        else
          return true;

    }

    return false;
  },



  //
  // returns the current animation frame for a given tile object
  //
  getFrame: function(tile) {
    if (tile.frames == 0)
      return 0;
    
    return this.animationFrame - Math.floor(this.animationFrame / tile.frames) * tile.frames;
  },


  //
  // returns the appropriate tile for the current map rotation
  //
  getTile: function(tileId, cell = null) {
    let tile = game.data.tiles[tileId];
    let rotation = game.mapRotation;

    if (tile.flip_alt_tile == 'Y' && cell !== null){
      if ([0,2].includes(rotation) && this.flipTile(tile, cell)){

        if (rotation < 3)
          rotation++
        else
          rotation = 0;

      } else if ([1,3].includes(rotation) && !this.flipTile(tile, cell)) {
        if (rotation < 3)
          rotation++
        else
          rotation = 0;

      } else if ([1,3].includes(rotation) && this.flipTile(tile, cell)) {
        if (rotation < 3)
          rotation++
        else
          rotation = 0;
      }
    }

    switch (rotation) {
      case 0:
        tile = game.data.tiles[tile.rotate_0];
        break;
      case 1:
        tile = game.data.tiles[tile.rotate_1];
        break;
      case 2:
        tile = game.data.tiles[tile.rotate_2];
        break;
      case 3:
        tile = game.data.tiles[tile.rotate_3];
        break;
    }

    return tile;
  },


  //
  // draws a tile from the tilemap to the primary canvas
  //
  drawTile: function(tileId, cell, topOffset = 0, heightMap = false) {
    // only do work if we're within the current draw frame
    if (!this.drawFrame)
      return;

    let x = cell.coordinates.bottom.x;
    let y = cell.coordinates.bottom.y;

    if (!this.isInsideClipBoundary(x, y))
      return;

    // get tile ID, look up tilemap position
    let tile = this.getTile(tileId, cell);
    let tilemapId = tile.id;

    // debug toggle for animated tiles
    if (game.debug.hideAnimatedTiles && tile.frames > 0)
      return;

    // do we need the mirrored tile?
    if (this.flipTile(tile, cell) && !heightMap)
      tilemapId = tilemapId+'_H';

    // get tile frame sequence
    let frame = this.getFrame(tile);

    if (heightMap && cell.water_level == 'dry')
      tilemapId = tilemapId+'_VT_'+cell.z;
    else if (heightMap && cell.water_level != 'dry')
      tilemapId = tilemapId+'_VW_'+cell.z;
    else
      tilemapId = tilemapId+'_'+frame;

    let tilemap = this.tilemap[tilemapId];

    if (tilemap === undefined){
    //  console.log(tilemapId);
    //  console.log(cell);
      return;
    }

    // bitwise shift to round
    x = x - (tilemap.w / 2) << 0;
    y = y - (tilemap.h) - topOffset << 0;

    this.primaryContext.drawImage(this.tilemapImages[tilemap.t], tilemap.x, tilemap.y, tilemap.w, tilemap.h, x, y, tilemap.w, tilemap.h);
  },


  //
  // draws a "vector" based tile
  // todo: needs work, vector tiles are now pre-generated and included on tilemaps
  //
  drawVectorTile: function (tileId, fillColor, strokeColor, innerStrokeColor, offsetX, offsetY, renderingArea) {
    var renderingArea = typeof renderingArea !== 'undefined' ? renderingArea : this.interfaceContext;
    var cacheId = tileId + fillColor + strokeColor + innerStrokeColor;

    if (typeof this.vectorTileCache[cacheId] !== 'undefined') {
      var cachedImage = this.vectorTileCache[cacheId];
      renderingArea.drawImage(cachedImage, offsetX - 64, offsetY - 64);
      return;
    }

    var tile = game.data.tiles[tileId];

    var cacheCanvas = document.createElement('canvas');
    var cacheContext = cacheCanvas.getContext('2d');
    cacheContext.canvas.width = 128;
    cacheContext.canvas.height = 128;

    if (tile.hasOwnProperty('polygon'))
      if (tile.polygon !== '')
        this.drawPoly(tile.polygon, fillColor, strokeColor, 64, 64, 2, cacheContext);

    if (tile.hasOwnProperty('lines'))
      if (tile.lines !== '')
        this.drawLines(tile.lines, innerStrokeColor, 64, 64, cacheContext);

    this.vectorTileCache[cacheId] = cacheCanvas;
    renderingArea.drawImage(cacheCanvas, offsetX - 64, offsetY - 64);
  },


  //
  // calculate distance in pixels between two sets of x/y coordinates
  //
  distanceBetweenPoints: function(x1, y1, x2, y2) {
    return distance = Math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
  },


  //
  // returns true if a given x/y coordinate pair exists within the bounds of the provided polygon object
  //
  isPointInPolygon: function(x, y, polygon) {
    var p = { x: x, y: y };
    var isInside = false;
    var minX = polygon[0].x, maxX = polygon[0].x;
    var minY = polygon[0].y, maxY = polygon[0].y;

    for (var n = 1; n < polygon.length; n++) {
      var q = polygon[n];
      minX = Math.min(q.x, minX);
      maxX = Math.max(q.x, maxX);
      minY = Math.min(q.y, minY);
      maxY = Math.max(q.y, maxY);
    }

    if (p.x < minX || p.x > maxX || p.y < minY || p.y > maxY) {
      return false;
    }

    var i = 0, j = polygon.length - 1;
    for (i, j; i < polygon.length; j = i++) {
      if ( (polygon[i].y > p.y) != (polygon[j].y > p.y) &&
        p.x < (polygon[j].x - polygon[i].x) * (p.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x ) {
        isInside = !isInside;
      }
    }

    return isInside;
  },



  //
  // draws a vector polygon
  // todo: normalize the input params offsetX/offsetY
  //
  drawPoly: function(polygon, fillColor, strokeColor, offsetX, offsetY, width, renderingArea) {
    if (polygon == null)
      return;

    var renderingArea = typeof renderingArea !== 'undefined' ? renderingArea : this.interfaceContext;
    var fillColor = typeof fillColor !== 'undefined' ? fillColor : 'rgba(255, 0, 0, .25)';
    var strokeColor = typeof strokeColor !== 'undefined' ? strokeColor : 'rgba(255, 0, 0, .9)';
    var width = typeof width !== 'undefined' ? width : 1;
    var offsetX = typeof offsetX !== 'undefined' ? offsetX : 0;
    var offsetY = typeof offsetY !== 'undefined' ? offsetY : 0;

    renderingArea.fillStyle = fillColor;
    renderingArea.strokeStyle = strokeColor;
    renderingArea.lineWidth = width;
    renderingArea.beginPath();
    renderingArea.moveTo(Math.floor(polygon[0].x + offsetX), Math.floor(polygon[0].y + offsetY));

    for (var i = 1; i < polygon.length; i++)
      renderingArea.lineTo(Math.floor(polygon[i].x + offsetX), Math.floor(polygon[i].y + offsetY));

    renderingArea.stroke();
    renderingArea.fill();
    renderingArea.closePath();
  },



  //
  // draws a vector line
  // todo: normalize the input params offsetX/offsetY
  //
  drawLine: function(x1, y1, x2, y2, color, width, renderingArea) {
    var renderingArea = typeof renderingArea !== 'undefined' ? renderingArea : this.interfaceContext;
    var width = typeof width !== 'undefined' ? width : 1;
    var color = typeof color !== 'undefined' ? color : 'white';

    renderingArea.strokeStyle = color;
    renderingArea.lineWidth = width;
    renderingArea.beginPath();
    renderingArea.moveTo(Math.floor(x1), Math.floor(y1));
    renderingArea.lineTo(Math.floor(x2), Math.floor(y2));
    renderingArea.stroke();
    renderingArea.closePath();
  },



  //
  // draws an array of vector lines
  // todo: normalize the input params offsetX/offsetY
  //
  drawLines: function(lines, strokeColor, offsetX, offsetY, renderingArea) {
    if (lines == null)
      return;

    var renderingArea = typeof renderingArea !== 'undefined' ? renderingArea : this.interfaceContext;
    var strokeColor = typeof strokeColor !== 'undefined' ? strokeColor : 'rgba(255, 0, 0, .9)';
    var width = typeof width !== 'undefined' ? width : 1;
    var offsetX = typeof offsetX !== 'undefined' ? offsetX : 0;
    var offsetY = typeof offsetY !== 'undefined' ? offsetY : 0;

    for (var i = 0; i < lines.length; i++)
      this.drawLine(lines[i].x1 + offsetX, lines[i].y1 + offsetY, lines[i].x2 + offsetX, lines[i].y2 + offsetY, strokeColor, width, renderingArea);
  },


};