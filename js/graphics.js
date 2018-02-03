game.graphics = {

  primaryCanvas: undefined,
  primaryContext: undefined,

  interfaceCanvas: undefined,
  interfaceContext: undefined,

  animationFrame: 0, //frame number
  animationFrameRate: 500, // ms between each frame
  maxAnimationFrames: 512,
  currentFrame: 0,

  tileHeight: 32,
  tileWidth: 64,
  layerOffset: 24,

  imageFormat: 'png',

  vectorTileCache: new Object(),
  transformedTileCache: new Object(),

  clipBoundary: {
    top: 0,
    right: 0,
    bottom: 0,
    left: 0
  },


  createRenderingCanvas: function() {
    this.primaryCanvas = document.querySelectorAll('#primaryCanvas');
    this.primaryContext = this.primaryCanvas[0].getContext('2d');

    this.interfaceCanvas = document.querySelectorAll('#interfaceCanvas');
    this.interfaceContext = this.interfaceCanvas[0].getContext('2d');

    // set initial properties

    var width = document.documentElement.clientWidth;
    var height = document.documentElement.clientHeight;

    this.primaryContext.canvas.width  = width;
    this.primaryContext.canvas.height = height;

    this.interfaceContext.canvas.width  = width;
    this.interfaceContext.canvas.height = height;

    this.primaryContext.imageSmoothingEnabled = false;
    this.interfaceContext.imageSmoothingEnabled = false;
  },


  updateCanvasSize: function() {
    var width = document.documentElement.clientWidth;
    var height = document.documentElement.clientHeight;

    this.primaryContext.canvas.width  = width;
    this.primaryContext.canvas.height = height;

    this.interfaceContext.canvas.width  = width;
    this.interfaceContext.canvas.height = height;

    game.originX = (width / 2 - game.tilesX * this.tileWidth / 2) + game.ui.cameraOffsetX;
    game.originY = (height / 2) + game.ui.cameraOffsetY;

    for(var tX = (game.tilesX - 1); tX >= 0; tX--)
      for(var tY = 0; tY < game.tilesY; tY++)
        game.data.map[tX][tY].coordinates = this.getCoordinates(game.data.map[tX][tY]);

    this.clipBoundary = {
      top: 0 + game.debug.clipOffset,
      right: 0 + this.primaryContext.canvas.width - game.debug.clipOffset,
      bottom: 0 + this.primaryContext.canvas.height - game.debug.clipOffset,
      left: 0 + game.debug.clipOffset
    };
  },


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








  animationFrames: function() {
    this.animationFrame--;

    if (this.animationFrame < 0)
      this.animationFrame = this.maxAnimationFrames;

    self = this;

    setTimeout(function(){
      self.animationFrames();
    }, this.animationFrameRate);
  },




  clearCanvas: function() {
    var width = document.documentElement.clientWidth;
    var height = document.documentElement.clientHeight;

    this.primaryContext.clearRect(0, 0, width, height);
    this.interfaceContext.clearRect(0, 0, width, height);
  },



  isCellInsideClipBoundary: function(cell) {
    if (cell.coordinates.center.x < this.clipBoundary.left || cell.coordinates.center.x > this.clipBoundary.right)
      return false;

    if (cell.coordinates.center.y < this.clipBoundary.top || cell.coordinates.center.y > this.clipBoundary.bottom)
      return false;

    return true;
  },



  isInsideClipBoundary: function(x, y) {
    if (x < this.clipBoundary.left - (this.tileHeight * 4) || x > this.clipBoundary.right + (this.tileHeight * 3))
      return false;

    if (y < this.clipBoundary.top - (this.tileWidth) || y > this.clipBoundary.bottom + (this.tileWidth * 3))
      return false;

    return true;
  },




  drawTile: function(tileId, cell, topOffset = 0) {
    let x = cell.coordinates.bottom.x;
    let y = cell.coordinates.bottom.y;

    if (!this.isInsideClipBoundary(x, y))
      return;

    //if (!(tileId == 217 || tileId == 209 || tileId == 245 || tileId == 139))
    //  return;

    //if (!(tileId == 214 || tileId == 218 || tileId == 247 || tileId == 204))
    //  return;

    let tile = this.getTile(tileId);
    let image = this.getFrame(tile);

    // bitwise shift to round
    x = x - (image.width / 2) << 0;
    y = y - (image.height) - topOffset << 0;


    if (this.flipTile(tile, cell)) {
      this.drawImage(image, x, y, tileId, true);
      //this.primaryContext.strokeRect(x, y, image.width, image.height);
    } else {
      this.drawImage(image, x, y, tileId);
    }

    // debug: outline tile
    //if (game.debug.outlineBuildingTiles)
      //this.primaryContext.strokeRect(x, y, image.width, image.height);
  },



  flipTile: function(tile, cell) {
    if (tile.id > 256)
      return false;

    if (cell.rotate != 'Y')
      return false;

    if (tile.flip_h != 'Y')
      return false;

    if (game.mapRotation == 0 || game.mapRotation == 2)
      if (game.data.cityRotation == 1 || game.data.cityRotation == 3)
        return true;

    if (game.mapRotation == 1 || game.mapRotation == 3)
      if (game.data.cityRotation == 2 || game.data.cityRotation == 4)
        return true;

    return false;
  },



  // returns the appropriate tile for the current map rotation
  getTile: function(tileId) {
    let tile = game.data.tiles[tileId];

    switch (game.mapRotation) {
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




  // for animated tiles, returns the current frame to display based on the global animationFrame counter / timer
  // non animated tiles (frame count 0) just return the first frame in the array
  getFrame: function(tile) {
    if (tile.frames == 0)
      return tile.image[0];
    
    let frame = this.animationFrame - Math.floor(this.animationFrame / tile.frames) * tile.frames;
    return tile.image[frame];
  },





  // wrapper for the canvas drawImage function
  // will flip horizontally or vertically
  drawImage: function (image, x, y, tileId = null, flip_h = false, flip_v = false) {

    // if no transforms, just draw the image
    if (!flip_h && !flip_v) {
      this.primaryContext.drawImage(image, x, y);
      return;
    }
    
    // return cached tile image if available
    if (this.transformedTileCache[tileId] !== undefined && tileId !== null) {
      var cachedImage = this.transformedTileCache[tileId];
      this.primaryContext.drawImage(cachedImage, x, y);
      return;
    }

    // create temporary canvas and render the transformed tile
    var canvas = document.createElement('canvas');
    canvas.width = image.width;
    canvas.height = image.height;
    var context = canvas.getContext('2d');

    // horizontal flip
    if (flip_h) {
      // debug: draw rect around transformed tiles
      // context.strokeStyle = 'rgba(255,0,255,1)';
      // context.strokeRect(0, 0, canvas.width, canvas.height);
      context.scale(-1,1);
      context.translate(-canvas.width - image.width, 0);
      context.drawImage(image, canvas.width, 0);
    }else{
      context.drawImage(image, 0, 0);
    }

    this.primaryContext.drawImage(canvas, x, y);

    // save to cache as a png
    var cachedImage = new Image();
    cachedImage.src = canvas.toDataURL();

    if (cachedImage.src != 'data:,')
      this.transformedTileCache[tileId] = cachedImage;
  },




  drawVectorTile: function (tileId, fillColor, strokeColor, innerStrokeColor, offsetX, offsetY, renderingArea) {
    var renderingArea = typeof renderingArea !== 'undefined' ? renderingArea : this.primaryContext;
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





  distanceBetweenPoints: function(x1, y1, x2, y2) {
    return distance = Math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
  },



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




  drawPoly: function(polygon, fillColor, strokeColor, offsetX, offsetY, width, renderingArea) {
    if (polygon == null)
      return;

    var renderingArea = typeof renderingArea !== 'undefined' ? renderingArea : this.primaryContext;
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


  drawLines: function(lines, strokeColor, offsetX, offsetY, renderingArea) {
    if (lines == null)
      return;

    var renderingArea = typeof renderingArea !== 'undefined' ? renderingArea : this.primaryContext;
    var strokeColor = typeof strokeColor !== 'undefined' ? strokeColor : 'rgba(255, 0, 0, .9)';
    var width = typeof width !== 'undefined' ? width : 1;
    var offsetX = typeof offsetX !== 'undefined' ? offsetX : 0;
    var offsetY = typeof offsetY !== 'undefined' ? offsetY : 0;

    for (var i = 0; i < lines.length; i++)
      this.drawLine(lines[i].x1 + offsetX, lines[i].y1 + offsetY, lines[i].x2 + offsetX, lines[i].y2 + offsetY, strokeColor, width, renderingArea);
  },


  drawLine: function(x1, y1, x2, y2, color, width, renderingArea) {
    var renderingArea = typeof renderingArea !== 'undefined' ? renderingArea : this.primaryContext;
    var color = typeof color !== 'undefined' ? color : 'white';
    var width = typeof width !== 'undefined' ? width : 1;

    renderingArea.strokeStyle = color;
    renderingArea.lineWidth = width;
    renderingArea.beginPath();
    renderingArea.moveTo(Math.floor(x1), Math.floor(y1));
    renderingArea.lineTo(Math.floor(x2), Math.floor(y2));
    renderingArea.stroke();
    renderingArea.closePath();
  },


};