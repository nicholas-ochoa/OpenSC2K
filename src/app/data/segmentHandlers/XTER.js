import data, { binaryString } from "../"

export const XTER = (segment, { tiles }) => {
  (new Uint8Array(segment)).forEach((square, i) => {
    let terrain = {
      id: (square & 0x0F),
      raw: binaryString(square, 1),
      slope: null,
      surfaceWater: null,
      waterLevel: null,
      waterLevelHex: 0x0
    }

    // dry land, underwater, surface water
    if (square < 0x3E) {
      terrain = {
        ...terrain,
        slope: data.xterSlopeMap[(square & 0x0F)],
        //surfaceWater: data.xterSlopeMap[0],
        surfaceWater: (square & 0x0F),
        waterLevel: data.waterLevels[((square & 0xF0) >> 4)],
        waterLevelHex: (square & 0xF0) >> 4
      }
    // waterfall special case
    } else if (square === 0x3E) {
      terrain = {
        ...terrain,
        slope: data.xterSlopeMap[0],
        //surfaceWater: data.xterSlopeMap[0],
        surfaceWater: (square & 0x0F),
        waterLevel: data.waterLevels[0x4],
        waterLevelHex: 0x4
      }
    // surface water cont.
    } else if (square >= 0x40) {
      terrain = {
        ...terrain,
        slope: data.xterSlopeMap[0],
        //surfaceWater: data.xterWaterMap[(square & 0x0F)],
        surfaceWater: (square & 0x0F),
        waterLevel: data.waterLevels[0x3],
        waterLevelHex: 0x3
      }
    }

    tiles[i].XTER = terrain
  })
}
