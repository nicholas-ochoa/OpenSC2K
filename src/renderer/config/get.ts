import _ from 'lodash';
import { data } from './data';

export function get(path: string): string {
  const value: string = _.get(data, path);

  return value;
}
