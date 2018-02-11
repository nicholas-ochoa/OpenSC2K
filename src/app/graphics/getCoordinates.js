import game from "@/app/game"
import graphics from "./"

// calculate cell coordinates during tile load
// used for positioning tiles when drawing to the canvas
export const getCoordinates = ({ x, y, z }) => {
  // originally cell.width, needed?
  const cellWidth = 1
  const { tileWidth, tileHeight } = graphics

  const offX = x * tileWidth / 2 + y * tileWidth / 2 + game.originX
  let offY = y * tileHeight / 2 - x * tileHeight / 2 + game.originY

  if (z > 1) offY = offY - (game.layerOffset * z) + game.layerOffset

  const topX = offX + tileWidth / 2
  const topY = offY + tileHeight - (tileHeight * cellWidth)

  const rightX = offX + (tileWidth / 2) + ((tileWidth / 2) * cellWidth)
  const rightY = offY + tileHeight - ((tileHeight / 2) * cellWidth)

  const bottomX = (offX + tileWidth / 2)
  const bottomY = (offY + tileHeight)

  const leftX = offX + (tileWidth / 2) - ((tileWidth / 2) * cellWidth)
  const leftY = offY + tileHeight - ((tileHeight / 2) * cellWidth)

  const centerX = leftX + ((rightX - leftX) / 2)
  const centerY = topY - ((topY - bottomY) / 2)

  return {
    top: { x: topX, y: topY },
    right: { x: rightX, y: rightY },
    bottom: { x: bottomX, y: bottomY },
    left: { x: leftX, y: leftY },
    center: { x: centerX, y: centerY },
    polygon: [
      { x: topX, y: topY },
      { x: rightX, y: rightY },
      { x: rightX, y: rightY + game.layerOffset },
      { x: bottomX, y: bottomY + game.layerOffset },
      { x: leftX, y: leftY + game.layerOffset },
      { x: leftX, y: leftY },
      { x: topX, y: topY }
    ]
  }
}
