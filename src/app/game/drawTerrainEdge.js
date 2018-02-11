import debug from "@/app/debug"
import graphics, { drawTile } from "@/app/graphics"
import game from "./"

export const drawTerrainEdge = cell => {
  const { water_level: waterLevel, x, y, z } = cell
  if (debug.hideTerrainEdge || x !== 0 || y !== game.tilesY - 1) return
  let topOffset = 0

  // draw rock
  for (let i = z; i > 0; i--) {
    topOffset -= graphics.layerOffset * i
    drawTile(269, cell, topOffset)
  }

  // draw water blocks when needed
  if ((waterLevel === `submerged` || waterLevel === `shore`) && (!debug.hideWater)) {
    for (let i = game.waterLevel; i > 0; i--) {
      topOffset -= (graphics.layerOffset * i) + (graphics.layerOffset * game.waterLevel)
      if (i > z) drawTile(284, cell, topOffset)
    }
  }
}
