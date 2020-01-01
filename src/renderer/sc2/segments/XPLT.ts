import { data } from '../data';
import { resize } from 'utils';

export function XPLT(bytes: any) {
  const view = new Uint8Array(bytes);
  let xplt = [];

  view.forEach((bits, i) => {
    xplt[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xplt = resize(xplt, 64, 128);

  xplt.forEach((bytes, i) => {
    data.cells[i].segments.XPLT = xplt[i];
  });
}
