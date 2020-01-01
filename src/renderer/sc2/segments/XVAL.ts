import { data } from '../data';
import { resize } from 'utils';

export function XVAL(bytes: any) {
  const view = new Uint8Array(bytes);
  let xval = [];

  view.forEach((bits, i) => {
    xval[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xval = resize(xval, 64, 128);

  xval.forEach((bytes, i) => {
    data.cells[i].segments.XVAL = xval[i];
  });
}
