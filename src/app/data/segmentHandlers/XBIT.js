export const XBIT = (segment, { tiles }) => {
  (new Uint8Array(segment)).forEach((square, i) => {
    tiles[i].XBIT = {
      conductive: (square & 0x80) !== 0,
      powered: (square & 0x40) !== 0,
      piped: (square & 0x20) !== 0,
      watered: (square & 0x10) !== 0,
      landValue: (square & 0x08) !== 0,
      waterCovered: (square & 0x04) !== 0,
      rotate: (square & 0x02) !== 0,
      saltWater: (square & 0x01) !== 0
      //raw = binaryString(square, 1)
    }
  })
}
