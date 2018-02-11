import { colors } from "@/app/constants"
import graphics from "@/app/graphics"
import debug from "./"

export const cellCoordinates = ({ x, y, z, coordinates: { center } }) => {
  if (!debug.showTileCoordinates) return

  graphics.interfaceContext.font = `8px Verdana`
  graphics.interfaceContext.fillStyle = colors.white50
  graphics.interfaceContext.fillText(`${x}, ${y}, ${z}`, center.x - 16, center.y + 3)
}
