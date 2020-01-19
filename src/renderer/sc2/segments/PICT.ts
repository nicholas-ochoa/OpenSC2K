import { data } from '../data';

export function PICT(bytes: Buffer) {
  const pict: any = {};

  // similar format to game artwork
  // 4 byte header PICT
  // 4 byte length
  // 4 byte fixed '80 00 00 00'
  // 2 byte image width
  // 2 byes image height
  // [length] bytes = image data, 1 byte per pixel using palette lookup

  pict.raw = bytes;

  data.segments.PICT = pict;
}
