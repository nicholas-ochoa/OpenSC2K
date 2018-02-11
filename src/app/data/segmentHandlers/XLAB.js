// user text / labels / signs
export const XLAB = (segment, struct) => {
  // labels (1 byte len + 24 byte string)
  const view = new Uint8Array(segment)
  let labels = []

  for (let i = 0; i < 256; i++) {
    const labelPos = i * 25
    const labelLength = Math.max(0, Math.min(view[labelPos], 24))
    const labelData = view.subarray(labelPos + 1, labelPos + 1 + labelLength)

    labels[i] = Array.prototype.map.call(labelData, x => String.fromCharCode(x)).join(``)
  }

  struct.XLAB = labels
}
