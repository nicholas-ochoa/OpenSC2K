import { data } from '../data';
import { bytesToAscii } from 'utils';

export function TEXT(bytes: any) {
  const text: any = {};

  text.text = bytesToAscii(bytes.subarray(4));
  text.raw = bytes;

  data.segments.TEXT = text;
}
