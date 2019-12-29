import { resize } from './common';

export default (data, map) => {
  let view = new Uint8Array(data);
  let xtrf = [];

  view.forEach((bits, i) => {
    xtrf[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xtrf = resize(xtrf, 64, 128);

  xtrf.forEach((data, i) => {
    map.cells[i]._segmentData.XTRF = xtrf[i];
  });
};