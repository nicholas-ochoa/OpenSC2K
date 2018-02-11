import { colors } from "@/app/constants"
import graphics from "@/app/graphics"
import debug from "./"

export const drawDebugLayer = ({ coordinates: { center: { x, y } } }) => {
  if (!debug.showTileCount) return

  debug.tileCount++
  graphics.interfaceContext.font = `8px Verdana`
  graphics.interfaceContext.fillStyle = colors.white50
  graphics.interfaceContext.fillText(debug.tileCount, x - 10, y + 3)
}
