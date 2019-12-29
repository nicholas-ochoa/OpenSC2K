import config from 'config';
import { parse } from './parse';

export function load(fileName?: string): void {
  parse(fileName ?? config.get<string>('paths.cities') + '/CAPEQUES.SC2');
}
