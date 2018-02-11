class State {
  cityLoaded = false
  tiles = []
  map = []

  alreadyDecompressedSegments = {
    ALTM: true,
    CNAM: true
  }

  xzonTypeMap = {
    '0000': 0,
    '0001': 1,
    '0010': 2,
    '0011': 3,
    '0100': 4,
    '0101': 5,
    '0110': 6,
    '0111': 7,
    '1000': 8,
    '1001': 9
  }

  xterSlopeMap = {
    //    T R B L           B L R T
    0x0: [0, 0, 0, 0], //0x0: [0,0,0,0], 256

    0x1: [0, 0, 1, 1], //0x1: [1,1,0,0], 260
    0x2: [1, 0, 0, 1], //0x2: [0,1,0,1], 257
    0x3: [1, 1, 0, 0], //0x3: [0,0,1,1], 258
    0x4: [0, 1, 1, 0], //0x4: [1,0,1,0], 259

    0x5: [1, 0, 1, 1], //0x5: [1,1,0,1], 264
    0x6: [1, 1, 0, 1], //0x6: [0,1,1,1], 261
    0x7: [1, 1, 1, 0], //0x7: [1,0,1,1], 262
    0x8: [0, 1, 1, 1], //0x8: [1,1,1,0], 263

    0x9: [0, 0, 0, 1], //0x9: [0,1,0,0], 268
    0xA: [1, 0, 0, 0], //0xA: [0,0,0,1], 265
    0xB: [0, 1, 0, 0], //0xB: [0,0,1,0], 266
    0xC: [0, 0, 1, 0], //0xC: [1,0,0,0], 267

    0xD: [1, 1, 1, 1] //0xD: [1,1,1,1]  269
  }

  xterTerrainTileMap = {
    0x0: 256,

    0x1: 260,
    0x2: 257,
    0x3: 258,
    0x4: 259,
    0x5: 264,
    0x6: 261,
    0x7: 262,
    0x8: 263,
    0x9: 268,
    0xA: 265,
    0xB: 266,
    0xC: 267,

    0xD: 269
  }

  xterWaterMap = {
    0x0: [1, 0, 0, 1], // left-right open canal
    0x1: [0, 1, 1, 0], // top-bottom open canal
    0x2: [1, 1, 0, 1], // right open bay
    0x3: [1, 0, 1, 1], // left open bay
    0x4: [0, 1, 1, 1], // top open bay
    0x5: [1, 1, 1, 0] // bottom open bay
  }

  waterLevels = {
    0x0: `dry`,
    0x1: `submerged`,
    0x2: `shore`,
    0x3: `surface`,
    0x4: `waterfall`
  }
}

export const state = new State()
