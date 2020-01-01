import { ipcMain } from 'electron';
import { data } from './data';
import { load } from './load';

export async function register() {
  ipcMain.handle('tiles.data', event => {
    try {
      return data;
    } catch (err) {
      console.error('handler error', err);
    }
  });

  ipcMain.handle('tiles.load', () => {
    try {
      load();
    } catch (err) {
      console.error('handler error', err);
    }
  });
}
