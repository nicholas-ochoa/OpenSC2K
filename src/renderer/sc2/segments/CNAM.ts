import { data } from '../data';
import { bytesToAscii } from 'utils';

export function CNAM(bytes: any) {
  const text = bytesToAscii(bytes.subarray(1, bytes.indexOf(0)));
  const raw = bytes.subarray(1, bytes.indexOf(0));

  data.segments.CNAM = {
    text,
    bytes,
    raw,
  };
}
