import { ipcMain } from 'electron';
import { data } from './data';
import { get } from './get';
import { set } from './set';
import { load } from './load';

export async function register() {
  ipcMain.handle('config.data', event => {
    try {
      return data;
    } catch (err) {
      console.error('handler error', err);
    }
  });

  ipcMain.handle('config.get', (event, path) => {
    try {
      return get(path);
    } catch (err) {
      console.error('handler error', err);
    }
  });

  ipcMain.handle('config.set', (event, path, value) => {
    try {
      set(path, value);
    } catch (err) {
      console.error('handler error', err);
    }
  });

  ipcMain.handle('config.load', () => {
    try {
      load();
    } catch (err) {
      console.error('handler error', err);
    }
  });
}
