import _ from 'lodash';
import { data } from './data';
import { ipcMain } from 'electron';

export function set(path: string, value: any): void {
  _.set(data, path, value);
}

ipcMain.handle('config.set', (event, path, value) => {
  return set(path, value);
});
