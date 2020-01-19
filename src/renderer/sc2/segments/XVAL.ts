import { data } from '../data';
import { resize } from '../resize';

export function XVAL(bytes: Buffer) {
  let xval = [];

  bytes.forEach((bits, i) => {
    xval[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xval = resize(xval, 64, 128);

  xval.forEach((bytes, i) => {
    data.cells[i].segments.XVAL = xval[i];
  });
}
