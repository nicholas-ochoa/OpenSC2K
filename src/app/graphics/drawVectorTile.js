import data from "@/app/data"
import graphics, { drawLines, drawPoly } from "./"

// draws a "vector" based tile
// todo: needs work, vector tiles are now pre-generated and included on tilemaps
export const drawVectorTile = (tileId, fillColor, strokeColor, innerStrokeColor, offsetX, offsetY, renderingArea = graphics.interfaceContext) => {
  const cacheId = tileId + fillColor + strokeColor + innerStrokeColor

  if (graphics.vectorTileCache[cacheId]) {
    renderingArea.drawImage(graphics.vectorTileCache[cacheId], offsetX - 64, offsetY - 64)
    return
  }

  const { polygon, lines } = data.tiles[tileId]

  let cacheCanvas = document.createElement(`canvas`)
  let cacheContext = cacheCanvas.getContext(`2d`)
  cacheContext.canvas.width = 128
  cacheContext.canvas.height = 128

  if (polygon) drawPoly(polygon, fillColor, strokeColor, 64, 64, 2, cacheContext)
  if (lines) drawLines(lines, innerStrokeColor, 64, 64, cacheContext)
  graphics.vectorTileCache[cacheId] = cacheCanvas
  renderingArea.drawImage(cacheCanvas, offsetX - 64, offsetY - 64)
}
