import graphics from "./"

// draws a vector line
// todo: normalize the input params offsetX/offsetY
export const drawLine = (x1, y1, x2, y2, color = `white`, width = 1, renderingArea = graphics.interfaceContext) => {
  renderingArea.strokeStyle = color
  renderingArea.lineWidth = width
  renderingArea.beginPath()
  renderingArea.moveTo(Math.floor(x1), Math.floor(y1))
  renderingArea.lineTo(Math.floor(x2), Math.floor(y2))
  renderingArea.stroke()
  renderingArea.closePath()
}
