import { colors } from "@/app/constants"
import data from "@/app/data"
import events from "@/app/events"
import game, { isCursorOnMap, getMapCell } from "@/app/game"
import graphics, { drawPoly } from "@/app/graphics"
import ui from "@/app/ui"
import debug from "./"

export const debugOverlay = () => {
  if (!debug.showOverlayInfo) return
  const { cursorX, cursorY, cursorTileX, cursorTileY, selectedTileX, selectedTileY } = ui

  const width = 280
  const height = 100
  let line = 25

  // draw box
  drawPoly([{ x: 0, y: 0 }, { x: width, y: 0 }, { x: width, y: height }, { x: 0, y: height }, { x: 0, y: 0 }], colors.black40, colors.white70, 10, 10)

  // draw text
  graphics.interfaceContext.font = `10px Verdana`
  graphics.interfaceContext.fillStyle = colors.white90

  if (isCursorOnMap()) {
    const { x, y, z } = getMapCell(cursorTileX, cursorTileY)
    graphics.interfaceContext.fillText(`tile x: ${x}, y: ${y}, z: ${z}`, 20, line)
    line += 15
  }

  graphics.interfaceContext.fillText(`cursor x: ${cursorX}, y: ${cursorY}`, 20, line)
  line += 15
  graphics.interfaceContext.fillText(`selected tile x: ${selectedTileX}, y: ${selectedTileY}`, 20, line)
  line += 15
  graphics.interfaceContext.fillText(`map rotation: ${game.mapRotation}`, 20, line)
  line += 15
  graphics.interfaceContext.fillText(`city rotation: ${data.cityRotation}`, 20, line)
  line += 15
  graphics.interfaceContext.fillText(`active cursor tool: ${events.activeCursorTool}`, 20, line)
}
