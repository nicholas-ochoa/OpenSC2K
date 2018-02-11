import debug, { debugBuilding  } from "@/app/debug"
import graphics, { getTile, drawTile } from "@/app/graphics"
import game from "./"

export const drawBuildingTile = cell => {
  const { corners, tiles: { building }, water_level: waterLevel, z } = cell
  if (!building || (building > 14 && building < 108)) return
  const { size } = getTile(building)
  const keyTile = (corners === game.corners[game.mapRotation] || size === `1x1`)
  const topOffset = ((waterLevel === `submerged` || waterLevel === `shore`) && z < game.waterLevel)
    ? (game.waterLevel - z) * graphics.layerOffset
    : 0

  if (keyTile && !debug.hideBuildings) {
    if (debug.lowerBuildingOpacity) graphics.primaryContext.globalAlpha = 0.6
    drawTile(building, cell, topOffset)
  } else {
    if (debug.lowerBuildingOpacity) graphics.primaryContext.globalAlpha = 1
    debugBuilding(cell)
  }
}
