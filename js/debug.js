game.debug = {
  
  enabled: true,
  
  hideTerrain: false,
  hideZones: false,
  hideNetworks: false,
  hideBuildings: false,
  hideWater: false,
  hideTerrainEdge: false,
  hideAnimatedTiles: false,

  showTileCoordinates: false,
  showHeightMap: false,
  showClipBounds: false,

  showBuildingCorners: false,
  showZoneOverlay: false,
  showNetworkOverlay: false,
  showTileCount: false,
  lowerBuildingOpacity: false,

  higlightSelectedCellSurroundings: false,
  showSelectedTileInfo: true,

  showOverlayInfo: true,
  showStatsPanel: false,

  clipOffset: 0,
  tileCount: 0,

  beginTime: performance.now(),
  previousTime: performance.now(),
  frameTime: 0,
  frames: 0,
  frameCount: 0,
  fps: 0,



  main: function () {
    if(!this.enabled)
      return;

    this.drawClipBounds();
    this.debugOverlay();
    this.showTileInfo();
    this.showFrameStats();
  },



  begin: function() {
    this.beginTime = performance.now();
    this.tileCount = 0;
  },



  end: function() {
    var time = performance.now();

    this.frames++;

    if (time > this.previousTime + 1000) {
      this.msPerFrame = Math.round(time - this.beginTime);
      this.fps = Math.round((this.frames * 1000) / (time - this.previousTime));

      this.previousTime = time;
      this.frameCount += this.frames;
      this.frames = 0;
    }

    return time;
  },



  showFrameStats: function() {
    var width = 170;
    var height = 30;
    var x = game.graphics.interfaceContext.canvas.width - width;
    var y = game.graphics.interfaceContext.canvas.height - height;

    game.graphics.drawPoly([{ x: 0, y: 0 }, { x: width, y: 0 }, { x: width, y: height }, { x: 0, y: height }, { x: 0, y: 0 }], 'rgba(0,0,0,.5)', 'rgba(255,255,255,.7)', x + 10, y + 10);

    game.graphics.interfaceContext.font = '10px Verdana';
    game.graphics.interfaceContext.fillStyle = 'rgba(255,255,255,1)';
    game.graphics.interfaceContext.fillText(this.msPerFrame+' m/s per frame ('+this.fps+' FPS)', x + 20, y + 24);
  },


  terrain: function(cell) {
    if(!this.enabled)
      return;

    this.heightMap(cell);
    this.cellCoordinates(cell);
  },


  building: function(cell) {
    if(!this.enabled)
      return;

    this.buildingCorners(cell);
    this.networkOverlay(cell);
  },


  buildingCorners: function(cell) {
    if(!this.showBuildingCorners)
      return;

    if (cell.tiles.building == null || cell.tiles.building == 0)
      return;

    var tile = game.graphics.getTile(cell.tiles.building);

    if (tile.size == '1x1')
      return;

    var line = 'rgba(0,0,255,.5)';
    var fill = 'rgba(0,0,255,.1)';
    var textStyle = 'rgba(255,255,255,.75)';
    

    if (cell.corners == game.corners[0]){
      var tileType = 'C0 TR';

    }else if (cell.corners == game.corners[1]){
      var tileType = 'C1 BL';

    }else if (cell.corners == game.corners[2]){
      var tileType = 'C2 BR';

    }else if (cell.corners == game.corners[3]){
      var tileType = 'C3 TL';

    }else{
      var line = 'rgba(128,128,128,.6)';
      var fill = 'rgba(128,128,128,.4)';
      var textStyle = 'rgba(0,0,0,0)';
      var tileType = '';
    }

    if (cell.corners == game.corners[game.mapRotation]) {
      var line = 'rgba(255,0,0,.9)';
      var fill = 'rgba(255,0,0,.25)';
      var tileType = tileType + ' K';
    }

    game.graphics.interfaceContext.font = '8px Verdana';
    game.graphics.interfaceContext.fillStyle = textStyle;
    game.graphics.interfaceContext.fillText(tileType, cell.coordinates.center.x - 16, cell.coordinates.center.y + 3);
    game.ui.selectionBox(cell.x, cell.y, line, 2, fill);
  },





  networkOverlay: function(cell) {
    if (!this.showNetworkOverlay)
      return;

    var tile = game.graphics.getTile(cell.tiles.building);

    if (tile.name.substring(0,4) == 'road'){
      var line = 'rgba(255,255,255,.9)';
      var fill = 'rgba(255,255,255,.3)';

    }else if (tile.name.substring(0,4) == 'rail'){
      var line = 'rgba(97,65,38,.9)';
      var fill = 'rgba(97,65,38,.3)';

    }else if (tile.name.substring(0,4) == 'powe'){
      var line = 'rgba(255,0,0,.9)';
      var fill = 'rgba(255,0,0,.3)';

    }else{
      return;
    }

    game.graphics.interfaceContext.font = '8px Verdana';
    game.graphics.interfaceContext.fillStyle = 'rgba(255, 255, 255, .25)';
    game.graphics.interfaceContext.fillText(tile.name.substring(0,8), cell.coordinates.center.x - 16, cell.coordinates.center.y + 3);
    game.ui.selectionBox(cell.x, cell.y, line, 2, fill);
  },




  zoneOverlay: function(cell) {
    if (!this.showZoneOverlay)
      return;

    if(cell.tiles.zone == 0)
      return;

    var tile = game.graphics.getTile(cell.tiles.zone);
    var color;

    if (tile.name == 'l_res')
      color = '0,255,0';
    else if (tile.name == 'd_res')
      color = '0,180,0';
    else if (tile.name == 'l_com')
      color = '0,0,255';
    else if (tile.name == 'd_com')
      color = '0,0,180';
    else if (tile.name == 'l_ind')
      color = '255,255,0';
    else if (tile.name == 'd_ind')
      color = '180,180,0';
    else if (tile.name == 'sea')
      color = '255,0,255';
    else if (tile.name == 'mil')
      color = '0,255,255';
    else if (tile.name == 'air')
      color = '255,0,0';
    else
      color = '128,128,128';

    game.ui.selectionBox(cell.x, cell.y, 'rgba('+color+',.5)', 2, 'rgba('+color+',.3)');
    game.graphics.interfaceContext.font = '8px Verdana';
    game.graphics.interfaceContext.fillStyle = 'rgba(255, 255, 255, .7)';
    game.graphics.interfaceContext.fillText(tile.type, cell.coordinates.center.x - 10, cell.coordinates.center.y + 3);
  },


  heightMap: function(cell) {
    if(!game.debug.showHeightMap)
      return;

    if (cell.tiles.terrain == null || cell.tiles.terrain == 0 || cell.tiles.terrain < 256 || cell.tiles.terrain > 268)
      return;

    let tile = cell.tiles.terrain;
    let topOffset = 0;

    if (tile == 256)
      topOffset = 0 - game.graphics.tileHeight;
    else
      topOffset = 0 - (game.graphics.layerOffset / 3);

    game.graphics.drawTile(tile, cell, topOffset, true);
  },




  cellCoordinates: function(cell) {
    if(!this.showTileCoordinates)
      return;

    game.graphics.interfaceContext.font = '8px Verdana';
    game.graphics.interfaceContext.fillStyle = 'rgba(255, 255, 255, .5)';
    game.graphics.interfaceContext.fillText(cell.x+', '+cell.y+', '+cell.z, cell.coordinates.center.x - 16, cell.coordinates.center.y + 3);

  },


  drawDebugLayer: function(cell) {
    if(!this.showTileCount)
      return;

    this.tileCount++;

    game.graphics.interfaceContext.font = '8px Verdana';
    game.graphics.interfaceContext.fillStyle = 'rgba(255, 255, 255, .5)';
    game.graphics.interfaceContext.fillText(this.tileCount, cell.coordinates.center.x - 10, cell.coordinates.center.y + 3);

  },



  toggleClipBoundDebug: function() {
    this.showClipBounds = !this.showClipBounds;

    if (!this.showClipBounds) {
      this.clipOffset = 0;
    }else{
      this.clipOffset = 400;
    }

    game.graphics.updateCanvasSize();
  },



  drawClipBounds: function() {
    if(!this.showClipBounds)
      return;

    var polygon = [
      { x: game.graphics.clipBoundary.top,                                                y: game.graphics.clipBoundary.top },
      { x: game.graphics.interfaceContext.canvas.width - game.graphics.clipBoundary.top,    y: game.graphics.clipBoundary.top },
      { x: game.graphics.interfaceContext.canvas.width - game.graphics.clipBoundary.top,    y: game.graphics.interfaceContext.canvas.height - game.graphics.clipBoundary.top },
      { x: game.graphics.clipBoundary.top,                                                y: game.graphics.interfaceContext.canvas.height - game.graphics.clipBoundary.top },
      { x: game.graphics.clipBoundary.top,                                                y: game.graphics.clipBoundary.top }
    ];

    game.graphics.drawPoly(polygon, 'rgba(0, 0, 0, 0)', 'rgba(255, 0, 0, .9)', 0, 0, 3);
  },




  debugOverlay: function() {
    if (!this.showOverlayInfo)
      return;

    var line = 25;
    var width = 280;
    var height = 100;

    // draw box
    game.graphics.drawPoly([{ x: 0, y: 0 }, { x: width, y: 0 }, { x: width, y: height }, { x: 0, y: height }, { x: 0, y: 0 }], 'rgba(0,0,0,.4)', 'rgba(255,255,255,.7)', 10, 10);

    // draw text
    game.graphics.interfaceContext.font = '10px Verdana';
    game.graphics.interfaceContext.fillStyle = 'rgba(255,255,255,.9)';

    if(game.isCursorOnMap()) {
      var cell = game.getMapCell(game.ui.cursorTileX, game.ui.cursorTileY);
      game.graphics.interfaceContext.fillText('tile x: '+cell.x+', y: '+cell.y+', z: '+cell.z, 20, line); line += 15;
    }

    game.graphics.interfaceContext.fillText('cursor x: '+game.ui.cursorX+', y: '+game.ui.cursorY, 20, line); line += 15;
    game.graphics.interfaceContext.fillText('selected tile x: '+game.ui.selectedTileX+', y: '+game.ui.selectedTileY, 20, line); line += 15;
    game.graphics.interfaceContext.fillText('map rotation: '+game.mapRotation, 20, line); line += 15;
    game.graphics.interfaceContext.fillText('city rotation: '+game.data.cityRotation, 20, line); line += 15;
    game.graphics.interfaceContext.fillText('active cursor tool: '+game.events.activeCursorTool, 20, line); line += 15;
  },






  showTileInfo: function() {
    if (!this.showSelectedTileInfo)
      return;

    var context = game.graphics.interfaceContext;
    var cell = game.getMapCell(game.ui.cursorTileX, game.ui.cursorTileY);

    if (!cell)
      return;

    // draw text
    var textData = new Array();

    // todo: this should be moved to a function for drawing text?
    textData.push('Cell Position:');
    textData.push('Current X: '+cell.x+', Y: '+cell.y+', Z: '+cell.z);
    textData.push('Original X: '+cell.original_x+', Y: '+cell.original_y);
    textData.push('');

    if (cell.tiles.terrain > 0){
      let tile = game.graphics.getTile(cell.tiles.terrain);

      textData.push('Terrain: '+cell.tiles.terrain+' (R'+game.mapRotation+': '+tile.id+')');
      textData.push('  Slopes: '+tile.slopes);
      textData.push('  Frames: '+tile.frames);
      textData.push('  Water Level: '+cell.water_level);
      textData.push('');
    }

    if (cell.tiles.building > 0){
      let tile = game.graphics.getTile(cell.tiles.building);

      textData.push('Building: '+cell.tiles.building+' (R'+game.mapRotation+': '+tile.id+')');
      textData.push('  Name: '+tile.description);
      textData.push('  Lot Size: '+tile.size);
      textData.push('  Frames: '+tile.frames);
      textData.push('  Corners: '+cell.corners+' / '+game.corners[game.mapRotation])
      textData.push('  Key Tile: '+(cell.corners == game.corners[game.mapRotation] ? 'Y':'N'));
      textData.push('  Transforms:');
      textData.push('    Tile Flip: '+tile.flip_h);
      textData.push('    Alt Flip Tile: '+tile.flip_alt_tile);
      textData.push('    Cell Rotate: '+cell.rotate);
      textData.push('    Display Mirrored: '+(game.graphics.flipTile(tile, cell) ? 'Y':'N'));
      textData.push('');
    }

    if (cell.tiles.zone > 0){
      let tile = game.graphics.getTile(cell.tiles.zone);

      textData.push('Zone: '+cell.tiles.zone+' (R'+game.mapRotation+': '+tile.id+')');
      textData.push('  Type: '+tile.name);
      textData.push('  Description: '+tile.description);
      textData.push('');
    }



    // draw background
    var height = 20 + (textData.length * 15);
    var width = 220
    game.graphics.drawPoly([{ x: 0, y: 0 }, { x: width, y: 0 }, { x: width, y: height }, { x: 0, y: height }, { x: 0, y: 0 }], 'rgba(0,0,0,.5)', 'rgba(255,255,255,.75)', game.ui.cursorX + 10, game.ui.cursorY + 10);

    var lineX = game.ui.cursorX + 20;
    var lineY = game.ui.cursorY + 25;
    context.font = '10px Verdana';
    context.fillStyle = 'rgba(255,255,255,.9)';

    for (i = 0; i < textData.length; i++){
      context.fillText(textData[i], lineX, lineY);
      lineY += 15;
    }

  },




  highlightCell: function(cell, lineWidth, lineColor, fillColor, text, textcolor) {
    if (!this.graphics.isCellInsideClipBoundary(cell))
      return;

    var lineColor = typeof lineColor !== 'undefined' ? lineColor : 'rgba(255, 255, 0, .75)';
    var lineWidth = typeof lineWidth !== 'undefined' ? lineWidth : 2;
    var fillColor = typeof fillColor !== 'undefined' ? fillColor : 'rgba(0,0,0,0)';
    var text = typeof text !== 'undefined' ? text : '';
    var textColor = typeof textColor !== 'undefined' ? textColor : 'rgba(0,0,0,.9)';

    var offsetX = cell.coordinates.top.x;

    if (cell.tiles.terrain.slopes[0] == 1 || cell.tiles.terrain.slopes[1] == 1 || cell.tiles.terrain.slopes[2] == 1 || cell.tiles.terrain.slopes[3] == 1)
      if (cell.water == 1)
        var offsetY = cell.coordinates.top.y;
      else
        var offsetY = cell.coordinates.top.y - this.layerOffset;
    else
      if (cell.water == 1)
        var offsetY = cell.coordinates.top.y + this.layerOffset;
      else
        var offsetY = cell.coordinates.top.y;

    if (cell.water == 1)
      this.graphics.drawVectorTile(cell.tiles.terrain, fillColor, lineColor, 'rgba(0,0,0,0)', offsetX, offsetY);
    else
      this.graphics.drawVectorTile(cell.tiles.terrain, fillColor, lineColor, 'rgba(0,0,0,0)', offsetX, offsetY);

  },




  debugTestTile: function(cell, type, color) {
    var type = typeof type !== 'undefined' ? type : 'box';
    var color = typeof color !== 'undefined' ? color : '#ff00ff';

    var topLeftX = 10;
    var topLeftY = 10;
    var topRightX = game.graphics.interfaceContext.canvas.width - 10;
    var topRightY = game.graphics.interfaceContext.canvas.height - 10;
    var bottomLeftX = 10;
    var bottomLeftY = 10;
    var bottomRightX = game.graphics.interfaceContext.canvas.width - 10;
    var bottomRightY = game.graphics.interfaceContext.canvas.height - 10;

    var topCenterX = (game.graphics.interfaceContext.canvas.width / 2);
    var topCenterY = 10;
    var rightCenterX = game.graphics.interfaceContext.canvas.width - 10;
    var rightCenterY = game.graphics.interfaceContext.canvas.height / 2;
    var bottomCenterX = (game.graphics.interfaceContext.canvas.width / 2);
    var bottomCenterY = game.graphics.interfaceContext.canvas.height - 10;
    var leftCenterX = 10;
    var leftCenterY = game.graphics.interfaceContext.canvas.height / 2;

    // debug: draw lines to the 4 corners and the center
    if (type == 'lines') {
      game.graphics.drawLine(cell.coordinates.center.x, cell.coordinates.center.y, topLeftX, topLeftY, color, 3);
      game.graphics.drawLine(cell.coordinates.top.x, cell.coordinates.top.y, topCenterX, topCenterY, color, 3);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y, rightCenterX, rightCenterY, color, 3);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y, bottomCenterX, bottomCenterY, color, 3);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y, leftCenterX, leftCenterY, color, 3);
    }

    // debug: draw a box around the tile image
    if (type == 'box') {
      game.graphics.drawLine(cell.coordinates.top.x, cell.coordinates.top.y, cell.coordinates.right.x, cell.coordinates.right.y, color, 2);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y, cell.coordinates.bottom.x, cell.coordinates.bottom.y, color, 2);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y, cell.coordinates.left.x, cell.coordinates.left.y, color, 2);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y, cell.coordinates.top.x, cell.coordinates.top.y, color, 2);
    }

    // debug: draw a polygon around the tile image
    if (type == 'polygon') {
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y, cell.coordinates.top.x, cell.coordinates.top.y, color, 2);
      game.graphics.drawLine(cell.coordinates.top.x, cell.coordinates.top.y, cell.coordinates.right.x, cell.coordinates.right.y, color, 2);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y, cell.coordinates.left.x, cell.coordinates.left.y + this.layerOffset, color, 2);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y, cell.coordinates.right.x, cell.coordinates.right.y + this.layerOffset, color, 2);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y + this.layerOffset, tile.coordinates.bottom.x, tile.coordinates.bottom.y + this.layerOffset, color, 2);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y + this.layerOffset, tile.coordinates.right.x, tile.coordinates.right.y + this.layerOffset, color, 2);
    }
  },


}