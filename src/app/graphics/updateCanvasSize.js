import data from "@/app/data"
import debug from "@/app/debug"
import game from "@/app/game"
import ui from "@/app/ui"
import graphics, { getCoordinates } from "./"

// called on page load, resize events
// updates the canvas width and height
// updates the camera clipping bounds
// updates all map cell coordinates
// sets the game origin X/Y coordinates
export const updateCanvasSize = () => {
  graphics.drawFrame = true

  const width = document.documentElement.clientWidth
  const height = document.documentElement.clientHeight

  graphics.primaryCanvas.width = width
  graphics.primaryCanvas.height = height

  graphics.interfaceCanvas.width = width
  graphics.interfaceCanvas.height = height

  game.originX = (width / 2 - game.tilesX * graphics.tileWidth / 2) + ui.cameraOffsetX
  game.originY = (height / 2) + ui.cameraOffsetY

  for (let tX = (game.tilesX - 1); tX >= 0; tX--) {
    for (let tY = 0; tY < game.tilesY; tY++) {
      data.map[tX][tY].coordinates = getCoordinates(data.map[tX][tY])
    }
  }

  // set viewport clipping boundary
  graphics.clipBoundary = {
    top: 0 + (graphics.clipOffset.top + debug.clipOffset),
    right: 0 + graphics.primaryContext.canvas.width - (graphics.clipOffset.right + debug.clipOffset),
    bottom: 0 + graphics.primaryContext.canvas.height - (graphics.clipOffset.bottom + debug.clipOffset),
    left: 0 + (graphics.clipOffset.left + debug.clipOffset)
  }
}
