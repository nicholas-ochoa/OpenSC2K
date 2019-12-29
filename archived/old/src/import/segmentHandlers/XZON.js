import { bin2str } from './common';

export default (data, map) => {
  let view = new Uint8Array(data);

  view.forEach((bits, i) => {
    let xzon = {};

    // indicates the tile is a key / corner tile
    // for a building larger than 1x1 tile
    xzon.top    = (bits & 0b00010000) !== 0;
    xzon.right  = (bits & 0b00100000) !== 0;
    xzon.bottom = (bits & 0b01000000) !== 0;
    xzon.left   = (bits & 0b10000000) !== 0;

    // indicates the tile has no key / corners set
    xzon.none   = (bits & 0b11110000) === 0;

    // tile zone id and type
    xzon.zone        = xzonMap[bits & 0b00001111].id;
    xzon.zoneType    = xzonMap[bits & 0b00001111].type;

    // raw binary values as strings for research/debug
    xzon.binaryText = {
      bits:       bin2str(bits, 8),
      first4bits: bin2str((bits & 0b11110000) >> 4, 4),
      last4bits:  bin2str(bits & 0b00001111, 4)
    };

    map.cells[i]._segmentData.XZON = xzon;
  });
};

let xzonMap = {
  0x00: { id: null, type: null },
  0x01: { id: 291,  type: 'l_res' },
  0x02: { id: 292,  type: 'd_res' },
  0x03: { id: 293,  type: 'l_comm' },
  0x04: { id: 294,  type: 'd_comm' },
  0x05: { id: 295,  type: 'l_ind' },
  0x06: { id: 296,  type: 'd_ind' },
  0x07: { id: 297,  type: 'mil' },
  0x08: { id: 298,  type: 'air' },
  0x09: { id: 299,  type: 'sea' },
};