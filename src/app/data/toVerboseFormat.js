import data, { segmentHandlers } from "./"

export const toVerboseFormat = segments => {
  let x = 0
  let y = 0

  data.struct = {
    tiles: new Array(128 * 128).fill({}).map((tile, i) => {
      if (y === 128) {
        y = 0
        x++
      }
      tile.x = x
      tile.y = y
      y++
      return tile
    })
  }

  Object.keys(segments).forEach(segmentTitle => {
    const segment = segments[segmentTitle]
    const handler = segmentHandlers[segmentTitle]

    if (handler) handler(segment, data.struct)
  })
}
