import { data } from '../data';
import { resize } from 'utils';

export function XPLC(bytes: any) {
  const view = new Uint8Array(bytes);
  let xplc = [];

  view.forEach((bits, i) => {
    xplc[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xplc = resize(xplc, 32, 128);

  xplc.forEach((bytes, i) => {
    data.cells[i].segments.XPLC = xplc[i];
  });
}
