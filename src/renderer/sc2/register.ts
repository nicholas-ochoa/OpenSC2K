import { ipcMain } from 'electron';
import { load } from './load';
import { data } from './data';

export async function register() {
  ipcMain.handle('sc2.load', (event, filePath) => {
    try {
      load(filePath);
    } catch (err) {
      console.error('handler error', err);
    }
  });

  ipcMain.handle('sc2.data', event => {
    try {
      return data;
    } catch (err) {
      console.error('handler error', err);
    }
  });
}
