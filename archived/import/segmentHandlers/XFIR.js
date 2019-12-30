import { resize } from './common';

export default (data, map) => {
  let view = new Uint8Array(data);
  let xfir = [];

  view.forEach((bits, i) => {
    xfir[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xfir = resize(xfir, 32, 128);

  xfir.forEach((data, i) => {
    map.cells[i]._segmentData.XFIR = xfir[i];
  });
};