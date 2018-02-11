export const imageBlock = bytes => {
  // let length = 0
  let offset = 0
  let img = []

  while (true) {
    let row = {}

    row.length = parseInt(bytes.subarray(offset + 0, offset + 1), 10)
    row.more = bytes.subarray(offset + 1, offset + 2)

    offset += 2

    row.data = bytes.subarray(offset, offset + row.length)
    row.parsedData = this.imageRow(row.data)

    img.push(row)

    if (row.more !== 1) break

    offset += row.length
  }

  return img
}
