import debug from "@/app/debug"
import graphics, { flipTile, getFrame, getTile, isInsideClipBoundary } from "./"

// draws a tile from the tilemap to the primary canvas
export const drawTile = (tileId, cell, topOffset = 0, heightMap = false) => {
  if (!graphics.drawFrame) return
  const { x, y } = cell.coordinates.bottom

  if (!isInsideClipBoundary(x, y)) return

  // get tile ID, look up tilemap position
  let tile = getTile(tileId, cell)
  let tilemapId = tile.id

  // debug toggle for animated tiles
  if (debug.hideAnimatedTiles && tile.frames > 0) return

  // do we need the mirrored tile?
  if (flipTile(tile, cell) && !heightMap) tilemapId = `${tilemapId}_H`

  // get tile frame sequence
  let frame = getFrame(tile)

  if (heightMap && cell.water_level === `dry`) tilemapId = `${tilemapId}_VT_${cell.z}`
  else if (heightMap && cell.water_level !== `dry`) tilemapId = `${tilemapId}_VW_${cell.z}`
  else tilemapId = `${tilemapId}+_${frame}`

  let tileMap = graphics.tilemap[tilemapId]

  if (!tileMap) {
  // console.log(tilemapId)
  // console.log(cell)
    return
  }

  // bitwise shift to round
  x = x - (tileMap.w / 2) << 0 // eslint-disable-line
  y = y - (tileMap.h) - topOffset << 0 // eslint-disable-line

  graphics.primaryContext.drawImage(graphics.tilemapImages[tileMap.t], tileMap.x, tileMap.y, tileMap.w, tileMap.h, x, y, tileMap.w, tileMap.h)
}
