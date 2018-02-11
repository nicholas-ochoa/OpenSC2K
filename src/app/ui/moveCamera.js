import { updateCanvasSize } from "@/app/graphics"
import ui from "./"

export const moveCamera = direction => {
  //console.log(`Move Camera: ${direction}`)
  const moveOffset = 40

  if (direction === `up`) ui.cameraOffsetY += moveOffset
  if (direction === `down`) ui.cameraOffsetY -= moveOffset
  if (direction === `left`) ui.cameraOffsetX += moveOffset
  if (direction === `right`) ui.cameraOffsetX -= moveOffset

  updateCanvasSize()
}
