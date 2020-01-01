import { data } from '../data';

export function TMPL(bytes: any) {
  const tmpl: any = {};

  tmpl.raw = bytes;

  data.segments.TMPL = tmpl;
}
