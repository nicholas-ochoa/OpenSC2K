import { colors } from "@/app/constants"
import game, { getMapCell } from "@/app/game"
import graphics, { drawVectorTile, isCellInsideClipBoundary, getTile } from "@/app/graphics"

export const selectionBox = (tX, tY, lineColor = colors.yellow75, width = 2, fillColor = colors.black0) => {
  const cell = getMapCell(tX, tY)
  if (!isCellInsideClipBoundary(cell)) return
  const { coordinates: { top: { x, y } }, tiles: { terrain }, water } = cell
  const { id, slopes } = getTile(terrain)
  const offsetY = (slopes[0] === 1 || slopes[1] === 1 || slopes[2] === 1 || slopes[3] === 1)
    ? (water === 1) ? y : y - game.layerOffset
    : (water === 1) ? y + game.layerOffset : y

  drawVectorTile(id, fillColor, lineColor, colors.black0, x, offsetY, graphics.scaledInterfaceContext)
}
