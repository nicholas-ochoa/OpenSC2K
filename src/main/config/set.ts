import _ from 'lodash';
import { data } from './data';

export function set(path: string, value: any): void {
  _.set(data, path, value);
}
