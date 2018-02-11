import { updateCanvasSize } from "@/app/graphics"
import debug from "./"

export const toggleClipBoundDebug = () => {
  debug.showClipBounds = !debug.showClipBounds
  debug.clipOffset = (debug.showClipBounds) ? 400 : 0
  updateCanvasSize()
}
