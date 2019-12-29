import { bin2str } from './common';

export default (data, map) => {
  let view = new Uint8Array(data);

  view.forEach((bits, i) => {
    let xbit = {};

    // can this tile receive power?
    xbit.wired         = (bits & 0b10000000) !== 0;

    // does this tile HAVE power?
    xbit.powered       = (bits & 0b01000000) !== 0;

    // can this tile receive piped water?
    xbit.piped         = (bits & 0b00100000) !== 0;

    // does this tile HAVE piped water?
    xbit.watered       = (bits & 0b00010000) !== 0;

    // mask for XVAL
    // not currently used
    //xbit.xvalMask      = (bits & 0b00001000) !== 0;

    // is this tile covered by water?
    xbit.waterCovered  = (bits & 0b00000100) !== 0;

    // rotate tile by 90 degrees?
    xbit.rotate        = (bits & 0b00000010) !== 0;

    // is tile salt water or fresh water?
    xbit.saltWater     = (bits & 0b00000001) !== 0;

    xbit.binaryText = {
      bits: bin2str(bits, 8),
    };

    map.cells[i]._segmentData.XBIT = xbit;
  });
};