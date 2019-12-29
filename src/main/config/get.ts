import _ from 'lodash';
import { data } from './data';
import { ipcMain } from 'electron';

export function get<T>(path: string): T {
  const value: any = _.get(data, path, undefined);

  return value as T;
}

ipcMain.handle('config.get', (event, path) => {
  return get<string>(path);
});
