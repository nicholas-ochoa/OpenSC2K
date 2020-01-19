import { data } from '../data';
import { bytesToAscii } from '../bytesToAscii';

export function CNAM(bytes: Buffer) {
  const text = bytesToAscii(bytes.subarray(1, bytes.indexOf(0)));

  data.segments.CNAM = text;
}
