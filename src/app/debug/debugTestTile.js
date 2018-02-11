import { colors } from "@/app/constants"
import graphics, { drawLine } from "@/app/graphics"
import debug from "./"

export const debugTestTile = ({ coordinates: { top, right, bottom, left, center } }, type = `box`, color = colors.debug) => {
  const { interfaceContext: { canvas: { width, height } } } = graphics
  const topLeftX = 10
  const topLeftY = 10
  // const topRightX = width - 10
  // const topRightY = height - 10
  // const bottomLeftX = 10
  // const bottomLeftY = 10
  // const bottomRightX = width - 10
  // const bottomRightY = height - 10

  const topCenterX = width / 2
  const topCenterY = 10
  const rightCenterX = width - 10
  const rightCenterY = height / 2
  const bottomCenterX = width / 2
  const bottomCenterY = height - 10
  const leftCenterX = 10
  const leftCenterY = height / 2

  // debug: draw lines to the 4 corners and the center
  if (type === `lines`) {
    drawLine(center.x, center.y, topLeftX, topLeftY, color, 3)
    drawLine(top.x, top.y, topCenterX, topCenterY, color, 3)
    drawLine(right.x, right.y, rightCenterX, rightCenterY, color, 3)
    drawLine(bottom.x, bottom.y, bottomCenterX, bottomCenterY, color, 3)
    drawLine(left.x, left.y, leftCenterX, leftCenterY, color, 3)
  }

  // debug: draw a box around the tile image
  if (type === `box`) {
    drawLine(top.x, top.y, right.x, right.y, color, 2)
    drawLine(right.x, right.y, bottom.x, bottom.y, color, 2)
    drawLine(bottom.x, bottom.y, left.x, left.y, color, 2)
    drawLine(left.x, left.y, top.x, top.y, color, 2)
  }

  // debug: draw a polygon around the tile image
  if (type === `polygon`) {
    drawLine(left.x, left.y, top.x, top.y, color, 2)
    drawLine(top.x, top.y, right.x, right.y, color, 2)
    drawLine(left.x, left.y, left.x, left.y + debug.layerOffset, color, 2)
    drawLine(right.x, right.y, right.x, right.y + debug.layerOffset, color, 2)
    drawLine(left.x, left.y + debug.layerOffset, bottom.x, bottom.y + debug.layerOffset, color, 2)
    drawLine(bottom.x, bottom.y + debug.layerOffset, right.x, right.y + debug.layerOffset, color, 2)
  }
}
