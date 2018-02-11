import data from "@/app/data"
import { isInsideClipBoundary } from "@/app/graphics"
import ui from "@/app/ui"
import game from "./"

export const getTileUnderCursor = event => {
  ui.cursorX = event.pageX
  ui.cursorY = event.pageY

  for (let tX = (game.tilesX - 1); tX >= 0; tX--) {
    for (let tY = 0; tY < game.tilesY; tY++) {
      const { top, left, bottom, right } = data.map[tX][tY].coordinates
      if (isInsideClipBoundary(tX, tY)
        && ui.cursorY > top.y
        && ui.cursorY < bottom.y
        && ui.cursorX > left.x
        && ui.cursorX < right.x
      ) {
        ui.cursorTileX = tX
        ui.cursorTileY = tY
      }
    }
  }
}
