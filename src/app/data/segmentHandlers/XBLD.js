import { hexString } from "../"

export const XBLD = (segment, { tiles }) => {
  (new Uint8Array(segment)).forEach((square, i) => {
    tiles[i].XBLD = {
      id: square,
      idHex: hexString(square, 1)
    }
  })
}
