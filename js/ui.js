game.ui = {
  cameraOffsetX: 0,
  cameraOffsetY: 0,
  cursorX: -1,
  cursorY: -1,
  cursorTileX: -1,
  cursorTileY: -1,
  selectedTileX: -1,
  selectedTileY: -1,

  interfaceFont: 'Helvetica,Arial,sans-serif',

  centerCameraOnClick: function() {
    var centerX = game.graphics.primaryContext.canvas.width / 2;
    var centerY = game.graphics.primaryContext.canvas.height / 2;

    var cursorOffsetX = this.cameraOffsetX - Math.floor(this.cursorX - centerX);
    var cursorOffsetY = this.cameraOffsetY - Math.floor(this.cursorY - centerY);

    this.cameraOffsetX =+ cursorOffsetX;
    this.cameraOffsetY =+ cursorOffsetY;

    game.graphics.updateCanvasSize();
  },



  moveCamera: function(direction){
    //console.log('Move Camera: '+direction);
    var moveOffset = 40;

    if (direction == 'up')
      this.cameraOffsetY = this.cameraOffsetY + moveOffset;

    if (direction == 'down')
      this.cameraOffsetY = this.cameraOffsetY - moveOffset;

    if (direction == 'left')
      this.cameraOffsetX = this.cameraOffsetX + moveOffset;

    if (direction == 'right')
      this.cameraOffsetX = this.cameraOffsetX - moveOffset;

    game.graphics.updateCanvasSize();
  },



  selectionBox: function(tX, tY, color, width, fillColor) {
    var cell = game.getMapCell(tX, tY);

    if (!game.graphics.isCellInsideClipBoundary(cell))
      return;

    var lineColor = typeof color !== 'undefined' ? color : 'rgba(255, 255, 0, .75)';
    var lineWidth = typeof width !== 'undefined' ? width : 2;
    var fillColor = typeof fillColor !== 'undefined' ? fillColor : 'rgba(0,0,0,0)';

    var offsetX = cell.coordinates.top.x;
    var tile = game.graphics.getTile(cell.tiles.terrain);

    if (tile.slopes[0] == 1 || tile.slopes[1] == 1 || tile.slopes[2] == 1 || tile.slopes[3] == 1)
      if (cell.water == 1)
        var offsetY = cell.coordinates.top.y;
      else
        var offsetY = cell.coordinates.top.y - game.layerOffset;
    else
      if (cell.water == 1)
        var offsetY = cell.coordinates.top.y + game.layerOffset;
      else
        var offsetY = cell.coordinates.top.y;

    if (cell.water == 1)
      game.graphics.drawVectorTile(tile.id, fillColor, lineColor, 'rgba(0,0,0,0)', offsetX, offsetY);
    else
      game.graphics.drawVectorTile(tile.id, fillColor, lineColor, 'rgba(0,0,0,0)', offsetX, offsetY);

  },




  selectionCube: function(tX, tY) {
    return;

    var lineWidth = 1;
    var lineColor = 'rgba(255, 255, 255, .75)';
    var boxHeightUpper = 0;
    var boxHeightLower = game.layerOffset;

    var cell = game.getMapCell(tX, tY);

    var lineLength = 8;
    var lineLengthMultiplier = .4;

    // if (cell.width == 4){
    //   var lineLength = 18;
    //   var lineLengthMultiplier = .4;

    // }else if (cell.width == 3){
    //   var lineLength = 16;
    //   var lineLengthMultiplier = 1;

    // }else if (cell.width == 2){
    //   var lineLength = 12;
    //   var lineLengthMultiplier = -1;

    // }else if (cell.width == 1){
    //   var lineLength = 8;
    //   var lineLengthMultiplier = .4;
    // }

    //if (cell.height > 2)
    //  boxHeightUpper = (cell.height * this.layerOffset) - (this.layerOffset * 2) + (this.layerOffset / 2);
    //else
      boxHeightUpper = (cell.height * game.layerOffset / 2);

    //top
    cell.coordinates.top.y -= boxHeightUpper;
    cell.coordinates.bottom.y -= boxHeightUpper;
    cell.coordinates.left.y -= boxHeightUpper;
    cell.coordinates.right.y -= boxHeightUpper;
    
    if (cell.width == 1){
      game.graphics.drawLine(cell.coordinates.top.x, cell.coordinates.top.y, cell.coordinates.right.x - (lineLength / lineLengthMultiplier), cell.coordinates.right.y - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.top.x, cell.coordinates.top.y, cell.coordinates.left.x + (lineLength / lineLengthMultiplier), cell.coordinates.left.y - ((lineLength / 2) / lineLengthMultiplier),   lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.top.x, cell.coordinates.top.y, cell.coordinates.top.x, cell.coordinates.top.y + lineLength,   lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y, cell.coordinates.right.x - (lineLength / lineLengthMultiplier), cell.coordinates.right.y + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y, cell.coordinates.left.x + (lineLength / lineLengthMultiplier), cell.coordinates.left.y + ((lineLength / 2) / lineLengthMultiplier),   lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y, cell.coordinates.bottom.x, cell.coordinates.bottom.y + lineLength,   lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y, cell.coordinates.top.x - (lineLength / lineLengthMultiplier), cell.coordinates.top.y + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y, cell.coordinates.bottom.x - (lineLength / lineLengthMultiplier), cell.coordinates.bottom.y - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y, cell.coordinates.left.x, cell.coordinates.left.y + lineLength, lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y, cell.coordinates.top.x + (lineLength / lineLengthMultiplier), cell.coordinates.top.y + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y, cell.coordinates.bottom.x + (lineLength / lineLengthMultiplier), cell.coordinates.bottom.y - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y, cell.coordinates.right.x, cell.coordinates.right.y + lineLength, lineColor, lineWidth);
    }else{
      game.graphics.drawLine(cell.coordinates.top.x, cell.coordinates.top.y, cell.coordinates.right.x - (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.right.y - (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.top.x, cell.coordinates.top.y, cell.coordinates.left.x + (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.left.y - (game.tileWidth + (lineLength / 2) / lineLengthMultiplier),   lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.top.x, cell.coordinates.top.y, cell.coordinates.top.x, cell.coordinates.top.y + lineLength,   lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y, cell.coordinates.right.x - (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.right.y + (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y, cell.coordinates.left.x + (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.left.y + (game.tileWidth + (lineLength / 2) / lineLengthMultiplier),   lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y, cell.coordinates.bottom.x, cell.coordinates.bottom.y + lineLength,   lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y, cell.coordinates.top.x - (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.top.y + (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y, cell.coordinates.bottom.x - (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.bottom.y - (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y, cell.coordinates.left.x, cell.coordinates.left.y + lineLength, lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y, cell.coordinates.top.x + (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.top.y + (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y, cell.coordinates.bottom.x + (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.bottom.y - (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y, cell.coordinates.right.x, cell.coordinates.right.y + lineLength, lineColor, lineWidth);
    }

    cell.coordinates.top.y += boxHeightUpper;
    cell.coordinates.bottom.y += boxHeightUpper;
    cell.coordinates.left.y += boxHeightUpper;
    cell.coordinates.right.y += boxHeightUpper;


    //bottom
    cell.coordinates.top.y -= boxHeightLower;
    cell.coordinates.bottom.y -= boxHeightLower;
    cell.coordinates.left.y -= boxHeightLower;
    cell.coordinates.right.y -= boxHeightLower;

    if (cell.width == 1){
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y + boxHeightLower, cell.coordinates.right.x - (lineLength / lineLengthMultiplier), cell.coordinates.right.y  + boxHeightLower + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y + boxHeightLower, cell.coordinates.left.x + (lineLength / lineLengthMultiplier), cell.coordinates.left.y  + boxHeightLower + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y + boxHeightLower, cell.coordinates.bottom.x, cell.coordinates.bottom.y + boxHeightLower - lineLength, lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y + boxHeightLower, cell.coordinates.top.x + (lineLength / lineLengthMultiplier), cell.coordinates.top.y + boxHeightLower + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y + boxHeightLower, cell.coordinates.bottom.x + (lineLength / lineLengthMultiplier), cell.coordinates.bottom.y + boxHeightLower - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y + boxHeightLower, cell.coordinates.right.x, cell.coordinates.right.y + boxHeightLower - lineLength, lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y + boxHeightLower, cell.coordinates.top.x - (lineLength / lineLengthMultiplier), cell.coordinates.top.y + boxHeightLower + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y + boxHeightLower, cell.coordinates.bottom.x - (lineLength / lineLengthMultiplier), cell.coordinates.bottom.y + boxHeightLower - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y + boxHeightLower, cell.coordinates.left.x, cell.coordinates.left.y + boxHeightLower - lineLength, lineColor, lineWidth);
    }else{
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y + boxHeightLower, cell.coordinates.right.x - (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.right.y  + boxHeightLower + (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y + boxHeightLower, cell.coordinates.left.x + (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.left.y  + boxHeightLower + (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.bottom.x, cell.coordinates.bottom.y + boxHeightLower, cell.coordinates.bottom.x, cell.coordinates.bottom.y + boxHeightLower - lineLength, lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y + boxHeightLower, cell.coordinates.top.x + (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.top.y + boxHeightLower + (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y + boxHeightLower, cell.coordinates.bottom.x + (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.bottom.y + boxHeightLower - (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.right.x, cell.coordinates.right.y + boxHeightLower, cell.coordinates.right.x, cell.coordinates.right.y + boxHeightLower - lineLength, lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y + boxHeightLower, cell.coordinates.top.x - (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.top.y + boxHeightLower + (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y + boxHeightLower, cell.coordinates.bottom.x - (game.tileHeight + lineLength / lineLengthMultiplier), cell.coordinates.bottom.y + boxHeightLower - (game.tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth);
      game.graphics.drawLine(cell.coordinates.left.x, cell.coordinates.left.y + boxHeightLower, cell.coordinates.left.x, cell.coordinates.left.y + boxHeightLower - lineLength, lineColor, lineWidth);
    }

    cell.coordinates.top.y += boxHeightLower;
    cell.coordinates.bottom.y += boxHeightLower;
    cell.coordinates.left.y += boxHeightLower;
    cell.coordinates.right.y += boxHeightLower;
  },
}
