import { colors } from "@/app/constants"
import game, { getMapCell } from "@/app/game"
import { drawLine } from "@/app/graphics"

export const selectionCube = (tX, tY) => {
  //return
  const { tileHeight, tileWidth, layerOffset } = game
  const { height, width, coordinates: { top, left, bottom, right } } = getMapCell(tX, tY)

  let lineWidth = 1
  let lineColor = colors.white75
  let boxHeightUpper = 0
  let boxHeightLower = layerOffset

  let lineLength = 8
  let lineLengthMultiplier = 0.4

  // if (width == 4) {
  //   lineLength = 18
  //   lineLengthMultiplier = .4
  // } else if (width == 3) {
  //   lineLength = 16
  //   lineLengthMultiplier = 1
  // } else if (width == 2) {
  //   lineLength = 12
  //   lineLengthMultiplier = -1
  // } else if (width == 1) {
  //   lineLength = 8
  //   lineLengthMultiplier = .4
  // }
  //if (height > 2) boxHeightUpper = (height * state.layerOffset) - (state.layerOffset * 2) + (state.layerOffset / 2)
  //else
  boxHeightUpper = (height * layerOffset / 2)

  //top
  top.y -= boxHeightUpper
  bottom.y -= boxHeightUpper
  left.y -= boxHeightUpper
  right.y -= boxHeightUpper

  if (width === 1) {
    drawLine(top.x, top.y, right.x - (lineLength / lineLengthMultiplier), right.y - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(top.x, top.y, left.x + (lineLength / lineLengthMultiplier), left.y - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(top.x, top.y, top.x, top.y + lineLength, lineColor, lineWidth)
    drawLine(bottom.x, bottom.y, right.x - (lineLength / lineLengthMultiplier), right.y + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(bottom.x, bottom.y, left.x + (lineLength / lineLengthMultiplier), left.y + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(bottom.x, bottom.y, bottom.x, bottom.y + lineLength, lineColor, lineWidth)
    drawLine(left.x, left.y, top.x - (lineLength / lineLengthMultiplier), top.y + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(left.x, left.y, bottom.x - (lineLength / lineLengthMultiplier), bottom.y - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(left.x, left.y, left.x, left.y + lineLength, lineColor, lineWidth)
    drawLine(right.x, right.y, top.x + (lineLength / lineLengthMultiplier), top.y + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(right.x, right.y, bottom.x + (lineLength / lineLengthMultiplier), bottom.y - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(right.x, right.y, right.x, right.y + lineLength, lineColor, lineWidth)
  } else {
    drawLine(top.x, top.y, right.x - (tileHeight + lineLength / lineLengthMultiplier), right.y - (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(top.x, top.y, left.x + (tileHeight + lineLength / lineLengthMultiplier), left.y - (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(top.x, top.y, top.x, top.y + lineLength, lineColor, lineWidth)
    drawLine(bottom.x, bottom.y, right.x - (tileHeight + lineLength / lineLengthMultiplier), right.y + (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(bottom.x, bottom.y, left.x + (tileHeight + lineLength / lineLengthMultiplier), left.y + (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(bottom.x, bottom.y, bottom.x, bottom.y + lineLength, lineColor, lineWidth)
    drawLine(left.x, left.y, top.x - (tileHeight + lineLength / lineLengthMultiplier), top.y + (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(left.x, left.y, bottom.x - (tileHeight + lineLength / lineLengthMultiplier), bottom.y - (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(left.x, left.y, left.x, left.y + lineLength, lineColor, lineWidth)
    drawLine(right.x, right.y, top.x + (tileHeight + lineLength / lineLengthMultiplier), top.y + (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(right.x, right.y, bottom.x + (tileHeight + lineLength / lineLengthMultiplier), bottom.y - (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(right.x, right.y, right.x, right.y + lineLength, lineColor, lineWidth)
  }

  top.y += boxHeightUpper
  bottom.y += boxHeightUpper
  left.y += boxHeightUpper
  right.y += boxHeightUpper


  //bottom
  top.y -= boxHeightLower
  bottom.y -= boxHeightLower
  left.y -= boxHeightLower
  right.y -= boxHeightLower

  if (width === 1) {
    drawLine(bottom.x, bottom.y + boxHeightLower, right.x - (lineLength / lineLengthMultiplier), right.y + boxHeightLower + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(bottom.x, bottom.y + boxHeightLower, left.x + (lineLength / lineLengthMultiplier), left.y + boxHeightLower + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(bottom.x, bottom.y + boxHeightLower, bottom.x, bottom.y + boxHeightLower - lineLength, lineColor, lineWidth)
    drawLine(right.x, right.y + boxHeightLower, top.x + (lineLength / lineLengthMultiplier), top.y + boxHeightLower + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(right.x, right.y + boxHeightLower, bottom.x + (lineLength / lineLengthMultiplier), bottom.y + boxHeightLower - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(right.x, right.y + boxHeightLower, right.x, right.y + boxHeightLower - lineLength, lineColor, lineWidth)
    drawLine(left.x, left.y + boxHeightLower, top.x - (lineLength / lineLengthMultiplier), top.y + boxHeightLower + ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(left.x, left.y + boxHeightLower, bottom.x - (lineLength / lineLengthMultiplier), bottom.y + boxHeightLower - ((lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(left.x, left.y + boxHeightLower, left.x, left.y + boxHeightLower - lineLength, lineColor, lineWidth)
  } else {
    drawLine(bottom.x, bottom.y + boxHeightLower, right.x - (tileHeight + lineLength / lineLengthMultiplier), right.y + boxHeightLower + (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(bottom.x, bottom.y + boxHeightLower, left.x + (tileHeight + lineLength / lineLengthMultiplier), left.y + boxHeightLower + (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(bottom.x, bottom.y + boxHeightLower, bottom.x, bottom.y + boxHeightLower - lineLength, lineColor, lineWidth)
    drawLine(right.x, right.y + boxHeightLower, top.x + (tileHeight + lineLength / lineLengthMultiplier), top.y + boxHeightLower + (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(right.x, right.y + boxHeightLower, bottom.x + (tileHeight + lineLength / lineLengthMultiplier), bottom.y + boxHeightLower - (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(right.x, right.y + boxHeightLower, right.x, right.y + boxHeightLower - lineLength, lineColor, lineWidth)
    drawLine(left.x, left.y + boxHeightLower, top.x - (tileHeight + lineLength / lineLengthMultiplier), top.y + boxHeightLower + (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(left.x, left.y + boxHeightLower, bottom.x - (tileHeight + lineLength / lineLengthMultiplier), bottom.y + boxHeightLower - (tileWidth + (lineLength / 2) / lineLengthMultiplier), lineColor, lineWidth)
    drawLine(left.x, left.y + boxHeightLower, left.x, left.y + boxHeightLower - lineLength, lineColor, lineWidth)
  }

  top.y += boxHeightLower
  bottom.y += boxHeightLower
  left.y += boxHeightLower
  right.y += boxHeightLower
}
