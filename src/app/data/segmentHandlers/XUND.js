import data, { binaryString } from "../"

export const XUND = (segment, { tiles }) => {
  (new Uint8Array(segment)).forEach((square, i) => {
    let underground = {
      raw: binaryString(square, 1),
      subway: false,
      pipes: false,
      slope: null,
      subwayLeftRight: null,
      missileSilo: false,
      subwayStation: false
    }

    // subway, pipes
    if (square < 0x1E) {
      underground.slope = data.xterSlopeMap[(square & 0x0F)]
      if ((square & 0xF0) === 0x00) underground.subway = true
      else if (((square & 0xF0) === 0x10) && (square < 0x1F)) underground.pipes = true
    // subway / pipe crossover
    } else if ((square === 0x1F) || (square === 0x20)) {
      underground.subway = true
      underground.pipes = true
      underground.slope = data.xterSlopeMap[0x0]
      underground.subwayLeftRight = square === 0x1F
    // missile silo underground portion
    } else if (square === 0x22) {
      underground.missileSilo = true
    // subway station / subrail transition
    } else if (square === 0x23) {
      underground.subwayStation = true
      underground.slope = data.xterSlopeMap[0x0]
    }

    tiles[i].XUND = underground
  })
}
