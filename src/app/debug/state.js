class State {
  enabled = true
  logEvents = true

  hideTerrain = false
  hideZones = false
  hideNetworks = false
  hideBuildings = false
  hideWater = false
  hideTerrainEdge = false
  hideAnimatedTiles = false

  showTileCoordinates = false
  showHeightMap = false
  showClipBounds = false

  showBuildingCorners = false
  showZoneOverlay = false
  showNetworkOverlay = false
  showTileCount = false
  lowerBuildingOpacity = false

  higlightSelectedCellSurroundings = false
  showSelectedTileInfo = true

  showOverlayInfo = true
  showStatsPanel = false

  clipOffset = 0
  tileCount = 0

  beginTime = performance.now()
  previousTime = performance.now()
  frameTime = 0
  frames = 0
  frameCount = 0
  fps = 0
}

export const state = new State()
