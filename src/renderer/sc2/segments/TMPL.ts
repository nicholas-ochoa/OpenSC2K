import { data } from '../data';

export function TMPL(bytes: Buffer) {
  const tmpl: any = {};

  tmpl.raw = bytes;

  data.segments.TMPL = tmpl;
}
