import { colors } from "@/app/constants"
import debug from "./"
import graphics, { drawPoly } from "@/app/graphics"

export const showFrameStats = () => {
  const width = 170
  const height = 30
  const x = graphics.interfaceContext.canvas.width - width
  const y = graphics.interfaceContext.canvas.height - height

  drawPoly(
    // TODO: create basic shape utility functions
    [{ x: 0, y: 0 }, { x: width, y: 0 }, { x: width, y: height }, { x: 0, y: height }, { x: 0, y: 0 }],
    colors.black50,
    colors.white70,
    x + 10,
    y + 10
  )

  graphics.interfaceContext.font = `10px Verdana`
  graphics.interfaceContext.fillStyle = colors.white
  graphics.interfaceContext.fillText(`${debug.msPerFrame} m/s per frame (${debug.fps} FPS)`, x + 20, y + 24)
}
