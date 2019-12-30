import _ from 'lodash';
import { data } from './data';
import { ipcMain } from 'electron';

export function get(path: string): string {
  const value: string = _.get(data, path);

  return value;
}

ipcMain.handle('config.get', (event, path) => {
  return get(path);
});
