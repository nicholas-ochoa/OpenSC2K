import { data } from '../data';
import tiles from 'tiles';

export function XUND(bytes: Buffer) {
  bytes.forEach((bits, i) => {
    const xund: any = {};

    xund.id = bits;

    if (xund.id > 0) {
      xund.type = tiles.data[xund.id].type || null;
      xund.subtype = tiles.data[xund.id].subtype || null;
      xund.desc = tiles.data[xund.id];
    }

    data.cells[i].segments.XUND = xund;
  });
}
