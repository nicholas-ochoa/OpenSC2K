import { data } from '../data';
import { resize } from 'utils';

export function XFIR(bytes: any) {
  const view = new Uint8Array(bytes);
  let xfir = [];

  view.forEach((bits, i) => {
    xfir[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xfir = resize(xfir, 32, 128);

  xfir.forEach((bytes, i) => {
    data.cells[i].segments.XFIR = xfir[i];
  });
}
