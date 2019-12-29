import { cells } from '../data';
import { resize } from 'utils';

export function XVAL(data: any) {
  const view = new Uint8Array(data);
  let xval = [];

  view.forEach((bits, i) => {
    xval[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xval = resize(xval, 64, 128);

  xval.forEach((data, i) => {
    cells[i].segments.XVAL = xval[i];
  });
}
