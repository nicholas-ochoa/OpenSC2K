import { config } from 'utils';
import { parse } from './parse';

export function load(fileName?: string): void {
  parse(fileName ?? config.data.paths.cities + '/CAPEQUES.SC2');
}
