import { data } from '../data';
import { resize } from '../resize';

export function XPLC(bytes: Buffer) {
  let xplc = [];

  bytes.forEach((bits, i) => {
    xplc[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xplc = resize(xplc, 32, 128);

  xplc.forEach((bytes, i) => {
    data.cells[i].segments.XPLC = xplc[i];
  });
}
