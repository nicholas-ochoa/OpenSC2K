import { data } from '../data';
import { resize } from '../resize';

export function XTRF(bytes: any) {
  let xtrf = [];

  bytes.forEach((bits, i) => {
    xtrf[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xtrf = resize(xtrf, 64, 128);

  xtrf.forEach((bytes, i) => {
    data.cells[i].segments.XTRF = xtrf[i];
  });
}
