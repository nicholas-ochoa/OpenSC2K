import { data } from '../data';
import { resize } from '../resize';

export function XCRM(bytes: Buffer) {
  let xcrm = [];

  bytes.forEach((bits, i) => {
    xcrm[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xcrm = resize(xcrm, 64, 128);

  xcrm.forEach((bytes, i) => {
    data.cells[i].segments.XCRM = xcrm[i];
  });
}
