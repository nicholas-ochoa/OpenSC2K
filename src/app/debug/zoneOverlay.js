import { colors } from "@/app/constants"
import graphics, { getTile } from "@/app/graphics"
import { selectionBox } from "@/app/ui"
import debug from "./"

export const zoneOverlay = ({ x, y, coordinates: { center }, tiles: { zone } }) => {
  if (!debug.showZoneOverlay || zone === 0) return

  const { name, type } = getTile(zone)
  const color = colors[name] ? colors[name] : colors.grey30

  graphics.interfaceContext.font = `8px Verdana`
  graphics.interfaceContext.fillStyle = colors.white70
  graphics.interfaceContext.fillText(type, center.x - 10, center.y + 3)
  selectionBox(x, y, color)
}
