import { ipcMain } from 'electron';
import config from 'config';
import { parse } from './parse';
import { data } from './data';

export function load(fileName?: string): void {
  parse(fileName ?? config.get('paths.cities') + '/CAPEQUES.SC2');
}

ipcMain.handle('sc2.load', (event, filePath) => {
  load(filePath);
  return data;
});
