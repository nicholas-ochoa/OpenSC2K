import { data } from '../data';
import { bytesToAscii } from 'utils';

export function XLAB(bytes: any) {
  const xlab = [];

  for (let i = 0; i < 256; i++) {
    const offset = i * 25;
    const length = bytes[offset];
    const text = bytesToAscii(bytes.subarray(offset + 1, offset + 1 + length));

    xlab[i] = {
      text,
      offset,
      length,
    };
  }

  data.segments.XLAB = xlab;
}
