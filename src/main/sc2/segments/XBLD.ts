import { cells } from '../data';
import { bin2str } from 'utils';
import tiles from 'tiles';

export function XBLD(data: any) {
  const view = new Uint8Array(data);

  view.forEach((bits, i) => {
    const xbld: any = {};

    if (tiles.data[bits]) {
      xbld.id = bits;
      xbld.type = tiles.data[bits].type || xbld.type;
      xbld.subtype = tiles.data[bits].subtype || xbld.subtype;
    }

    if (xbld.id > 0) {
      xbld.desc = tiles.data[xbld.id];
    }

    // raw binary values as strings for research/debug
    xbld.binaryText = {
      bits: bin2str(bits, 8),
    };

    cells[i].segments.XBLD = xbld;
  });
}
