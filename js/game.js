var game = {
  app: undefined,
  fs: undefined,

  tileHeight: 64,
  tileWidth: 32,
  layerOffset: 24,

  originX: 0,
  originY: 0,

  maxMapSize: 128,
  tilesX: 128,
  tilesY: 128,
  waterLevel: 4,
  mapRotation: 0, //0 == normal, 0 degree, 1 = 90 degrees, 2 = 180 degrees, 3 = 270 degrees

  corners: ['1000','0100','0010','0001'],

  init: function() {
    this.app = require('electron').remote;
    this.fs = require('fs');

    this.graphics.createRenderingCanvas();
    this.data.load();

    if (this.data.cityId === undefined) {
      game.import.openFile();
      window.location.reload();
    }

    this.graphics.animationFrames();
    this.startGame();
  },


  startGame: function() {
    this.events.register();
    this.graphics.updateCanvasSize();
    requestAnimationFrame(game.gameLoop);
  },


  gameLoop: function() {
    game.game();
    requestAnimationFrame(game.gameLoop);
  },


  game: function(){
    this.debug.begin();
    this.graphics.clearCanvas();

    if (!game.graphics.ready) {
      this.graphics.loadingMessage();
      this.debug.end();
      return;
    }

    for(var tY = 0; tY < this.tilesY; tY++){
      for(var tX = (this.tilesX - 1); tX >= 0; tX--){
        var cell = this.getMapCell(tX, tY);

        this.drawTerrainEdge(cell);
        this.drawTerrainTile(cell);
        this.drawZoneTile(cell);
        this.drawNetworkTile(cell);
        this.drawBuildingTile(cell);

        this.debug.drawDebugLayer(cell);
      }
    }

    // selection box under cursor
    if (this.isCursorOnMap())
      this.ui.selectionBox(this.ui.cursorTileX, this.ui.cursorTileY);

    // selection cube
    //if (this.isCursorOnMap() && this.ui.selectedTileX >= 0 && this.ui.selectedTileY >= 0)
    //  this.ui.selectionCube(this.ui.selectedTileX, this.ui.selectedTileY);

    // run any remaining debug code
    this.debug.main();
    this.debug.end();

    this.graphics.loopEnd();
  },





  drawTerrainTile: function(cell) {
    if (cell.tiles.terrain == null || cell.tiles.terrain == 0)
      return;

    let tileId = cell.tiles.terrain;
    let topOffset = 0;

    if (((cell.water_level == 'submerged' || cell.water_level == 'shore') && cell.z < this.waterLevel) && (!this.debug.hideWater))
      topOffset = ((this.waterLevel - cell.z) * this.graphics.layerOffset);

    if ((cell.water_level == 'submerged') && (!this.debug.hideWater))
      tileId = 270;

    if ((cell.water_level == 'shore' || cell.water_level == 'surface') && (!this.debug.hideWater))
      tileId = cell.tiles.terrain + 14;

    if ((cell.water_level == 'waterfall') && (cell.tiles.building != 198) && (!this.debug.hideWater))
      tileId = 284;

    if (this.debug.hideWater)
      if (cell.water_level == 'surface')
        tileId = 256;
      else if (cell.water_level == 'waterfall')
        tileId = 269;


    if(!this.debug.hideTerrain)
      this.graphics.drawTile(tileId, cell, topOffset);

    this.debug.terrain(cell);
  },




  drawZoneTile: function(cell) {
    if (cell.tiles.zone == null || cell.tiles.zone == 0)
      return;

    if (!this.debug.hideZones)
      this.graphics.drawTile(cell.tiles.zone, cell);

    this.debug.zoneOverlay(cell);
  },




  drawNetworkTile: function(cell) {
    if (cell.tiles.building == null || cell.tiles.building == 0 || cell.tiles.building < 14 || (cell.tiles.building > 108))
      return;

    let topOffset = 0;
    let tile = this.graphics.getTile(cell.tiles.building);

    if ((cell.water_level == 'submerged' || cell.water_level == 'shore') && cell.z < this.waterLevel)
      topOffset = ((this.waterLevel - cell.z) * this.graphics.layerOffset);

    if (cell.tiles.terrain == 269)
      topOffset += this.graphics.layerOffset;

    if ((this.mapRotation == 0 && cell.corners[0] == 1) ||
        (this.mapRotation == 1 && cell.corners[2] == 1) ||
        (this.mapRotation == 2 && cell.corners[3] == 1) ||
        (this.mapRotation == 3 && cell.corners[1] == 1) ||
        (tile.size == '1x1')){
      var keyTile = true;
    }else{
      var keyTile = false;
    }

    if (keyTile && !this.debug.hideNetworks)
      this.graphics.drawTile(cell.tiles.building, cell, topOffset);

    this.debug.networkOverlay(cell);
  },





  drawBuildingTile: function(cell) {
    if (cell.tiles.building == null || cell.tiles.building == 0 || (cell.tiles.building > 14 && cell.tiles.building < 108))
      return;

    let topOffset = 0;

    if ((cell.water_level == 'submerged' || cell.water_level == 'shore') && cell.z < this.waterLevel)
      topOffset = ((this.waterLevel - cell.z) * this.graphics.layerOffset);

    var tile = this.graphics.getTile(cell.tiles.building);

    var keyTile = false;

    if (cell.corners == this.corners[this.mapRotation])
      keyTile = true;

    if (tile.size == '1x1')
      keyTile = true;

    if (this.debug.lowerBuildingOpacity)
      game.graphics.primaryContext.globalAlpha = 0.6;

    if (keyTile && !this.debug.hideBuildings)
      this.graphics.drawTile(cell.tiles.building, cell, topOffset);

    if (this.debug.lowerBuildingOpacity)
      game.graphics.primaryContext.globalAlpha = 1;

    this.debug.building(cell);
  },



  drawTerrainEdge: function(cell) {
    if(this.debug.hideTerrainEdge)
      return;

    if (cell.x == 0 || cell.y == this.tilesY - 1)
      var drawEdge = true;
    else
      return;


    var tile = 269;
    var topOffset = 0;

    // draw rock
    for (i = cell.z; i > 0; i--){
      topOffset = -game.graphics.layerOffset * i;
      this.graphics.drawTile(tile, cell, topOffset);
    }

    // draw water blocks when needed
    if ((cell.water_level == 'submerged' || cell.water_level == 'shore') && (!this.debug.hideWater)) {
      tile = 284;
      for (i = game.waterLevel; i > 0; i--){
        topOffset = -(game.graphics.layerOffset * i) + (game.graphics.layerOffset * game.waterLevel);

        if (i > cell.z)
          this.graphics.drawTile(tile, cell, topOffset);
      }
    }
  },


  getMapCell: function(xT, yT){
    if (typeof this.data.map[xT] !== 'undefined') {
      if (typeof this.data.map[xT][yT] !== 'undefined') {
        return this.data.map[xT][yT];
      }
    }

    return false;
  },




  // [NW, N, NE]
  // [W,  C,  W]
  // [SW, S, SE]
  getSurroundingCells: function(tX, tY) {
    var cell = this.getMapCell(tX, tY);
    var surroundingCells = new Array();

    for (cX = -1; cX <= 1; cX++) {
      for (cY = -1; cY <= 1; cY++) {
        surroundingCells.push({ x: tX + cX, y: tY + cY });
      }
    }

    // debug highlight surrounding cells
    //for (i = 0; i < surroundingCells.length; i++) {
    //  this.ui.selectionBox(surroundingCells[i].x, surroundingCells[i].y, '#ff0000', 3);
    //}

    return surroundingCells;
  },


  isCursorOnMap: function() {
    return (this.ui.cursorTileX >= 0 && this.ui.cursorTileX < this.tilesX &&
            this.ui.cursorTileY >= 0 && this.ui.cursorTileY < this.tilesY &&
            this.graphics.isInsideClipBoundary(this.ui.cursorX, this.ui.cursorY));
  },


  getTileUnderCursor: function(event){
    this.ui.cursorX = event.pageX;
    this.ui.cursorY = event.pageY;

    for(var tX = (this.tilesX - 1); tX >= 0; tX--){
      for(var tY = 0; tY < this.tilesY; tY++){
        if(this.graphics.isInsideClipBoundary(tX, tY)){
          if (this.ui.cursorY > this.data.map[tX][tY].coordinates.top.y && this.ui.cursorY < this.data.map[tX][tY].coordinates.bottom.y
              && this.ui.cursorX > this.data.map[tX][tY].coordinates.left.x && this.ui.cursorX < this.data.map[tX][tY].coordinates.right.x){
            this.ui.cursorTileX = tX;
            this.ui.cursorTileY = tY;
          }
        }

      }
    }
  },


  setSelectedTile: function(){
    if (this.isCursorOnMap()){
      this.ui.selectedTileX = this.ui.cursorTileX;
      this.ui.selectedTileY = this.ui.cursorTileY;
    }else{
      this.ui.selectedTileX = -1;
      this.ui.selectedTileY = -1;
    }
  },


  //
  // shifts tiles based on rotation and updates the tile array
  //
  rotateMap: function(direction) {
    var rotatedMap = new Array();

    if (direction == 'left'){
      var newX = 0;
      var newY = this.maxMapSize - 1;
    }else{
      var newX = this.maxMapSize - 1;
      var newY = 0;
    }

    for (var mX = 0; mX < this.maxMapSize; mX++){
      for (var mY = 0; mY < this.maxMapSize; mY++){

        if (typeof rotatedMap[newY] == 'undefined')
          rotatedMap[newY] = new Array();
        
        if (typeof rotatedMap[newX] == 'undefined')
          rotatedMap[newX] = new Array();

        // update tile position x/y
        rotatedMap[newY][newX] = this.data.map[mX][mY];
        rotatedMap[newY][newX].x = newY;
        rotatedMap[newY][newX].y = newX;

        // if building tile should flip, toggle rotate flag
        let buildingTile = this.graphics.getTile(this.data.map[mX][mY].tiles.building);

        if (rotatedMap[newY][newX].rotate == 'Y')
          rotatedMap[newY][newX].rotate = 'N';
        else if (rotatedMap[newY][newX].rotate == 'N' && buildingTile.flip_h == 'Y')
          rotatedMap[newY][newX].rotate = 'Y';

        
        if (direction == 'left'){
          newY--;
          if (newY < 0)
            newY = this.maxMapSize - 1;

        }else{
          newY++;
          if (newY >= this.maxMapSize)
            newY = 0;
        }
      }

      if (direction == 'left'){
        newX++;
        if (newX >= this.maxMapSize)
          newX = 0;

      }else{
        newX--;
        if (newX < 0)
          newX = this.maxMapSize - 1;
      }
    }

    this.data.map = rotatedMap;

    if (direction == 'left'){
      this.mapRotation++;

      if (this.mapRotation > 3)
        this.mapRotation = 0;
    }else{
      this.mapRotation--;

      if (this.mapRotation < 0)
        this.mapRotation = 3;
    }

    this.graphics.updateCanvasSize();
  },


};