import { data } from '../data';
import { resize } from '../resize';

export function XFIR(bytes: Buffer) {
  let xfir = [];

  bytes.forEach((bits, i) => {
    xfir[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xfir = resize(xfir, 32, 128);

  xfir.forEach((bytes, i) => {
    data.cells[i].segments.XFIR = xfir[i];
  });
}
