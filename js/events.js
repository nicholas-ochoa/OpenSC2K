game.events = {

  activeCursorTool: 'center', // none, center, query, debugQuery

  register: function() {
    document.addEventListener('mousewheel', function(event) {
      event.preventDefault();
    });

    window.addEventListener('resize', function(){
      game.graphics.updateCanvasSize();
    });

    document.addEventListener('mousemove', function(event) {
      game.getTileUnderCursor(event);
    });

    document.addEventListener('click', function(event) {
      event.preventDefault();
      game.getTileUnderCursor(event);
      game.setSelectedTile();

      if (game.events.activeCursorTool == 'center')
        game.ui.centerCameraOnClick();


    });

    document.addEventListener('keydown', function(event) {
      game.events.keyEvent(event);
    });
  },



  keyEvent: function(event) {
    //console.log('Key Event: '+ event.key);

    switch(event.key){
      case '1':
        game.events.activeCursorTool = 'none';
        game.debug.showSelectedTileInfo = false;
        break;

      case '2':
        game.events.activeCursorTool = 'center';
        game.debug.showSelectedTileInfo = true;
        break;

      case '3':
        game.events.activeCursorTool = 'info';
        game.debug.showSelectedTileInfo = true;
        break;

      case 'a':
        game.debug.showSelectedTileInfo = !game.debug.showSelectedTileInfo;
        break;

      case 'z':
        game.debug.showBuildingCorners = !game.debug.showBuildingCorners;
        break;

      case 'c':
        game.debug.showTileCoordinates = !game.debug.showTileCoordinates;
        break;

      case 'i':
        game.debug.showTileCount = !game.debug.showTileCount;
        break;

      case 'x':
        game.debug.hideTerrain = !game.debug.hideTerrain;
        break;

      case 'v':
        game.debug.hideZones = !game.debug.hideZones;
        break;

      case 'y':
        game.debug.hideNetworks = !game.debug.hideNetworks;
        break;

      case 'b':
        game.debug.hideBuildings = !game.debug.hideBuildings;
        break;

      case 'n':
        game.debug.hideWater = !game.debug.hideWater;
        break;

      case 'm':
        game.debug.hideTerrainEdge = !game.debug.hideTerrainEdge;
        break;

      case 'h':
        game.debug.showHeightMap = !game.debug.showHeightMap;
        break;

      case 'k':
        game.debug.showZoneOverlay = !game.debug.showZoneOverlay;
        break;

      case 'j':
        game.debug.showNetworkOverlay = !game.debug.showNetworkOverlay;
        break;

      case 'q':
        game.rotateMap('left');
        break;

      case 'w':
        game.rotateMap('right');
        break;

      case 't':
        game.debug.toggleClipBoundDebug();
        break;

      case 'o':
        game.import.openFile();
        break;

      case 0:
        game.data.clear();
        window.location.reload();
        break;

      case 'F5':
        window.location.reload();
        break;

      case 'ArrowUp':
        game.ui.moveCamera('up');
        break;

      case 'ArrowRight':
        game.ui.moveCamera('right');
        break;

      case 'ArrowDown':
        game.ui.moveCamera('down');
        break;

      case 'ArrowLeft':
        game.ui.moveCamera('left');
        break;
    };
  },

}