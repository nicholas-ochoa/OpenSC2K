import graphics, { drawTile } from "@/app/graphics"
import debug from "./"

export const heightMap = cell => {
  const { tiles: { terrain } } = cell
  if (!debug.showHeightMap || !terrain || terrain < 256 || terrain > 268) return
  const topOffset = (terrain === 256) ? 0 - graphics.tileHeight : 0 - (graphics.layerOffset / 3)

  drawTile(terrain, cell, topOffset, true)
}
