import { cells } from '../data';
import { resize } from 'utils';

export function XTRF(data: any) {
  const view = new Uint8Array(data);
  let xtrf = [];

  view.forEach((bits, i) => {
    xtrf[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xtrf = resize(xtrf, 64, 128);

  xtrf.forEach((data, i) => {
    cells[i].segments.XTRF = xtrf[i];
  });
}
