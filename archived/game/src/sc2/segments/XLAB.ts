import { segments } from '../data';
import { bytesToAscii } from 'utils';

export function XLAB(data: any) {
  const xlab = [];

  for (let i = 0; i < 256; i++) {
    const offset = i * 25;
    const length = data[offset];
    const text = bytesToAscii(data.subarray(offset + 1, offset + 1 + length));

    xlab[i] = {
      text,
      offset,
      length,
    };
  }

  segments.XLAB = xlab;
}
