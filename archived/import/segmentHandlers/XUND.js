import { bin2str } from './common';
import tiles from '../tiles';

export default (data, map) => {
  let view = new Uint8Array(data);

  view.forEach((bits, i) => {
    let xund = { desc: null };

    xund.id = bits;

    if (xund.id > 0) {
      xund.type     = tiles[xund.id].type    || null;
      xund.subtype  = tiles[xund.id].subtype || null;
      xund.desc = tiles[xund.id];
    }

    // raw binary values as strings for research/debug
    xund.binaryText = {
      bits: bin2str(bits, 8)
    };

    map.cells[i]._segmentData.XUND = xund;
  });
};