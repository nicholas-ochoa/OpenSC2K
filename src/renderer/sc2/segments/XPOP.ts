import { data } from '../data';
import { resize } from 'utils';

export function XPOP(bytes: any) {
  const view = new Uint8Array(bytes);
  let xpop = [];

  view.forEach((bits, i) => {
    xpop[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xpop = resize(xpop, 32, 128);

  xpop.forEach((bytes, i) => {
    data.cells[i].segments.XPOP = xpop[i];
  });
}
