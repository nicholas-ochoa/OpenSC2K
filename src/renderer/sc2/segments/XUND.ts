import { data } from '../data';
import { bin2str } from 'utils';
import tiles from 'tiles';

export function XUND(bytes: any) {
  const view = new Uint8Array(bytes);

  view.forEach((bits, i) => {
    const xund: any = {};

    xund.id = bits;

    if (xund.id > 0) {
      xund.type = tiles.data[xund.id].type || null;
      xund.subtype = tiles.data[xund.id].subtype || null;
      xund.desc = tiles.data[xund.id];
    }

    // raw binary values as strings for research/debug
    xund.binaryText = {
      bits: bin2str(bits, 8),
    };

    data.cells[i].segments.XUND = xund;
  });
}
