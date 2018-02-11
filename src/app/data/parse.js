import data, { loadCity, splitIntoSegments, toVerboseFormat } from "./"

export const parse = (bytes, options) => {
  const buffer = new Uint8Array(bytes)
  const fileHeader = buffer.subarray(0, 12) // eslint-disable-line
  const rest = buffer.subarray(12)
  const segments = splitIntoSegments(rest)

  toVerboseFormat(segments)
  log(data.struct)

  loadCity()
}
