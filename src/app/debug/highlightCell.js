import { colors } from "@/app/constants"
import { drawVectorTile, isCellInsideClipBoundary } from "@/app/graphics"
import debug from "./"

export const highlightCell = (cell, lineWidth = 2, lineColor = colors.yellow75, fillColor = colors.black0, text = ``, textColor = colors.black90) => {
  if (!isCellInsideClipBoundary(cell)) return
  const { tiles: { terrain }, coordinates: { top: { x, y } }, water } = cell
  const { slopes } = terrain
  const offsetX = x
  const offsetY = (slopes[0] === 1 || slopes[1] === 1 || slopes[2] === 1 || slopes[3] === 1)
    ? (water === 1) ? y : y - debug.layerOffset
    : (water === 1) ? y + debug.layerOffset : y

  drawVectorTile(terrain, fillColor, lineColor, textColor, offsetX, offsetY)
}
