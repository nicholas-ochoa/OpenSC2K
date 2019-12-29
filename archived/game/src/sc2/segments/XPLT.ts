import { cells } from '../data';
import { resize } from 'utils';

export function XPLT(data: any) {
  const view = new Uint8Array(data);
  let xplt = [];

  view.forEach((bits, i) => {
    xplt[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xplt = resize(xplt, 64, 128);

  xplt.forEach((data, i) => {
    cells[i].segments.XPLT = xplt[i];
  });
}
