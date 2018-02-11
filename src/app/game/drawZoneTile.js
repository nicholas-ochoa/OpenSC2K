import debug, { zoneOverlay } from "@/app/debug"
import { drawTile } from "@/app/graphics"

export const drawZoneTile = cell => {
  const { tiles: { zone } } = cell

  if (!zone) return

  if (debug.hideZones) {
    zoneOverlay(cell)
  } else {
    drawTile(zone, cell)
  }
}
