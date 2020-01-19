import { data } from '../data';
import { bytesToAscii } from '../bytesToAscii';

export function XLAB(bytes: Buffer) {
  const xlab = [];

  for (let i = 0; i < 256; i++) {
    const offset = i * 25;
    const length = bytes[offset];
    const text = bytesToAscii(bytes.subarray(offset + 1, offset + 1 + length));

    if (text) {
      xlab[i] = text;
    }
  }

  data.segments.XLAB = xlab;
}
