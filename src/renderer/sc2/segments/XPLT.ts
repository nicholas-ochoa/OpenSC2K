import { data } from '../data';
import { resize } from '../resize';

export function XPLT(bytes: Buffer) {
  let xplt = [];

  bytes.forEach((bits, i) => {
    xplt[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xplt = resize(xplt, 64, 128);

  xplt.forEach((bytes, i) => {
    data.cells[i].segments.XPLT = xplt[i];
  });
}
