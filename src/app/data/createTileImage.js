import { colors } from "@/app/constants"
import { writeImageToFile } from "./"

export const createTileImage = (imageId, { width, height, imageBlock }) => {
  let canvas = document.createElement(`canvas`)
  canvas.width = width * 2
  canvas.height = height * 2
  let context = canvas.getContext(`2d`)
  context.scale(2, 2)

  let x = 0
  let y = 0

  for (const row of imageBlock) {
    x = 0
    for (const { pixelData } of row) {
      context.fillStyle = colors.lookup(pixelData)
      context.fillRect(x, y, 1, 1)
      x++
    }
    y++
  }

  canvas.toBlob(blob => {
    let fileReader = new FileReader()

    fileReader.onload = event => {
      writeImageToFile(imageId, event.target.result)
    }

    fileReader.readAsArrayBuffer(blob)
  })
}
