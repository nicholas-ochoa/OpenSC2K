import { segments } from '../data';

export function TMPL(data: any) {
  const tmpl: any = {};

  tmpl.raw = data;

  segments.TMPL = tmpl;
}
