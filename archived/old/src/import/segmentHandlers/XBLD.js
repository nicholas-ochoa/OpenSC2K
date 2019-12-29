import { bin2str } from './common';
import tiles from '../tiles';

export default (data, map) => {
  let view = new Uint8Array(data);

  view.forEach((bits, i) => {
    let xbld = {
      id: 0,
      type: null,
      subtype: null,
      desc: null
    };

    if (tiles[bits]) {
      xbld.id      = bits;
      xbld.type    = tiles[bits].type    || xbld.type;
      xbld.subtype = tiles[bits].subtype || xbld.subtype;
    }

    if (xbld.id > 0)
      xbld.desc = tiles[xbld.id];

    // raw binary values as strings for research/debug
    xbld.binaryText = {
      bits: bin2str(bits, 8)
    };

    map.cells[i]._segmentData.XBLD = xbld;
  });
};