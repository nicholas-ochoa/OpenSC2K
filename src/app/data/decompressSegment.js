export const decompressSegment = bytes => {
  let output = []
  let dataCount = 0

  for (let i = 0; i < bytes.length; i++) {
    if (dataCount > 0) {
      output.push(bytes[i])
      dataCount -= 1
    } else if (bytes[i] < 128) {
      // data bytes
      dataCount = bytes[i]
    } else {
      // run-length encoded byte
      const repeatCount = bytes[i] - 127
      const repeated = bytes[i + 1]

      for (let j = 0; j < repeatCount; j++) {
        output.push(repeated)
      }
      // skip the next byte
      i += 1
    }
  }

  return Uint8Array.from(output)
}
