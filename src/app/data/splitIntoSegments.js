import data, { decompressSegment } from "./"

export const splitIntoSegments = rest => {
  let temp = rest
  let segments = {}

  while (temp.length > 0) {
    const segmentTitle = Array.prototype.map.call(temp.subarray(0, 4), x => String.fromCharCode(x)).join(``)
    const lengthBytes = temp.subarray(4, 8)
    const segmentLength = new DataView(lengthBytes.buffer).getUint32(lengthBytes.byteOffset)
    let segmentContent = temp.subarray(8, 8 + segmentLength)

    if (!data.alreadyDecompressedSegments[segmentTitle]) segmentContent = decompressSegment(segmentContent)

    segments[segmentTitle] = segmentContent
    temp = temp.subarray(8 + segmentLength)
  }

  return segments
}
