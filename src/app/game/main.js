import { startDebugging, debugLoop, endDebugging, drawDebugLayer } from "@/app/debug"
import graphics, { clearCanvas, loadingMessage, loopEnd } from "@/app/graphics"
import ui, { selectionBox } from "@/app/ui"
import game, { getMapCell, drawTerrainEdge, drawTerrainTile, drawZoneTile, drawNetworkTile, drawBuildingTile, isCursorOnMap } from "./"

export const main = () => {
  startDebugging()
  clearCanvas()

  if (!graphics.ready) {
    loadingMessage()
    endDebugging()
    return
  }

  for (let tY = 0; tY < game.tilesY; tY++) {
    for (let tX = (game.tilesX - 1); tX >= 0; tX--) {
      const cell = getMapCell(tX, tY)

      drawTerrainEdge(cell)
      drawTerrainTile(cell)
      drawZoneTile(cell)
      drawNetworkTile(cell)
      drawBuildingTile(cell)

      drawDebugLayer(cell)
    }
  }

  // selection box under cursor
  if (isCursorOnMap()) selectionBox(ui.cursorTileX, ui.cursorTileY)

  // selection cube
  //if (isCursorOnMap() && ui.selectedTileX >= 0 && ui.selectedTileY >= 0) selectionCube(ui.selectedTileX, ui.selectedTileY)

  // run any remaining debug code
  debugLoop()
  endDebugging()

  loopEnd()
}
