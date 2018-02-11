import { colors } from "@/app/constants"
import graphics, { drawPoly } from "@/app/graphics"
import debug from "./"

export const drawClipBounds = () => {
  if (!debug.showClipBounds) return
  const { clipBoundary: { top }, interfaceContext: { canvas: width, height } } = graphics

  drawPoly([
    { x: top, y: top },
    { x: width - top, y: top },
    { x: width - top, y: height - top },
    { x: top, y: height - top },
    { x: top, y: top }
  ], colors.black0, colors.red90, 0, 0, 3)
}
