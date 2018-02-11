import { binaryString, hexString } from "../"

// signs, microsim labels, xthg data / references
export const XTXT = (segment, { tiles }) => {
  (new Uint8Array(segment)).forEach((square, i) => {
    let txt = {
      raw: binaryString(square, 1)
    }

    if (square === 0x00) {
      txt.sign = false
      txt.microsimLabel = false
    } else if (square >= 0x01 && square <= 0x32) {
      txt.sign = true
      txt.microsimLabel = false
      txt.xlabId = hexString(square, 1)
    } else if (square >= 0x33 && square <= 0xC9) {
      txt.sign = false
      txt.microsimLabel = true
      txt.xlabId = hexString(square, 1)
    } else if (square >= 0xC9) {
      txt.sign = false
      txt.microsimLabel = false
      txt.xthgData = hexString(square, 1)
    }

    tiles[i].XTXT = txt
  })
}
