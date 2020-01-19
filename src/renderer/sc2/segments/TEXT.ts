import { data } from '../data';
import { bytesToAscii } from '../bytesToAscii';

export function TEXT(bytes: Buffer) {
  const text: any = {};

  text.text = bytesToAscii(bytes.subarray(4));
  text.raw = bytes;

  data.segments.TEXT = text;
}
