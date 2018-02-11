class State {
  tileHeight = 64
  tileWidth = 32
  layerOffset = 24

  originX = 0
  originY = 0

  maxMapSize = 128
  tilesX = 128
  tilesY = 128
  waterLevel = 4
  mapRotation = 0 //0 == normal, 0 degree, 1 = 90 degrees, 2 = 180 degrees, 3 = 270 degrees

  corners = [`1000`, `0100`, `0010`, `0001`]
}

export const state = new State()
