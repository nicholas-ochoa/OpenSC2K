import { colors } from "@/app/constants"
import graphics, { getTile } from "@/app/graphics"
import { selectionBox } from "@/app/ui"
import debug from "./"

export const networkOverlay = ({ x, y, coordinates: { center }, tiles: { building } }) => {
  if (!debug.showNetworkOverlay) return

  const { name } = getTile(building)
  let line
  let fill

  if (name.substring(0, 4) === `road`) {
    line = colors.white90
    fill = colors.white30
  } else if (name.substring(0, 4) === `rail`) {
    line = colors.brown90
    fill = colors.brow30
  } else if (name.substring(0, 4) === `powe`) {
    line = colors.red90
    fill = colors.red30
  } else {
    return
  }

  graphics.interfaceContext.font = `8px Verdana`
  graphics.interfaceContext.fillStyle = colors.white25
  graphics.interfaceContext.fillText(name.substring(0, 8), x - 16, center.y + 3)
  selectionBox(x, y, line, 2, fill)
}
