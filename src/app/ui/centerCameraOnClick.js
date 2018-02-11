import graphics, { updateCanvasSize } from "@/app/graphics"
import ui from "./"

export const centerCameraOnClick = () => {
  const centerX = graphics.primaryContext.canvas.width / 2
  const centerY = graphics.primaryContext.canvas.height / 2

  const cursorOffsetX = ui.cameraOffsetX - Math.floor(ui.cursorX - centerX)
  const cursorOffsetY = ui.cameraOffsetY - Math.floor(ui.cursorY - centerY)

  ui.cameraOffsetX += cursorOffsetX
  ui.cameraOffsetY += cursorOffsetY

  updateCanvasSize()
}
