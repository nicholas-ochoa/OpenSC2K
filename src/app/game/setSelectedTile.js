import ui from "@/app/ui"
import { isCursorOnMap } from "./"

export const setSelectedTile = () => {
  const cursorOnMap = isCursorOnMap()
  ui.selectedTileX = cursorOnMap ? ui.cursorTileX : -1
  ui.selectedTileY = cursorOnMap ? ui.cursorTileY : -1
}
