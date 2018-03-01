var common = function () {
  return {
    scale: 2,
    tileWidth: 64,
    tileHeight: 32,
    layerOffset: 24,
    tilemap: 'tiles',
    tiles: [],
    cache: {
      vectorTiles: []
    }
  }
}

export default common;