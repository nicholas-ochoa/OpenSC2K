import debug, { debugTerrain } from "../debug"
import graphics, { drawTile } from "../graphics"
import game from "./"

export const drawTerrainTile = cell => {
  const { tiles: { building, terrain }, water_level: waterLevel, z } = cell
  if (!terrain) return
  const topOffset = ((waterLevel === `submerged` || waterLevel === `shore`) && z < game.waterLevel)
    && (!debug.hideWater)
    ? (game.waterLevel - z) * graphics.layerOffset
    : 0
  let tile = terrain
  if (debug.hideWater) {
    if (waterLevel === `surface`) tile = 256
    if (waterLevel === `waterfall`) tile = 269
  } else {
    if (waterLevel === `submerged`) tile = 270
    if (waterLevel === `shore` || waterLevel === `surface`) tile = terrain + 14
    if (waterLevel === `waterfall` && building !== 198) tile = 284
  }

  if (debug.hideTerrain) {
    debugTerrain(cell)
  } else {
    drawTile(tile, cell, topOffset)
  }
}
