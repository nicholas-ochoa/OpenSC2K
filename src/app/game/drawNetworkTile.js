import debug, { networkOverlay } from "@/app/debug"
import graphics, { getTile, drawTile } from "@/app/graphics"
import game from "./"

export const drawNetworkTile = cell => {
  const { corners, tiles: { building, terrain }, water_level: waterLevel, z } = cell
  if (!building || building < 14 || (building > 108)) return
  const { size } = getTile(building)
  const keyTile = (
    (game.mapRotation === 0 && corners[0] === 1)
    || (game.mapRotation === 1 && corners[2] === 1)
    || (game.mapRotation === 2 && corners[3] === 1)
    || (game.mapRotation === 3 && corners[1] === 1)
    || size === `1x1`
  )
  const topOffset = ((waterLevel === `submerged` || waterLevel === `shore`) && z < game.waterLevel
    ? (game.waterLevel - z) * graphics.layerOffset
    : 0) + ((terrain === 269) ? graphics.layerOffset : 0)

  if (keyTile && !debug.hideNetworks) {
    drawTile(building, cell, topOffset)
  } else {
    networkOverlay(cell)
  }
}
