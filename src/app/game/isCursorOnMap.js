import { isInsideClipBoundary } from "@/app/graphics"
import ui from "@/app/ui"
import game from "./"

export const isCursorOnMap = () => (
  ui.cursorTileX >= 0
  && ui.cursorTileX < game.tilesX
  && ui.cursorTileY >= 0 && ui.cursorTileY < game.tilesY
  && isInsideClipBoundary(ui.cursorX, ui.cursorY)
)
