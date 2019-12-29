import { bin2str } from './common';
import * as CONST from '../../constants';

export default (data, map) => {
  data.forEach((bits, i) => {
    let xter = {};

    xter.terrain = xterMap[bits].terrain;
    xter.water   = xterMap[bits].water;
    xter.type    = xterMap[bits].type;

    // raw binary values as strings for research/debug
    xter.binaryText = {
      bits: bin2str(bits, 8)
    };

    map.cells[i]._segmentData.XTER = xter;
  });
};


// terrain tile id is set in all cases
// so we know what type of terrain tile to
// display when water is hidden or heightmap
// is displayed
let xterMap = {
  // land
  0x00: { terrain: 256, water: null, type: CONST.TERRAIN_DRY },
  0x01: { terrain: 257, water: null, type: CONST.TERRAIN_DRY },
  0x02: { terrain: 258, water: null, type: CONST.TERRAIN_DRY },
  0x03: { terrain: 259, water: null, type: CONST.TERRAIN_DRY },
  0x04: { terrain: 260, water: null, type: CONST.TERRAIN_DRY },
  0x05: { terrain: 261, water: null, type: CONST.TERRAIN_DRY },
  0x06: { terrain: 262, water: null, type: CONST.TERRAIN_DRY },
  0x07: { terrain: 263, water: null, type: CONST.TERRAIN_DRY },
  0x08: { terrain: 264, water: null, type: CONST.TERRAIN_DRY },
  0x09: { terrain: 265, water: null, type: CONST.TERRAIN_DRY },
  0x0A: { terrain: 266, water: null, type: CONST.TERRAIN_DRY },
  0x0B: { terrain: 267, water: null, type: CONST.TERRAIN_DRY },
  0x0C: { terrain: 268, water: null, type: CONST.TERRAIN_DRY },
  0x0D: { terrain: 269, water: null, type: CONST.TERRAIN_DRY },

  // underwater
  0x10: { terrain: 256, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x11: { terrain: 257, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x12: { terrain: 258, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x13: { terrain: 259, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x14: { terrain: 260, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x15: { terrain: 261, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x16: { terrain: 262, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x17: { terrain: 263, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x18: { terrain: 264, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x19: { terrain: 265, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x1A: { terrain: 266, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x1B: { terrain: 267, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x1C: { terrain: 268, water: 270, type: CONST.TERRAIN_SUBMERGED },
  0x1D: { terrain: 269, water: 270, type: CONST.TERRAIN_SUBMERGED },

  // shoreline
  0x20: { terrain: 256, water: 270, type: CONST.TERRAIN_SHORE },
  0x21: { terrain: 257, water: 271, type: CONST.TERRAIN_SHORE },
  0x22: { terrain: 258, water: 272, type: CONST.TERRAIN_SHORE },
  0x23: { terrain: 259, water: 273, type: CONST.TERRAIN_SHORE },
  0x24: { terrain: 260, water: 274, type: CONST.TERRAIN_SHORE },
  0x25: { terrain: 261, water: 275, type: CONST.TERRAIN_SHORE },
  0x26: { terrain: 262, water: 276, type: CONST.TERRAIN_SHORE },
  0x27: { terrain: 263, water: 277, type: CONST.TERRAIN_SHORE },
  0x28: { terrain: 264, water: 278, type: CONST.TERRAIN_SHORE },
  0x29: { terrain: 265, water: 279, type: CONST.TERRAIN_SHORE },
  0x2A: { terrain: 266, water: 280, type: CONST.TERRAIN_SHORE },
  0x2B: { terrain: 267, water: 281, type: CONST.TERRAIN_SHORE },
  0x2C: { terrain: 268, water: 282, type: CONST.TERRAIN_SHORE },
  0x2D: { terrain: 269, water: 283, type: CONST.TERRAIN_SHORE },

  // surface water
  0x30: { terrain: 256, water: 270, type: CONST.TERRAIN_SURFACE },
  0x31: { terrain: 256, water: 271, type: CONST.TERRAIN_SURFACE },
  0x32: { terrain: 256, water: 272, type: CONST.TERRAIN_SURFACE },
  0x33: { terrain: 256, water: 273, type: CONST.TERRAIN_SURFACE },
  0x34: { terrain: 256, water: 274, type: CONST.TERRAIN_SURFACE },
  0x35: { terrain: 256, water: 275, type: CONST.TERRAIN_SURFACE },
  0x36: { terrain: 256, water: 276, type: CONST.TERRAIN_SURFACE },
  0x37: { terrain: 256, water: 277, type: CONST.TERRAIN_SURFACE },
  0x38: { terrain: 256, water: 278, type: CONST.TERRAIN_SURFACE },
  0x39: { terrain: 256, water: 279, type: CONST.TERRAIN_SURFACE },
  0x3A: { terrain: 256, water: 280, type: CONST.TERRAIN_SURFACE },
  0x3B: { terrain: 256, water: 281, type: CONST.TERRAIN_SURFACE },
  0x3C: { terrain: 256, water: 282, type: CONST.TERRAIN_SURFACE },
  0x3D: { terrain: 256, water: 283, type: CONST.TERRAIN_SURFACE },

  // waterfall
  0x3E: { terrain: 269, water: 284, type: CONST.TERRAIN_WATERFALL },

  // streams
  0x40: { terrain: 256, water: 285, type: CONST.TERRAIN_SURFACE },
  0x41: { terrain: 256, water: 286, type: CONST.TERRAIN_SURFACE },
  0x42: { terrain: 256, water: 287, type: CONST.TERRAIN_SURFACE },
  0x43: { terrain: 256, water: 288, type: CONST.TERRAIN_SURFACE },
  0x44: { terrain: 256, water: 289, type: CONST.TERRAIN_SURFACE },
  0x45: { terrain: 256, water: 290, type: CONST.TERRAIN_SURFACE },
};