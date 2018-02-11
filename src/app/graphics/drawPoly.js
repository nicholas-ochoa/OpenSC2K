import { colors } from "@/app/constants"
import graphics from "./"

// draws a vector polygon
// todo: normalize the input params offsetX/offsetY
export const drawPoly = (polygon, fillColor = colors.red25, strokeColor = colors.red90, offsetX = 0, offsetY = 0, width = 1, renderingArea = graphics.interfaceContext) => {
  if (polygon === null) return

  renderingArea.fillStyle = fillColor
  renderingArea.strokeStyle = strokeColor
  renderingArea.lineWidth = width
  renderingArea.beginPath()
  for (const { x, y } of polygon) {
    renderingArea.lineTo(Math.floor(x + offsetX), Math.floor(y + offsetY))
  }
  renderingArea.stroke()
  renderingArea.fill()
  renderingArea.closePath()
}
