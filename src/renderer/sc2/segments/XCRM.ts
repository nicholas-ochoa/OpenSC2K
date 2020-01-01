import { data } from '../data';
import { resize } from 'utils';

export function XCRM(bytes: any) {
  const view = new Uint8Array(bytes);
  let xcrm = [];

  view.forEach((bits, i) => {
    xcrm[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xcrm = resize(xcrm, 64, 128);

  xcrm.forEach((bytes, i) => {
    data.cells[i].segments.XCRM = xcrm[i];
  });
}
