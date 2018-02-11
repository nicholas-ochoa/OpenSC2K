import { colors } from "@/app/constants"
import graphics, { drawLine } from "./"

// draws an array of vector lines
// todo: normalize the input params offsetX/offsetY
export const drawLines = (lines, width = 1, strokeColor = colors.red90, offsetX = 0, offsetY = 0, renderingArea = graphics.interfaceContext) => {
  if (!lines) return

  for (const { x1, x2, y1, y2 } of lines) {
    drawLine(x1 + offsetX, y1 + offsetY, x2 + offsetX, y2 + offsetY, strokeColor, width, renderingArea)
  }
}
