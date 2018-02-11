class State {
  tilemapImages = {}
  totalTilemaps = 4
  loadedTilemaps = 0
  ready = false

  drawFrame = true
  animationFrame = 0
  animationFrameRate = 500
  maxAnimationFrames = 512
  currentFrame = 0

  tileHeight = 32
  tileWidth = 64
  layerOffset = 24

  scale = 1

  tileCache = {}
  vectorTileCache = {}
  transformedTileCache = {}

  clipOffset = {
    top: 50,
    right: -100,
    bottom: -200,
    left: -100
  }

  clipBoundary = {
    top: 0,
    right: 0,
    bottom: 0,
    left: 0
  }
}

export const state = new State()
