import { resize } from './common';

export default (data, map) => {
  let view = new Uint8Array(data);
  let xrog = [];

  view.forEach((bits, i) => {
    xrog[i] = bits;
  });
  
  // resize data array from 64x64 to 128x128
  xrog = resize(xrog, 32, 128);

  xrog.forEach((data, i) => {
    map.cells[i]._segmentData.XROG = xrog[i];
  });
};