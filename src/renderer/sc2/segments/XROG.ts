import { data } from '../data';
import { resize } from '../resize';

export function XROG(bytes: Buffer) {
  let xrog = [];

  bytes.forEach((bits, i) => {
    xrog[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xrog = resize(xrog, 32, 128);

  xrog.forEach((bytes, i) => {
    data.cells[i].segments.XROG = xrog[i];
  });
}
