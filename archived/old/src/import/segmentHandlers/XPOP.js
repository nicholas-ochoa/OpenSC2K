import { resize } from './common';

export default (data, map) => {
  let view = new Uint8Array(data);
  let xpop = [];

  view.forEach((bits, i) => {
    xpop[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xpop = resize(xpop, 32, 128);

  xpop.forEach((data, i) => {
    map.cells[i]._segmentData.XPOP = xpop[i];
  });
};