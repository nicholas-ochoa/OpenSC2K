export const imageRow = bytes => {
  let pixelData = bytes
  let padding = 0
  let length = 0
  let extra = 0
  let pixels = null
  // let count = pixelData[0]
  let mode = pixelData[1]
  let imageArray = []
  let bytesParsed = 0
  let headerLength = 0

  // loop through the row chunks
  while (true) {
    pixelData = pixelData.subarray(bytesParsed)

    // special case for multi-chunk rows, drop first byte if zero
    if (pixelData[0] === 0x00 && bytesParsed > 0) pixelData = pixelData.subarray(1)

    if (pixelData.length <= 0) break

    bytesParsed = 0
    mode = pixelData[1] // read mode

    if (mode === 0 || mode === 3) {
      padding = pixelData[0] // padding pixels from the left edge
      length = pixelData[2] // pixels in the row to draw
      extra = pixelData[3] // extra bit / flag

      if (length === 0 && extra === 0) {
        length = pixelData[4]
        extra = pixelData[5]
        pixels = pixelData.subarray(6, 6 + length)
        headerLength = 6
      } else {
        pixels = pixelData.subarray(4, 4 + length)
        headerLength = 4
      }
    } else if (mode === 4) {
      length = pixelData[0]
      pixels = pixelData.subarray(2, 2 + length)
      headerLength = 2
    }

    // byte offset for the next loop
    bytesParsed += headerLength + length

    // save padding pixels (transparent) as null
    for (let i = 0; i < parseInt(padding, 10); i++) imageArray.push(null)

    // save pixel data afterwards
    for (const pixel of pixels) imageArray.push(pixel)
  }

  return imageArray
}
