import { cells } from '../data';
import { resize } from 'utils';

export function XPLC(data: any) {
  const view = new Uint8Array(data);
  let xplc = [];

  view.forEach((bits, i) => {
    xplc[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xplc = resize(xplc, 32, 128);

  xplc.forEach((data, i) => {
    cells[i].segments.XPLC = xplc[i];
  });
}
