import { cells } from '../data';
import { resize } from 'utils';

export function XROG(data: any) {
  const view = new Uint8Array(data);
  let xrog = [];

  view.forEach((bits, i) => {
    xrog[i] = bits;
  });

  // resize data array from 64x64 to 128x128
  xrog = resize(xrog, 32, 128);

  xrog.forEach((data, i) => {
    cells[i].segments.XROG = xrog[i];
  });
}
