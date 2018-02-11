import { register } from "@/app/events"
import { updateCanvasSize } from "@/app/graphics"
import { loop } from "./"

export const start = () => {
  register()
  updateCanvasSize()
  requestAnimationFrame(loop)
}
