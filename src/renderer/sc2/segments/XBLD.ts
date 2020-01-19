import { data } from '../data';
import tiles from 'tiles';

export function XBLD(bytes: Buffer) {
  bytes.forEach((bits, i) => {
    const xbld: any = {};

    if (bits > 0) {
      xbld.id = bits;

      if (tiles.data[bits]?.type) {
        xbld.type = tiles.data[bits].type;
      }

      if (tiles.data[bits]?.subtype) {
        xbld.subtype = tiles.data[bits].subtype;
      }
    }

    data.cells[i].segments.XBLD = xbld;
  });
}
