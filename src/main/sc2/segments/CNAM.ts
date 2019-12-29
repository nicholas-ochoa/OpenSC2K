import { segments } from '../data';
import { bytesToAscii } from 'utils';

export function CNAM(data: any) {
  const text = bytesToAscii(data.subarray(1, data.indexOf(0)));
  const raw = data.subarray(1, data.indexOf(0));

  segments.CNAM = {
    text,
    data,
    raw,
  };
}
