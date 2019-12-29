import { segments } from '../data';
import { bytesToAscii } from 'utils';

export function TEXT(data: any) {
  const text: any = {};

  text.text = bytesToAscii(data.subarray(4));
  text.raw = data;

  segments.TEXT = text;
}
