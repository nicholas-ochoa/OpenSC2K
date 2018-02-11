import { createTileImage, imageBlock } from "./"

// parses the LARGE.dat
export const extract = bytes => {
  const fileSize = bytes.byteLength
  let imageHeaderSize = 10

  //todo: validate file here

  let view = new DataView(bytes.buffer)
  let imageCount = view.getUint16(0x00)
  let imageData = new DataView(bytes.buffer, 2, imageCount * imageHeaderSize)
  let offset = 0

  let images = {}
  let imageArray = []

  info(`Parsing Images..`)

  // calculate image ids, offsets and dimensions
  for (let i = 0; i < imageCount; i++) {
    let image = {}

    image.id = imageData.getUint16(offset)
    image.offsetBegin = imageData.getUint32(offset + 2)
    image.height = imageData.getUint16(offset + 6)
    image.width = imageData.getUint16(offset + 8)

    imageArray.push(image)

    offset += 10
  }

  // calculate image offset ends, size
  // get each image from the raw data
  imageCount = 0

  for (let i = 0; i < imageArray.length; i++) {
    // image offset ends
    if (imageArray[i + 1]) imageArray[i].offsetEnd = imageArray[i + 1].offsetBegin - 1
    else imageArray[i].offsetEnd = fileSize

    imageArray[i].size = imageArray[i].offsetEnd - imageArray[i].offsetBegin
    imageArray[i].data = bytes.subarray(imageArray[i].offsetBegin, imageArray[i].offsetEnd)

    // only count unique images (1204 and 1183 are duplicated)
    if (!images[imageArray[i].id]) imageCount++

    // save the last entry for each image id to the images object
    images[imageArray[i].id] = imageArray[i]
  }

  // create tile images
  info(`Writing Files..`)
  for (const [key, image] of Object.entries(images)) {
    image.imageBlock = imageBlock(image.data)
    createTileImage(key, image)
  }

  info(`Completed`)
}
