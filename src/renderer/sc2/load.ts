import config from 'config';
import { data } from './data';
import { parse } from './parse';

export function load(fileName?: string): void {
  data.info = {};
  data.cells = [];
  data.segments = {};

  console.time('load');
  parse(fileName ?? config.get('paths.cities') + '/DEFAULT.SC2');
  console.timeEnd('load');
}
