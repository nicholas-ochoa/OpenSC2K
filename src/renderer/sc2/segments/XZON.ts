import { data } from '../data';

export function XZON(bytes: Buffer) {
  bytes.forEach((bits, i) => {
    const xzon: any = {};

    // indicates the tile is a key / corner tile
    // for a building larger than 1x1 tile
    xzon.top = (bits & 0b00010000) !== 0;
    xzon.right = (bits & 0b00100000) !== 0;
    xzon.bottom = (bits & 0b01000000) !== 0;
    xzon.left = (bits & 0b10000000) !== 0;

    // indicates the tile has no key / corners set
    xzon.none = (bits & 0b11110000) === 0;

    // tile zone id and type
    xzon.zone = xzonMap[bits & 0b00001111];

    data.cells[i].segments.XZON = xzon;
  });
}

const xzonMap = {
  0x00: {},
  0x01: { id: 291, type: 'lightResidential' },
  0x02: { id: 292, type: 'denseResidential' },
  0x03: { id: 293, type: 'lightCommercial' },
  0x04: { id: 294, type: 'denseCommercial' },
  0x05: { id: 295, type: 'lightIndustrial' },
  0x06: { id: 296, type: 'denseIndustrial' },
  0x07: { id: 297, type: 'military' },
  0x08: { id: 298, type: 'airport' },
  0x09: { id: 299, type: 'seaport' },
};
